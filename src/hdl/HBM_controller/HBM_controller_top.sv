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
    parameter N_CHANNELS = 2 /* Number of enabled channels */
)

(
    input HBM_REF_CLK,
    input ARESET_N,
    input APB_PCLK,
    input APB_PRESET_N,
    
    output hbm_cattrip_output
);

localparam MMCM_CLKFBOUT_MULT_F  = 9;
localparam MMCM_CLKOUT0_DIVIDE_F = 2;
localparam MMCM_DIVCLK_DIVIDE    = 1;
localparam MMCM_CLKIN1_PERIOD    = 10.000;

(* keep = "TRUE" *) wire HBM_REF_CLK_buf/*[0:N_CHANNELS-1]*/;
(* keep = "TRUE" *) wire dfi_clk_buf/*[0:N_CHANNELS-1]*/;
(* keep = "TRUE" *) wire dfi_clk_in/*[0:N_CHANNELS-1]*/;
(* keep = "TRUE" *) wire MMCM_LOCK/*[0:N_CHANNELS-1]*/;

(* keep = "TRUE" *) wire      APB_PCLK_IBUF/*[0:N_CHANNELS-1]*/;
(* keep = "TRUE" *) wire      APB_PCLK_BUF/*[0:N_CHANNELS-1]*/;
(* keep = "TRUE" *) wire      APB_PRESET_N_sync/*[0:N_CHANNELS-1]*/;

wire	[3:0]		w_rst_sys_rst/*[0:N_CHANNELS-1]*/;
reg  [7:0] cnt_rst_0/*[0:N_CHANNELS-1]*/;
reg  rst_mmcm_n/*[0:N_CHANNELS-1]*/;

reg	[7:0]	cnt_apb_rst_p2l_st0/*[0:N_CHANNELS-1]*/;
wire		w_apb_reset_n_inv_st0/*[0:N_CHANNELS-1]*/;
reg			r_apb_preset_n_p2l_st0/*[0:N_CHANNELS-1]*/; 

wire           dfi_init_start/*[0:N_CHANNELS-1]*/;
wire   [1:0]   dfi_aw_ck_p0/*[0:N_CHANNELS-1]*/;
wire   [1:0]   dfi_aw_cke_p0/*[0:N_CHANNELS-1]*/;
wire   [11:0]  dfi_aw_row_p0/*[0:N_CHANNELS-1]*/;
wire   [15:0]  dfi_aw_col_p0/*[0:N_CHANNELS-1]*/;
wire   [255:0] dfi_dw_wrdata_p0/*[0:N_CHANNELS-1]*/;
wire   [31:0]  dfi_dw_wrdata_mask_p0/*[0:N_CHANNELS-1]*/;
wire   [31:0]  dfi_dw_wrdata_dbi_p0/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_wrdata_par_p0/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_wrdata_dq_en_p0/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_wrdata_par_en_p0/*[0:N_CHANNELS-1]*/;
wire   [1:0]   dfi_aw_ck_p1/*[0:N_CHANNELS-1]*/;
wire   [1:0]   dfi_aw_cke_p1/*[0:N_CHANNELS-1]*/;
wire   [11:0]  dfi_aw_row_p1/*[0:N_CHANNELS-1]*/;
wire   [15:0]  dfi_aw_col_p1/*[0:N_CHANNELS-1]*/;
wire   [255:0] dfi_dw_wrdata_p1/*[0:N_CHANNELS-1]*/;
wire   [31:0]  dfi_dw_wrdata_mask_p1/*[0:N_CHANNELS-1]*/;
wire   [31:0]  dfi_dw_wrdata_dbi_p1/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_wrdata_par_p1/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_wrdata_dq_en_p1/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_wrdata_par_en_p1/*[0:N_CHANNELS-1]*/;
wire           dfi_aw_ck_dis/*[0:N_CHANNELS-1]*/;
wire           dfi_lp_pwr_e_req/*[0:N_CHANNELS-1]*/;
wire           dfi_lp_sr_e_req/*[0:N_CHANNELS-1]*/;
wire           dfi_lp_pwr_x_e_req/*[0:N_CHANNELS-1]*/;
wire           dfi_aw_tx_indx_ld/*[0:N_CHANNELS-1]*/;
wire           dfi_dw_tx_indx_ld/*[0:N_CHANNELS-1]*/;
wire           dfi_dw_rx_indx_ld/*[0:N_CHANNELS-1]*/;
wire           dfi_ctrlupd_ack/*[0:N_CHANNELS-1]*/;
wire           dfi_phyupd_req/*[0:N_CHANNELS-1]*/;
wire           dfi_init_complete/*[0:N_CHANNELS-1]*/;
wire   [255:0] dfi_dw_rddata_p0/*[0:N_CHANNELS-1]*/;
wire   [31:0]  dfi_dw_rddata_dm_p0/*[0:N_CHANNELS-1]*/;
wire   [31:0]  dfi_dw_rddata_dbi_p0/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_rddata_par_p0/*[0:N_CHANNELS-1]*/;
wire   [255:0] dfi_dw_rddata_p1/*[0:N_CHANNELS-1]*/;
wire   [31:0]  dfi_dw_rddata_dm_p1/*[0:N_CHANNELS-1]*/;
wire   [31:0]  dfi_dw_rddata_dbi_p1/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_rddata_par_p1/*[0:N_CHANNELS-1]*/;
wire   [15:0]  dfi_dbi_byte_disable/*[0:N_CHANNELS-1]*/;
wire   [3:0]   dfi_dw_rddata_valid/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_derr_n/*[0:N_CHANNELS-1]*/;
wire   [1:0]   dfi_aw_aerr_n/*[0:N_CHANNELS-1]*/;
wire           dfi_ctrlupd_req/*[0:N_CHANNELS-1]*/;
wire           dfi_phyupd_ack/*[0:N_CHANNELS-1]*/;
wire           dfi_clk_init/*[0:N_CHANNELS-1]*/;
wire           dfi_out_rst_n/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_wrdata_dqs_p0/*[0:N_CHANNELS-1]*/;
wire   [7:0]   dfi_dw_wrdata_dqs_p1/*[0:N_CHANNELS-1]*/;

wire          DRAM_STAT_CATTRIP/*[0:N_CHANNELS-1]*/;
wire   [6:0]  DRAM_STAT_TEMP/*[0:N_CHANNELS-1]*/;

// wire      [31:0]  APB_PWDAT/*A[0:N_CHANNELS-1*/] = 32'b0;
// wire      [21:0]  APB_PADD/*R[0:N_CHANNELS-1*/]  = 22'b0;
// wire              APB_PENABL/*E[0:N_CHANNELS-1*/] = 1'b0;
// wire              APB_PSE/*L[0:N_CHANNELS-1*/] = 1'b0;
// wire              APB_PWRIT/*E[0:N_CHANNELS-1*/] = 1'b0;
wire      [31:0]  APB_PRDATA/*[0:N_CHANNELS-1]*/;
wire              APB_PREADY/*[0:N_CHANNELS-1]*/;
wire              APB_PSLVERR/*[0:N_CHANNELS-1]*/;
wire              apb_seq_complete_s/*[0:N_CHANNELS-1]*/;

reg          dfi_rst_n/*[0:N_CHANNELS-1]*/;
reg          rst_r1_n/*[0:N_CHANNELS-1]*/;
reg          rst0_st0_r1_n/*[0:N_CHANNELS-1]*/;
reg          rst0_st0_r2_n/*[0:N_CHANNELS-1]*/;
reg          rst_st0_n/*[0:N_CHANNELS-1]*/;

reg           w_rst_sys_rst_r1/*[0:N_CHANNELS-1]*/;
reg           w_rst_sys_rst_r2/*[0:N_CHANNELS-1]*/;
reg           w_rst_sys_rst_1_r1/*[0:N_CHANNELS-1]*/;
reg           w_rst_sys_rst_1_r2/*[0:N_CHANNELS-1]*/;

reg           rst_mmcm/*[0:N_CHANNELS-1]*/;
reg  [3:0]    cnt_rst/*[0:N_CHANNELS-1]*/;

//genvar i;
//generate
//    for( i = 0; i < N_CHANNELS; i = i+1 ) begin

        

        always @ (posedge HBM_REF_CLK_buf/*[i]*/ or negedge ARESET_N) begin
            if (~ARESET_N) begin
                cnt_rst_0/*[i]*/        <= 8'h00;
                rst_mmcm_n/*[i]*/     <= 1'b0;
            end else begin
                if (~rst_r1_n/*[i]*/) begin
                    if( cnt_rst_0/*[i]*/ >= 8'd100 ) begin
                        cnt_rst_0/*[i]*/ <= cnt_rst_0/*[i]*/;
                        rst_mmcm_n/*[i]*/ <= 1'b0;
                    end
                    else begin
                        cnt_rst_0/*[i]*/ <= cnt_rst_0/*[i]*/ + 1;
                        rst_mmcm_n/*[i]*/ <= rst_mmcm_n/*[i]*/;
                    end
                end else begin
                    cnt_rst_0/*[i]*/ <= 'd0;
                    rst_mmcm_n/*[i]*/ <= 1'b1;
                end
            end
        end


        always @ (posedge HBM_REF_CLK_buf/*[i]*/ or negedge ARESET_N) begin
            if (~ARESET_N) begin
                rst_mmcm/*[i]*/  <= 1'b0;
            end else begin
                if (cnt_rst/*[i]*/ != 4'h0) begin
                    rst_mmcm/*[i]*/ <= 1'b0;
                end else begin
                    rst_mmcm/*[i]*/ <= 1'b1;
                end
            end
        end


        always @ (posedge HBM_REF_CLK_buf/*[i]*/ or negedge ARESET_N) begin
            if (~ARESET_N) begin
                w_rst_sys_rst_r1/*[i]*/ <= 1'b0;
                w_rst_sys_rst_r2/*[i]*/ <= 1'b0;
            end else begin
                w_rst_sys_rst_r1/*[i]*/ <= w_rst_sys_rst/*[i]*/[1];
                w_rst_sys_rst_r2/*[i]*/ <= w_rst_sys_rst_r1/*[i]*/;
            end
        end

        always @ (posedge HBM_REF_CLK_buf/*[i]*/ or negedge ARESET_N) begin
            if (~ARESET_N) begin
                rst_st0_n/*[i]*/ <= 1'b0;
            end else begin
                rst_st0_n/*[i]*/ <= rst_mmcm/*[i]*/ & MMCM_LOCK/*[i]*/ & (~w_rst_sys_rst_r2/*[i]*/);
            end
        end



        always @ (posedge dfi_clk_buf/*[i]*/ or negedge ARESET_N) begin
        if (~ARESET_N) begin
            rst0_st0_r1_n/*[i]*/ <= 1'b0;
            rst0_st0_r2_n/*[i]*/ <= 1'b0;
        end else begin
            rst0_st0_r1_n/*[i]*/ <= rst_st0_n/*[i]*/;
            rst0_st0_r2_n/*[i]*/ <= rst0_st0_r1_n/*[i]*/;
        end
        end

        always @ (posedge dfi_clk_buf/*[i]*/ or negedge ARESET_N) begin
        if (~ARESET_N) begin
            dfi_rst_n/*[i]*/ <= 1'b0;
        end else begin
            dfi_rst_n/*[i]*/ <= rst0_st0_r2_n/*[i]*/;
        end
        end


        always @ (posedge HBM_REF_CLK_buf/*[i]*/ or negedge ARESET_N) begin
            if (~ARESET_N) begin
                cnt_rst/*[i]*/ <= 4'hA;
            end else begin
                if (~rst_r1_n/*[i]*/) begin
                    cnt_rst/*[i]*/ <= 4'hA;
                end else if (cnt_rst/*[i]*/ != 4'h0) begin
                    cnt_rst/*[i]*/ <= cnt_rst/*[i]*/ - 1'b1;
                end else begin
                    cnt_rst/*[i]*/ <= cnt_rst/*[i]*/;
                end
            end
        end

        always @ (posedge HBM_REF_CLK_buf/*[i]*/ or negedge ARESET_N) begin
            if (~ARESET_N) begin
                rst_r1_n/*[i]*/ <= 1'b0;
            end else begin
                rst_r1_n/*[i]*/ <= 1'b1;
            end
        end

        assign w_rst_sys_rst/*[i]*/ = 4'h0;
        assign	w_apb_reset_n_inv_st0/*[i]*/ = APB_PRESET_N && ~w_rst_sys_rst/*[i]*/[0];
        always @ ( posedge APB_PCLK_BUF/*[i]*/ or negedge  w_apb_reset_n_inv_st0/*[i]*/ )
        begin
            if( w_apb_reset_n_inv_st0/*[i]*/ == 1'b0 )
                begin
                    cnt_apb_rst_p2l_st0/*[i]*/ <= 8'd0;
                    r_apb_preset_n_p2l_st0/*[i]*/ <= 1'd0;
                end
            else
                begin
                    if( cnt_apb_rst_p2l_st0/*[i]*/ >= 8'd200 )
                    begin
                        r_apb_preset_n_p2l_st0/*[i]*/	<= 1'd1;
                        cnt_apb_rst_p2l_st0/*[i]*/		<= cnt_apb_rst_p2l_st0/*[i]*/;
                    end
                    else
                    begin
                        cnt_apb_rst_p2l_st0/*[i]*/		<= cnt_apb_rst_p2l_st0/*[i]*/ + 8'd1;
                        r_apb_preset_n_p2l_st0/*[i]*/ <= 1'b0;
                    end
                end
        end

        assign APB_PRESET_N_sync/*[i]*/ = r_apb_preset_n_p2l_st0/*[i]*/ ;



        IBUF u_APB_PCLK_IBUF  (
        .I (APB_PCLK),
        .O (APB_PCLK_IBUF/*[i]*/)
        );

        BUFG u_APB_PCLK_BUFG  (
        .I (APB_PCLK_IBUF/*[i]*/),
        .O (APB_PCLK_BUF/*[i]*/)
        );

        BUFG u_HBM_REF_CLK  (
        .I (HBM_REF_CLK),
        .O (HBM_REF_CLK_buf/*[i]*/)
        );

        BUFG u_dfi_clk_buf  (
        .I (dfi_clk_in/*[i]*/),
        .O (dfi_clk_buf/*[i]*/)
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
        u_mmcm
            // Output clocks
        (
            .CLKFBOUT            (),
            .CLKFBOUTB           (),
            .CLKOUT0             (dfi_clk_in/*[i]*/),

            .CLKOUT0B            (),
            .CLKOUT1             (),
            .CLKOUT1B            (),
            .CLKOUT2             (),
            .CLKOUT2B            (),
            .CLKOUT3             (),
            .CLKOUT3B            (),
            .CLKOUT4             (),
            .CLKOUT5             (),
            .CLKOUT6             (),
            // Input clock control
            .CLKFBIN             (), //mmcm_fb
            .CLKIN1              (HBM_REF_CLK_buf/*[i]*/),
            .CLKIN2              (1'b0),
            // Other control and status signals
            .LOCKED              (MMCM_LOCK/*[i]*/),
            .PWRDWN              (1'b0),
            .RST                 (~rst_mmcm_n/*[i]*/),
        
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

        HBM_controller#() 
        HBM_controller_i
        (
            .dfi_clk_buf                    (dfi_clk_buf/*[i]*/   )
            ,.dfi_rst_n                     (dfi_rst_n/*[i]*/     )
            ,.dfi_rst_buf_n                 (dfi_out_rst_n/*[i]*/ )
            ,.dfi_init_start                (dfi_init_start/*[i]*/         )
            ,.dfi_aw_ck_p0                  (dfi_aw_ck_p0/*[i]*/           )
            ,.dfi_aw_cke_p0                 (dfi_aw_cke_p0/*[i]*/          )
            ,.dfi_aw_row_p0                 (dfi_aw_row_p0/*[i]*/          )
            ,.dfi_aw_col_p0                 (dfi_aw_col_p0/*[i]*/          )
            ,.dfi_dw_wrdata_p0              (dfi_dw_wrdata_p0/*[i]*/       )
            ,.dfi_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0/*[i]*/  )
            ,.dfi_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0/*[i]*/   )
            ,.dfi_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0/*[i]*/   )
            ,.dfi_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0/*[i]*/ )
            ,.dfi_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0/*[i]*/)
            ,.dfi_aw_ck_p1                  (dfi_aw_ck_p1/*[i]*/           )
            ,.dfi_aw_cke_p1                 (dfi_aw_cke_p1/*[i]*/          )
            ,.dfi_aw_row_p1                 (dfi_aw_row_p1/*[i]*/          )
            ,.dfi_aw_col_p1                 (dfi_aw_col_p1/*[i]*/          )
            ,.dfi_dw_wrdata_p1              (dfi_dw_wrdata_p1/*[i]*/       )
            ,.dfi_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1/*[i]*/  )
            ,.dfi_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1/*[i]*/   )
            ,.dfi_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1/*[i]*/   )
            ,.dfi_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1/*[i]*/ )
            ,.dfi_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1/*[i]*/)
            ,.dfi_aw_ck_dis                 (dfi_aw_ck_dis/*[i]*/          )
            ,.dfi_lp_pwr_e_req              (dfi_lp_pwr_e_req/*[i]*/       )
            ,.dfi_lp_sr_e_req               (dfi_lp_sr_e_req/*[i]*/        )
            ,.dfi_lp_pwr_x_req              (dfi_lp_pwr_x_e_req/*[i]*/     )
            ,.dfi_aw_tx_indx_ld             (dfi_aw_tx_indx_ld/*[i]*/      )
            ,.dfi_dw_tx_indx_ld             (dfi_dw_tx_indx_ld/*[i]*/      )
            ,.dfi_dw_rx_indx_ld             (dfi_dw_rx_indx_ld/*[i]*/      )
            ,.dfi_ctrlupd_ack               (dfi_ctrlupd_ack/*[i]*/        )
            ,.dfi_phyupd_req                (dfi_phyupd_req/*[i]*/         )
            ,.dfi_dw_rddata_p0              (dfi_dw_rddata_p0/*[i]*/    )
            ,.dfi_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0/*[i]*/ )
            ,.dfi_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0/*[i]*/)
            ,.dfi_dw_rddata_par_p0          (dfi_dw_rddata_par_p0/*[i]*/)
            ,.dfi_dw_rddata_p1              (dfi_dw_rddata_p1/*[i]*/    )
            ,.dfi_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1/*[i]*/ )
            ,.dfi_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1/*[i]*/)
            ,.dfi_dw_rddata_par_p1          (dfi_dw_rddata_par_p1/*[i]*/)
            ,.dfi_dw_rddata_valid           (dfi_dw_rddata_valid/*[i]*/)
            ,.dfi_ctrlupd_req               (dfi_ctrlupd_req/*[i]*/)
            ,.dfi_phyupd_ack                (dfi_phyupd_ack/*[i]*/ )
            ,.dfi_init_complete             (dfi_init_complete/*[i]*/)
        );
// end
// endgenerate




hbm_0 hbm_0_i
(
    .HBM_REF_CLK_0                    (HBM_REF_CLK_buf/*[0]*/        )
    ,.dfi_0_clk                       (dfi_clk_buf/*[0]*/            )
    ,.dfi_0_rst_n                     (dfi_rst_n/*[0]*/              )
    ,.dfi_0_init_start                (dfi_init_start/*[0]*/         )
    ,.dfi_0_aw_ck_p0                  (dfi_aw_ck_p0/*[0]*/           )
    ,.dfi_0_aw_cke_p0                 (dfi_aw_cke_p0/*[0]*/          )
    ,.dfi_0_aw_row_p0                 (dfi_aw_row_p0/*[0]*/          )
    ,.dfi_0_aw_col_p0                 (dfi_aw_col_p0/*[0]*/          )
    ,.dfi_0_dw_wrdata_p0              (dfi_dw_wrdata_p0/*[0]*/       )
    ,.dfi_0_dw_wrdata_mask_p0         (dfi_dw_wrdata_mask_p0/*[0]*/  )
    ,.dfi_0_dw_wrdata_dbi_p0          (dfi_dw_wrdata_dbi_p0/*[0]*/   )
    ,.dfi_0_dw_wrdata_par_p0          (dfi_dw_wrdata_par_p0/*[0]*/   )
    ,.dfi_0_dw_wrdata_dq_en_p0        (dfi_dw_wrdata_dq_en_p0/*[0]*/ )
    ,.dfi_0_dw_wrdata_par_en_p0       (dfi_dw_wrdata_par_en_p0/*[0]*/)
    ,.dfi_0_aw_ck_p1                  (dfi_aw_ck_p1/*[0]*/           )
    ,.dfi_0_aw_cke_p1                 (dfi_aw_cke_p1/*[0]*/          )
    ,.dfi_0_aw_row_p1                 (dfi_aw_row_p1/*[0]*/          )
    ,.dfi_0_aw_col_p1                 (dfi_aw_col_p1/*[0]*/          )
    ,.dfi_0_dw_wrdata_p1              (dfi_dw_wrdata_p1/*[0]*/       )
    ,.dfi_0_dw_wrdata_mask_p1         (dfi_dw_wrdata_mask_p1/*[0]*/  )
    ,.dfi_0_dw_wrdata_dbi_p1          (dfi_dw_wrdata_dbi_p1/*[0]*/   )
    ,.dfi_0_dw_wrdata_par_p1          (dfi_dw_wrdata_par_p1/*[0]*/   )
    ,.dfi_0_dw_wrdata_dq_en_p1        (dfi_dw_wrdata_dq_en_p1/*[0]*/ )
    ,.dfi_0_dw_wrdata_par_en_p1       (dfi_dw_wrdata_par_en_p1/*[0]*/)
    ,.dfi_0_aw_ck_dis                 (dfi_aw_ck_dis/*[0]*/          )
    ,.dfi_0_lp_pwr_e_req              (dfi_lp_pwr_e_req/*[0]*/       )
    ,.dfi_0_lp_sr_e_req               (dfi_lp_sr_e_req/*[0]*/        )
    ,.dfi_0_lp_pwr_x_req              (dfi_lp_pwr_x_e_req/*[0]*/     )
    ,.dfi_0_aw_tx_indx_ld             (dfi_aw_tx_indx_ld/*[0]*/      )
    ,.dfi_0_dw_tx_indx_ld             (dfi_dw_tx_indx_ld/*[0]*/      )
    ,.dfi_0_dw_rx_indx_ld             (dfi_dw_rx_indx_ld/*[0]*/      )
    ,.dfi_0_ctrlupd_ack               (dfi_ctrlupd_ack/*[0]*/        )
    ,.dfi_0_phyupd_req                (dfi_phyupd_req/*[0]*/         )
    ,.dfi_0_dw_wrdata_dqs_p0          (8'hff)
    ,.dfi_0_dw_wrdata_dqs_p1          (8'hff)

    ,.APB_0_PCLK                      (APB_PCLK_BUF/*[0]*/)
    ,.APB_0_PRESET_N                  (APB_PRESET_N_sync/*[0]*/)
//    ,.APB_0_PWDATA                  (APB_PWDATA  )
//    ,.APB_0_PADDR                   (APB_PADDR   )
//    ,.APB_0_PENABLE                 (APB_PENABLE )
//    ,.APB_0_PSEL                    (APB_PSEL    )
//    ,.APB_0_PWRITE                  (APB_PWRITE  )

    ,.dfi_0_dw_rddata_p0              (dfi_dw_rddata_p0/*[0]*/    )
    ,.dfi_0_dw_rddata_dm_p0           (dfi_dw_rddata_dm_p0/*[0]*/ )
    ,.dfi_0_dw_rddata_dbi_p0          (dfi_dw_rddata_dbi_p0/*[0]*/)
    ,.dfi_0_dw_rddata_par_p0          (dfi_dw_rddata_par_p0/*[0]*/)
    ,.dfi_0_dw_rddata_p1              (dfi_dw_rddata_p1/*[0]*/    )
    ,.dfi_0_dw_rddata_dm_p1           (dfi_dw_rddata_dm_p1/*[0]*/ )
    ,.dfi_0_dw_rddata_dbi_p1          (dfi_dw_rddata_dbi_p1/*[0]*/)
    ,.dfi_0_dw_rddata_par_p1          (dfi_dw_rddata_par_p1/*[0]*/)
    ,.dfi_0_dbi_byte_disable          ( /* Not Connected */  )
    ,.dfi_0_dw_rddata_valid           (dfi_dw_rddata_valid/*[0]*/)
    ,.dfi_0_dw_derr_n                 ( /* Not Connected */  )
    ,.dfi_0_aw_aerr_n                 ( /* Not Connected */  )
    ,.dfi_0_ctrlupd_req               (dfi_ctrlupd_req/*[0]*/)
    ,.dfi_0_phyupd_ack                (dfi_phyupd_ack/*[0]*/ )
    ,.dfi_0_clk_init                  ( /* Not Connected */  )
    ,.dfi_0_init_complete             (dfi_init_complete/*[0]*/)
    ,.dfi_0_out_rst_n                 (dfi_out_rst_n/*[0]*/    )

    ,.apb_complete_0                  (apb_seq_complete_s/*[0]*/)
//    ,.APB_0_PRDATA                  (APB_PRDATA )
//    ,.APB_0_PREADY                  (APB_PREADY )
//    ,.APB_0_PSLVERR                 (APB_PSLVERR)

    ,.DRAM_0_STAT_CATTRIP             (DRAM_STAT_CATTRIP/*[0]*/)
    ,.DRAM_0_STAT_TEMP                (DRAM_STAT_TEMP/*[0]*/   )
);
  
  
  OBUF HBM_CATRIP_INST (
    .I (1'b0),
    .O (hbm_cattrip_output)
    );
  
  endmodule