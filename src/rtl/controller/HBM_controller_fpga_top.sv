`timescale 1ps / 1ps
// Minimal-pin top for Vivado synthesis/implementation (e.g. Alveo U50).
// Instantiates HBM_controller_top with clocks/resets/APB on package pins only.
// Per-channel stimulus buses and dfi_clk_buf[] stay internal (not top-level ports).
//
// Tie-off-only stimulus is optimized away (empty netlist, WNS inf). This wrapper
// includes a slow APB clock-domain read strobe (round-robin channels) so request
// paths stay live for synthesis/implementation.
//
// APB_PCLK_0 must not fan out to both an IBUF (inside HBM_controller_top) and
// fabric flops; one IBUF+BUFG is instantiated here and the core uses
// P_APB_PCLK0_BUFFERED=1 (BUFG only inside).
//
// Compile this with DEBUG undefined so HBM_controller_top exposes the non-DEBUG
// port list (P_REQ_ID_WIDTH = 4 in hbm_controller.svh). Simulation should keep
// using HBM_controller_top_tb -> HBM_controller_top directly.

module HBM_controller_fpga_top (
    input  wire HBM_REF_CLK_0,
    input  wire ARESET_N_0,
    input  wire APB_PCLK_0,
    input  wire APB_PRESET_N_0,
    input  wire ARESET_N_1,
    input  wire APB_PCLK_1,
    input  wire APB_PRESET_N_1,
    output wire hbm_cattrip_output
);

`ifdef DEBUG
    // Simulation uses HBM_controller_top_tb -> HBM_controller_top (+DEBUG) directly.
    assign hbm_cattrip_output = 1'b0;
`else
    localparam int NCH = 16;
    localparam int DW  = 256;
    // Must match P_REQ_ID_WIDTH when `DEBUG is not defined (hbm_controller.svh).
    localparam int REQ_ID_W = 4;

    // APB cycles between read strobes; hold valid this many APB cycles (coarse vs request_picked).
    localparam int STIM_GAP   = 1024;
    localparam int HOLD_APB   = 64;

    wire apb_ibuf_o;
    wire apb_clk_g;
    IBUF u_fpga_apb_ibuf (
        .I (APB_PCLK_0),
        .O (apb_ibuf_o)
    );
    BUFG u_fpga_apb_bufg (
        .I (apb_ibuf_o),
        .O (apb_clk_g)
    );

    wire dfi_clk_buf [0:NCH-1];

    wire [31:0]               address              [0:NCH-1];
    wire [1:0]                request              [0:NCH-1];
    wire [DW-1:0]             write_data           [0:NCH-1];
    wire                      request_valid        [0:NCH-1];
    wire                      request_picked       [0:NCH-1];
    wire                      reset_hbm_controller [0:NCH-1];
    wire [REQ_ID_W-1:0]       request_id           [0:NCH-1];

    wire                      rd_data_valid_ps0    [0:NCH-1];
    wire                      rd_data_valid_ps1    [0:NCH-1];
    wire [REQ_ID_W-1:0]       rd_data_req_id_ps0   [0:NCH-1];
    wire [DW-1:0]             rd_data_ps0          [0:NCH-1];
    wire [REQ_ID_W-1:0]       rd_data_req_id_ps1   [0:NCH-1];
    wire [DW-1:0]             rd_data_ps1          [0:NCH-1];

    reg [31:0] gap_ctr;
    reg [$clog2(HOLD_APB)-1:0] hold_ctr;
    reg strobing;
    reg [$clog2(NCH)-1:0] strobe_ch;
    reg [$clog2(NCH)-1:0] rr_ch;
    reg [31:0] ch_addr [0:NCH-1];

    integer ac;
    always @(posedge apb_clk_g or negedge APB_PRESET_N_0) begin
        if (!APB_PRESET_N_0) begin
            gap_ctr   <= '0;
            hold_ctr  <= '0;
            strobing  <= 1'b0;
            strobe_ch <= '0;
            rr_ch     <= '0;
            for (ac = 0; ac < NCH; ac = ac + 1)
                ch_addr[ac] <= 32'd0;
        end else begin
            if (!strobing) begin
                if (gap_ctr >= STIM_GAP - 1) begin
                    strobing  <= 1'b1;
                    strobe_ch <= rr_ch;
                    hold_ctr  <= ($clog2(HOLD_APB))'(HOLD_APB - 1);
                    gap_ctr   <= '0;
                    ch_addr[rr_ch] <= ch_addr[rr_ch] + 32'd4096;
                    if (rr_ch == NCH - 1)
                        rr_ch <= '0;
                    else
                        rr_ch <= rr_ch + 1'b1;
                end else
                    gap_ctr <= gap_ctr + 1'b1;
            end else begin
                if (hold_ctr != '0)
                    hold_ctr <= hold_ctr - 1'b1;
                else
                    strobing <= 1'b0;
            end
        end
    end

    genvar gj;
    generate
        for (gj = 0; gj < NCH; gj++) begin : g_drv
            assign write_data[gj]    = '0;
            assign request_id[gj]    = '0;
            assign address[gj]       = ch_addr[gj];
            assign request[gj]       = (strobing && (strobe_ch == gj)) ? 2'b01 : 2'b00;
            assign request_valid[gj] = strobing && (strobe_ch == gj);
        end
    endgenerate

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
`endif

endmodule
