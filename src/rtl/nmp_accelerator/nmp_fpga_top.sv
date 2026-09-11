`timescale 1ps / 1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"

/******************************************************************************/
/* NMP FPGA TOP - implementation entry point for controller + accelerator     */
/*                                                                            */
/* The counterpart of HBM_controller_fpga_top for the NMP build: the same      */
/* controller, with the accelerator on channel 0 instead of a read strobe.     */
/* Pick one or the other as the top; both build with or without DEBUG.         */
/*                                                                            */
/* Until 2026-09-11 this file required DEBUG, because P_REQ_ID_WIDTH was 4     */
/* without it and the accelerator needs 15. That is fixed at the source now:   */
/* hbm_controller.svh carries one width for every build.                       */
/*                                                                            */
/* Like the controller-only top, this one has to keep the design alive: a      */
/* netlist whose inputs are tied off and whose outputs go nowhere is optimised */
/* away and reports a meaningless zero. So:                                    */
/*   - q_h is filled from an LFSR, not from constants;                         */
/*   - a job is restarted every LP_RESTART cycles, for ever;                   */
/*   - every output of the engine is folded into one register and out on one   */
/*     pin, so nothing downstream can be pruned.                               */
/* None of this stimulus is the design under measurement: it is a few hundred  */
/* LUTs, and report_utilization -hierarchical keeps it separate.               */
/*                                                                            */
/* The engine sits on channel 0 and runs on dfi_clk_buf[0], the same clock the */
/* testbench uses. Channels 1..15 keep their request ports tied off.           */
/******************************************************************************/

module nmp_fpga_top (
    input  wire HBM_REF_CLK_0,
    input  wire ARESET_N_0,
    input  wire APB_PCLK_0,
    input  wire APB_PRESET_N_0,
    input  wire ARESET_N_1,
    input  wire APB_PCLK_1,
    input  wire APB_PRESET_N_1,
    output wire hbm_cattrip_output,
    output wire nmp_status_o                  /* everything the engine produces, folded */
);

localparam int NCH = 16;
localparam int DW  = P_DATA_WIDTH;

/* Job under measurement: the context length and the two regions. S = 256 is
   the point every cycle number in doc/nmp/CHANGELOG.md refers to.            */
localparam logic [P_NMP_SEQ_WIDTH-1:0]      LP_SEQ_LEN    = 12'd256;
localparam logic [P_NMP_BLK_ADDR_WIDTH-1:0] LP_BASE_K_BLK = 24'h000000;
localparam logic [P_NMP_BLK_ADDR_WIDTH-1:0] LP_BASE_V_BLK = 24'h010000;
/* a fresh job every so many channel cycles, comfortably longer than one job */
localparam int LP_RESTART = 20000;

/**************************************/
/* APB clock: one IBUF + BUFG here     */
/**************************************/
/* Same reason as in HBM_controller_fpga_top: APB_PCLK_0 must not reach both an
   IBUF inside the core and fabric flops, so the core is told it is buffered. */
wire apb_ibuf_o;
wire apb_clk_g;
IBUF u_apb_ibuf ( .I (APB_PCLK_0), .O (apb_ibuf_o) );
BUFG u_apb_bufg ( .I (apb_ibuf_o), .O (apb_clk_g)  );

/**************************************/
/* Controller interface                */
/**************************************/
wire                      dfi_clk_buf          [0:NCH-1];

wire [31:0]               address              [0:NCH-1];
wire [1:0]                request              [0:NCH-1];
wire [DW-1:0]             write_data           [0:NCH-1];
wire                      request_valid        [0:NCH-1];
wire                      request_picked       [0:NCH-1];
wire                      reset_hbm_controller [0:NCH-1];
wire [P_REQ_ID_WIDTH-1:0] request_id           [0:NCH-1];

wire                      rd_data_valid_ps0    [0:NCH-1];
wire                      rd_data_valid_ps1    [0:NCH-1];
wire [P_REQ_ID_WIDTH-1:0] rd_data_req_id_ps0   [0:NCH-1];
wire [DW-1:0]             rd_data_ps0          [0:NCH-1];
wire [P_REQ_ID_WIDTH-1:0] rd_data_req_id_ps1   [0:NCH-1];
wire [DW-1:0]             rd_data_ps1          [0:NCH-1];

wire ch0_clk   = dfi_clk_buf[0];
wire ch0_reset = reset_hbm_controller[0];

/**************************************/
/* Engine                              */
/**************************************/
logic                           q_wr_en;
logic [P_NMP_BLK_IDX_WIDTH-1:0] q_wr_idx;
logic [DW-1:0]                  q_wr_data;
logic                           eng_start;

wire                            eng_busy;
wire                            eng_done;
wire                            o_valid;
wire [P_NMP_OUT_IDX_WIDTH-1:0]  o_idx;
wire [31:0]                     o_data;
wire [31:0]                     l_data;
wire signed [31:0]              m_data;

wire [31:0] cyc_pass_k, cyc_softmax, cyc_pass_v, cyc_total;
wire [31:0] stall_credit_cnt, wait_picked_cnt, starve_cnt, n_beats, n_dropped;
wire        arith_overflow;

wire [31:0]               eng_address;
wire [1:0]                eng_request;
wire [DW-1:0]             eng_write_data;
wire [P_REQ_ID_WIDTH-1:0] eng_request_id;
wire                      eng_request_valid;

nmp_head_engine u_engine (
    .clock_i              (ch0_clk),
    .reset_ni             (ch0_reset),
    .q_wr_en_i            (q_wr_en),
    .q_wr_idx_i           (q_wr_idx),
    .q_wr_data_i          (q_wr_data),
    .start_i              (eng_start),
    .base_k_blk_i         (LP_BASE_K_BLK),
    .base_v_blk_i         (LP_BASE_V_BLK),
    .seq_len_i            (LP_SEQ_LEN),
    .busy_o               (eng_busy),
    .done_o               (eng_done),
    .o_valid_o            (o_valid),
    .o_idx_o              (o_idx),
    .o_o                  (o_data),
    .l_o                  (l_data),
    .m_o                  (m_data),
    .address_o            (eng_address),
    .request_o            (eng_request),
    .write_data_o         (eng_write_data),
    .request_id_o         (eng_request_id),
    .request_valid_o      (eng_request_valid),
    .request_picked_i     (request_picked[0]),
    .rd_data_valid_ps0_i  (rd_data_valid_ps0[0]),
    .rd_data_req_id_ps0_i (rd_data_req_id_ps0[0]),
    .rd_data_ps0_i        (rd_data_ps0[0]),
    .rd_data_valid_ps1_i  (rd_data_valid_ps1[0]),
    .rd_data_req_id_ps1_i (rd_data_req_id_ps1[0]),
    .rd_data_ps1_i        (rd_data_ps1[0]),
    .cyc_pass_k_o         (cyc_pass_k),
    .cyc_softmax_o        (cyc_softmax),
    .cyc_pass_v_o         (cyc_pass_v),
    .cyc_total_o          (cyc_total),
    .stall_credit_cnt_o   (stall_credit_cnt),
    .wait_picked_cnt_o    (wait_picked_cnt),
    .starve_cnt_o         (starve_cnt),
    .n_beats_o            (n_beats),
    .n_dropped_o          (n_dropped),
    .arith_overflow_o     (arith_overflow)
);

/* channel 0 is driven by the engine, the others stay quiet */
genvar gj;
generate
    for ( gj = 0; gj < NCH; gj++ ) begin : g_drive
        if ( gj == 0 ) begin : g_ch0
            assign address[gj]       = eng_address;
            assign request[gj]       = eng_request;
            assign write_data[gj]    = eng_write_data;
            assign request_valid[gj] = eng_request_valid;
            assign request_id[gj]    = eng_request_id;
        end
        else begin : g_idle
            assign address[gj]       = 32'd0;
            assign request[gj]       = 2'd0;
            assign write_data[gj]    = { DW { 1'b0 } };
            assign request_valid[gj] = 1'b0;
            assign request_id[gj]    = { P_REQ_ID_WIDTH { 1'b0 } };
        end
    end
endgenerate

/**************************************/
/* Stimulus, so nothing is optimised   */
/* away. Not the design under test.    */
/**************************************/
logic [31:0] r_lfsr;
logic [31:0] r_gap;
logic [3:0]  r_qcnt;
logic        r_qload;

always @ ( posedge ch0_clk or negedge ch0_reset ) begin
    if ( ch0_reset == 1'b0 ) begin
        r_lfsr    <= 32'h1234_5678;
        r_gap     <= 32'd0;
        r_qcnt    <= 4'd0;
        r_qload   <= 1'b1;
        q_wr_en   <= 1'b0;
        q_wr_idx  <= { P_NMP_BLK_IDX_WIDTH { 1'b0 } };
        q_wr_data <= { DW { 1'b0 } };
        eng_start <= 1'b0;
    end
    else begin
        /* 32 bit maximal length LFSR, taps 32,22,2,1 */
        r_lfsr    <= { r_lfsr[30:0], r_lfsr[31] ^ r_lfsr[21] ^ r_lfsr[1] ^ r_lfsr[0] };
        eng_start <= 1'b0;
        q_wr_en   <= 1'b0;

        if ( r_qload ) begin
            /* 8 beats of q, built from the LFSR so they are not constants */
            q_wr_en   <= 1'b1;
            q_wr_idx  <= r_qcnt[P_NMP_BLK_IDX_WIDTH-1:0];
            q_wr_data <= { 8 { r_lfsr } };
            if ( r_qcnt == P_NMP_BLK_PER_ROW - 1 ) begin
                r_qload <= 1'b0;
                r_qcnt  <= 4'd0;
            end
            else begin
                r_qcnt <= r_qcnt + 1'b1;
            end
        end
        else if ( ~eng_busy ) begin
            if ( r_gap >= LP_RESTART - 1 ) begin
                r_gap     <= 32'd0;
                eng_start <= 1'b1;
            end
            else begin
                r_gap <= r_gap + 1'b1;
            end
        end
    end
end

/* Fold every output into one flop: without this the tool prunes the whole
   output path, the accumulators with it, and the area report is a fiction. */
logic r_status;

always @ ( posedge ch0_clk or negedge ch0_reset ) begin
    if ( ch0_reset == 1'b0 ) begin
        r_status <= 1'b0;
    end
    else begin
        r_status <= r_status
                  ^ ^{ o_data, l_data, m_data }
                  ^ ^{ o_idx, o_valid, eng_busy, eng_done, arith_overflow }
                  ^ ^{ cyc_pass_k, cyc_softmax, cyc_pass_v, cyc_total }
                  ^ ^{ stall_credit_cnt, wait_picked_cnt, starve_cnt }
                  ^ ^{ n_beats, n_dropped };
    end
end

assign nmp_status_o = r_status;

(* DONT_TOUCH = "yes" *)
HBM_controller_top #(
    .P_APB_PCLK0_BUFFERED(1)
) u_hbm_core (
    .HBM_REF_CLK_0       (HBM_REF_CLK_0),
    .ARESET_N_0          (ARESET_N_0),
    .APB_PCLK_0          (apb_clk_g),
    .APB_PRESET_N_0      (APB_PRESET_N_0),
    .ARESET_N_1          (ARESET_N_1),
    .APB_PCLK_1          (APB_PCLK_1),
    .APB_PRESET_N_1      (APB_PRESET_N_1),
    .dfi_clk_buf         (dfi_clk_buf),
    .hbm_cattrip_output  (hbm_cattrip_output),
    .address             (address),
    .request             (request),
    .write_data          (write_data),
    .request_valid       (request_valid),
    .request_picked      (request_picked),
    .reset_hbm_controller(reset_hbm_controller),
    .request_id          (request_id),
    .rd_data_valid_ps0   (rd_data_valid_ps0),
    .rd_data_valid_ps1   (rd_data_valid_ps1),
    .rd_data_req_id_ps0  (rd_data_req_id_ps0),
    .rd_data_ps0         (rd_data_ps0),
    .rd_data_req_id_ps1  (rd_data_req_id_ps1),
    .rd_data_ps1         (rd_data_ps1)
);

endmodule
