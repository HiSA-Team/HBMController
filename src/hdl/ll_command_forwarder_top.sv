/** Last Level Command Fowarder Top Module **/
`timescale 1ps/1ps


module ll_command_forwarder_top # (
    parameter		P_ROW_ADDR_WIDTH = 16,
    parameter		P_COL_ADDR_WIDTH = 12,
    parameter		P_BA_ADDR_WIDTH	 = 5,
    parameter       P_DATA_WIDTH     = 256
)(

    input HBM_REF_CLK_0,
    input ARESET_N_0,
    input APB_PCLK,
    input APB_PRESET_N,
    
    
    /* My Interface */
    output                              ready_to_cmd_m,
    input [3:0]                         cmd_m,
    input [P_BA_ADDR_WIDTH-1:0]         bank_address_m,
    input [P_ROW_ADDR_WIDTH-1:0]        row_address_m,
    input [P_COL_ADDR_WIDTH-1:0]        column_address_m,
    input [(P_DATA_WIDTH*2)-1:0]        data_m

);


localparam MMCM_CLKFBOUT_MULT_F  = 9;
localparam MMCM_CLKOUT0_DIVIDE_F = 2;
localparam MMCM_DIVCLK_DIVIDE    = 1;
localparam MMCM_CLKIN1_PERIOD    = 10.000;


wire HBM_REF_CLK_0_buf;
wire dfi_0_clk_buf;
wire dfi_0_clk_in;
wire MMCM_LOCK_0;

wire           dfi_0_init_start;
wire   [1:0]   dfi_0_aw_ck_p0;
wire   [1:0]   dfi_0_aw_cke_p0;
wire   [11:0]  dfi_0_aw_row_p0;
wire   [15:0]  dfi_0_aw_col_p0;
wire   [255:0] dfi_0_dw_wrdata_p0;
wire   [31:0]  dfi_0_dw_wrdata_mask_p0;
wire   [31:0]  dfi_0_dw_wrdata_dbi_p0;
wire   [7:0]   dfi_0_dw_wrdata_par_p0;
wire   [7:0]   dfi_0_dw_wrdata_dq_en_p0;
wire   [7:0]   dfi_0_dw_wrdata_par_en_p0;
wire   [1:0]   dfi_0_aw_ck_p1;
wire   [1:0]   dfi_0_aw_cke_p1;
wire   [11:0]  dfi_0_aw_row_p1;
wire   [15:0]  dfi_0_aw_col_p1;
wire   [255:0] dfi_0_dw_wrdata_p1;
wire   [31:0]  dfi_0_dw_wrdata_mask_p1;
wire   [31:0]  dfi_0_dw_wrdata_dbi_p1;
wire   [7:0]   dfi_0_dw_wrdata_par_p1;
wire   [7:0]   dfi_0_dw_wrdata_dq_en_p1;
wire   [7:0]   dfi_0_dw_wrdata_par_en_p1;
wire           dfi_0_aw_ck_dis;
wire           dfi_0_lp_pwr_e_req;
wire           dfi_0_lp_sr_e_req;
wire           dfi_0_lp_pwr_x_e_req;
wire           dfi_0_aw_tx_indx_ld;
wire           dfi_0_dw_tx_indx_ld;
wire           dfi_0_dw_rx_indx_ld;
wire           dfi_0_ctrlupd_ack;
wire           dfi_0_phyupd_req;
wire           dfi_0_init_complete;
wire   [255:0] dfi_0_dw_rddata_p0;
wire   [31:0]  dfi_0_dw_rddata_dm_p0;
wire   [31:0]  dfi_0_dw_rddata_dbi_p0;
wire   [7:0]   dfi_0_dw_rddata_par_p0;
wire   [255:0] dfi_0_dw_rddata_p1;
wire   [31:0]  dfi_0_dw_rddata_dm_p1;
wire   [31:0]  dfi_0_dw_rddata_dbi_p1;
wire   [7:0]   dfi_0_dw_rddata_par_p1;
wire   [15:0]  dfi_0_dbi_byte_disable;
wire   [3:0]   dfi_0_dw_rddata_valid;
wire   [7:0]   dfi_0_dw_derr_n;
wire   [1:0]   dfi_0_aw_aerr_n;
wire           dfi_0_ctrlupd_req;
wire           dfi_0_phyupd_ack;
wire           dfi_0_clk_init;
wire           dfi_0_out_rst_n;
wire   [7:0]   dfi_0_dw_wrdata_dqs_p0;
wire   [7:0]   dfi_0_dw_wrdata_dqs_p1;


wire          DRAM_0_STAT_CATTRIP;
wire [  6:0]  DRAM_0_STAT_TEMP;

wire      APB_0_PCLK_IBUF;
wire      APB_0_PCLK_BUF;
wire      APB_0_PRESET_N_sync;
wire     [ 31:0]  APB_0_PWDATA = 32'b0;
wire     [ 21:0]  APB_0_PADDR  = 22'b0;
wire              APB_0_PENABLE = 1'b0;
wire              APB_0_PSEL = 1'b0;
wire              APB_0_PWRITE = 1'b0;
wire     [ 31:0]  APB_0_PRDATA;
wire              APB_0_PREADY;
wire              APB_0_PSLVERR;
wire          apb_seq_complete_0_s;

wire	[3:0]		w_rst_sys_rst_0;

reg  [7:0] cnt_rst_0_0;
reg  rst_0_mmcm_n_0;

reg	[7:0]	cnt_apb_rst_p2l_st0;
wire		w_apb_0_reset_n_inv_st0;
reg			r_apb_preset_n_p2l_st0; 

reg          dfi_0_rst_n;
reg          rst_0_r1_n;
reg          rst0_st0_r1_n;
reg          rst0_st0_r2_n;
reg          rst_st0_n;

reg           w_rst_sys_rst_0_r1;
reg           w_rst_sys_rst_0_r2;
reg           w_rst_sys_rst_1_r1;
reg           w_rst_sys_rst_1_r2;

reg           rst_0_mmcm_n;
reg  [3:0]    cnt_rst_0;


IBUF u_APB_0_PCLK_IBUF  (
  .I (APB_PCLK),
  .O (APB_0_PCLK_IBUF)
);

BUFG u_APB_0_PCLK_BUFG  (
  .I (APB_0_PCLK_IBUF),
  .O (APB_0_PCLK_BUF)
);

BUFG u_HBM_REF_CLK_0  (
  .I (HBM_REF_CLK_0),
  .O (HBM_REF_CLK_0_buf)
);

BUFG u_dfi_0_clk_buf  (
  .I (dfi_0_clk_in),
  .O (dfi_0_clk_buf)
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
    .CLKOUT0             (dfi_0_clk_in),

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
    .CLKIN1              (HBM_REF_CLK_0_buf),
    .CLKIN2              (1'b0),
    // Other control and status signals
    .LOCKED              (MMCM_LOCK_0),
    .PWRDWN              (1'b0),
    .RST                 (~rst_0_mmcm_n_0),
  
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


ll_command_forwarder#(
    .P_ROW_ADDR_WIDTH(P_ROW_ADDR_WIDTH),
    .P_COL_ADDR_WIDTH(P_COL_ADDR_WIDTH),
    .P_BA_ADDR_WIDTH(P_BA_ADDR_WIDTH)

) u_ll_command_forwarder (
    .dfi_clk                               (dfi_0_clk_buf),
    .dfi_rst_n                             (dfi_0_rst_n),
    .dfi_rst_buf_n                         (dfi_0_out_rst_n),
    
    .dfi_init_start                        (dfi_0_init_start         ),
    .dfi_aw_ck_p0                          (dfi_0_aw_ck_p0           ),
    .dfi_aw_cke_p0                         (dfi_0_aw_cke_p0          ),
    .dfi_aw_row_p0                         (dfi_0_aw_row_p0          ),
    .dfi_aw_col_p0                         (dfi_0_aw_col_p0          ),
    .dfi_dw_wrdata_p0                      (dfi_0_dw_wrdata_p0       ),
    .dfi_dw_wrdata_mask_p0                 (dfi_0_dw_wrdata_mask_p0  ),
    .dfi_dw_wrdata_dbi_p0                  (dfi_0_dw_wrdata_dbi_p0   ),
    .dfi_dw_wrdata_par_p0                  (dfi_0_dw_wrdata_par_p0   ),
    .dfi_dw_wrdata_dq_en_p0                (dfi_0_dw_wrdata_dq_en_p0 ),
    .dfi_dw_wrdata_par_en_p0               (dfi_0_dw_wrdata_par_en_p0),
    .dfi_aw_ck_p1                          (dfi_0_aw_ck_p1           ),
    .dfi_aw_cke_p1                         (dfi_0_aw_cke_p1          ),
    .dfi_aw_row_p1                         (dfi_0_aw_row_p1          ),
    .dfi_aw_col_p1                         (dfi_0_aw_col_p1          ),
    .dfi_dw_wrdata_p1                      (dfi_0_dw_wrdata_p1       ),
    .dfi_dw_wrdata_mask_p1                 (dfi_0_dw_wrdata_mask_p1  ),
    .dfi_dw_wrdata_dbi_p1                  (dfi_0_dw_wrdata_dbi_p1   ),
    .dfi_dw_wrdata_par_p1                  (dfi_0_dw_wrdata_par_p1   ),
    .dfi_dw_wrdata_dq_en_p1                (dfi_0_dw_wrdata_dq_en_p1 ),
    .dfi_dw_wrdata_par_en_p1               (dfi_0_dw_wrdata_par_en_p1),
    .dfi_aw_ck_dis                         (dfi_0_aw_ck_dis          ),
    .dfi_lp_pwr_e_req                      (dfi_0_lp_pwr_e_req       ),
    .dfi_lp_sr_e_req                       (dfi_0_lp_sr_e_req        ),
    .dfi_lp_pwr_x_e_req                    (dfi_0_lp_pwr_x_e_req     ),
    .dfi_aw_tx_indx_ld                     (dfi_0_aw_tx_indx_ld      ),
    .dfi_dw_tx_indx_ld                     (dfi_0_dw_tx_indx_ld      ),
    .dfi_dw_rx_indx_ld                     (dfi_0_dw_rx_indx_ld      ),
    .dfi_ctrlupd_ack                       (dfi_0_ctrlupd_ack        ),
    .dfi_phyupd_req                        (dfi_0_phyupd_req         ),

    .dfi_init_complete                     (dfi_0_init_complete   ),
    .dfi_dw_rddata_valid                   (dfi_0_dw_rddata_valid ),
    .dfi_dw_rddata_p0                      (dfi_0_dw_rddata_p0    ),
    .dfi_dw_rddata_dm_p0                   (dfi_0_dw_rddata_dm_p0 ),
    .dfi_dw_rddata_dbi_p0                  (dfi_0_dw_rddata_dbi_p0),
    .dfi_dw_rddata_par_p0                  (dfi_0_dw_rddata_par_p0),
    .dfi_dw_rddata_p1                      (dfi_0_dw_rddata_p1    ),
    .dfi_dw_rddata_dm_p1                   (dfi_0_dw_rddata_dm_p1 ),
    .dfi_dw_rddata_dbi_p1                  (dfi_0_dw_rddata_dbi_p1),
    .dfi_dw_rddata_par_p1                  (dfi_0_dw_rddata_par_p1),
    .dfi_ctrlupd_req                       (dfi_0_ctrlupd_req     ),
    .dfi_phyupd_ack                        (dfi_0_phyupd_ack      ),
    
    .ready_to_cmd_m(ready_to_cmd_m),
    .cmd_m(cmd_m),
    .bank_address_m(bank_address_m),
    .row_address_m(row_address_m),
    .column_address_m(column_address_m),
    .data_m(data_m)
);

hbm_0 u_hbm_0
(
    .HBM_REF_CLK_0                 (HBM_REF_CLK_0_buf)
    ,.dfi_0_clk                    (dfi_0_clk_buf)
    ,.dfi_0_rst_n                  (dfi_0_rst_n   )
    ,.dfi_0_init_start             (dfi_0_init_start         )
    ,.dfi_0_aw_ck_p0               (dfi_0_aw_ck_p0           )
    ,.dfi_0_aw_cke_p0              (dfi_0_aw_cke_p0          )
    ,.dfi_0_aw_row_p0              (dfi_0_aw_row_p0          )
    ,.dfi_0_aw_col_p0              (dfi_0_aw_col_p0          )
    ,.dfi_0_dw_wrdata_p0           (dfi_0_dw_wrdata_p0       )
    ,.dfi_0_dw_wrdata_mask_p0      (dfi_0_dw_wrdata_mask_p0  )
    ,.dfi_0_dw_wrdata_dbi_p0       (dfi_0_dw_wrdata_dbi_p0   )
    ,.dfi_0_dw_wrdata_par_p0       (dfi_0_dw_wrdata_par_p0   )
    ,.dfi_0_dw_wrdata_dq_en_p0     (dfi_0_dw_wrdata_dq_en_p0 )
    ,.dfi_0_dw_wrdata_par_en_p0    (dfi_0_dw_wrdata_par_en_p0)
    ,.dfi_0_aw_ck_p1               (dfi_0_aw_ck_p1           )
    ,.dfi_0_aw_cke_p1              (dfi_0_aw_cke_p1          )
    ,.dfi_0_aw_row_p1              (dfi_0_aw_row_p1          )
    ,.dfi_0_aw_col_p1              (dfi_0_aw_col_p1          )
    ,.dfi_0_dw_wrdata_p1           (dfi_0_dw_wrdata_p1       )
    ,.dfi_0_dw_wrdata_mask_p1      (dfi_0_dw_wrdata_mask_p1  )
    ,.dfi_0_dw_wrdata_dbi_p1       (dfi_0_dw_wrdata_dbi_p1   )
    ,.dfi_0_dw_wrdata_par_p1       (dfi_0_dw_wrdata_par_p1   )
    ,.dfi_0_dw_wrdata_dq_en_p1     (dfi_0_dw_wrdata_dq_en_p1 )
    ,.dfi_0_dw_wrdata_par_en_p1    (dfi_0_dw_wrdata_par_en_p1)
    ,.dfi_0_aw_ck_dis              (dfi_0_aw_ck_dis          )
    ,.dfi_0_lp_pwr_e_req           (dfi_0_lp_pwr_e_req       )
    ,.dfi_0_lp_sr_e_req            (dfi_0_lp_sr_e_req        )
    ,.dfi_0_lp_pwr_x_req           (dfi_0_lp_pwr_x_e_req     )
    ,.dfi_0_aw_tx_indx_ld          (dfi_0_aw_tx_indx_ld      )
    ,.dfi_0_dw_tx_indx_ld          (dfi_0_dw_tx_indx_ld      )
    ,.dfi_0_dw_rx_indx_ld          (dfi_0_dw_rx_indx_ld      )
    ,.dfi_0_ctrlupd_ack            (dfi_0_ctrlupd_ack        )
    ,.dfi_0_phyupd_req             (dfi_0_phyupd_req         )
    ,.dfi_0_dw_wrdata_dqs_p0       (8'hff)
    ,.dfi_0_dw_wrdata_dqs_p1       (8'hff)

    ,.APB_0_PCLK                   (APB_0_PCLK_BUF)
    ,.APB_0_PRESET_N               (APB_0_PRESET_N_sync)
//    ,.APB_0_PWDATA                 (APB_0_PWDATA  )
//    ,.APB_0_PADDR                  (APB_0_PADDR   )
//    ,.APB_0_PENABLE                (APB_0_PENABLE )
//    ,.APB_0_PSEL                   (APB_0_PSEL    )
//    ,.APB_0_PWRITE                 (APB_0_PWRITE  )

    ,.dfi_0_dw_rddata_p0           (dfi_0_dw_rddata_p0    )
    ,.dfi_0_dw_rddata_dm_p0        (dfi_0_dw_rddata_dm_p0 )
    ,.dfi_0_dw_rddata_dbi_p0       (dfi_0_dw_rddata_dbi_p0)
    ,.dfi_0_dw_rddata_par_p0       (dfi_0_dw_rddata_par_p0)
    ,.dfi_0_dw_rddata_p1           (dfi_0_dw_rddata_p1    )
    ,.dfi_0_dw_rddata_dm_p1        (dfi_0_dw_rddata_dm_p1 )
    ,.dfi_0_dw_rddata_dbi_p1       (dfi_0_dw_rddata_dbi_p1)
    ,.dfi_0_dw_rddata_par_p1       (dfi_0_dw_rddata_par_p1)
    ,.dfi_0_dbi_byte_disable       ( /* Not Connected */  )
    ,.dfi_0_dw_rddata_valid        (dfi_0_dw_rddata_valid)
    ,.dfi_0_dw_derr_n              ( /* Not Connected */  )
    ,.dfi_0_aw_aerr_n              ( /* Not Connected */  )
    ,.dfi_0_ctrlupd_req            (dfi_0_ctrlupd_req)
    ,.dfi_0_phyupd_ack             (dfi_0_phyupd_ack )
    ,.dfi_0_clk_init               ( /* Not Connected */  )
    ,.dfi_0_init_complete          (dfi_0_init_complete)
    ,.dfi_0_out_rst_n              (dfi_0_out_rst_n    )

    ,.apb_complete_0               (apb_seq_complete_0_s)
//    ,.APB_0_PRDATA                 (APB_0_PRDATA )
//    ,.APB_0_PREADY                 (APB_0_PREADY )
//    ,.APB_0_PSLVERR                (APB_0_PSLVERR)

    ,.DRAM_0_STAT_CATTRIP          (DRAM_0_STAT_CATTRIP)
    ,.DRAM_0_STAT_TEMP             (DRAM_0_STAT_TEMP   )

);



always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        cnt_rst_0_0        <= 8'h00;
        rst_0_mmcm_n_0     <= 1'b0;
    end else begin
        if (~rst_0_r1_n) begin
            if( cnt_rst_0_0 >= 8'd100 ) begin
                cnt_rst_0_0 <= cnt_rst_0_0;
                rst_0_mmcm_n_0 <= 1'b0;
            end
            else begin
                cnt_rst_0_0 <= cnt_rst_0_0 + 1;
                rst_0_mmcm_n_0 <= rst_0_mmcm_n_0;
            end
        end else begin
            cnt_rst_0_0 <= 'd0;
            rst_0_mmcm_n_0 <= 1'b1;
        end
    end
end


always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        rst_0_mmcm_n  <= 1'b0;
    end else begin
        if (cnt_rst_0 != 4'h0) begin
            rst_0_mmcm_n <= 1'b0;
        end else begin
            rst_0_mmcm_n <= 1'b1;
        end
    end
end


always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        w_rst_sys_rst_0_r1 <= 1'b0;
        w_rst_sys_rst_0_r2 <= 1'b0;
    end else begin
        w_rst_sys_rst_0_r1 <= w_rst_sys_rst_0[1];
        w_rst_sys_rst_0_r2 <= w_rst_sys_rst_0_r1;
    end
end

always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        rst_st0_n <= 1'b0;
    end else begin
        rst_st0_n <= rst_0_mmcm_n & MMCM_LOCK_0 & (~w_rst_sys_rst_0_r2);
    end
end



always @ (posedge dfi_0_clk_buf or negedge ARESET_N_0) begin
  if (~ARESET_N_0) begin
    rst0_st0_r1_n <= 1'b0;
    rst0_st0_r2_n <= 1'b0;
  end else begin
    rst0_st0_r1_n <= rst_st0_n;
    rst0_st0_r2_n <= rst0_st0_r1_n;
  end
end

always @ (posedge dfi_0_clk_buf or negedge ARESET_N_0) begin
  if (~ARESET_N_0) begin
    dfi_0_rst_n <= 1'b0;
  end else begin
    dfi_0_rst_n <= rst0_st0_r2_n;
  end
end


always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        cnt_rst_0 <= 4'hA;
    end else begin
        if (~rst_0_r1_n) begin
            cnt_rst_0 <= 4'hA;
        end else if (cnt_rst_0 != 4'h0) begin
            cnt_rst_0 <= cnt_rst_0 - 1'b1;
        end else begin
            cnt_rst_0 <= cnt_rst_0;
        end
    end
end

always @ (posedge HBM_REF_CLK_0_buf or negedge ARESET_N_0) begin
    if (~ARESET_N_0) begin
        rst_0_r1_n <= 1'b0;
    end else begin
        rst_0_r1_n <= 1'b1;
    end
end

assign w_rst_sys_rst_0 = 4'h0;
assign	w_apb_0_reset_n_inv_st0 = APB_PRESET_N && ~w_rst_sys_rst_0[0];
always @ ( posedge APB_0_PCLK_BUF or negedge  w_apb_0_reset_n_inv_st0 )
begin
	if( w_apb_0_reset_n_inv_st0 == 1'b0 )
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

assign APB_0_PRESET_N_sync = r_apb_preset_n_p2l_st0 ;


endmodule