`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/27/2023 09:42:34 AM
// Design Name: 
// Module Name: HBM_controller_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module HBM_controller_top#
(
    parameter N_CHANNELS   = 16, /* Number of enabled channels */
    parameter P_DATA_WIDTH = 256,
    parameter P_BA_N_PS    = 16,         /* Number of Banks per group */

    /* FIFO QUEUE LEN */
    parameter P_QUEUE_LEN  = 8,
    
    /* REQ and CMD IDs */
    parameter P_REQ_ID_WIDTH = $clog2(P_BA_N_PS*P_QUEUE_LEN*2),
    parameter P_CMD_ID_WIDTH = 32'd3

)

(
    input HBM_REF_CLK_0,
    input ARESET_N_0,
    input APB_PCLK_0,
    input APB_PRESET_N_0,
    
//    input HBM_REF_CLK_1,
    input ARESET_N_1,
    input APB_PCLK_1,
    input APB_PRESET_N_1,

    // input [31:0]address,
    // input [256-1:0]write_data,
    // input [1:0]request,

    output hbm_cattrip_output,

    `ifndef DEBUG
        output        done,
        input  [1:0]  request [0:N_CHANNELS-1],
        input  [31:0] address [0:N_CHANNELS-1],
        input                       request_valid        [0:N_CHANNELS-1],
        output                      request_picked       [0:N_CHANNELS-1]
        // output [P_REQ_ID_WIDTH-1:0] rd_data_req_id_ps0   [0:16-1],
        // output [P_REQ_ID_WIDTH-1:0] rd_data_req_id_ps1   [0:16-1],

    `endif

    `ifdef DEBUG
        input  [31:0]               address              [0:16-1],
        input  [1:0]                request              [0:16-1],
        input  [P_DATA_WIDTH-1:0]   write_data           [0:16-1],
        input                       request_valid        [0:16-1],
        output                      request_picked       [0:16-1],
        output                      reset_hbm_controller [0:16-1],

        output [P_REQ_ID_WIDTH-1:0] rd_data_req_id_ps0   [0:16-1],
        output [P_DATA_WIDTH-1:0]   rd_data_ps0          [0:16-1],
        output [P_REQ_ID_WIDTH-1:0] rd_data_req_id_ps1   [0:16-1],
        output [P_DATA_WIDTH-1:0]   rd_data_ps1          [0:16-1]
    `endif

);

localparam MMCM_CLKFBOUT_MULT_F  = 9;
localparam MMCM_CLKOUT0_DIVIDE_F = 2;
localparam MMCM_DIVCLK_DIVIDE    = 1;
localparam MMCM_CLKIN1_PERIOD    = 10.000;

/*(* keep = "TRUE" *)*/ wire HBM_REF_CLK_buf_0;
/*(* keep = "TRUE" *)*/ wire HBM_REF_CLK_buf_1;
/*(* keep = "TRUE" *)*/ wire dfi_clk_buf[0:15] /*[0:N_CHANNELS-1]*/;
/*(* keep = "TRUE" *)*/ wire dfi_clk_in[0:15] /*[0:N_CHANNELS-1]*/;
/*(* keep = "TRUE" *)*/ wire MMCM_LOCK_0;
/*(* keep = "TRUE" *)*/ wire MMCM_LOCK_1;

/*(* keep = "TRUE" *)*/ wire      APB_PCLK_IBUF_0;
/*(* keep = "TRUE" *)*/ wire      APB_PCLK_BUF_0;
/*(* keep = "TRUE" *)*/ wire      APB_PRESET_N_sync_0;
/*(* keep = "TRUE" *)*/ wire      APB_PCLK_IBUF_1;
/*(* keep = "TRUE" *)*/ wire      APB_PCLK_BUF_1;
/*(* keep = "TRUE" *)*/ wire      APB_PRESET_N_sync_1;


wire	[3:0]		w_rst_sys_rst;
reg  [7:0] cnt_rst_0;
reg  rst_mmcm_n;

reg	[7:0]	cnt_apb_rst_p2l_st0;
wire		w_apb_reset_n_inv_st0;
reg			r_apb_preset_n_p2l_st0; 

wire	[3:0]		w_rst_sys_rst_1;
reg  [7:0] cnt_rst_0_1;
reg  rst_mmcm_n_1;

reg	[7:0]	cnt_apb_rst_p2l_st0_1;
wire		w_apb_reset_n_inv_st0_1;
reg			r_apb_preset_n_p2l_st0_1;

wire           dfi_init_start[0:16-1];
wire   [1:0]   dfi_aw_ck_p0[0:16-1];
wire   [1:0]   dfi_aw_cke_p0[0:16-1];
wire   [11:0]  dfi_aw_row_p0[0:16-1];
wire   [15:0]  dfi_aw_col_p0[0:16-1];
wire   [255:0] dfi_dw_wrdata_p0[0:16-1];
wire   [31:0]  dfi_dw_wrdata_mask_p0[0:16-1];
wire   [31:0]  dfi_dw_wrdata_dbi_p0[0:16-1];
wire   [7:0]   dfi_dw_wrdata_par_p0[0:16-1];
wire   [7:0]   dfi_dw_wrdata_dq_en_p0[0:16-1];
wire   [7:0]   dfi_dw_wrdata_par_en_p0[0:16-1];
wire   [1:0]   dfi_aw_ck_p1[0:16-1];
wire   [1:0]   dfi_aw_cke_p1[0:16-1];
wire   [11:0]  dfi_aw_row_p1[0:16-1];
wire   [15:0]  dfi_aw_col_p1[0:16-1];
wire   [255:0] dfi_dw_wrdata_p1[0:16-1];
wire   [31:0]  dfi_dw_wrdata_mask_p1[0:16-1];
wire   [31:0]  dfi_dw_wrdata_dbi_p1[0:16-1];
wire   [7:0]   dfi_dw_wrdata_par_p1[0:16-1];
wire   [7:0]   dfi_dw_wrdata_dq_en_p1[0:16-1];
wire   [7:0]   dfi_dw_wrdata_par_en_p1[0:16-1];
wire           dfi_aw_ck_dis[0:16-1];
wire           dfi_lp_pwr_e_req[0:16-1];
wire           dfi_lp_sr_e_req[0:16-1];
wire           dfi_lp_pwr_x_e_req[0:16-1];
wire           dfi_lp_pwr_x_req[0:16-1];
wire           dfi_aw_tx_indx_ld[0:16-1];
wire           dfi_dw_tx_indx_ld[0:16-1];
wire           dfi_dw_rx_indx_ld[0:16-1];
wire           dfi_ctrlupd_ack[0:16-1];
wire           dfi_phyupd_req[0:16-1];
wire           dfi_init_complete[0:16-1];
wire   [255:0] dfi_dw_rddata_p0[0:16-1];
wire   [31:0]  dfi_dw_rddata_dm_p0[0:16-1];
wire   [31:0]  dfi_dw_rddata_dbi_p0[0:16-1];
wire   [7:0]   dfi_dw_rddata_par_p0[0:16-1];
wire   [255:0] dfi_dw_rddata_p1[0:16-1];
wire   [31:0]  dfi_dw_rddata_dm_p1[0:16-1];
wire   [31:0]  dfi_dw_rddata_dbi_p1[0:16-1];
wire   [7:0]   dfi_dw_rddata_par_p1[0:16-1];
wire   [15:0]  dfi_dbi_byte_disable[0:16-1];
wire   [3:0]   dfi_dw_rddata_valid[0:16-1];
wire   [7:0]   dfi_dw_derr_n[0:16-1];
wire   [1:0]   dfi_aw_aerr_n[0:16-1];
wire           dfi_ctrlupd_req[0:16-1];
wire           dfi_phyupd_ack[0:16-1];
wire           dfi_clk_init[0:16-1];
wire           dfi_out_rst_n[0:16-1];
wire   [7:0]   dfi_dw_wrdata_dqs_p0[0:16-1];
wire   [7:0]   dfi_dw_wrdata_dqs_p1[0:16-1];

wire          DRAM_STAT_CATTRIP;
wire   [6:0]  DRAM_STAT_TEMP;

wire      [31:0]  APB_PRDATA;
wire              APB_PREADY;
wire              APB_PSLVERR;
wire              apb_seq_complete_s;
wire              apb_seq_complete_s_1;
wire              apb_seq_complete_s_2;

reg          dfi_rst_n[0:16-1];
reg          rst_r1_n;
reg          rst_r1_n_1;
reg          rst_r1_n_2;

reg          rst0_st0_r1_n[0:16-1];
reg          rst0_st0_r2_n[0:16-1];
reg          rst_st0_n;
reg          rst_st1_n;

reg           w_rst_sys_rst_r1;
reg           w_rst_sys_rst_r2;
reg           w_rst_sys_rst_1_r1;
reg           w_rst_sys_rst_1_r2;

reg           rst_mmcm;
reg  [3:0]    cnt_rst;



reg          rst_st0_n_1;
reg          rst_st1_n_1;

reg           w_rst_sys_rst_r1_1;
reg           w_rst_sys_rst_r2_1;
reg           w_rst_sys_rst_1_r1_1;
reg           w_rst_sys_rst_1_r2_1;

reg           rst_mmcm_1;
reg  [3:0]    cnt_rst_1;


    
    always @ (posedge HBM_REF_CLK_buf_0 or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            cnt_rst_0        <= 8'h00;
            rst_mmcm_n     <= 1'b0;
        end else begin
            if (~rst_r1_n) begin
                if( cnt_rst_0 >= 8'd100 ) begin
                    cnt_rst_0 <= cnt_rst_0;
                    rst_mmcm_n <= 1'b0;
                end
                else begin
                    cnt_rst_0 <= cnt_rst_0 + 1;
                    rst_mmcm_n <= rst_mmcm_n;
                end
            end else begin
                cnt_rst_0 <= 'd0;
                rst_mmcm_n <= 1'b1;
            end
        end
    end


    always @ (posedge HBM_REF_CLK_buf_0 or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            rst_mmcm  <= 1'b0;
        end else begin
            if (cnt_rst != 4'h0) begin
                rst_mmcm <= 1'b0;
            end else begin
                rst_mmcm <= 1'b1;
            end
        end
    end


    always @ (posedge HBM_REF_CLK_buf_0 or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            w_rst_sys_rst_r1 <= 1'b0;
            w_rst_sys_rst_r2 <= 1'b0;
        end else begin
            w_rst_sys_rst_r1 <= w_rst_sys_rst;
            w_rst_sys_rst_r2 <= w_rst_sys_rst_r1;
        end
    end

    always @ (posedge HBM_REF_CLK_buf_0 or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            rst_st0_n <= 1'b0;
        end else begin
            rst_st0_n <= rst_mmcm & MMCM_LOCK_0 & (~w_rst_sys_rst_r2);
        end
    end
    

    always @ (posedge HBM_REF_CLK_buf_0 or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            cnt_rst <= 4'hA;
        end else begin
            if (~rst_r1_n) begin
                cnt_rst <= 4'hA;
            end else if (cnt_rst != 4'h0) begin
                cnt_rst <= cnt_rst - 1'b1;
            end else begin
                cnt_rst <= cnt_rst;
            end
        end
    end

    always @ (posedge HBM_REF_CLK_buf_0 or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            rst_r1_n <= 1'b0;
        end else begin
            rst_r1_n <= 1'b1;
        end
    end

    assign w_rst_sys_rst = 4'h0;
    assign	w_apb_reset_n_inv_st0 = APB_PRESET_N_0 && ~w_rst_sys_rst;
    always @ ( posedge APB_PCLK_BUF_0 or negedge  w_apb_reset_n_inv_st0 )
    begin
        if( w_apb_reset_n_inv_st0 == 1'b0 )
            begin
                cnt_apb_rst_p2l_st0 <= 8'd0;
                r_apb_preset_n_p2l_st0 <= 1'd0;
            end
        else
            begin
                if( cnt_apb_rst_p2l_st0 >= 8'd200 )
                begin
                    r_apb_preset_n_p2l_st0	<= 1'd1;
                    cnt_apb_rst_p2l_st0		<= cnt_apb_rst_p2l_st0;
                end
                else
                begin
                    cnt_apb_rst_p2l_st0		<= cnt_apb_rst_p2l_st0 + 8'd1;
                    r_apb_preset_n_p2l_st0 <= 1'b0;
                end
            end
    end

    assign APB_PRESET_N_sync_0 = r_apb_preset_n_p2l_st0;





    always @ (posedge HBM_REF_CLK_buf_1 or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            cnt_rst_0_1        <= 8'h00;
            rst_mmcm_n_1     <= 1'b0;
        end else begin
            if (~rst_r1_n_1) begin
                if( cnt_rst_0_1 >= 8'd100 ) begin
                    cnt_rst_0_1 <= cnt_rst_0_1;
                    rst_mmcm_n_1 <= 1'b0;
                end
                else begin
                    cnt_rst_0_1 <= cnt_rst_0_1 + 1;
                    rst_mmcm_n_1 <= rst_mmcm_n_1;
                end
            end else begin
                cnt_rst_0_1 <= 'd0;
                rst_mmcm_n_1 <= 1'b1;
            end
        end
    end


    always @ (posedge HBM_REF_CLK_buf_1 or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            rst_mmcm_1  <= 1'b0;
        end else begin
            if (cnt_rst_1 != 4'h0) begin
                rst_mmcm_1 <= 1'b0;
            end else begin
                rst_mmcm_1 <= 1'b1;
            end
        end
    end


    always @ (posedge HBM_REF_CLK_buf_1 or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            w_rst_sys_rst_r1_1 <= 1'b0;
            w_rst_sys_rst_r2_1 <= 1'b0;
        end else begin
            w_rst_sys_rst_r1_1 <= w_rst_sys_rst_1;
            w_rst_sys_rst_r2_1 <= w_rst_sys_rst_r1_1;
        end
    end

    always @ (posedge HBM_REF_CLK_buf_1 or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            rst_st0_n_1 <= 1'b0;
        end else begin
            rst_st0_n_1 <= rst_mmcm & MMCM_LOCK_1 & (~w_rst_sys_rst_r2_1);
        end
    end
    

    always @ (posedge HBM_REF_CLK_buf_1 or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            cnt_rst_1 <= 4'hA;
        end else begin
            if (~rst_r1_n_1) begin
                cnt_rst_1 <= 4'hA;
            end else if (cnt_rst_1 != 4'h0) begin
                cnt_rst_1 <= cnt_rst_1 - 1'b1;
            end else begin
                cnt_rst_1 <= cnt_rst_1;
            end
        end
    end

    always @ (posedge HBM_REF_CLK_buf_1 or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            rst_r1_n_1 <= 1'b0;
        end else begin
            rst_r1_n_1 <= 1'b1;
        end
    end

    assign w_rst_sys_rst_1 = 4'h0;
    assign	w_apb_reset_n_inv_st0_1 = APB_PRESET_N_1 && ~w_rst_sys_rst_1;
    always @ ( posedge APB_PCLK_BUF_1 or negedge  w_apb_reset_n_inv_st0_1 )
    begin
        if( w_apb_reset_n_inv_st0_1 == 1'b0 )
            begin
                cnt_apb_rst_p2l_st0_1 <= 8'd0;
                r_apb_preset_n_p2l_st0_1 <= 1'd0;
            end
        else
            begin
                if( cnt_apb_rst_p2l_st0_1 >= 8'd200 )
                begin
                    r_apb_preset_n_p2l_st0_1	<= 1'd1;
                    cnt_apb_rst_p2l_st0_1		<= cnt_apb_rst_p2l_st0_1;
                end
                else
                begin
                    cnt_apb_rst_p2l_st0_1		<= cnt_apb_rst_p2l_st0_1 + 8'd1;
                    r_apb_preset_n_p2l_st0_1 <= 1'b0;
                end
            end
    end

    assign APB_PRESET_N_sync_1 = r_apb_preset_n_p2l_st0_1 ;
    

    IBUF u_APB_PCLK_IBUF_0  (
    .I (APB_PCLK_0),
    .O (APB_PCLK_IBUF_0)
    );

    BUFG u_APB_PCLK_BUFG_0  (
    .I (APB_PCLK_IBUF_0),
    .O (APB_PCLK_BUF_0)
    );

    BUFG u_HBM_REF_CLK_0  (
    .I (HBM_REF_CLK_0),
    .O (HBM_REF_CLK_buf_0)
    );
    
    IBUF u_APB_PCLK_IBUF_1  (
    .I (APB_PCLK_1),
    .O (APB_PCLK_IBUF_1)
    );

    BUFG u_APB_PCLK_BUFG_1  (
    .I (APB_PCLK_IBUF_1),
    .O (APB_PCLK_BUF_1)
    );

    BUFG u_HBM_REF_CLK_1  (
    .I (HBM_REF_CLK_0),
    .O (HBM_REF_CLK_buf_1)
    );



    MMCME4_ADV
    #(.BANDWIDTH            ("OPTIMIZED"),
        .CLKOUT4_CASCADE      ("FALSE"),
        .COMPENSATION         ("INTERNAL"),
        .STARTUP_WAIT         ("FALSE"),
        .DIVCLK_DIVIDE        (MMCM_DIVCLK_DIVIDE),
        .CLKFBOUT_MULT_F      (MMCM_CLKFBOUT_MULT_F),
        .CLKFBOUT_PHASE       (0.000),
        .CLKFBOUT_USE_FINE_PS ("FALSE"),
        .CLKOUT0_DIVIDE_F     (MMCM_CLKOUT0_DIVIDE_F),
        .CLKOUT0_PHASE        (0.000),
        .CLKOUT0_DUTY_CYCLE   (0.500),
        .CLKOUT0_USE_FINE_PS  ("FALSE"),
        .CLKOUT1_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
        .CLKOUT2_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
        .CLKOUT3_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
        .CLKOUT4_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
        .CLKOUT5_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
        .CLKOUT6_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
        .CLKIN1_PERIOD        (MMCM_CLKIN1_PERIOD),
        .REF_JITTER1          (0.010))
    u_mmcm_0
        // Output clocks
    (
        .CLKFBOUT            (),
        .CLKFBOUTB           (),
        .CLKOUT0             (dfi_clk_in[0]),

        .CLKOUT0B            (),
        .CLKOUT1             (dfi_clk_in[1]),
        .CLKOUT1B            (),
        .CLKOUT2             (dfi_clk_in[2]),
        .CLKOUT2B            (),
        .CLKOUT3             (dfi_clk_in[3]),
        .CLKOUT3B            (),
        .CLKOUT4             (dfi_clk_in[4]),
        .CLKOUT5             (dfi_clk_in[5]),
        .CLKOUT6             (dfi_clk_in[6]),
        // Input clock control
        .CLKFBIN             (), //mmcm_fb
        .CLKIN1              (HBM_REF_CLK_buf_0),
        .CLKIN2              (1'b0),
        // Other control and status signals
        .LOCKED              (MMCM_LOCK_0),
        .PWRDWN              (1'b0),
        .RST                 (~rst_mmcm_n),
    
        .CDDCDONE            (),
        .CLKFBSTOPPED        (),
        .CLKINSTOPPED        (),
        .DO                  (),
        .DRDY                (),
        .PSDONE              (),
        .CDDCREQ             (1'b0),
        .CLKINSEL            (1'b1),
        .DADDR               (7'b0),
        .DCLK                (1'b0),
        .DEN                 (1'b0),
        .DI                  (16'b0),
        .DWE                 (1'b0),
        .PSCLK               (1'b0),
        .PSEN                (1'b0),
        .PSINCDEC            (1'b0)
    );
    
    if (N_CHANNELS >= 1 /*8*/) begin
        MMCME4_ADV
        #(.BANDWIDTH            ("OPTIMIZED"),
            .CLKOUT4_CASCADE      ("FALSE"),
            .COMPENSATION         ("INTERNAL"),
            .STARTUP_WAIT         ("FALSE"),
            .DIVCLK_DIVIDE        (MMCM_DIVCLK_DIVIDE),
            .CLKFBOUT_MULT_F      (MMCM_CLKFBOUT_MULT_F),
            .CLKFBOUT_PHASE       (0.000),
            .CLKFBOUT_USE_FINE_PS ("FALSE"),
            .CLKOUT0_DIVIDE_F     (MMCM_CLKOUT0_DIVIDE_F),
            .CLKOUT0_PHASE        (0.000),
            .CLKOUT0_DUTY_CYCLE   (0.500),
            .CLKOUT0_USE_FINE_PS  ("FALSE"),
            .CLKOUT1_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
            .CLKOUT2_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
            .CLKOUT3_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
            .CLKOUT4_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
            .CLKOUT5_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
            .CLKOUT6_DIVIDE       (MMCM_CLKOUT0_DIVIDE_F),
            .CLKIN1_PERIOD        (MMCM_CLKIN1_PERIOD),
            .REF_JITTER1          (0.010))
        u_mmcm_1
            // Output clocks
        (
            .CLKFBOUT            (),
            .CLKFBOUTB           (),
            .CLKOUT0             (dfi_clk_in[8]),

            .CLKOUT0B            (),
            .CLKOUT1             (dfi_clk_in[9]),
            .CLKOUT1B            (),
            .CLKOUT2             (dfi_clk_in[10]),
            .CLKOUT2B            (),
            .CLKOUT3             (dfi_clk_in[11]),
            .CLKOUT3B            (),
            .CLKOUT4             (dfi_clk_in[12]),
            .CLKOUT5             (dfi_clk_in[13]),
            .CLKOUT6             (dfi_clk_in[14]),
            // Input clock control
            .CLKFBIN             (), //mmcm_fb
            .CLKIN1              (HBM_REF_CLK_buf_1),
            .CLKIN2              (1'b0),
            // Other control and status signals
            .LOCKED              (MMCM_LOCK_1),
            .PWRDWN              (1'b0),
            .RST                 (~rst_mmcm_n_1),
        
            .CDDCDONE            (),
            .CLKFBSTOPPED        (),
            .CLKINSTOPPED        (),
            .DO                  (),
            .DRDY                (),
            .PSDONE              (),
            .CDDCREQ             (1'b0),
            .CLKINSEL            (1'b1),
            .DADDR               (7'b0),
            .DCLK                (1'b0),
            .DEN                 (1'b0),
            .DI                  (16'b0),
            .DWE                 (1'b0),
            .PSCLK               (1'b0),
            .PSEN                (1'b0),
            .PSINCDEC            (1'b0)
        );
    end
        
    
    

    `ifndef DEBUG
        wire [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps0   [0:16-1];
        wire [P_DATA_WIDTH-1:0]           rd_data_ps0          [0:16-1];
        wire [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps1   [0:16-1];
        wire [P_DATA_WIDTH-1:0]           rd_data_ps1          [0:16-1];

        wire reset_hbm_controller[0:16-1];
        // wire [31:0]address[0:16-1];
        // wire [1:0]request[0:16-1];
        wire [P_DATA_WIDTH-1:0] write_data[0:16-1];

        // reg [31:0] r_address[0:16-1];
        // reg [1:0] r_request[0:16-1];
        reg [P_DATA_WIDTH-1:0] r_wrt_data[0:16-1];
        reg [0:16-1]r_done;

        // assign address = r_address;
        // assign request = r_request;
        assign write_data = r_wrt_data;

        assign done = &r_done[0:N_CHANNELS-1];

        // /*(* keep = "TRUE" *)*/ reg   request_valid  [0:N_CHANNELS-1];
        // /*(* keep = "TRUE" *)*/ wire  request_picked [0:N_CHANNELS-1];
    `endif

    
    always @ (posedge dfi_clk_buf[0] or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            rst0_st0_r1_n[0] <= 1'b0;
            rst0_st0_r2_n[0] <= 1'b0;
        end else begin
            rst0_st0_r1_n[0] <= rst_st0_n;
            rst0_st0_r2_n[0] <= rst0_st0_r1_n[0];
        end
    end
    
    always @ (posedge dfi_clk_buf[1] or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            rst0_st0_r1_n[1] <= 1'b0;
            rst0_st0_r2_n[1] <= 1'b0;
        end else begin
            rst0_st0_r1_n[1] <= rst_st0_n;
            rst0_st0_r2_n[1] <= rst0_st0_r1_n[1];
        end
    end
    
    always @ (posedge dfi_clk_buf[2] or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            rst0_st0_r1_n[2] <= 1'b0;
            rst0_st0_r2_n[2] <= 1'b0;
        end else begin
            rst0_st0_r1_n[2] <= rst_st0_n;
            rst0_st0_r2_n[2] <= rst0_st0_r1_n[2];
        end
    end
    
    always @ (posedge dfi_clk_buf[3] or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            rst0_st0_r1_n[3] <= 1'b0;
            rst0_st0_r2_n[3] <= 1'b0;
        end else begin
            rst0_st0_r1_n[3] <= rst_st0_n;
            rst0_st0_r2_n[3] <= rst0_st0_r1_n[3];
        end
    end
    
    always @ (posedge dfi_clk_buf[4] or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            rst0_st0_r1_n[4] <= 1'b0;
            rst0_st0_r2_n[4] <= 1'b0;
        end else begin
            rst0_st0_r1_n[4] <= rst_st0_n;
            rst0_st0_r2_n[4] <= rst0_st0_r1_n[4];
        end
    end
    
    always @ (posedge dfi_clk_buf[5] or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            rst0_st0_r1_n[5] <= 1'b0;
            rst0_st0_r2_n[5] <= 1'b0;
        end else begin
            rst0_st0_r1_n[5] <= rst_st0_n;
            rst0_st0_r2_n[5] <= rst0_st0_r1_n[5];
        end
    end

    always @ (posedge dfi_clk_buf[6] or negedge ARESET_N_0) begin
        if (~ARESET_N_0) begin
            rst0_st0_r1_n[6] <= 1'b0;
            rst0_st0_r2_n[6] <= 1'b0;
        end else begin
            rst0_st0_r1_n[6] <= rst_st0_n;
            rst0_st0_r2_n[6] <= rst0_st0_r1_n[6];
        end
    end

    always @ (posedge dfi_clk_buf[8] or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            rst0_st0_r1_n[8] <= 1'b0;
            rst0_st0_r2_n[8] <= 1'b0;
        end else begin
            rst0_st0_r1_n[8] <= rst_st0_n_1;
            rst0_st0_r2_n[8] <= rst0_st0_r1_n[8];
        end
    end

    always @ (posedge dfi_clk_buf[9] or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            rst0_st0_r1_n[9] <= 1'b0;
            rst0_st0_r2_n[9] <= 1'b0;
        end else begin
            rst0_st0_r1_n[9] <= rst_st0_n_1;
            rst0_st0_r2_n[9] <= rst0_st0_r1_n[9];
        end
    end


    always @ (posedge dfi_clk_buf[10] or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            rst0_st0_r1_n[10] <= 1'b0;
            rst0_st0_r2_n[10] <= 1'b0;
        end else begin
            rst0_st0_r1_n[10] <= rst_st0_n_1;
            rst0_st0_r2_n[10] <= rst0_st0_r1_n[10];
        end
    end

    always @ (posedge dfi_clk_buf[11] or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            rst0_st0_r1_n[11] <= 1'b0;
            rst0_st0_r2_n[11] <= 1'b0;
        end else begin
            rst0_st0_r1_n[11] <= rst_st0_n_1;
            rst0_st0_r2_n[11] <= rst0_st0_r1_n[11];
        end
    end

    always @ (posedge dfi_clk_buf[12] or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            rst0_st0_r1_n[12] <= 1'b0;
            rst0_st0_r2_n[12] <= 1'b0;
        end else begin
            rst0_st0_r1_n[12] <= rst_st0_n_1;
            rst0_st0_r2_n[12] <= rst0_st0_r1_n[12];
        end
    end

    always @ (posedge dfi_clk_buf[13] or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            rst0_st0_r1_n[13] <= 1'b0;
            rst0_st0_r2_n[13] <= 1'b0;
        end else begin
            rst0_st0_r1_n[13] <= rst_st0_n_1;
            rst0_st0_r2_n[13] <= rst0_st0_r1_n[13];
        end
    end

    always @ (posedge dfi_clk_buf[14] or negedge ARESET_N_1) begin
        if (~ARESET_N_1) begin
            rst0_st0_r1_n[14] <= 1'b0;
            rst0_st0_r2_n[14] <= 1'b0;
        end else begin
            rst0_st0_r1_n[14] <= rst_st0_n_1;
            rst0_st0_r2_n[14] <= rst0_st0_r1_n[14];
        end
    end

genvar i;
generate
for( i = 0; i < N_CHANNELS; i = i+1 ) begin
    if (i == 7 ) begin

        always @ (posedge dfi_clk_buf[6] or negedge ARESET_N_0) begin
            if (~ARESET_N_0) begin
                dfi_rst_n[6] <= 1'b0;
            end else begin
                dfi_rst_n[6] <= rst0_st0_r2_n[6];
            end
        end

        `ifndef DEBUG
            always @(posedge dfi_clk_buf[6] or negedge dfi_rst_n[6]) begin
                if (dfi_rst_n[6] == 1'b0) begin
                    r_done[i] <= 1'b0;
                end
                else begin
                    if ( &rd_data_req_id_ps0[i] && &rd_data_req_id_ps1[i] && rd_data_ps0[i] == {P_DATA_WIDTH{1'b1}} && rd_data_ps1[i] == {P_DATA_WIDTH{1'b0}} ) begin
                        r_done[i] <= 1'b1;
                    end
                    else begin
                        r_done[i] <= 1'b0;
                    end
                end
            end

            always @(posedge dfi_clk_buf[6] or negedge dfi_rst_n[6]) begin
                if (dfi_rst_n[6] == 1'b0) begin
                    // r_address[i] <= {33{1'b0}};
                    // r_request[i] <= 2'b00;
                    r_wrt_data[i] <= {P_DATA_WIDTH { 1'b0 } };
                    // request_valid[i] <= 1'b0;
                end
                else begin
                    // if (request_valid[i] == 1'b0) begin
                        // request_valid[i] <= 1'b1;
                        // r_address[i] <= r_address[i] + 1'b1;
                        r_wrt_data[i] <= r_wrt_data[i] + 32'hAAAABBBB;
                        // if ( r_request[i] == 2'b00 ) begin
                        //     r_request[i] <= 2'b01; 
                        // end
                        // else begin
                        //     r_request[i] <= 2'b00;
                        // end
                    // end
                    // else if (request_valid[i] == 1'b1 && request_picked[i] == 1'b1 ) begin
                    //     request_valid[i] <= 1'b0;
                    // end
                end
            end
        `endif

    end
    else if ( i == 15 ) begin

        always @ (posedge dfi_clk_buf[14] or negedge ARESET_N_1) begin
            if (~ARESET_N_1) begin
                dfi_rst_n[14] <= 1'b0;
            end else begin
                dfi_rst_n[14] <= rst0_st0_r2_n[14];
            end
        end

        `ifndef DEBUG
            always @(posedge dfi_clk_buf[14] or negedge dfi_rst_n[14]) begin
                if (dfi_rst_n[14] == 1'b0) begin
                    r_done[i] <= 1'b0;
                end
                else begin
                    if ( &rd_data_req_id_ps0[i] && &rd_data_req_id_ps1[i] && rd_data_ps0[i] == {P_DATA_WIDTH{1'b1}} && rd_data_ps1[i] == {P_DATA_WIDTH{1'b0}} ) begin
                        r_done[i] <= 1'b1;
                    end
                    else begin
                        r_done[i] <= 1'b0;
                    end
                end
            end

            always @(posedge dfi_clk_buf[14] or negedge dfi_rst_n[14]) begin
                if (dfi_rst_n[14] == 1'b0) begin
                    // r_address[i] <= {33{1'b0}};
                    // r_request[i] <= 2'b00;
                    r_wrt_data[i] <= {P_DATA_WIDTH { 1'b0 } };
                    // request_valid[i] <= 1'b0;
                end
                else begin
                    // if (request_valid[i] == 1'b0) begin
                    //     request_valid[i] <= 1'b1;
                        // r_address[i] <= r_address[i] + 1'b1;
                        r_wrt_data[i] <= r_wrt_data[i] + 32'hAAAABBBB;;
                        // if ( r_request[i] == 2'b00 ) begin
                        //     r_request[i] <= 2'b01; 
                        // end
                        // else begin
                        //     r_request[i] <= 2'b00;
                        // end
                    // end
                    // else if (request_valid[i] == 1'b1 && request_picked[i] == 1'b1 ) begin
                    //     request_valid[i] <= 1'b0;
                    // end
                end
            end
        `endif

    end
    else begin

        if (i > 7 ) begin
            always @ (posedge dfi_clk_buf[i] or negedge ARESET_N_1) begin
                if (~ARESET_N_1) begin
                    dfi_rst_n[i] <= 1'b0;
                end else begin
                    dfi_rst_n[i] <= rst0_st0_r2_n[i];
                end
            end
        end
        else begin 
            always @ (posedge dfi_clk_buf[i] or negedge ARESET_N_0) begin
                if (~ARESET_N_0) begin
                    dfi_rst_n[i] <= 1'b0;
                end else begin
                    dfi_rst_n[i] <= rst0_st0_r2_n[i];
                end
            end
        end 
    

        BUFG u_dfi_clk_buf_0  (
        .I (dfi_clk_in[i]),
        .O (dfi_clk_buf[i])
        );

        `ifndef DEBUG
            always @(posedge dfi_clk_buf[i] or negedge dfi_rst_n[i]) begin
                if (dfi_rst_n[i] == 1'b0) begin
                    r_done[i] <= 1'b0;
                end
                else begin
                    if ( &rd_data_req_id_ps0[i] && &rd_data_req_id_ps1[i] && rd_data_ps0[i] == {P_DATA_WIDTH{1'b1}} && rd_data_ps1[i] == {P_DATA_WIDTH{1'b0}} ) begin
                        r_done[i] <= 1'b1;
                    end
                    else begin
                        r_done[i] <= 1'b0;
                    end
                end
            end

            always @(posedge dfi_clk_buf[i] or negedge dfi_rst_n[i]) begin
                if (dfi_rst_n[i] == 1'b0) begin
                    // r_address[i] <= {33{1'b0}};
                    // r_request[i] <= 2'b00;
                    r_wrt_data[i] <= {P_DATA_WIDTH { 1'b0 } };
                    // request_valid[i] <= 1'b0;
                end
                else begin
                    // if (request_valid[i] == 1'b0) begin
                    //     request_valid[i] <= 1'b1;
                        // r_address[i] <= r_address[i] + 1'b1;
                        r_wrt_data[i] <= r_wrt_data[i] + 32'hAAAABBBB;;
                        // if ( r_request[i] == 2'b00 ) begin
                        //     r_request[i] <= 2'b01; 
                        // end
                        // else begin
                        //     r_request[i] <= 2'b00;
                        // end
                    // end
                    // else if (request_valid[i] == 1'b1 && request_picked[i] == 1'b1 ) begin
                    //     request_valid[i] <= 1'b0;
                    // end
                end
            end
        `endif
    
    end
    
    if ( i == 7 ) begin
        HBM_channel_controller #(
            .P_QUEUE_LEN(P_QUEUE_LEN)
        )
        HBM_channel_controller_i
        (
            .dfi_clk_buf                    (dfi_clk_buf[6]   )
            ,.dfi_rst_n                     (dfi_rst_n[6]     )
            ,.dfi_rst_buf_n                 (dfi_out_rst_n[i] )
            ,.dfi_init_start                (dfi_init_start[i]         )
            ,.dfi_aw_ck_p0                  (dfi_aw_ck_p0[i]           )
            ,.dfi_aw_cke_p0                 (dfi_aw_cke_p0[i]          )
            ,.dfi_aw_row_p0                 (dfi_aw_row_p0[i]          )
            ,.dfi_aw_col_p0                 (dfi_aw_col_p0[i]          )
            ,.dfi_dw_wrdata_p0              (dfi_dw_wrdata_p0[i]       )
            ,.dfi_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[i]  )
            ,.dfi_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[i]   )
            ,.dfi_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[i]   )
            ,.dfi_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[i] )
            ,.dfi_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[i])
            ,.dfi_aw_ck_p1                  (dfi_aw_ck_p1[i]           )
            ,.dfi_aw_cke_p1                 (dfi_aw_cke_p1[i]          )
            ,.dfi_aw_row_p1                 (dfi_aw_row_p1[i]          )
            ,.dfi_aw_col_p1                 (dfi_aw_col_p1[i]          )
            ,.dfi_dw_wrdata_p1              (dfi_dw_wrdata_p1[i]       )
            ,.dfi_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[i]  )
            ,.dfi_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[i]   )
            ,.dfi_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[i]   )
            ,.dfi_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[i] )
            ,.dfi_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[i])
            ,.dfi_aw_ck_dis                 (dfi_aw_ck_dis[i]          )
            ,.dfi_lp_pwr_e_req              (dfi_lp_pwr_e_req[i]       )
            ,.dfi_lp_sr_e_req               (dfi_lp_sr_e_req[i]        )
            ,.dfi_lp_pwr_x_req              (dfi_lp_pwr_x_req[i]     )
            ,.dfi_lp_pwr_x_e_req            (dfi_lp_pwr_x_e_req[i]     )
            ,.dfi_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[i]      )
            ,.dfi_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[i]      )
            ,.dfi_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[i]      )
            ,.dfi_ctrlupd_ack               (dfi_ctrlupd_ack[i]        )
            ,.dfi_phyupd_req                (dfi_phyupd_req[i]         )
            ,.dfi_dw_rddata_p0              (dfi_dw_rddata_p0[i]    )
            ,.dfi_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[i] )
            ,.dfi_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[i])
            ,.dfi_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[i])
            ,.dfi_dw_rddata_p1              (dfi_dw_rddata_p1[i]    )
            ,.dfi_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[i] )
            ,.dfi_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[i])
            ,.dfi_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[i])
            ,.dfi_dw_rddata_valid           (dfi_dw_rddata_valid[i])
            ,.dfi_ctrlupd_req               (dfi_ctrlupd_req[i])
            ,.dfi_phyupd_ack                (dfi_phyupd_ack[i] )
            ,.dfi_init_complete             (dfi_init_complete[i])
            
            ,.reset_hbm_controller          (reset_hbm_controller[i])
            ,.input_write_data              (write_data[i])
            ,.input_request                 (request[i])
            ,.input_address                 (address[i])
            ,.input_request_valid           (request_valid[i])
            ,.output_request_picked         (request_picked[i])

            ,.rd_data_req_id_ps0(rd_data_req_id_ps0[i])
            ,.rd_data_ps0(rd_data_ps0[i])
            ,.rd_data_req_id_ps1(rd_data_req_id_ps1[i])
            ,.rd_data_ps1(rd_data_ps1[i])
        );
    end

    else if ( i == 15 ) begin
        HBM_channel_controller #(
            .P_QUEUE_LEN(P_QUEUE_LEN)
        )
        HBM_channel_controller_i
        (
            .dfi_clk_buf                    (dfi_clk_buf[14]   )
            ,.dfi_rst_n                     (dfi_rst_n[14]     )
            ,.dfi_rst_buf_n                 (dfi_out_rst_n[i] )
            ,.dfi_init_start                (dfi_init_start[i]         )
            ,.dfi_aw_ck_p0                  (dfi_aw_ck_p0[i]           )
            ,.dfi_aw_cke_p0                 (dfi_aw_cke_p0[i]          )
            ,.dfi_aw_row_p0                 (dfi_aw_row_p0[i]          )
            ,.dfi_aw_col_p0                 (dfi_aw_col_p0[i]          )
            ,.dfi_dw_wrdata_p0              (dfi_dw_wrdata_p0[i]       )
            ,.dfi_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[i]  )
            ,.dfi_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[i]   )
            ,.dfi_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[i]   )
            ,.dfi_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[i] )
            ,.dfi_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[i])
            ,.dfi_aw_ck_p1                  (dfi_aw_ck_p1[i]           )
            ,.dfi_aw_cke_p1                 (dfi_aw_cke_p1[i]          )
            ,.dfi_aw_row_p1                 (dfi_aw_row_p1[i]          )
            ,.dfi_aw_col_p1                 (dfi_aw_col_p1[i]          )
            ,.dfi_dw_wrdata_p1              (dfi_dw_wrdata_p1[i]       )
            ,.dfi_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[i]  )
            ,.dfi_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[i]   )
            ,.dfi_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[i]   )
            ,.dfi_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[i] )
            ,.dfi_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[i])
            ,.dfi_aw_ck_dis                 (dfi_aw_ck_dis[i]          )
            ,.dfi_lp_pwr_e_req              (dfi_lp_pwr_e_req[i]       )
            ,.dfi_lp_sr_e_req               (dfi_lp_sr_e_req[i]        )
            ,.dfi_lp_pwr_x_req              (dfi_lp_pwr_x_req[i]     )
            ,.dfi_lp_pwr_x_e_req            (dfi_lp_pwr_x_e_req[i]     )
            ,.dfi_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[i]      )
            ,.dfi_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[i]      )
            ,.dfi_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[i]      )
            ,.dfi_ctrlupd_ack               (dfi_ctrlupd_ack[i]        )
            ,.dfi_phyupd_req                (dfi_phyupd_req[i]         )
            ,.dfi_dw_rddata_p0              (dfi_dw_rddata_p0[i]    )
            ,.dfi_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[i] )
            ,.dfi_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[i])
            ,.dfi_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[i])
            ,.dfi_dw_rddata_p1              (dfi_dw_rddata_p1[i]    )
            ,.dfi_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[i] )
            ,.dfi_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[i])
            ,.dfi_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[i])
            ,.dfi_dw_rddata_valid           (dfi_dw_rddata_valid[i])
            ,.dfi_ctrlupd_req               (dfi_ctrlupd_req[i])
            ,.dfi_phyupd_ack                (dfi_phyupd_ack[i] )
            ,.dfi_init_complete             (dfi_init_complete[i])
            
            ,.reset_hbm_controller          (reset_hbm_controller[i])
            ,.input_write_data              (write_data[i])
            ,.input_request                 (request[i])
            ,.input_address                 (address[i])
            ,.input_request_valid                 (request_valid[i])
            ,.output_request_picked                (request_picked[i])

            ,.rd_data_req_id_ps0(rd_data_req_id_ps0[i])
            ,.rd_data_ps0(rd_data_ps0[i])
            ,.rd_data_req_id_ps1(rd_data_req_id_ps1[i])
            ,.rd_data_ps1(rd_data_ps1[i])
        );
    
    end

    else begin
        HBM_channel_controller #(
            .P_QUEUE_LEN(P_QUEUE_LEN)
        ) 
        HBM_channel_controller_i
        (
            .dfi_clk_buf                    (dfi_clk_buf[i]   )
            ,.dfi_rst_n                     (dfi_rst_n[i]     )
            ,.dfi_rst_buf_n                 (dfi_out_rst_n[i] )
            ,.dfi_init_start                (dfi_init_start[i]         )
            ,.dfi_aw_ck_p0                  (dfi_aw_ck_p0[i]           )
            ,.dfi_aw_cke_p0                 (dfi_aw_cke_p0[i]          )
            ,.dfi_aw_row_p0                 (dfi_aw_row_p0[i]          )
            ,.dfi_aw_col_p0                 (dfi_aw_col_p0[i]          )
            ,.dfi_dw_wrdata_p0              (dfi_dw_wrdata_p0[i]       )
            ,.dfi_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[i]  )
            ,.dfi_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[i]   )
            ,.dfi_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[i]   )
            ,.dfi_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[i] )
            ,.dfi_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[i])
            ,.dfi_aw_ck_p1                  (dfi_aw_ck_p1[i]           )
            ,.dfi_aw_cke_p1                 (dfi_aw_cke_p1[i]          )
            ,.dfi_aw_row_p1                 (dfi_aw_row_p1[i]          )
            ,.dfi_aw_col_p1                 (dfi_aw_col_p1[i]          )
            ,.dfi_dw_wrdata_p1              (dfi_dw_wrdata_p1[i]       )
            ,.dfi_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[i]  )
            ,.dfi_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[i]   )
            ,.dfi_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[i]   )
            ,.dfi_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[i] )
            ,.dfi_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[i])
            ,.dfi_aw_ck_dis                 (dfi_aw_ck_dis[i]          )
            ,.dfi_lp_pwr_e_req              (dfi_lp_pwr_e_req[i]       )
            ,.dfi_lp_sr_e_req               (dfi_lp_sr_e_req[i]        )
            ,.dfi_lp_pwr_x_req              (dfi_lp_pwr_x_req[i]     )
            ,.dfi_lp_pwr_x_e_req            (dfi_lp_pwr_x_e_req[i]     )
            ,.dfi_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[i]      )
            ,.dfi_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[i]      )
            ,.dfi_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[i]      )
            ,.dfi_ctrlupd_ack               (dfi_ctrlupd_ack[i]        )
            ,.dfi_phyupd_req                (dfi_phyupd_req[i]         )
            ,.dfi_dw_rddata_p0              (dfi_dw_rddata_p0[i]    )
            ,.dfi_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[i] )
            ,.dfi_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[i])
            ,.dfi_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[i])
            ,.dfi_dw_rddata_p1              (dfi_dw_rddata_p1[i]    )
            ,.dfi_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[i] )
            ,.dfi_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[i])
            ,.dfi_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[i])
            ,.dfi_dw_rddata_valid           (dfi_dw_rddata_valid[i])
            ,.dfi_ctrlupd_req               (dfi_ctrlupd_req[i])
            ,.dfi_phyupd_ack                (dfi_phyupd_ack[i] )
            ,.dfi_init_complete             (dfi_init_complete[i])

            ,.reset_hbm_controller          (reset_hbm_controller[i])
            ,.input_write_data              (write_data[i])
            ,.input_request                 (request[i])
            ,.input_address                 (address[i])
            ,.input_request_valid                 (request_valid[i])
            ,.output_request_picked                (request_picked[i])

            ,.rd_data_req_id_ps0(rd_data_req_id_ps0[i])
            ,.rd_data_ps0(rd_data_ps0[i])
            ,.rd_data_req_id_ps1(rd_data_req_id_ps1[i])
            ,.rd_data_ps1(rd_data_ps1[i])
        );
    end
end
endgenerate

hbm_0 hbm_0_i
(
    .HBM_REF_CLK_0                    (HBM_REF_CLK_buf_0        )
    ,.HBM_REF_CLK_1                   (HBM_REF_CLK_buf_1        )
    
    ,.dfi_0_clk                       (dfi_clk_buf[0]            )
    ,.dfi_0_rst_n                     (dfi_rst_n[0]              )
    ,.dfi_0_init_start                (dfi_init_start[0]         )
    ,.dfi_0_aw_ck_p0                  (dfi_aw_ck_p0[0]           )
    ,.dfi_0_aw_cke_p0                 (dfi_aw_cke_p0[0]          )
    ,.dfi_0_aw_row_p0                 (dfi_aw_row_p0[0]          )
    ,.dfi_0_aw_col_p0                 (dfi_aw_col_p0[0]          )
    ,.dfi_0_dw_wrdata_p0              (dfi_dw_wrdata_p0[0]       )
    ,.dfi_0_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[0]  )
    ,.dfi_0_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[0]   )
    ,.dfi_0_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[0]   )
    ,.dfi_0_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[0] )
    ,.dfi_0_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[0])
    ,.dfi_0_aw_ck_p1                  (dfi_aw_ck_p1[0]           )
    ,.dfi_0_aw_cke_p1                 (dfi_aw_cke_p1[0]          )
    ,.dfi_0_aw_row_p1                 (dfi_aw_row_p1[0]          )
    ,.dfi_0_aw_col_p1                 (dfi_aw_col_p1[0]          )
    ,.dfi_0_dw_wrdata_p1              (dfi_dw_wrdata_p1[0]       )
    ,.dfi_0_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[0]  )
    ,.dfi_0_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[0]   )
    ,.dfi_0_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[0]   )
    ,.dfi_0_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[0] )
    ,.dfi_0_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[0])
    ,.dfi_0_aw_ck_dis                 (dfi_aw_ck_dis[0]          )
    ,.dfi_0_lp_pwr_e_req              (dfi_lp_pwr_e_req[0]       )
    ,.dfi_0_lp_sr_e_req               (dfi_lp_sr_e_req[0]        )
    ,.dfi_0_lp_pwr_x_req              (dfi_lp_pwr_x_req[0]     )
    ,.dfi_0_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[0]      )
    ,.dfi_0_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[0]      )
    ,.dfi_0_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[0]      )
    ,.dfi_0_ctrlupd_ack               (dfi_ctrlupd_ack[0]        )
    ,.dfi_0_phyupd_req                (dfi_phyupd_req[0]         )
    ,.dfi_0_dw_wrdata_dqs_p0          (8'hff)
    ,.dfi_0_dw_wrdata_dqs_p1          (8'hff)
    ,.APB_0_PCLK                      (APB_PCLK_BUF_0)
    ,.APB_0_PRESET_N                  (APB_PRESET_N_sync_0)
    ,.APB_1_PCLK                      (APB_PCLK_BUF_1)
    ,.APB_1_PRESET_N                  (APB_PRESET_N_sync_1)
    ,.dfi_0_dw_rddata_p0              (dfi_dw_rddata_p0[0]    )
    ,.dfi_0_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[0] )
    ,.dfi_0_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[0])
    ,.dfi_0_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[0])
    ,.dfi_0_dw_rddata_p1              (dfi_dw_rddata_p1[0]    )
    ,.dfi_0_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[0] )
    ,.dfi_0_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[0])
    ,.dfi_0_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[0])
    ,.dfi_0_dbi_byte_disable          ( /* Not Connected */  )
    ,.dfi_0_dw_rddata_valid           (dfi_dw_rddata_valid[0])
    ,.dfi_0_dw_derr_n                 ( /* Not Connected */  )
    ,.dfi_0_aw_aerr_n                 ( /* Not Connected */  )
    ,.dfi_0_ctrlupd_req               (dfi_ctrlupd_req[0])
    ,.dfi_0_phyupd_ack                (dfi_phyupd_ack[0] )
    ,.dfi_0_clk_init                  ( /* Not Connected */  )
    ,.dfi_0_init_complete             (dfi_init_complete[0])
    ,.dfi_0_out_rst_n                 (dfi_out_rst_n[0]    )
    ,.apb_complete_0                  (apb_seq_complete_s)
    ,.DRAM_0_STAT_CATTRIP             (DRAM_STAT_CATTRIP)
    ,.DRAM_0_STAT_TEMP                (DRAM_STAT_TEMP)
    
   ,.dfi_1_clk                       (dfi_clk_buf[1]            )
   ,.dfi_1_rst_n                     (dfi_rst_n[1]              )
   ,.dfi_1_init_start                (dfi_init_start[1]         )
   ,.dfi_1_aw_ck_p0                  (dfi_aw_ck_p0[1]           )
   ,.dfi_1_aw_cke_p0                 (dfi_aw_cke_p0[1]          )
   ,.dfi_1_aw_row_p0                 (dfi_aw_row_p0[1]          )
   ,.dfi_1_aw_col_p0                 (dfi_aw_col_p0[1]          )
   ,.dfi_1_dw_wrdata_p0              (dfi_dw_wrdata_p0[1]       )
   ,.dfi_1_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[1]  )
   ,.dfi_1_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[1]   )
   ,.dfi_1_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[1]   )
   ,.dfi_1_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[1] )
   ,.dfi_1_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[1])
   ,.dfi_1_aw_ck_p1                  (dfi_aw_ck_p1[1]           )
   ,.dfi_1_aw_cke_p1                 (dfi_aw_cke_p1[1]          )
   ,.dfi_1_aw_row_p1                 (dfi_aw_row_p1[1]          )
   ,.dfi_1_aw_col_p1                 (dfi_aw_col_p1[1]          )
   ,.dfi_1_dw_wrdata_p1              (dfi_dw_wrdata_p1[1]       )
   ,.dfi_1_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[1]  )
   ,.dfi_1_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[1]   )
   ,.dfi_1_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[1]   )
   ,.dfi_1_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[1] )
   ,.dfi_1_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[1])
   ,.dfi_1_aw_ck_dis                 (dfi_aw_ck_dis[1]          )
   ,.dfi_1_lp_pwr_e_req              (dfi_lp_pwr_e_req[1]       )
   ,.dfi_1_lp_sr_e_req               (dfi_lp_sr_e_req[1]        )
   ,.dfi_1_lp_pwr_x_req              (dfi_lp_pwr_x_req[1]     )
   ,.dfi_1_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[1]      )
   ,.dfi_1_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[1]      )
   ,.dfi_1_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[1]      )
   ,.dfi_1_ctrlupd_ack               (dfi_ctrlupd_ack[1]        )
   ,.dfi_1_phyupd_req                (dfi_phyupd_req[1]         )
   ,.dfi_1_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_1_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_1_dw_rddata_p0              (dfi_dw_rddata_p0[1]    )
   ,.dfi_1_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[1] )
   ,.dfi_1_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[1])
   ,.dfi_1_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[1])
   ,.dfi_1_dw_rddata_p1              (dfi_dw_rddata_p1[1]    )
   ,.dfi_1_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[1] )
   ,.dfi_1_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[1])
   ,.dfi_1_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[1])
   ,.dfi_1_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_1_dw_rddata_valid           (dfi_dw_rddata_valid[1])
   ,.dfi_1_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_1_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_1_ctrlupd_req               (dfi_ctrlupd_req[1])
   ,.dfi_1_phyupd_ack                (dfi_phyupd_ack[1] )
   ,.dfi_1_clk_init                  ( /* Not Connected */  )
   ,.dfi_1_init_complete             (dfi_init_complete[1])
   ,.dfi_1_out_rst_n                 (dfi_out_rst_n[1]    )


   ,.dfi_2_clk                       (dfi_clk_buf[2]            )
   ,.dfi_2_rst_n                     (dfi_rst_n[2]              )
   ,.dfi_2_init_start                (dfi_init_start[2]         )
   ,.dfi_2_aw_ck_p0                  (dfi_aw_ck_p0[2]           )
   ,.dfi_2_aw_cke_p0                 (dfi_aw_cke_p0[2]          )
   ,.dfi_2_aw_row_p0                 (dfi_aw_row_p0[2]          )
   ,.dfi_2_aw_col_p0                 (dfi_aw_col_p0[2]          )
   ,.dfi_2_dw_wrdata_p0              (dfi_dw_wrdata_p0[2]       )
   ,.dfi_2_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[2]  )
   ,.dfi_2_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[2]   )
   ,.dfi_2_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[2]   )
   ,.dfi_2_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[2] )
   ,.dfi_2_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[2])
   ,.dfi_2_aw_ck_p1                  (dfi_aw_ck_p1[2]           )
   ,.dfi_2_aw_cke_p1                 (dfi_aw_cke_p1[2]          )
   ,.dfi_2_aw_row_p1                 (dfi_aw_row_p1[2]          )
   ,.dfi_2_aw_col_p1                 (dfi_aw_col_p1[2]          )
   ,.dfi_2_dw_wrdata_p1              (dfi_dw_wrdata_p1[2]       )
   ,.dfi_2_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[2]  )
   ,.dfi_2_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[2]   )
   ,.dfi_2_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[2]   )
   ,.dfi_2_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[2] )
   ,.dfi_2_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[2])
   ,.dfi_2_aw_ck_dis                 (dfi_aw_ck_dis[2]          )
   ,.dfi_2_lp_pwr_e_req              (dfi_lp_pwr_e_req[2]       )
   ,.dfi_2_lp_sr_e_req               (dfi_lp_sr_e_req[2]        )
   ,.dfi_2_lp_pwr_x_req              (dfi_lp_pwr_x_req[2]     )
   ,.dfi_2_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[2]      )
   ,.dfi_2_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[2]      )
   ,.dfi_2_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[2]      )
   ,.dfi_2_ctrlupd_ack               (dfi_ctrlupd_ack[2]        )
   ,.dfi_2_phyupd_req                (dfi_phyupd_req[2]         )
   ,.dfi_2_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_2_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_2_dw_rddata_p0              (dfi_dw_rddata_p0[2]    )
   ,.dfi_2_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[2] )
   ,.dfi_2_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[2])
   ,.dfi_2_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[2])
   ,.dfi_2_dw_rddata_p1              (dfi_dw_rddata_p1[2]    )
   ,.dfi_2_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[2] )
   ,.dfi_2_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[2])
   ,.dfi_2_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[2])
   ,.dfi_2_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_2_dw_rddata_valid           (dfi_dw_rddata_valid[2])
   ,.dfi_2_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_2_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_2_ctrlupd_req               (dfi_ctrlupd_req[2])
   ,.dfi_2_phyupd_ack                (dfi_phyupd_ack[2] )
   ,.dfi_2_clk_init                  ( /* Not Connected */  )
   ,.dfi_2_init_complete             (dfi_init_complete[2])
   ,.dfi_2_out_rst_n                 (dfi_out_rst_n[2]    )


   ,.dfi_3_clk                       (dfi_clk_buf[3]            )
   ,.dfi_3_rst_n                     (dfi_rst_n[3]              )
   ,.dfi_3_init_start                (dfi_init_start[3]         )
   ,.dfi_3_aw_ck_p0                  (dfi_aw_ck_p0[3]           )
   ,.dfi_3_aw_cke_p0                 (dfi_aw_cke_p0[3]          )
   ,.dfi_3_aw_row_p0                 (dfi_aw_row_p0[3]          )
   ,.dfi_3_aw_col_p0                 (dfi_aw_col_p0[3]          )
   ,.dfi_3_dw_wrdata_p0              (dfi_dw_wrdata_p0[3]       )
   ,.dfi_3_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[3]  )
   ,.dfi_3_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[3]   )
   ,.dfi_3_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[3]   )
   ,.dfi_3_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[3] )
   ,.dfi_3_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[3])
   ,.dfi_3_aw_ck_p1                  (dfi_aw_ck_p1[3]           )
   ,.dfi_3_aw_cke_p1                 (dfi_aw_cke_p1[3]          )
   ,.dfi_3_aw_row_p1                 (dfi_aw_row_p1[3]          )
   ,.dfi_3_aw_col_p1                 (dfi_aw_col_p1[3]          )
   ,.dfi_3_dw_wrdata_p1              (dfi_dw_wrdata_p1[3]       )
   ,.dfi_3_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[3]  )
   ,.dfi_3_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[3]   )
   ,.dfi_3_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[3]   )
   ,.dfi_3_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[3] )
   ,.dfi_3_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[3])
   ,.dfi_3_aw_ck_dis                 (dfi_aw_ck_dis[3]          )
   ,.dfi_3_lp_pwr_e_req              (dfi_lp_pwr_e_req[3]       )
   ,.dfi_3_lp_sr_e_req               (dfi_lp_sr_e_req[3]        )
   ,.dfi_3_lp_pwr_x_req              (dfi_lp_pwr_x_req[3]     )
   ,.dfi_3_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[3]      )
   ,.dfi_3_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[3]      )
   ,.dfi_3_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[3]      )
   ,.dfi_3_ctrlupd_ack               (dfi_ctrlupd_ack[3]        )
   ,.dfi_3_phyupd_req                (dfi_phyupd_req[3]         )
   ,.dfi_3_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_3_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_3_dw_rddata_p0              (dfi_dw_rddata_p0[3]    )
   ,.dfi_3_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[3] )
   ,.dfi_3_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[3])
   ,.dfi_3_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[3])
   ,.dfi_3_dw_rddata_p1              (dfi_dw_rddata_p1[3]    )
   ,.dfi_3_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[3] )
   ,.dfi_3_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[3])
   ,.dfi_3_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[3])
   ,.dfi_3_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_3_dw_rddata_valid           (dfi_dw_rddata_valid[3])
   ,.dfi_3_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_3_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_3_ctrlupd_req               (dfi_ctrlupd_req[3])
   ,.dfi_3_phyupd_ack                (dfi_phyupd_ack[3] )
   ,.dfi_3_clk_init                  ( /* Not Connected */  )
   ,.dfi_3_init_complete             (dfi_init_complete[3])
   ,.dfi_3_out_rst_n                 (dfi_out_rst_n[3]    )


   ,.dfi_4_clk                       (dfi_clk_buf[4]            )
   ,.dfi_4_rst_n                     (dfi_rst_n[4]              )
   ,.dfi_4_init_start                (dfi_init_start[4]         )
   ,.dfi_4_aw_ck_p0                  (dfi_aw_ck_p0[4]           )
   ,.dfi_4_aw_cke_p0                 (dfi_aw_cke_p0[4]          )
   ,.dfi_4_aw_row_p0                 (dfi_aw_row_p0[4]          )
   ,.dfi_4_aw_col_p0                 (dfi_aw_col_p0[4]          )
   ,.dfi_4_dw_wrdata_p0              (dfi_dw_wrdata_p0[4]       )
   ,.dfi_4_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[4]  )
   ,.dfi_4_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[4]   )
   ,.dfi_4_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[4]   )
   ,.dfi_4_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[4] )
   ,.dfi_4_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[4])
   ,.dfi_4_aw_ck_p1                  (dfi_aw_ck_p1[4]           )
   ,.dfi_4_aw_cke_p1                 (dfi_aw_cke_p1[4]          )
   ,.dfi_4_aw_row_p1                 (dfi_aw_row_p1[4]          )
   ,.dfi_4_aw_col_p1                 (dfi_aw_col_p1[4]          )
   ,.dfi_4_dw_wrdata_p1              (dfi_dw_wrdata_p1[4]       )
   ,.dfi_4_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[4]  )
   ,.dfi_4_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[4]   )
   ,.dfi_4_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[4]   )
   ,.dfi_4_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[4] )
   ,.dfi_4_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[4])
   ,.dfi_4_aw_ck_dis                 (dfi_aw_ck_dis[4]          )
   ,.dfi_4_lp_pwr_e_req              (dfi_lp_pwr_e_req[4]       )
   ,.dfi_4_lp_sr_e_req               (dfi_lp_sr_e_req[4]        )
   ,.dfi_4_lp_pwr_x_req              (dfi_lp_pwr_x_req[4]     )
   ,.dfi_4_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[4]      )
   ,.dfi_4_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[4]      )
   ,.dfi_4_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[4]      )
   ,.dfi_4_ctrlupd_ack               (dfi_ctrlupd_ack[4]        )
   ,.dfi_4_phyupd_req                (dfi_phyupd_req[4]         )
   ,.dfi_4_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_4_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_4_dw_rddata_p0              (dfi_dw_rddata_p0[4]    )
   ,.dfi_4_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[4] )
   ,.dfi_4_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[4])
   ,.dfi_4_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[4])
   ,.dfi_4_dw_rddata_p1              (dfi_dw_rddata_p1[4]    )
   ,.dfi_4_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[4] )
   ,.dfi_4_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[4])
   ,.dfi_4_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[4])
   ,.dfi_4_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_4_dw_rddata_valid           (dfi_dw_rddata_valid[4])
   ,.dfi_4_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_4_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_4_ctrlupd_req               (dfi_ctrlupd_req[4])
   ,.dfi_4_phyupd_ack                (dfi_phyupd_ack[4] )
   ,.dfi_4_clk_init                  ( /* Not Connected */  )
   ,.dfi_4_init_complete             (dfi_init_complete[4])
   ,.dfi_4_out_rst_n                 (dfi_out_rst_n[4]    )



   ,.dfi_5_clk                       (dfi_clk_buf[5]            )
   ,.dfi_5_rst_n                     (dfi_rst_n[5]              )
   ,.dfi_5_init_start                (dfi_init_start[5]         )
   ,.dfi_5_aw_ck_p0                  (dfi_aw_ck_p0[5]           )
   ,.dfi_5_aw_cke_p0                 (dfi_aw_cke_p0[5]          )
   ,.dfi_5_aw_row_p0                 (dfi_aw_row_p0[5]          )
   ,.dfi_5_aw_col_p0                 (dfi_aw_col_p0[5]          )
   ,.dfi_5_dw_wrdata_p0              (dfi_dw_wrdata_p0[5]       )
   ,.dfi_5_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[5]  )
   ,.dfi_5_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[5]   )
   ,.dfi_5_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[5]   )
   ,.dfi_5_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[5] )
   ,.dfi_5_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[5])
   ,.dfi_5_aw_ck_p1                  (dfi_aw_ck_p1[5]           )
   ,.dfi_5_aw_cke_p1                 (dfi_aw_cke_p1[5]          )
   ,.dfi_5_aw_row_p1                 (dfi_aw_row_p1[5]          )
   ,.dfi_5_aw_col_p1                 (dfi_aw_col_p1[5]          )
   ,.dfi_5_dw_wrdata_p1              (dfi_dw_wrdata_p1[5]       )
   ,.dfi_5_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[5]  )
   ,.dfi_5_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[5]   )
   ,.dfi_5_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[5]   )
   ,.dfi_5_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[5] )
   ,.dfi_5_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[5])
   ,.dfi_5_aw_ck_dis                 (dfi_aw_ck_dis[5]          )
   ,.dfi_5_lp_pwr_e_req              (dfi_lp_pwr_e_req[5]       )
   ,.dfi_5_lp_sr_e_req               (dfi_lp_sr_e_req[5]        )
   ,.dfi_5_lp_pwr_x_req              (dfi_lp_pwr_x_req[5]     )
   ,.dfi_5_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[5]      )
   ,.dfi_5_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[5]      )
   ,.dfi_5_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[5]      )
   ,.dfi_5_ctrlupd_ack               (dfi_ctrlupd_ack[5]        )
   ,.dfi_5_phyupd_req                (dfi_phyupd_req[5]         )
   ,.dfi_5_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_5_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_5_dw_rddata_p0              (dfi_dw_rddata_p0[5]    )
   ,.dfi_5_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[5] )
   ,.dfi_5_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[5])
   ,.dfi_5_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[5])
   ,.dfi_5_dw_rddata_p1              (dfi_dw_rddata_p1[5]    )
   ,.dfi_5_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[5] )
   ,.dfi_5_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[5])
   ,.dfi_5_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[5])
   ,.dfi_5_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_5_dw_rddata_valid           (dfi_dw_rddata_valid[5])
   ,.dfi_5_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_5_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_5_ctrlupd_req               (dfi_ctrlupd_req[5])
   ,.dfi_5_phyupd_ack                (dfi_phyupd_ack[5] )
   ,.dfi_5_clk_init                  ( /* Not Connected */  )
   ,.dfi_5_init_complete             (dfi_init_complete[5])
   ,.dfi_5_out_rst_n                 (dfi_out_rst_n[5]    )


   ,.dfi_6_clk                       (dfi_clk_buf[6]            )
   ,.dfi_6_rst_n                     (dfi_rst_n[6]              )
   ,.dfi_6_init_start                (dfi_init_start[6]         )
   ,.dfi_6_aw_ck_p0                  (dfi_aw_ck_p0[6]           )
   ,.dfi_6_aw_cke_p0                 (dfi_aw_cke_p0[6]          )
   ,.dfi_6_aw_row_p0                 (dfi_aw_row_p0[6]          )
   ,.dfi_6_aw_col_p0                 (dfi_aw_col_p0[6]          )
   ,.dfi_6_dw_wrdata_p0              (dfi_dw_wrdata_p0[6]       )
   ,.dfi_6_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[6]  )
   ,.dfi_6_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[6]   )
   ,.dfi_6_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[6]   )
   ,.dfi_6_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[6] )
   ,.dfi_6_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[6])
   ,.dfi_6_aw_ck_p1                  (dfi_aw_ck_p1[6]           )
   ,.dfi_6_aw_cke_p1                 (dfi_aw_cke_p1[6]          )
   ,.dfi_6_aw_row_p1                 (dfi_aw_row_p1[6]          )
   ,.dfi_6_aw_col_p1                 (dfi_aw_col_p1[6]          )
   ,.dfi_6_dw_wrdata_p1              (dfi_dw_wrdata_p1[6]       )
   ,.dfi_6_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[6]  )
   ,.dfi_6_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[6]   )
   ,.dfi_6_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[6]   )
   ,.dfi_6_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[6] )
   ,.dfi_6_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[6])
   ,.dfi_6_aw_ck_dis                 (dfi_aw_ck_dis[6]          )
   ,.dfi_6_lp_pwr_e_req              (dfi_lp_pwr_e_req[6]       )
   ,.dfi_6_lp_sr_e_req               (dfi_lp_sr_e_req[6]        )
   ,.dfi_6_lp_pwr_x_req              (dfi_lp_pwr_x_req[6]     )
   ,.dfi_6_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[6]      )
   ,.dfi_6_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[6]      )
   ,.dfi_6_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[6]      )
   ,.dfi_6_ctrlupd_ack               (dfi_ctrlupd_ack[6]        )
   ,.dfi_6_phyupd_req                (dfi_phyupd_req[6]         )
   ,.dfi_6_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_6_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_6_dw_rddata_p0              (dfi_dw_rddata_p0[6]    )
   ,.dfi_6_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[6] )
   ,.dfi_6_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[6])
   ,.dfi_6_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[6])
   ,.dfi_6_dw_rddata_p1              (dfi_dw_rddata_p1[6]    )
   ,.dfi_6_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[6] )
   ,.dfi_6_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[6])
   ,.dfi_6_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[6])
   ,.dfi_6_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_6_dw_rddata_valid           (dfi_dw_rddata_valid[6])
   ,.dfi_6_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_6_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_6_ctrlupd_req               (dfi_ctrlupd_req[6])
   ,.dfi_6_phyupd_ack                (dfi_phyupd_ack[6] )
   ,.dfi_6_clk_init                  ( /* Not Connected */  )
   ,.dfi_6_init_complete             (dfi_init_complete[6])
   ,.dfi_6_out_rst_n                 (dfi_out_rst_n[6]    )

   ,.dfi_7_clk                       (dfi_clk_buf[6]            )
   ,.dfi_7_rst_n                     (dfi_rst_n[6]              )
   ,.dfi_7_init_start                (dfi_init_start[7]         )
   ,.dfi_7_aw_ck_p0                  (dfi_aw_ck_p0[7]           )
   ,.dfi_7_aw_cke_p0                 (dfi_aw_cke_p0[7]          )
   ,.dfi_7_aw_row_p0                 (dfi_aw_row_p0[7]          )
   ,.dfi_7_aw_col_p0                 (dfi_aw_col_p0[7]          )
   ,.dfi_7_dw_wrdata_p0              (dfi_dw_wrdata_p0[7]       )
   ,.dfi_7_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[7]  )
   ,.dfi_7_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[7]   )
   ,.dfi_7_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[7]   )
   ,.dfi_7_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[7] )
   ,.dfi_7_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[7])
   ,.dfi_7_aw_ck_p1                  (dfi_aw_ck_p1[7]           )
   ,.dfi_7_aw_cke_p1                 (dfi_aw_cke_p1[7]          )
   ,.dfi_7_aw_row_p1                 (dfi_aw_row_p1[7]          )
   ,.dfi_7_aw_col_p1                 (dfi_aw_col_p1[7]          )
   ,.dfi_7_dw_wrdata_p1              (dfi_dw_wrdata_p1[7]       )
   ,.dfi_7_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[7]  )
   ,.dfi_7_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[7]   )
   ,.dfi_7_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[7]   )
   ,.dfi_7_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[7] )
   ,.dfi_7_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[7])
   ,.dfi_7_aw_ck_dis                 (dfi_aw_ck_dis[7]          )
   ,.dfi_7_lp_pwr_e_req              (dfi_lp_pwr_e_req[7]       )
   ,.dfi_7_lp_sr_e_req               (dfi_lp_sr_e_req[7]        )
   ,.dfi_7_lp_pwr_x_req              (dfi_lp_pwr_x_req[7]     )
   ,.dfi_7_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[7]      )
   ,.dfi_7_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[7]      )
   ,.dfi_7_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[7]      )
   ,.dfi_7_ctrlupd_ack               (dfi_ctrlupd_ack[7]        )
   ,.dfi_7_phyupd_req                (dfi_phyupd_req[7]         )
   ,.dfi_7_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_7_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_7_dw_rddata_p0              (dfi_dw_rddata_p0[7]    )
   ,.dfi_7_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[7] )
   ,.dfi_7_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[7])
   ,.dfi_7_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[7])
   ,.dfi_7_dw_rddata_p1              (dfi_dw_rddata_p1[7]    )
   ,.dfi_7_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[7] )
   ,.dfi_7_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[7])
   ,.dfi_7_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[7])
   ,.dfi_7_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_7_dw_rddata_valid           (dfi_dw_rddata_valid[7])
   ,.dfi_7_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_7_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_7_ctrlupd_req               (dfi_ctrlupd_req[7])
   ,.dfi_7_phyupd_ack                (dfi_phyupd_ack[7] )
   ,.dfi_7_clk_init                  ( /* Not Connected */  )
   ,.dfi_7_init_complete             (dfi_init_complete[7])
   ,.dfi_7_out_rst_n                 (dfi_out_rst_n[7]    )
    
    
   ,.dfi_8_clk                       (dfi_clk_buf[8]            )
   ,.dfi_8_rst_n                     (dfi_rst_n[8]              )
   ,.dfi_8_init_start                (dfi_init_start[8]         )
   ,.dfi_8_aw_ck_p0                  (dfi_aw_ck_p0[8]           )
   ,.dfi_8_aw_cke_p0                 (dfi_aw_cke_p0[8]          )
   ,.dfi_8_aw_row_p0                 (dfi_aw_row_p0[8]          )
   ,.dfi_8_aw_col_p0                 (dfi_aw_col_p0[8]          )
   ,.dfi_8_dw_wrdata_p0              (dfi_dw_wrdata_p0[8]       )
   ,.dfi_8_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[8]  )
   ,.dfi_8_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[8]   )
   ,.dfi_8_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[8]   )
   ,.dfi_8_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[8] )
   ,.dfi_8_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[8])
   ,.dfi_8_aw_ck_p1                  (dfi_aw_ck_p1[8]           )
   ,.dfi_8_aw_cke_p1                 (dfi_aw_cke_p1[8]          )
   ,.dfi_8_aw_row_p1                 (dfi_aw_row_p1[8]          )
   ,.dfi_8_aw_col_p1                 (dfi_aw_col_p1[8]          )
   ,.dfi_8_dw_wrdata_p1              (dfi_dw_wrdata_p1[8]       )
   ,.dfi_8_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[8]  )
   ,.dfi_8_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[8]   )
   ,.dfi_8_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[8]   )
   ,.dfi_8_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[8] )
   ,.dfi_8_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[8])
   ,.dfi_8_aw_ck_dis                 (dfi_aw_ck_dis[8]          )
   ,.dfi_8_lp_pwr_e_req              (dfi_lp_pwr_e_req[8]       )
   ,.dfi_8_lp_sr_e_req               (dfi_lp_sr_e_req[8]        )
   ,.dfi_8_lp_pwr_x_req              (dfi_lp_pwr_x_req[8]     )
   ,.dfi_8_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[8]      )
   ,.dfi_8_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[8]      )
   ,.dfi_8_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[8]      )
   ,.dfi_8_ctrlupd_ack               (dfi_ctrlupd_ack[8]        )
   ,.dfi_8_phyupd_req                (dfi_phyupd_req[8]         )
   ,.dfi_8_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_8_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_8_dw_rddata_p0              (dfi_dw_rddata_p0[8]    )
   ,.dfi_8_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[8] )
   ,.dfi_8_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[8])
   ,.dfi_8_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[8])
   ,.dfi_8_dw_rddata_p1              (dfi_dw_rddata_p1[8]    )
   ,.dfi_8_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[8] )
   ,.dfi_8_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[8])
   ,.dfi_8_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[8])
   ,.dfi_8_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_8_dw_rddata_valid           (dfi_dw_rddata_valid[8])
   ,.dfi_8_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_8_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_8_ctrlupd_req               (dfi_ctrlupd_req[8])
   ,.dfi_8_phyupd_ack                (dfi_phyupd_ack[8] )
   ,.dfi_8_clk_init                  ( /* Not Connected */  )
   ,.dfi_8_init_complete             (dfi_init_complete[8])
   ,.dfi_8_out_rst_n                 (dfi_out_rst_n[8]    )

   ,.dfi_9_clk                       (dfi_clk_buf[9]            )
   ,.dfi_9_rst_n                     (dfi_rst_n[9]              )
   ,.dfi_9_init_start                (dfi_init_start[9]         )
   ,.dfi_9_aw_ck_p0                  (dfi_aw_ck_p0[9]           )
   ,.dfi_9_aw_cke_p0                 (dfi_aw_cke_p0[9]          )
   ,.dfi_9_aw_row_p0                 (dfi_aw_row_p0[9]          )
   ,.dfi_9_aw_col_p0                 (dfi_aw_col_p0[9]          )
   ,.dfi_9_dw_wrdata_p0              (dfi_dw_wrdata_p0[9]       )
   ,.dfi_9_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[9]  )
   ,.dfi_9_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[9]   )
   ,.dfi_9_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[9]   )
   ,.dfi_9_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[9] )
   ,.dfi_9_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[9])
   ,.dfi_9_aw_ck_p1                  (dfi_aw_ck_p1[9]           )
   ,.dfi_9_aw_cke_p1                 (dfi_aw_cke_p1[9]          )
   ,.dfi_9_aw_row_p1                 (dfi_aw_row_p1[9]          )
   ,.dfi_9_aw_col_p1                 (dfi_aw_col_p1[9]          )
   ,.dfi_9_dw_wrdata_p1              (dfi_dw_wrdata_p1[9]       )
   ,.dfi_9_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[9]  )
   ,.dfi_9_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[9]   )
   ,.dfi_9_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[9]   )
   ,.dfi_9_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[9] )
   ,.dfi_9_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[9])
   ,.dfi_9_aw_ck_dis                 (dfi_aw_ck_dis[9]          )
   ,.dfi_9_lp_pwr_e_req              (dfi_lp_pwr_e_req[9]       )
   ,.dfi_9_lp_sr_e_req               (dfi_lp_sr_e_req[9]        )
   ,.dfi_9_lp_pwr_x_req              (dfi_lp_pwr_x_req[9]     )
   ,.dfi_9_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[9]      )
   ,.dfi_9_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[9]      )
   ,.dfi_9_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[9]      )
   ,.dfi_9_ctrlupd_ack               (dfi_ctrlupd_ack[9]        )
   ,.dfi_9_phyupd_req                (dfi_phyupd_req[9]         )
   ,.dfi_9_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_9_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_9_dw_rddata_p0              (dfi_dw_rddata_p0[9]    )
   ,.dfi_9_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[9] )
   ,.dfi_9_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[9])
   ,.dfi_9_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[9])
   ,.dfi_9_dw_rddata_p1              (dfi_dw_rddata_p1[9]    )
   ,.dfi_9_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[9] )
   ,.dfi_9_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[9])
   ,.dfi_9_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[9])
   ,.dfi_9_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_9_dw_rddata_valid           (dfi_dw_rddata_valid[9])
   ,.dfi_9_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_9_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_9_ctrlupd_req               (dfi_ctrlupd_req[9])
   ,.dfi_9_phyupd_ack                (dfi_phyupd_ack[9] )
   ,.dfi_9_clk_init                  ( /* Not Connected */  )
   ,.dfi_9_init_complete             (dfi_init_complete[9])
   ,.dfi_9_out_rst_n                 (dfi_out_rst_n[9]    )


   ,.dfi_10_clk                       (dfi_clk_buf[10]            )
   ,.dfi_10_rst_n                     (dfi_rst_n[10]              )
   ,.dfi_10_init_start                (dfi_init_start[10]         )
   ,.dfi_10_aw_ck_p0                  (dfi_aw_ck_p0[10]           )
   ,.dfi_10_aw_cke_p0                 (dfi_aw_cke_p0[10]          )
   ,.dfi_10_aw_row_p0                 (dfi_aw_row_p0[10]          )
   ,.dfi_10_aw_col_p0                 (dfi_aw_col_p0[10]          )
   ,.dfi_10_dw_wrdata_p0              (dfi_dw_wrdata_p0[10]       )
   ,.dfi_10_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[10]  )
   ,.dfi_10_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[10]   )
   ,.dfi_10_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[10]   )
   ,.dfi_10_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[10] )
   ,.dfi_10_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[10])
   ,.dfi_10_aw_ck_p1                  (dfi_aw_ck_p1[10]           )
   ,.dfi_10_aw_cke_p1                 (dfi_aw_cke_p1[10]          )
   ,.dfi_10_aw_row_p1                 (dfi_aw_row_p1[10]          )
   ,.dfi_10_aw_col_p1                 (dfi_aw_col_p1[10]          )
   ,.dfi_10_dw_wrdata_p1              (dfi_dw_wrdata_p1[10]       )
   ,.dfi_10_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[10]  )
   ,.dfi_10_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[10]   )
   ,.dfi_10_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[10]   )
   ,.dfi_10_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[10] )
   ,.dfi_10_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[10])
   ,.dfi_10_aw_ck_dis                 (dfi_aw_ck_dis[10]          )
   ,.dfi_10_lp_pwr_e_req              (dfi_lp_pwr_e_req[10]       )
   ,.dfi_10_lp_sr_e_req               (dfi_lp_sr_e_req[10]        )
   ,.dfi_10_lp_pwr_x_req              (dfi_lp_pwr_x_req[10]     )
   ,.dfi_10_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[10]      )
   ,.dfi_10_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[10]      )
   ,.dfi_10_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[10]      )
   ,.dfi_10_ctrlupd_ack               (dfi_ctrlupd_ack[10]        )
   ,.dfi_10_phyupd_req                (dfi_phyupd_req[10]         )
   ,.dfi_10_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_10_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_10_dw_rddata_p0              (dfi_dw_rddata_p0[10]    )
   ,.dfi_10_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[10] )
   ,.dfi_10_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[10])
   ,.dfi_10_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[10])
   ,.dfi_10_dw_rddata_p1              (dfi_dw_rddata_p1[10]    )
   ,.dfi_10_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[10] )
   ,.dfi_10_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[10])
   ,.dfi_10_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[10])
   ,.dfi_10_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_10_dw_rddata_valid           (dfi_dw_rddata_valid[10])
   ,.dfi_10_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_10_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_10_ctrlupd_req               (dfi_ctrlupd_req[10])
   ,.dfi_10_phyupd_ack                (dfi_phyupd_ack[10] )
   ,.dfi_10_clk_init                  ( /* Not Connected */  )
   ,.dfi_10_init_complete             (dfi_init_complete[10])
   ,.dfi_10_out_rst_n                 (dfi_out_rst_n[10]    )


   ,.dfi_11_clk                       (dfi_clk_buf[11]            )
   ,.dfi_11_rst_n                     (dfi_rst_n[11]              )
   ,.dfi_11_init_start                (dfi_init_start[11]         )
   ,.dfi_11_aw_ck_p0                  (dfi_aw_ck_p0[11]           )
   ,.dfi_11_aw_cke_p0                 (dfi_aw_cke_p0[11]          )
   ,.dfi_11_aw_row_p0                 (dfi_aw_row_p0[11]          )
   ,.dfi_11_aw_col_p0                 (dfi_aw_col_p0[11]          )
   ,.dfi_11_dw_wrdata_p0              (dfi_dw_wrdata_p0[11]       )
   ,.dfi_11_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[11]  )
   ,.dfi_11_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[11]   )
   ,.dfi_11_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[11]   )
   ,.dfi_11_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[11] )
   ,.dfi_11_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[11])
   ,.dfi_11_aw_ck_p1                  (dfi_aw_ck_p1[11]           )
   ,.dfi_11_aw_cke_p1                 (dfi_aw_cke_p1[11]          )
   ,.dfi_11_aw_row_p1                 (dfi_aw_row_p1[11]          )
   ,.dfi_11_aw_col_p1                 (dfi_aw_col_p1[11]          )
   ,.dfi_11_dw_wrdata_p1              (dfi_dw_wrdata_p1[11]       )
   ,.dfi_11_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[11]  )
   ,.dfi_11_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[11]   )
   ,.dfi_11_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[11]   )
   ,.dfi_11_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[11] )
   ,.dfi_11_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[11])
   ,.dfi_11_aw_ck_dis                 (dfi_aw_ck_dis[11]          )
   ,.dfi_11_lp_pwr_e_req              (dfi_lp_pwr_e_req[11]       )
   ,.dfi_11_lp_sr_e_req               (dfi_lp_sr_e_req[11]        )
   ,.dfi_11_lp_pwr_x_req              (dfi_lp_pwr_x_req[11]     )
   ,.dfi_11_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[11]      )
   ,.dfi_11_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[11]      )
   ,.dfi_11_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[11]      )
   ,.dfi_11_ctrlupd_ack               (dfi_ctrlupd_ack[11]        )
   ,.dfi_11_phyupd_req                (dfi_phyupd_req[11]         )
   ,.dfi_11_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_11_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_11_dw_rddata_p0              (dfi_dw_rddata_p0[11]    )
   ,.dfi_11_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[11] )
   ,.dfi_11_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[11])
   ,.dfi_11_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[11])
   ,.dfi_11_dw_rddata_p1              (dfi_dw_rddata_p1[11]    )
   ,.dfi_11_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[11] )
   ,.dfi_11_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[11])
   ,.dfi_11_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[11])
   ,.dfi_11_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_11_dw_rddata_valid           (dfi_dw_rddata_valid[11])
   ,.dfi_11_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_11_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_11_ctrlupd_req               (dfi_ctrlupd_req[11])
   ,.dfi_11_phyupd_ack                (dfi_phyupd_ack[11] )
   ,.dfi_11_clk_init                  ( /* Not Connected */  )
   ,.dfi_11_init_complete             (dfi_init_complete[11])
   ,.dfi_11_out_rst_n                 (dfi_out_rst_n[11]    )



   ,.dfi_12_clk                       (dfi_clk_buf[12]            )
   ,.dfi_12_rst_n                     (dfi_rst_n[12]              )
   ,.dfi_12_init_start                (dfi_init_start[12]         )
   ,.dfi_12_aw_ck_p0                  (dfi_aw_ck_p0[12]           )
   ,.dfi_12_aw_cke_p0                 (dfi_aw_cke_p0[12]          )
   ,.dfi_12_aw_row_p0                 (dfi_aw_row_p0[12]          )
   ,.dfi_12_aw_col_p0                 (dfi_aw_col_p0[12]          )
   ,.dfi_12_dw_wrdata_p0              (dfi_dw_wrdata_p0[12]       )
   ,.dfi_12_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[12]  )
   ,.dfi_12_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[12]   )
   ,.dfi_12_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[12]   )
   ,.dfi_12_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[12] )
   ,.dfi_12_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[12])
   ,.dfi_12_aw_ck_p1                  (dfi_aw_ck_p1[12]           )
   ,.dfi_12_aw_cke_p1                 (dfi_aw_cke_p1[12]          )
   ,.dfi_12_aw_row_p1                 (dfi_aw_row_p1[12]          )
   ,.dfi_12_aw_col_p1                 (dfi_aw_col_p1[12]          )
   ,.dfi_12_dw_wrdata_p1              (dfi_dw_wrdata_p1[12]       )
   ,.dfi_12_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[12]  )
   ,.dfi_12_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[12]   )
   ,.dfi_12_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[12]   )
   ,.dfi_12_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[12] )
   ,.dfi_12_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[12])
   ,.dfi_12_aw_ck_dis                 (dfi_aw_ck_dis[12]          )
   ,.dfi_12_lp_pwr_e_req              (dfi_lp_pwr_e_req[12]       )
   ,.dfi_12_lp_sr_e_req               (dfi_lp_sr_e_req[12]        )
   ,.dfi_12_lp_pwr_x_req              (dfi_lp_pwr_x_req[12]     )
   ,.dfi_12_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[12]      )
   ,.dfi_12_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[12]      )
   ,.dfi_12_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[12]      )
   ,.dfi_12_ctrlupd_ack               (dfi_ctrlupd_ack[12]        )
   ,.dfi_12_phyupd_req                (dfi_phyupd_req[12]         )
   ,.dfi_12_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_12_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_12_dw_rddata_p0              (dfi_dw_rddata_p0[12]    )
   ,.dfi_12_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[12] )
   ,.dfi_12_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[12])
   ,.dfi_12_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[12])
   ,.dfi_12_dw_rddata_p1              (dfi_dw_rddata_p1[12]    )
   ,.dfi_12_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[12] )
   ,.dfi_12_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[12])
   ,.dfi_12_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[12])
   ,.dfi_12_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_12_dw_rddata_valid           (dfi_dw_rddata_valid[12])
   ,.dfi_12_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_12_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_12_ctrlupd_req               (dfi_ctrlupd_req[12])
   ,.dfi_12_phyupd_ack                (dfi_phyupd_ack[12] )
   ,.dfi_12_clk_init                  ( /* Not Connected */  )
   ,.dfi_12_init_complete             (dfi_init_complete[12])
   ,.dfi_12_out_rst_n                 (dfi_out_rst_n[12]    )


   ,.dfi_13_clk                       (dfi_clk_buf[13]            )
   ,.dfi_13_rst_n                     (dfi_rst_n[13]              )
   ,.dfi_13_init_start                (dfi_init_start[13]         )
   ,.dfi_13_aw_ck_p0                  (dfi_aw_ck_p0[13]           )
   ,.dfi_13_aw_cke_p0                 (dfi_aw_cke_p0[13]          )
   ,.dfi_13_aw_row_p0                 (dfi_aw_row_p0[13]          )
   ,.dfi_13_aw_col_p0                 (dfi_aw_col_p0[13]          )
   ,.dfi_13_dw_wrdata_p0              (dfi_dw_wrdata_p0[13]       )
   ,.dfi_13_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[13]  )
   ,.dfi_13_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[13]   )
   ,.dfi_13_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[13]   )
   ,.dfi_13_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[13] )
   ,.dfi_13_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[13])
   ,.dfi_13_aw_ck_p1                  (dfi_aw_ck_p1[13]           )
   ,.dfi_13_aw_cke_p1                 (dfi_aw_cke_p1[13]          )
   ,.dfi_13_aw_row_p1                 (dfi_aw_row_p1[13]          )
   ,.dfi_13_aw_col_p1                 (dfi_aw_col_p1[13]          )
   ,.dfi_13_dw_wrdata_p1              (dfi_dw_wrdata_p1[13]       )
   ,.dfi_13_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[13]  )
   ,.dfi_13_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[13]   )
   ,.dfi_13_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[13]   )
   ,.dfi_13_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[13] )
   ,.dfi_13_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[13])
   ,.dfi_13_aw_ck_dis                 (dfi_aw_ck_dis[13]          )
   ,.dfi_13_lp_pwr_e_req              (dfi_lp_pwr_e_req[13]       )
   ,.dfi_13_lp_sr_e_req               (dfi_lp_sr_e_req[13]        )
   ,.dfi_13_lp_pwr_x_req              (dfi_lp_pwr_x_req[13]     )
   ,.dfi_13_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[13]      )
   ,.dfi_13_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[13]      )
   ,.dfi_13_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[13]      )
   ,.dfi_13_ctrlupd_ack               (dfi_ctrlupd_ack[13]        )
   ,.dfi_13_phyupd_req                (dfi_phyupd_req[13]         )
   ,.dfi_13_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_13_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_13_dw_rddata_p0              (dfi_dw_rddata_p0[13]    )
   ,.dfi_13_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[13] )
   ,.dfi_13_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[13])
   ,.dfi_13_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[13])
   ,.dfi_13_dw_rddata_p1              (dfi_dw_rddata_p1[13]    )
   ,.dfi_13_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[13] )
   ,.dfi_13_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[13])
   ,.dfi_13_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[13])
   ,.dfi_13_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_13_dw_rddata_valid           (dfi_dw_rddata_valid[13])
   ,.dfi_13_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_13_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_13_ctrlupd_req               (dfi_ctrlupd_req[13])
   ,.dfi_13_phyupd_ack                (dfi_phyupd_ack[13] )
   ,.dfi_13_clk_init                  ( /* Not Connected */  )
   ,.dfi_13_init_complete             (dfi_init_complete[13])
   ,.dfi_13_out_rst_n                 (dfi_out_rst_n[13]    )



   ,.dfi_14_clk                       (dfi_clk_buf[14]            )
   ,.dfi_14_rst_n                     (dfi_rst_n[14]              )
   ,.dfi_14_init_start                (dfi_init_start[14]         )
   ,.dfi_14_aw_ck_p0                  (dfi_aw_ck_p0[14]           )
   ,.dfi_14_aw_cke_p0                 (dfi_aw_cke_p0[14]          )
   ,.dfi_14_aw_row_p0                 (dfi_aw_row_p0[14]          )
   ,.dfi_14_aw_col_p0                 (dfi_aw_col_p0[14]          )
   ,.dfi_14_dw_wrdata_p0              (dfi_dw_wrdata_p0[14]       )
   ,.dfi_14_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[14]  )
   ,.dfi_14_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[14]   )
   ,.dfi_14_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[14]   )
   ,.dfi_14_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[14] )
   ,.dfi_14_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[14])
   ,.dfi_14_aw_ck_p1                  (dfi_aw_ck_p1[14]           )
   ,.dfi_14_aw_cke_p1                 (dfi_aw_cke_p1[14]          )
   ,.dfi_14_aw_row_p1                 (dfi_aw_row_p1[14]          )
   ,.dfi_14_aw_col_p1                 (dfi_aw_col_p1[14]          )
   ,.dfi_14_dw_wrdata_p1              (dfi_dw_wrdata_p1[14]       )
   ,.dfi_14_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[14]  )
   ,.dfi_14_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[14]   )
   ,.dfi_14_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[14]   )
   ,.dfi_14_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[14] )
   ,.dfi_14_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[14])
   ,.dfi_14_aw_ck_dis                 (dfi_aw_ck_dis[14]          )
   ,.dfi_14_lp_pwr_e_req              (dfi_lp_pwr_e_req[14]       )
   ,.dfi_14_lp_sr_e_req               (dfi_lp_sr_e_req[14]        )
   ,.dfi_14_lp_pwr_x_req              (dfi_lp_pwr_x_req[14]     )
   ,.dfi_14_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[14]      )
   ,.dfi_14_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[14]      )
   ,.dfi_14_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[14]      )
   ,.dfi_14_ctrlupd_ack               (dfi_ctrlupd_ack[14]        )
   ,.dfi_14_phyupd_req                (dfi_phyupd_req[14]         )
   ,.dfi_14_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_14_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_14_dw_rddata_p0              (dfi_dw_rddata_p0[14]    )
   ,.dfi_14_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[14] )
   ,.dfi_14_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[14])
   ,.dfi_14_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[14])
   ,.dfi_14_dw_rddata_p1              (dfi_dw_rddata_p1[14]    )
   ,.dfi_14_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[14] )
   ,.dfi_14_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[14])
   ,.dfi_14_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[14])
   ,.dfi_14_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_14_dw_rddata_valid           (dfi_dw_rddata_valid[14])
   ,.dfi_14_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_14_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_14_ctrlupd_req               (dfi_ctrlupd_req[14])
   ,.dfi_14_phyupd_ack                (dfi_phyupd_ack[14] )
   ,.dfi_14_clk_init                  ( /* Not Connected */  )
   ,.dfi_14_init_complete             (dfi_init_complete[14])
   ,.dfi_14_out_rst_n                 (dfi_out_rst_n[14]    )



   ,.dfi_15_clk                       (dfi_clk_buf[14]            )
   ,.dfi_15_rst_n                     (dfi_rst_n[14]              )
   ,.dfi_15_init_start                (dfi_init_start[15]         )
   ,.dfi_15_aw_ck_p0                  (dfi_aw_ck_p0[15]           )
   ,.dfi_15_aw_cke_p0                 (dfi_aw_cke_p0[15]          )
   ,.dfi_15_aw_row_p0                 (dfi_aw_row_p0[15]          )
   ,.dfi_15_aw_col_p0                 (dfi_aw_col_p0[15]          )
   ,.dfi_15_dw_wrdata_p0              (dfi_dw_wrdata_p0[15]       )
   ,.dfi_15_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0[15]  )
   ,.dfi_15_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0[15]   )
   ,.dfi_15_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0[15]   )
   ,.dfi_15_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0[15] )
   ,.dfi_15_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0[15])
   ,.dfi_15_aw_ck_p1                  (dfi_aw_ck_p1[15]           )
   ,.dfi_15_aw_cke_p1                 (dfi_aw_cke_p1[15]          )
   ,.dfi_15_aw_row_p1                 (dfi_aw_row_p1[15]          )
   ,.dfi_15_aw_col_p1                 (dfi_aw_col_p1[15]          )
   ,.dfi_15_dw_wrdata_p1              (dfi_dw_wrdata_p1[15]       )
   ,.dfi_15_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1[15]  )
   ,.dfi_15_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1[15]   )
   ,.dfi_15_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1[15]   )
   ,.dfi_15_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1[15] )
   ,.dfi_15_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1[15])
   ,.dfi_15_aw_ck_dis                 (dfi_aw_ck_dis[15]          )
   ,.dfi_15_lp_pwr_e_req              (dfi_lp_pwr_e_req[15]       )
   ,.dfi_15_lp_sr_e_req               (dfi_lp_sr_e_req[15]        )
   ,.dfi_15_lp_pwr_x_req              (dfi_lp_pwr_x_req[15]     )
   ,.dfi_15_aw_tx_indx_ld             (dfi_aw_tx_indx_ld[15]      )
   ,.dfi_15_dw_tx_indx_ld             (dfi_dw_tx_indx_ld[15]      )
   ,.dfi_15_dw_rx_indx_ld             (dfi_dw_rx_indx_ld[15]      )
   ,.dfi_15_ctrlupd_ack               (dfi_ctrlupd_ack[15]        )
   ,.dfi_15_phyupd_req                (dfi_phyupd_req[15]         )
   ,.dfi_15_dw_wrdata_dqs_p0          (8'hff)
   ,.dfi_15_dw_wrdata_dqs_p1          (8'hff)
   ,.dfi_15_dw_rddata_p0              (dfi_dw_rddata_p0[15]    )
   ,.dfi_15_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0[15] )
   ,.dfi_15_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0[15])
   ,.dfi_15_dw_rddata_par_p0          (dfi_dw_rddata_par_p0[15])
   ,.dfi_15_dw_rddata_p1              (dfi_dw_rddata_p1[15]    )
   ,.dfi_15_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1[15] )
   ,.dfi_15_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1[15])
   ,.dfi_15_dw_rddata_par_p1          (dfi_dw_rddata_par_p1[15])
   ,.dfi_15_dbi_byte_disable          ( /* Not Connected */  )
   ,.dfi_15_dw_rddata_valid           (dfi_dw_rddata_valid[15])
   ,.dfi_15_dw_derr_n                 ( /* Not Connected */  )
   ,.dfi_15_aw_aerr_n                 ( /* Not Connected */  )
   ,.dfi_15_ctrlupd_req               (dfi_ctrlupd_req[15])
   ,.dfi_15_phyupd_ack                (dfi_phyupd_ack[15] )
   ,.dfi_15_clk_init                  ( /* Not Connected */  )
   ,.dfi_15_init_complete             (dfi_init_complete[15])
   ,.dfi_15_out_rst_n                 (dfi_out_rst_n[15]    )    
    
);
  
  
  OBUF HBM_CATRIP_INST (
    .I (1'b0),
    .O (hbm_cattrip_output)
    );
  
  endmodule