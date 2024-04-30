/******************************************************************************
// (c) Copyright 2017 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
******************************************************************************/
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : 1.0
//  \   \         Application        : MIG
//  /   /         Filename           : example_top_syn.sv
// /___/   /\     Date Last Modified : $Date$
// \   \  /  \    Date Created       : Tue Jan 3 2017
//  \___\/\___\
//
//Device: UltraScale+ HBM
//Design Name: HBM
//*****************************************************************************

`ifdef MODEL_TECH
  `define SIMULATION_MODE
`elsif INCA
  `define SIMULATION_MODE
`elsif VCS
  `define SIMULATION_MODE
`elsif XILINX_SIMULATOR
  `define SIMULATION_MODE
`elsif _VCP
  `define SIMULATION_MODE
`endif
`timescale 1ps/1ps
////////////////////////////////////////////////////////////////////////////////
// Module Delcaration
////////////////////////////////////////////////////////////////////////////////
module HBM_controller_top_example # (
  parameter APP_DATA_WIDTH   = 256,
  parameter APP_ADDR_WIDTH   = 33,
`ifdef SIMULATION_MODE
  parameter SIMULATION            = "TRUE" 
`else
`ifdef NETLIST_SIM
  parameter SIMULATION            = "TRUE"
`else
  parameter SIMULATION            = "FALSE"
`endif
`endif
  ) (
   input               APB_0_PCLK
  ,input               APB_0_PRESET_N
  ,input               AXI_ACLK_IN_0
  ,input               AXI_ARESET_N_0

`ifdef SIMULATION_MODE
  ,input      [ 31:0]  APB_0_PWDATA
  ,input      [ 21:0]  APB_0_PADDR
  ,input               APB_0_PENABLE
  ,input               APB_0_PSEL
  ,input               APB_0_PWRITE
  ,output     [ 31:0]  APB_0_PRDATA
  ,output              APB_0_PREADY
  ,output              APB_0_PSLVERR
`endif
`ifdef SIMULATION_MODE
  ,output              boot_mode_done_0
  ,output              axi_00_data_msmatch_err
`endif
  ,output                hbm_cattrip_output
`ifndef SIMULATION_MODE
  ,output              axi_trans_done
  ,output              axi_trans_err
`else
`ifdef NETLIST_SIM
  ,output              axi_trans_done
  ,output              axi_trans_err
`endif
`endif
    ,input [32:0]address
    ,input [256-1:0]write_data
    ,input [1:0]request
);
`ifdef OPT_DATA_W
	parameter APP_DATA_WIDTH_4D = APP_DATA_WIDTH/4;  
`else
	parameter APP_DATA_WIDTH_4D = APP_DATA_WIDTH;  
`endif

////////////////////////////////////////////////////////////////////////////////
// Localparams
////////////////////////////////////////////////////////////////////////////////
  localparam MMCM_CLKFBOUT_MULT_F  = 9;
  localparam MMCM_CLKOUT0_DIVIDE_F = 2;
  localparam MMCM_DIVCLK_DIVIDE    = 1;
  localparam MMCM_CLKIN1_PERIOD    = 10.000;
  
  localparam MMCM1_CLKFBOUT_MULT_F  = 9;
  localparam MMCM1_CLKOUT0_DIVIDE_F = 2;
  localparam MMCM1_DIVCLK_DIVIDE    = 1;
  localparam MMCM1_CLKIN1_PERIOD    = 10.000;

////////////////////////////////////////////////////////////////////////////////
// Wire Delcaration
////////////////////////////////////////////////////////////////////////////////
    OBUF HBM_CATRIP_INST (
    .I (1'b0),
    .O (hbm_cattrip_output)
    ); 

(* keep = "TRUE" *)   wire          AXI_ACLK_IN_0_buf;
(* keep = "TRUE" *)   wire          AXI_ACLK_IN_0_iobuf;
(* keep = "TRUE" *)   wire          AXI_ACLK0_st0;
(* keep = "TRUE" *)   wire          AXI_ACLK1_st0;
(* keep = "TRUE" *)   wire          AXI_ACLK2_st0;
(* keep = "TRUE" *)   wire          AXI_ACLK3_st0;
(* keep = "TRUE" *)   wire          AXI_ACLK4_st0;
(* keep = "TRUE" *)   wire          AXI_ACLK5_st0;
(* keep = "TRUE" *)   wire          AXI_ACLK6_st0;
`ifdef SIMULATION_MODE
(* keep = "TRUE" *)   reg          AXI_ACLK0_st0_buf;
(* keep = "TRUE" *)   reg          AXI_ACLK1_st0_buf;
(* keep = "TRUE" *)   reg          AXI_ACLK2_st0_buf;
(* keep = "TRUE" *)   reg          AXI_ACLK3_st0_buf;
(* keep = "TRUE" *)   reg          AXI_ACLK4_st0_buf;
(* keep = "TRUE" *)   reg          AXI_ACLK5_st0_buf;
(* keep = "TRUE" *)   reg          AXI_ACLK6_st0_buf;
`else
(* keep = "TRUE" *)   wire          AXI_ACLK0_st0_buf;
(* keep = "TRUE" *)   wire          AXI_ACLK1_st0_buf;
(* keep = "TRUE" *)   wire          AXI_ACLK2_st0_buf;
(* keep = "TRUE" *)   wire          AXI_ACLK3_st0_buf;
(* keep = "TRUE" *)   wire          AXI_ACLK4_st0_buf;
(* keep = "TRUE" *)   wire          AXI_ACLK5_st0_buf;
(* keep = "TRUE" *)   wire          AXI_ACLK6_st0_buf;
`endif
(* keep = "TRUE" *)  wire          i_clk_atg_axi_vio_st0;
  wire          MMCM_LOCK_0;
  wire          apb_seq_complete_0_s;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_0_st0_r0, apb_seq_complete_0_st0_r1, apb_seq_complete_0_st0_r2;
  wire          tg_start_st0_0;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_1_st0_r0, apb_seq_complete_1_st0_r1, apb_seq_complete_1_st0_r2;
  wire          tg_start_st0_1;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_2_st0_r0, apb_seq_complete_2_st0_r1, apb_seq_complete_2_st0_r2;
  wire          tg_start_st0_2;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_3_st0_r0, apb_seq_complete_3_st0_r1, apb_seq_complete_3_st0_r2;
  wire          tg_start_st0_3;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_4_st0_r0, apb_seq_complete_4_st0_r1, apb_seq_complete_4_st0_r2;
  wire          tg_start_st0_4;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_5_st0_r0, apb_seq_complete_5_st0_r1, apb_seq_complete_5_st0_r2;
  wire          tg_start_st0_5;
  (* ASYNC_REG = "TRUE" *) reg           apb_seq_complete_6_st0_r0, apb_seq_complete_6_st0_r1, apb_seq_complete_6_st0_r2;
  wire          tg_start_st0_6;

  wire              ext_apb_seq_complete_s;
  wire              ext_apb_seq_complete_0_int_s;
  wire              ext_apb_seq_complete_0_s;
`ifndef SIMULATION_MODE
  wire     [ 31:0]  APB_0_PWDATA = 32'b0;
  wire     [ 21:0]  APB_0_PADDR  = 22'b0;
  wire              APB_0_PENABLE = 1'b0;
  wire              APB_0_PSEL = 1'b0;
  wire              APB_0_PWRITE = 1'b0;
  wire     [ 31:0]  APB_0_PRDATA;
  wire              APB_0_PREADY;
  wire              APB_0_PSLVERR;
`endif

`ifndef SIMULATION_MODE
  wire              boot_mode_done_0;
`endif
 
  wire              boot_mode_done_1 = 1'b1;
 
  wire              boot_mode_done_2 = 1'b1;
 
  wire              boot_mode_done_3 = 1'b1;
 
  wire              boot_mode_done_4 = 1'b1;
 
  wire              boot_mode_done_5 = 1'b1;
 
  wire              boot_mode_done_6 = 1'b1;
 
  wire              boot_mode_done_7 = 1'b1;
 
  wire              boot_mode_done_8 = 1'b1;
 
  wire              boot_mode_done_9 = 1'b1;
 
  wire              boot_mode_done_10 = 1'b1;
 
  wire              boot_mode_done_11 = 1'b1;
 
  wire              boot_mode_done_12 = 1'b1;
 
  wire              boot_mode_done_13 = 1'b1;
 
  wire              boot_mode_done_14 = 1'b1;
 
  wire              boot_mode_done_15 = 1'b1;

  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_0;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_0;
  wire [ 36:0]  AXI_00_ARADDR;
  wire [  1:0]  AXI_00_ARBURST;
  wire [  5:0]  AXI_00_ARID;
  wire [  7:0]  AXI_00_ARLEN;
  wire [  2:0]  AXI_00_ARSIZE;
  wire          AXI_00_ARVALID;
  wire [ 36:0]  AXI_00_AWADDR;
  wire [  1:0]  AXI_00_AWBURST;
  wire [  5:0]  AXI_00_AWID;
  wire [  7:0]  AXI_00_AWLEN;
  wire [  2:0]  AXI_00_AWSIZE;
  wire          AXI_00_AWVALID;
  wire          AXI_00_RREADY;
  wire          AXI_00_BREADY;
  wire [255:0]  AXI_00_WDATA;
  wire          AXI_00_WLAST;
  wire [ 31:0]  AXI_00_WSTRB;
  wire [ 31:0]  AXI_00_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_00_WDATA_PARITY;
  wire          AXI_00_WVALID;
  wire [3:0]    AXI_00_ARCACHE;
  wire [3:0]    AXI_00_AWCACHE;
  wire [2:0]    AXI_00_AWPROT;
  wire      [31:0]  prbs_mode_seed_0 = 32'habcd_1234;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_awaddr_1;
  wire [APP_ADDR_WIDTH-1:0] o_m_axi_araddr_1;
  wire [ 36:0]  AXI_01_ARADDR;
  wire [  1:0]  AXI_01_ARBURST;
  wire [  5:0]  AXI_01_ARID;
  wire [  7:0]  AXI_01_ARLEN;
  wire [  2:0]  AXI_01_ARSIZE;
  wire          AXI_01_ARVALID;
  wire [ 36:0]  AXI_01_AWADDR;
  wire [  1:0]  AXI_01_AWBURST;
  wire [  5:0]  AXI_01_AWID;
  wire [  7:0]  AXI_01_AWLEN;
  wire [  2:0]  AXI_01_AWSIZE;
  wire          AXI_01_AWVALID;
  wire          AXI_01_RREADY;
  wire          AXI_01_BREADY;
  wire [255:0]  AXI_01_WDATA;
  wire          AXI_01_WLAST;
  wire [ 31:0]  AXI_01_WSTRB;
  wire [ 31:0]  AXI_01_WDATA_PARITY_i;
  reg  [ 31:0]  AXI_01_WDATA_PARITY;
  wire          AXI_01_WVALID;
  wire [3:0]    AXI_01_ARCACHE;
  wire [3:0]    AXI_01_AWCACHE;
  wire [2:0]    AXI_01_AWPROT;
  wire      [31:0]  prbs_mode_seed_1 = 32'habcd_1234;
 
  wire          AXI_00_ARREADY;
  wire          AXI_00_AWREADY;
  wire [ 31:0]  AXI_00_RDATA_PARITY;
  wire [255:0]  AXI_00_RDATA;
  wire [  5:0]  AXI_00_RID;
  wire          AXI_00_RLAST;
  wire [  1:0]  AXI_00_RRESP;
  wire          AXI_00_RVALID;
  wire          AXI_00_WREADY;
  wire [  5:0]  AXI_00_BID;
  wire [  1:0]  AXI_00_BRESP;
  wire          AXI_00_BVALID;
  wire [  1:0]  AXI_00_DFI_AW_AERR_N;
  wire          AXI_00_DFI_CLK_BUF;
  wire [  7:0]  AXI_00_DFI_DBI_BYTE_DISABLE;
  wire [20:00]  AXI_00_DFI_DW_RDDATA_DBI;
  wire [  7:0]  AXI_00_DFI_DW_RDDATA_DERR;
  wire [  1:0]  AXI_00_DFI_DW_RDDATA_VALID;
  wire          AXI_00_DFI_INIT_COMPLETE;
  wire          AXI_00_DFI_PHYUPD_REQ;
  wire          AXI_00_DFI_PHY_LP_STATE;
  wire          AXI_00_DFI_RST_N_BUF;
  wire [5:0]    AXI_00_MC_STATUS;
  wire [7:0]    AXI_00_PHY_STATUS;
  wire          AXI_01_ARREADY;
  wire          AXI_01_AWREADY;
  wire [ 31:0]  AXI_01_RDATA_PARITY;
  wire [255:0]  AXI_01_RDATA;
  wire [  5:0]  AXI_01_RID;
  wire          AXI_01_RLAST;
  wire [  1:0]  AXI_01_RRESP;
  wire          AXI_01_RVALID;
  wire          AXI_01_WREADY;
  wire [  5:0]  AXI_01_BID;
  wire [  1:0]  AXI_01_BRESP;
  wire          AXI_01_BVALID;
  wire [  1:0]  AXI_01_DFI_AW_AERR_N;
  wire          AXI_01_DFI_CLK_BUF;
  wire [  7:0]  AXI_01_DFI_DBI_BYTE_DISABLE;
  wire [20:00]  AXI_01_DFI_DW_RDDATA_DBI;
  wire [  7:0]  AXI_01_DFI_DW_RDDATA_DERR;
  wire [  1:0]  AXI_01_DFI_DW_RDDATA_VALID;
  wire          AXI_01_DFI_INIT_COMPLETE;
  wire          AXI_01_DFI_PHYUPD_REQ;
  wire          AXI_01_DFI_PHY_LP_STATE;
  wire          AXI_01_DFI_RST_N_BUF;
  
  wire          DRAM_0_STAT_CATTRIP;
  wire [  6:0]  DRAM_0_STAT_TEMP;

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

  wire   [15:0]  vio_0_instr_RA;
  wire   [4:0]   vio_0_instr_BA;
  wire   [1:0]   vio_0_instr_data_mode;
  wire           vio_0_instr_wrt_page;
  wire           vio_0_instr_rd_page;
  wire           vio_0_instr_wrt_loop;
  wire           vio_0_instr_rd_loop;
  wire           vio_0_instr_end;
  wire           vio_0_instr_dir_en;
  wire           vio_0_loop_break_pulse;
  wire           vio_0_resetb_fsm;
  wire           vio_0_phy_tg_start;
  wire           vio_0_rst_rd_cmp_err;
  wire           vio_0_instr_full_bank_wrt_rd;
  wire           vio_0_instr_add_mode;
  wire   [15:0]  vio_0_instr_bank_size;
  wire           vio_0_dq_bit_inv_en_ps0;
  wire           vio_0_dq_bit_inv_en_ps1;
  wire           ila_0_phy_tg_status_run; 
  wire   [255:0] ila_0_dfi_dw_rddata_first_exp_ps0;
  wire   [255:0] ila_0_dfi_dw_rddata_first_error_ps0;
  wire   [3:0]   ila_0_dfi_dw_rddata_first_error_valid_ps0;
  wire   [255:0] ila_0_dfi_dw_rddata_first_exp_ps1;
  wire   [255:0] ila_0_dfi_dw_rddata_first_error_ps1;
  wire   [3:0]   ila_0_dfi_dw_rddata_first_error_valid_ps1;
  wire           ila_0_phy_tg_done;
  wire   [3:0]   ila_0_phy_tg_state;
  wire           ila_0_phy_tg_status_rd_cmp_err;
  wire   [7:0]   ila_0_phy_tg_status_rd_cmp_err_cnt;
  wire   [7:0]   ila_0_phy_tg_status_rd_cmp_err_cnt_loop;
  wire   [20:0]  ila_0_phy_tg_status_curr_BA_RA;



wire reset_hbm_controller;





`ifndef SIMULATION_MODE
  wire          axi_00_data_msmatch_err;
`endif
  wire          axi_01_data_msmatch_err = 1'b0;
  wire          axi_02_data_msmatch_err = 1'b0;
  wire          axi_03_data_msmatch_err = 1'b0;
  wire          axi_04_data_msmatch_err = 1'b0;
  wire          axi_05_data_msmatch_err = 1'b0;
  wire          axi_06_data_msmatch_err = 1'b0;
  wire          axi_07_data_msmatch_err = 1'b0;
  wire          axi_08_data_msmatch_err = 1'b0;
  wire          axi_09_data_msmatch_err = 1'b0;
  wire          axi_10_data_msmatch_err = 1'b0;
  wire          axi_11_data_msmatch_err = 1'b0;
  wire          axi_12_data_msmatch_err = 1'b0;
  wire          axi_13_data_msmatch_err = 1'b0;
  wire          axi_14_data_msmatch_err = 1'b0;
  wire          axi_15_data_msmatch_err = 1'b0;
  wire                        vio_tg_rst_0;
  wire                        vio_tg_start_0;
  wire                        vio_tg_err_chk_en_0;
  wire                        vio_tg_err_clear_0;
  wire [3:0]                  vio_tg_instr_addr_mode_0;
  wire [3:0]                  vio_tg_instr_data_mode_0;
  wire [3:0]                  vio_tg_instr_rw_mode_0;
  wire [1:0]                  vio_tg_instr_rw_submode_0;
  wire [31:0]                 vio_tg_instr_num_of_iter_0;
  wire [5:0]                  vio_tg_instr_nxt_instr_0;
  wire                        vio_tg_restart_0;
  wire                        vio_tg_pause_0;
  wire                        vio_tg_err_clear_all_0;
  wire                        vio_tg_err_continue_0;
  wire                        vio_tg_instr_program_en_0;
  wire                        vio_tg_direct_instr_en_0;
  wire [4:0]                  vio_tg_instr_num_0;
  wire [2:0]                  vio_tg_instr_victim_mode_0;
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_0;
  wire [2:0]                  vio_tg_instr_victim_select_0;
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_0;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_0;
  wire                        vio_tg_seed_program_en_0;
  wire [7:0]                  vio_tg_seed_num_0;
  wire [22:0]                 vio_tg_seed_0;
  wire [7:0]                  vio_tg_glb_victim_bit_0;
  wire [32:0]                 vio_tg_glb_start_addr_0;
  wire [3:0]                  vio_tg_status_state_0;
  wire                        vio_tg_status_err_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_0;
  wire [31:0]                 vio_tg_status_err_cnt_0;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_0;
  wire                        vio_tg_status_exp_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_0;
  wire                        vio_tg_status_read_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_0;
  wire                        vio_tg_status_first_err_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_0;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_0;
  wire                        vio_tg_status_first_exp_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_0;
  wire                        vio_tg_status_first_read_bit_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_0;
  wire                        vio_tg_status_err_bit_sticky_valid_0;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_0;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_0;
  wire                        vio_tg_status_err_type_valid_0;
  wire                        vio_tg_status_err_type_0;
  wire                        vio_tg_status_wr_done_0;
  wire                        vio_tg_status_watch_dog_hang_0;
  wire                        tg_ila_debug_0;
  reg  [4:0]                  wr_cnt_00;
  reg  [4:0]                  rd_cnt_00;

  wire                        vio_tg_rst_1;                      
  wire                        vio_tg_start_1;                     
  wire                        vio_tg_err_chk_en_1;                
  wire                        vio_tg_err_clear_1;                 
  wire [3:0]                  vio_tg_instr_addr_mode_1;           
  wire [3:0]                  vio_tg_instr_data_mode_1;          
  wire [3:0]                  vio_tg_instr_rw_mode_1;             
  wire [1:0]                  vio_tg_instr_rw_submode_1;          
  wire [31:0]                 vio_tg_instr_num_of_iter_1;         
  wire [5:0]                  vio_tg_instr_nxt_instr_1;           
  wire                        vio_tg_restart_1;                    
  wire                        vio_tg_pause_1;                     
  wire                        vio_tg_err_clear_all_1;             
  wire                        vio_tg_err_continue_1;              
  wire                        vio_tg_instr_program_en_1;          
  wire                        vio_tg_direct_instr_en_1;           
  wire [4:0]                  vio_tg_instr_num_1;                 
  wire [2:0]                  vio_tg_instr_victim_mode_1;         
  wire [4:0]                  vio_tg_instr_victim_aggr_delay_1;   
  wire [2:0]                  vio_tg_instr_victim_select_1;       
  wire [9:0]                  vio_tg_instr_m_nops_btw_n_burst_m_1;
  wire [31:0]                 vio_tg_instr_m_nops_btw_n_burst_n_1;
  wire                        vio_tg_seed_program_en_1;           
  wire [7:0]                  vio_tg_seed_num_1;                  
  wire [22:0]                 vio_tg_seed_1;                      
  wire [7:0]                  vio_tg_glb_victim_bit_1;            
  wire [32:0]                 vio_tg_glb_start_addr_1;
  wire [3:0]                  vio_tg_status_state_1;
  wire                        vio_tg_status_err_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_1;
  wire [31:0]                 vio_tg_status_err_cnt_1;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_err_addr_1;
  wire                        vio_tg_status_exp_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_exp_bit_1;
  wire                        vio_tg_status_read_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_read_bit_1;
  wire                        vio_tg_status_first_err_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_err_bit_1;
  wire [APP_ADDR_WIDTH-1:0]   vio_tg_status_first_err_addr_1;
  wire                        vio_tg_status_first_exp_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_exp_bit_1;
  wire                        vio_tg_status_first_read_bit_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_first_read_bit_1;
  wire                        vio_tg_status_err_bit_sticky_valid_1;
  wire [APP_DATA_WIDTH_4D-1:0]   vio_tg_status_err_bit_sticky_1;
  wire [31:0]                 vio_tg_status_err_cnt_sticky_1;
  wire                        vio_tg_status_err_type_valid_1;
  wire                        vio_tg_status_err_type_1;
  wire                        vio_tg_status_wr_done_1;
  wire                        vio_tg_status_watch_dog_hang_1;
  wire                        tg_ila_debug_1;
  reg  [4:0]                  wr_cnt_01;
  reg  [4:0]                  rd_cnt_01;































////////////////////////////////////////////////////////////////////////////////
// Reg declaration
////////////////////////////////////////////////////////////////////////////////
reg  [3:0]                                          cnt_rst_0;
reg           axi_rst_0_r1_n;
reg           axi_rst_0_mmcm_n;
(* keep = "TRUE" *) reg           axi_rst_st0_n;
(* ASYNC_REG = "TRUE" *) reg           axi_rst0_st0_r1_n, axi_rst0_st0_r2_n;
(* keep = "TRUE" *) reg           axi_rst0_st0_n;
(* ASYNC_REG = "TRUE" *) reg           axi_rst1_st0_r1_n, axi_rst1_st0_r2_n;
(* keep = "TRUE" *) reg           axi_rst1_st0_n;
(* ASYNC_REG = "TRUE" *) reg           axi_rst2_st0_r1_n, axi_rst2_st0_r2_n;
(* keep = "TRUE" *) reg           axi_rst2_st0_n;
(* ASYNC_REG = "TRUE" *) reg           axi_rst3_st0_r1_n, axi_rst3_st0_r2_n;
(* keep = "TRUE" *) reg           axi_rst3_st0_n;
(* ASYNC_REG = "TRUE" *) reg           axi_rst4_st0_r1_n, axi_rst4_st0_r2_n;
(* keep = "TRUE" *) reg           axi_rst4_st0_n;
(* ASYNC_REG = "TRUE" *) reg           axi_rst5_st0_r1_n, axi_rst5_st0_r2_n;
(* keep = "TRUE" *) reg           axi_rst5_st0_n;
(* ASYNC_REG = "TRUE" *) reg           axi_rst6_st0_r1_n, axi_rst6_st0_r2_n;
(* keep = "TRUE" *) reg           axi_rst6_st0_n;


////////////////////////////////////////////////////////////////////////////////
// Instantiating BUFG for AXI Clock
////////////////////////////////////////////////////////////////////////////////
(* ASYNC_REG = "TRUE" *) reg           w_rst_sys_rst_0_r1;
(* ASYNC_REG = "TRUE" *) reg           w_rst_sys_rst_0_r2;
(* ASYNC_REG = "TRUE" *) reg           w_rst_sys_rst_1_r1;
(* ASYNC_REG = "TRUE" *) reg           w_rst_sys_rst_1_r2;
wire	[3:0]		w_rst_sys_rst_0;
wire	[3:0]		w_rst_sys_rst_1;

(* keep = "TRUE" *) wire      APB_0_PCLK_IBUF;
(* keep = "TRUE" *) wire      APB_0_PCLK_BUF;
(* keep = "TRUE" *) wire      APB_0_PRESET_N_sync;

IBUF u_APB_0_PCLK_IBUF  (
  .I (APB_0_PCLK),
  .O (APB_0_PCLK_IBUF)
);

BUFG u_APB_0_PCLK_BUFG  (
  .I (APB_0_PCLK_IBUF),
  .O (APB_0_PCLK_BUF)
);

reg	[7:0]	cnt_apb_rst_p2l_st0;
wire		w_apb_0_reset_n_inv_st0;
reg			r_apb_preset_n_p2l_st0; 
assign	w_apb_0_reset_n_inv_st0 = APB_0_PRESET_N && ~w_rst_sys_rst_0[0];
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

assign            APB_0_PRESET_N_sync = r_apb_preset_n_p2l_st0 ;

BUFG u_AXI_ACLK_IN_0  (
  .I (AXI_ACLK_IN_0),
  .O (AXI_ACLK_IN_0_buf)
);

////////////////////////////////////////////////////////////////////////////////
// Reset logic for AXI_0
////////////////////////////////////////////////////////////////////////////////
always @ (posedge AXI_ACLK_IN_0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst_0_r1_n <= 1'b0;
  end else begin
    axi_rst_0_r1_n <= 1'b1;
  end
end

always @ (posedge AXI_ACLK_IN_0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    cnt_rst_0 <= 4'hA;
  end else begin
    if (~axi_rst_0_r1_n) begin
      cnt_rst_0 <= 4'hA;
    end else if (cnt_rst_0 != 4'h0) begin
      cnt_rst_0 <= cnt_rst_0 - 1'b1;
    end else begin
      cnt_rst_0 <= cnt_rst_0;
    end
  end
end

always @ (posedge AXI_ACLK_IN_0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst_0_mmcm_n  <= 1'b0;
  end else begin
    if (cnt_rst_0 != 4'h0) begin
      axi_rst_0_mmcm_n <= 1'b0;
    end else begin
      axi_rst_0_mmcm_n <= 1'b1;
    end
  end
end

always @ (posedge AXI_ACLK_IN_0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    w_rst_sys_rst_0_r1 <= 1'b0;
    w_rst_sys_rst_0_r2 <= 1'b0;
  end else begin
    w_rst_sys_rst_0_r1 <= w_rst_sys_rst_0[1];
    w_rst_sys_rst_0_r2 <= w_rst_sys_rst_0_r1;
  end
end

always @ (posedge AXI_ACLK_IN_0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst_st0_n <= 1'b0;
  end else begin
    axi_rst_st0_n <= axi_rst_0_mmcm_n & MMCM_LOCK_0 & (~w_rst_sys_rst_0_r2);
  end
end

always @ (posedge AXI_ACLK0_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst0_st0_r1_n <= 1'b0;
    axi_rst0_st0_r2_n <= 1'b0;
  end else begin
    axi_rst0_st0_r1_n <= axi_rst_st0_n;
    axi_rst0_st0_r2_n <= axi_rst0_st0_r1_n;
  end
end

always @ (posedge AXI_ACLK0_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst0_st0_n <= 1'b0;
  end else begin
    axi_rst0_st0_n <= axi_rst0_st0_r2_n;
  end
end

always @ (posedge AXI_ACLK1_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst1_st0_r1_n <= 1'b0;
    axi_rst1_st0_r2_n <= 1'b0;
  end else begin
    axi_rst1_st0_r1_n <= axi_rst_st0_n;
    axi_rst1_st0_r2_n <= axi_rst1_st0_r1_n;
  end
end

always @ (posedge AXI_ACLK1_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst1_st0_n <= 1'b0;
  end else begin
    axi_rst1_st0_n <= axi_rst1_st0_r2_n;
  end
end

always @ (posedge AXI_ACLK2_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst2_st0_r1_n <= 1'b0;
    axi_rst2_st0_r2_n <= 1'b0;
  end else begin
    axi_rst2_st0_r1_n <= axi_rst_st0_n;
    axi_rst2_st0_r2_n <= axi_rst2_st0_r1_n;
  end
end

always @ (posedge AXI_ACLK2_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst2_st0_n <= 1'b0;
  end else begin
    axi_rst2_st0_n <= axi_rst2_st0_r2_n;
  end
end

always @ (posedge AXI_ACLK3_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst3_st0_r1_n <= 1'b0;
    axi_rst3_st0_r2_n <= 1'b0;
  end else begin
    axi_rst3_st0_r1_n <= axi_rst_st0_n;
    axi_rst3_st0_r2_n <= axi_rst3_st0_r1_n;
  end
end

always @ (posedge AXI_ACLK3_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst3_st0_n <= 1'b0;
  end else begin
    axi_rst3_st0_n <= axi_rst3_st0_r2_n;
  end
end

always @ (posedge AXI_ACLK4_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst4_st0_r1_n <= 1'b0;
    axi_rst4_st0_r2_n <= 1'b0;
  end else begin
    axi_rst4_st0_r1_n <= axi_rst_st0_n;
    axi_rst4_st0_r2_n <= axi_rst4_st0_r1_n;
  end
end

always @ (posedge AXI_ACLK4_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst4_st0_n <= 1'b0;
  end else begin
    axi_rst4_st0_n <= axi_rst4_st0_r2_n;
  end
end

always @ (posedge AXI_ACLK5_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst5_st0_r1_n <= 1'b0;
    axi_rst5_st0_r2_n <= 1'b0;
  end else begin
    axi_rst5_st0_r1_n <= axi_rst_st0_n;
    axi_rst5_st0_r2_n <= axi_rst5_st0_r1_n;
  end
end

always @ (posedge AXI_ACLK5_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst5_st0_n <= 1'b0;
  end else begin
    axi_rst5_st0_n <= axi_rst5_st0_r2_n;
  end
end

always @ (posedge AXI_ACLK6_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst6_st0_r1_n <= 1'b0;
    axi_rst6_st0_r2_n <= 1'b0;
  end else begin
    axi_rst6_st0_r1_n <= axi_rst_st0_n;
    axi_rst6_st0_r2_n <= axi_rst6_st0_r1_n;
  end
end

always @ (posedge AXI_ACLK6_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    axi_rst6_st0_n <= 1'b0;
  end else begin
    axi_rst6_st0_n <= axi_rst6_st0_r2_n;
  end
end

reg  [7:0]    cnt_rst_0_0;
reg           axi_rst_0_mmcm_n_0;

always @ (posedge AXI_ACLK_IN_0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    cnt_rst_0_0        <= 8'h00;
    axi_rst_0_mmcm_n_0 <= 1'b0;
  end else begin
    if (~axi_rst_0_r1_n) begin
	    if( cnt_rst_0_0 >= 8'd100 )
	    begin
        cnt_rst_0_0 <= cnt_rst_0_0;
        axi_rst_0_mmcm_n_0 <= 1'b0;
	    end
	    else
	    begin
        cnt_rst_0_0 <= cnt_rst_0_0 + 1;
        axi_rst_0_mmcm_n_0 <= axi_rst_0_mmcm_n_0;
	    end
    end else begin
      cnt_rst_0_0 <= 'd0;
      axi_rst_0_mmcm_n_0 <= 1'b1;
    end
  end
end


////////////////////////////////////////////////////////////////////////////////
// Instantiating MMCM for AXI clock generation
////////////////////////////////////////////////////////////////////////////////
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
    .CLKOUT0             (AXI_ACLK0_st0),

    .CLKOUT0B            (),
    .CLKOUT1             (AXI_ACLK1_st0),
    .CLKOUT1B            (),
    .CLKOUT2             (AXI_ACLK2_st0),
    .CLKOUT2B            (),
    .CLKOUT3             (AXI_ACLK3_st0),
    .CLKOUT3B            (),
    .CLKOUT4             (AXI_ACLK4_st0),
    .CLKOUT5             (AXI_ACLK5_st0),
    .CLKOUT6             (AXI_ACLK6_st0),
     // Input clock control
    .CLKFBIN             (), //mmcm_fb
    .CLKIN1              (AXI_ACLK_IN_0_buf),
    .CLKIN2              (1'b0),
    // Other control and status signals
    .LOCKED              (MMCM_LOCK_0),
    .PWRDWN              (1'b0),
    .RST                 (~axi_rst_0_mmcm_n_0),
  
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

//`ifdef SIMULATION_MODE
//initial begin
//  AXI_ACLK0_st0_buf = 1'b0;
//  AXI_ACLK1_st0_buf = 1'b0;
//  AXI_ACLK2_st0_buf = 1'b0;
//  AXI_ACLK3_st0_buf = 1'b0;
//  AXI_ACLK4_st0_buf = 1'b0;
//  AXI_ACLK5_st0_buf = 1'b0;
//  AXI_ACLK6_st0_buf = 1'b0;
//end
//
//always AXI_ACLK0_st0_buf = #1111.111111111111 ~AXI_ACLK0_st0_buf;
//always AXI_ACLK1_st0_buf = #1111.111111111111 ~AXI_ACLK1_st0_buf;
//always AXI_ACLK2_st0_buf = #1111.111111111111 ~AXI_ACLK2_st0_buf;
//always AXI_ACLK3_st0_buf = #1111.111111111111 ~AXI_ACLK3_st0_buf;
//always AXI_ACLK4_st0_buf = #1111.111111111111 ~AXI_ACLK4_st0_buf;
//always AXI_ACLK5_st0_buf = #1111.111111111111 ~AXI_ACLK5_st0_buf;
//always AXI_ACLK6_st0_buf = #1111.111111111111 ~AXI_ACLK6_st0_buf;
//
//`else
BUFG u_AXI_ACLK0_st0  (
  .I (AXI_ACLK0_st0),
  .O (AXI_ACLK0_st0_buf)
);

BUFG u_AXI_ACLK1_st0  (
  .I (AXI_ACLK1_st0),
  .O (AXI_ACLK1_st0_buf)
);

BUFG u_AXI_ACLK2_st0  (
  .I (AXI_ACLK2_st0),
  .O (AXI_ACLK2_st0_buf)
);

BUFG u_AXI_ACLK3_st0  (
  .I (AXI_ACLK3_st0),
  .O (AXI_ACLK3_st0_buf)
);

BUFG u_AXI_ACLK4_st0  (
  .I (AXI_ACLK4_st0),
  .O (AXI_ACLK4_st0_buf)
);

BUFG u_AXI_ACLK5_st0  (
  .I (AXI_ACLK5_st0),
  .O (AXI_ACLK5_st0_buf)
);

BUFG u_AXI_ACLK6_st0  (
  .I (AXI_ACLK6_st0),
  .O (AXI_ACLK6_st0_buf)
);
//`endif

BUFGCE_DIV #(
      .BUFGCE_DIVIDE(2),
      .SIM_DEVICE("ULTRASCALE_PLUS")
   )
    u_AXI_vio_CLK_st0  (
  .I (AXI_ACLK0_st0),
  .CE (1'b1),
  .CLR (1'b0),
  .O (i_clk_atg_axi_vio_st0)
);


////////////////////////////////////////////////////////////////////////////////
// Calculating Write Data Parity
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// Instantiating User Design
////////////////////////////////////////////////////////////////////////////////
hbm_0 u_hbm_0
(
  .HBM_REF_CLK_0                 (AXI_ACLK_IN_0_buf)
  ,.dfi_0_clk                    (AXI_ACLK0_st0_buf)
  ,.dfi_0_rst_n                  (axi_rst0_st0_n   )
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
//  ,.APB_0_PWDATA                 (APB_0_PWDATA  )
//  ,.APB_0_PADDR                  (APB_0_PADDR   )
//  ,.APB_0_PENABLE                (APB_0_PENABLE )
//  ,.APB_0_PSEL                   (APB_0_PSEL    )
//  ,.APB_0_PWRITE                 (APB_0_PWRITE  )

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
//  ,.APB_0_PRDATA                 (APB_0_PRDATA )
//  ,.APB_0_PREADY                 (APB_0_PREADY )
//  ,.APB_0_PSLVERR                (APB_0_PSLVERR)
  
  ,.DRAM_0_STAT_CATTRIP          (DRAM_0_STAT_CATTRIP)
  ,.DRAM_0_STAT_TEMP             (DRAM_0_STAT_TEMP   )
);


always @ (posedge AXI_ACLK0_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_0_st0_r0 <= 1'b0;
    apb_seq_complete_0_st0_r1 <= 1'b0;
    apb_seq_complete_0_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_0_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_0_st0_r1 <= apb_seq_complete_0_st0_r0;
    apb_seq_complete_0_st0_r2 <= apb_seq_complete_0_st0_r1;
  end
end

assign tg_start_st0_0 = apb_seq_complete_0_st0_r1 && ~(apb_seq_complete_0_st0_r2);

always @ (posedge AXI_ACLK1_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_1_st0_r0 <= 1'b0;
    apb_seq_complete_1_st0_r1 <= 1'b0;
    apb_seq_complete_1_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_1_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_1_st0_r1 <= apb_seq_complete_1_st0_r0;
    apb_seq_complete_1_st0_r2 <= apb_seq_complete_1_st0_r1;
  end
end

assign tg_start_st0_1 = apb_seq_complete_1_st0_r1 && ~(apb_seq_complete_1_st0_r2);

always @ (posedge AXI_ACLK2_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_2_st0_r0 <= 1'b0;
    apb_seq_complete_2_st0_r1 <= 1'b0;
    apb_seq_complete_2_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_2_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_2_st0_r1 <= apb_seq_complete_2_st0_r0;
    apb_seq_complete_2_st0_r2 <= apb_seq_complete_2_st0_r1;
  end
end

assign tg_start_st0_2 = apb_seq_complete_2_st0_r1 && ~(apb_seq_complete_2_st0_r2);

always @ (posedge AXI_ACLK3_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_3_st0_r0 <= 1'b0;
    apb_seq_complete_3_st0_r1 <= 1'b0;
    apb_seq_complete_3_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_3_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_3_st0_r1 <= apb_seq_complete_3_st0_r0;
    apb_seq_complete_3_st0_r2 <= apb_seq_complete_3_st0_r1;
  end
end

assign tg_start_st0_3 = apb_seq_complete_3_st0_r1 && ~(apb_seq_complete_3_st0_r2);

always @ (posedge AXI_ACLK4_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_4_st0_r0 <= 1'b0;
    apb_seq_complete_4_st0_r1 <= 1'b0;
    apb_seq_complete_4_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_4_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_4_st0_r1 <= apb_seq_complete_4_st0_r0;
    apb_seq_complete_4_st0_r2 <= apb_seq_complete_4_st0_r1;
  end
end

assign tg_start_st0_4 = apb_seq_complete_4_st0_r1 && ~(apb_seq_complete_4_st0_r2);

always @ (posedge AXI_ACLK5_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_5_st0_r0 <= 1'b0;
    apb_seq_complete_5_st0_r1 <= 1'b0;
    apb_seq_complete_5_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_5_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_5_st0_r1 <= apb_seq_complete_5_st0_r0;
    apb_seq_complete_5_st0_r2 <= apb_seq_complete_5_st0_r1;
  end
end

assign tg_start_st0_5 = apb_seq_complete_5_st0_r1 && ~(apb_seq_complete_5_st0_r2);

always @ (posedge AXI_ACLK6_st0_buf or negedge AXI_ARESET_N_0) begin
  if (~AXI_ARESET_N_0) begin
    apb_seq_complete_6_st0_r0 <= 1'b0;
    apb_seq_complete_6_st0_r1 <= 1'b0;
    apb_seq_complete_6_st0_r2 <= 1'b0;
  end else begin
    apb_seq_complete_6_st0_r0 <= apb_seq_complete_0_s;
    apb_seq_complete_6_st0_r1 <= apb_seq_complete_6_st0_r0;
    apb_seq_complete_6_st0_r2 <= apb_seq_complete_6_st0_r1;
  end
end

assign tg_start_st0_6 = apb_seq_complete_6_st0_r1 && ~(apb_seq_complete_6_st0_r2);


// PHY ONLY TG
HBM_controller#() 
HBM_controller_i
(
    // .i_vio_instr_RA                        (vio_0_instr_RA              ),
    // .i_vio_instr_BA                        (vio_0_instr_BA              ),
    // .i_vio_instr_data_mode                 (vio_0_instr_data_mode       ),
    // .i_vio_instr_wrt_page                  (vio_0_instr_wrt_page        ),
    // .i_vio_instr_rd_page                   (vio_0_instr_rd_page         ),
    // .i_vio_instr_wrt_loop                  (vio_0_instr_wrt_loop        ),
    // .i_vio_instr_rd_loop                   (vio_0_instr_rd_loop         ),
    // .i_vio_instr_end                       (vio_0_instr_end             ),
    // .i_vio_instr_dir_en                    (vio_0_instr_dir_en          ),
    // .i_vio_loop_break_pulse                (vio_0_loop_break_pulse      ),
    // .i_vio_resetb_fsm                      (vio_0_resetb_fsm            ),
    // .i_vio_phy_tg_start                    (vio_0_phy_tg_start          ),
    // .i_vio_rst_rd_cmp_err                  (vio_0_rst_rd_cmp_err        ),
    // .i_vio_instr_full_bank_wrt_rd          (vio_0_instr_full_bank_wrt_rd),
    // .i_vio_instr_add_mode                  (vio_0_instr_add_mode        ),
    // .i_vio_instr_bank_size                 (vio_0_instr_bank_size       ),
    // .i_dq_bit_inv_en_ps0                   (vio_0_dq_bit_inv_en_ps0     ),
    // .i_dq_bit_inv_en_ps1                   (vio_0_dq_bit_inv_en_ps1     ),
    // .o_phy_tg_status_run                   (ila_0_phy_tg_status_run                  ),
    // .o_dfi_dw_rddata_first_exp_ps0         (ila_0_dfi_dw_rddata_first_exp_ps0        ),
    // .o_dfi_dw_rddata_first_error_ps0       (ila_0_dfi_dw_rddata_first_error_ps0      ),
    // .o_dfi_dw_rddata_first_error_valid_ps0 (ila_0_dfi_dw_rddata_first_error_valid_ps0),
    // .o_dfi_dw_rddata_first_exp_ps1         (ila_0_dfi_dw_rddata_first_exp_ps1        ),
    // .o_dfi_dw_rddata_first_error_ps1       (ila_0_dfi_dw_rddata_first_error_ps1      ),
    // .o_dfi_dw_rddata_first_error_valid_ps1 (ila_0_dfi_dw_rddata_first_error_valid_ps1),
    // .o_phy_tg_state                        (ila_0_phy_tg_state                       ),
    // .o_phy_tg_status_rd_cmp_err_cnt        (ila_0_phy_tg_status_rd_cmp_err_cnt       ),
    // .o_phy_tg_status_rd_cmp_err_cnt_loop   (ila_0_phy_tg_status_rd_cmp_err_cnt_loop  ),
    // .o_phy_tg_status_curr_BA_RA            (ila_0_phy_tg_status_curr_BA_RA           ),

    .dfi_clk_buf                               (AXI_ACLK0_st0_buf),
    .dfi_rst_n                             (axi_rst0_st0_n),
    .dfi_rst_buf_n                           (dfi_0_out_rst_n),
//    .i_en_phy_tg                           (apb_seq_complete_0_st0_r2),
//    .o_phy_tg_done                         (boot_mode_done_0),
//    .o_phy_tg_status_rd_cmp_err            (axi_00_data_msmatch_err),
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
    
    .address(address),
    .write_data(write_data),
    .request(request),

    .reset_hbm_controller(reset_hbm_controller)
    );

assign vio_0_instr_RA               = 0;
assign vio_0_instr_BA               = 0;
assign vio_0_instr_data_mode        = 0;
assign vio_0_instr_wrt_page         = 0;
assign vio_0_instr_rd_page          = 0;
assign vio_0_instr_wrt_loop         = 0;
assign vio_0_instr_rd_loop          = 0;
assign vio_0_instr_end              = 0;
assign vio_0_instr_dir_en           = 0;
assign vio_0_loop_break_pulse       = 0;
assign vio_0_resetb_fsm             = 1;
assign vio_0_rst_rd_cmp_err         = 0;
assign vio_0_instr_full_bank_wrt_rd = 1;
assign vio_0_instr_add_mode         = 0;
assign vio_0_instr_bank_size        = 255;
assign vio_0_dq_bit_inv_en_ps0      = 0;
assign vio_0_dq_bit_inv_en_ps1      = 0;


//////////////////////////////////////////////
//////////////////////////////////////////////
assign w_rst_sys_rst_0 = 4'h0;
assign vio_0_phy_tg_start = 1'b1;
//////////////////////////////////////////////
//////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////
// Generating AXI transaciton error status signal
////////////////////////////////////////////////////////////////////////////////
assign axi_trans_err = axi_00_data_msmatch_err || axi_01_data_msmatch_err ||
                       axi_02_data_msmatch_err || axi_03_data_msmatch_err ||
                       axi_04_data_msmatch_err || axi_05_data_msmatch_err ||
                       axi_06_data_msmatch_err || axi_07_data_msmatch_err ||
                       axi_08_data_msmatch_err || axi_09_data_msmatch_err ||
                       axi_10_data_msmatch_err || axi_11_data_msmatch_err ||
                       axi_12_data_msmatch_err || axi_13_data_msmatch_err ||
                       axi_14_data_msmatch_err || axi_15_data_msmatch_err ;

assign axi_trans_done = boot_mode_done_0  && boot_mode_done_1  && boot_mode_done_2  &&
                        boot_mode_done_3  && boot_mode_done_4  && boot_mode_done_5  &&
                        boot_mode_done_6  && boot_mode_done_7  && boot_mode_done_8  &&
                        boot_mode_done_9  && boot_mode_done_10 && boot_mode_done_11 &&
                        boot_mode_done_12 && boot_mode_done_13 && boot_mode_done_14 &&
                        boot_mode_done_15;


endmodule

