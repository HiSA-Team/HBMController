`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/26/2023 10:33:02 AM
// Design Name: 
// Module Name: ll_command_forwarder_RAS_CAS_PS0_PS1_queue
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


module last_level_command_forwarder # (
    parameter       P_DRIVE_PRECHARGE_CMD    = 114,
    parameter		P_PRECHG_THR             = 200,
    parameter		P_ACT_THR	             = 40,
    parameter		P_WRT_THR	             = 60,
    parameter		P_RD_THR	             = 60,
    parameter		P_DRIVE_ACT_CMD          = 240,
    parameter		P_MRS_CNT                = 8'hc0,

    parameter		P_ROW_ADDR_WIDTH         = 14,
    parameter		P_COL_ADDR_WIDTH         = 6,
    parameter		P_BA_ADDR_WIDTH	         = 5,
    parameter       P_DATA_WIDTH             = 256,
    parameter       P_BA_N_PS                = 16,       
    parameter       P_BA_N_G                 = 4, 
    parameter       P_WRT_DATA_BUFFER_LEN    = 4,
    parameter       P_RD_ID_BUFFER_LEN       = 16,

    /* COMMANDS     */
    /* COL COMMANDS */
    parameter       P_COL_NOP		    = 4'b1111,
    parameter       P_COL_RD		    = 4'b0101,
    parameter       P_COL_RD_AP		    = 4'b1101,
    parameter       P_COL_WRT		    = 4'b0001,
    parameter       P_COL_WRT_AP	    = 4'b1001,
    parameter       P_COL_MRS		    = 4'b0000,

    /* ROW COMMANDS */
    parameter       P_ROW_NOP		    = 3'b111,
    parameter       P_ROW_ACT		    = 3'b010,
    parameter       P_ROW_PRE		    = 3'b011,  // WITH R[10] -> L
    parameter       P_ROW_PREA		    = 3'b011,  // WITH R[10] -> H

    parameter       P_ROW_REFPB         = 4'b1100/*4'b1001*/,  // WITH R[4] on Falling -> H 

    parameter       P_GENERAL_NOP       = 4'b1111,
    //  parameter       P_ROW_REFA         = 4'b1001;  // WITH R[4] on Falling -> H 

    /* HBM TIMING CONSTRAINTS */
    parameter       tWL     =  32'd4,      
    parameter       tRL     =  32'd14,

    parameter       tCCDl   =  32'd1,      
    parameter       tRTW    =  32'd8,
    parameter       tWTRl   =  32'd8,      

    parameter       tRRD    =  32'd6,    /* ACT to ACT/Per Bank REF delay */
    parameter       tFAW    =  32'd30,
    parameter       tWTRs   =  32'd8,
    parameter       tRFCpb  =  32'd73,
    parameter       tRREFD  =  32'd4,     /* Per Bank REF to Per Bank REF/ACT (Different Banks) */
    parameter       P_REQ_ID_WIDTH = 32'd6,
    parameter       P_CMD_ID_WIDTH = 32'd3

)(
    //DFI INTERFACE SIGNALS
    input               dfi_clk,
    input           	dfi_rst_n,
    input            	dfi_rst_buf_n,

    output	           	dfi_init_start,
    output	[1:0]   	dfi_aw_ck_p0,
    output  [1:0]   	dfi_aw_cke_p0,
    output	[11:0]  	dfi_aw_row_p0,
    output	[15:0]		dfi_aw_col_p0,
    output	[255:0] 	dfi_dw_wrdata_p0,
    output  [31:0]		dfi_dw_wrdata_mask_p0,
    output  [31:0]		dfi_dw_wrdata_dbi_p0,
    output  [7:0]		dfi_dw_wrdata_par_p0,
    output  [7:0]		dfi_dw_wrdata_dq_en_p0,
    output  [7:0]		dfi_dw_wrdata_par_en_p0,

    output  [1:0]		dfi_aw_ck_p1,
    output  [1:0]		dfi_aw_cke_p1,
    output	[11:0]		dfi_aw_row_p1,
    output	[15:0]		dfi_aw_col_p1,
    output	[255:0]		dfi_dw_wrdata_p1,
    output  [31:0]		dfi_dw_wrdata_mask_p1,
    output  [31:0]		dfi_dw_wrdata_dbi_p1,
    output  [7:0]		dfi_dw_wrdata_par_p1,
    output  [7:0]		dfi_dw_wrdata_dq_en_p1,
    output  [7:0]		dfi_dw_wrdata_par_en_p1,

    output           dfi_aw_ck_dis,
    output           dfi_lp_pwr_e_req,
    output           dfi_lp_sr_e_req,
    output           dfi_lp_pwr_x_req,
    output           dfi_lp_pwr_x_e_req,
    output           dfi_aw_tx_indx_ld,
    output           dfi_dw_tx_indx_ld,
    output           dfi_dw_rx_indx_ld,
    output           dfi_ctrlupd_ack,
    output           dfi_phyupd_req,


    input            dfi_init_complete,

    input   [3:0]    dfi_dw_rddata_valid,
    input   [255:0]  dfi_dw_rddata_p0,
    input   [31:0]   dfi_dw_rddata_dm_p0,
    input   [31:0]   dfi_dw_rddata_dbi_p0,
    input   [7:0]    dfi_dw_rddata_par_p0,

    input   [255:0]  dfi_dw_rddata_p1,
    input   [31:0]   dfi_dw_rddata_dm_p1,
    input   [31:0]   dfi_dw_rddata_dbi_p1,
    input   [7:0]    dfi_dw_rddata_par_p1,

    input            dfi_ctrlupd_req,
    input            dfi_phyupd_ack,
    
        
    /* RAS cmd PS0 */
    /*(* keep = "TRUE" *)*/ output          ready_to_cmd_ras_ps0,
    input [3:0]                         cmd_ras_ps0,
    input [P_REQ_ID_WIDTH-1:0]          req_ras_id_ps0,
    input [P_CMD_ID_WIDTH-1:0]          cmd_ras_id_ps0,
    input [1:0]         bank_group_ras_ps0,
     input [P_ROW_ADDR_WIDTH-1:0]        row_address_ras_ps0,
    
    /* CAS cmd PS0 */
    /*(* keep = "TRUE" *)*/ output          ready_to_cmd_cas_ps0,
    input [3:0]                         cmd_cas_ps0,
    input [P_REQ_ID_WIDTH-1:0]          req_cas_id_ps0,
    input [P_CMD_ID_WIDTH-1:0]          cmd_cas_id_ps0,
    input [1:0]                         bank_group_cas_ps0,
    
    /* RAS cmd PS1 */
    /*(* keep = "TRUE" *)*/ output          ready_to_cmd_ras_ps1,
    input [3:0]                         cmd_ras_ps1,
    input [P_REQ_ID_WIDTH-1:0]          req_ras_id_ps1,
    input [P_CMD_ID_WIDTH-1:0]          cmd_ras_id_ps1,
    input [1:0]                          bank_group_ras_ps1,
     input [P_ROW_ADDR_WIDTH-1:0]        row_address_ras_ps1,
    
    /* CAS cmd PS1 */
    /*(* keep = "TRUE" *)*/ output          ready_to_cmd_cas_ps1,
    input [3:0]                         cmd_cas_ps1,
    input [P_REQ_ID_WIDTH-1:0]          req_cas_id_ps1,
    input [P_CMD_ID_WIDTH-1:0]          cmd_cas_id_ps1,
    input [1:0]         bank_group_cas_ps1,
    
    input [P_BA_ADDR_WIDTH-1:0]       bank_address_ras_ps0,
    input [P_BA_ADDR_WIDTH-1:0]       bank_address_ras_ps1,
    
    /* To inform bank schedulers that the command is served */
    output [(P_BA_N_PS*2)-1:0]          served_ras,
    output [(P_BA_N_PS*2)-1:0]          served_cas,

    /* Data Read out with the associate request id */
    output [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps0,
    output [P_DATA_WIDTH-1:0]           rd_data_ps0,
    output [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps1,
    output [P_DATA_WIDTH-1:0]           rd_data_ps1,

//    output [P_REQ_ID_WIDTH-1:0]         wrt_data_req_id_0_ps0,
//    output [P_REQ_ID_WIDTH-1:0]         wrt_data_req_id_1_ps0,
//    output [P_REQ_ID_WIDTH-1:0]         wrt_data_req_id_ps1,

    input  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] ram_cas_address_out_ps0,
    input  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] ram_cas_address_out_ps1,

    input  [P_DATA_WIDTH-1 : 0] wrt_data_cas_ps0,
    input  [P_DATA_WIDTH-1 : 0] wrt_data_cas_ps1,

    output reset_hbm_controller
    
);

wire [P_BA_ADDR_WIDTH-1:0]         bank_address_cas_ps0;
wire [P_COL_ADDR_WIDTH-1:0]        column_address_cas_ps0;
//wire [P_DATA_WIDTH-1:0]            wrt_data_cas_0_ps0;
//wire [P_DATA_WIDTH-1:0]            wrt_data_cas_1_ps0;

wire [P_BA_ADDR_WIDTH-1:0]         bank_address_cas_ps1;
wire [P_COL_ADDR_WIDTH-1:0]        column_address_cas_ps1;
//wire [P_DATA_WIDTH-1:0]            wrt_data_cas_ps1;


//assign wrt_data_cas_0_ps0      =   ram_cas_out_0_ps0;
//assign wrt_data_cas_1_ps0      =   ram_cas_out_1_ps0;

assign bank_address_cas_ps0    =   ram_cas_address_out_ps0  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:P_COL_ADDR_WIDTH];
assign column_address_cas_ps0  =   ram_cas_address_out_ps0  [P_COL_ADDR_WIDTH-1:0];

//assign wrt_data_cas_ps1        =   ram_cas_out_ps1;

assign bank_address_cas_ps1    =   ram_cas_address_out_ps1  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:P_COL_ADDR_WIDTH];
assign column_address_cas_ps1  =   ram_cas_address_out_ps1  [P_COL_ADDR_WIDTH-1:0];


assign dfi_dw_wrdata_mask_p0   = 32'h0000_0000;
assign dfi_dw_wrdata_dbi_p0    = 32'h0000_0000;
assign dfi_dw_wrdata_par_p0    = 8'h00;
assign dfi_dw_wrdata_par_en_p0 = 8'h00;
assign dfi_dw_wrdata_mask_p1   = 32'h0000_0000;
assign dfi_dw_wrdata_dbi_p1    = 32'h0000_0000;
assign dfi_dw_wrdata_par_p1    = 8'h00;
assign dfi_dw_wrdata_par_en_p1 = 8'h00;
assign dfi_lp_pwr_x_e_req      = 1'b0;

assign dfi_dw_wrdata_dq_en_p0  = 8'h00; //{{(4){r_dfi_dw_wrdata_dq_en_p0}}, {(4){r_dfi_dw_wrdata_dq_en_p1}}; 
assign dfi_dw_wrdata_dq_en_p1  = 8'h00; //{{(4){r_dfi_dw_wrdata_dq_en_p0}}, {(4){r_dfi_dw_wrdata_dq_en_p1}}; 

assign dfi_aw_ck_dis           = 1'b0;
assign dfi_lp_pwr_e_req        = 1'b0;
assign dfi_lp_sr_e_req         = 1'b0;
assign dfi_lp_pwr_x_req        = 1'b0;
assign dfi_aw_tx_indx_ld       = 1'b0;
assign dfi_dw_tx_indx_ld       = 1'b0;
assign dfi_dw_rx_indx_ld       = 1'b0;
assign dfi_ctrlupd_ack         = 1'b0;
assign dfi_phyupd_req          = 1'b0;

/* STATES */
localparam LP_IDLE			    = 4'd0;
localparam LP_MRS			    = 4'd1;
localparam LP_FETCH			    = 4'd2;
localparam LP_CMD_WAIT          = 4'd3;
localparam LP_CMD_WAIT_1        = 4'd4;

/* MODE REGISTERS */
localparam LP_MRS_CMD = 3'b000;
localparam LP_MRS0_A = 4'b0001;
localparam LP_MRS1_A = 4'b0001;
localparam LP_MRS2_A = 4'b0010;
localparam LP_MRS3_A = 4'b0011;
localparam LP_MRS4_A = 4'b0100;
localparam LP_MRS5_A = 4'b0101;
localparam LP_MRS6_A = 4'b0110;
localparam LP_MRS7_A = 4'b0111;

localparam LP_T_WL		= 1;
localparam LP_PAR       = 1'b1;

localparam LP_BA4_0     = 1'b0;      /* Pseudo Channel 0 */
localparam LP_BA4_1     = 1'b1;      /* Pseudo Channel 1 */


localparam  LP_BG_N = P_BA_N_PS/P_BA_N_G;

wire w_mrs_lat_cnt_done;
wire w_precharge_lat_done;
wire [2:0]				w_T_WL_MRS2;
wire [4:0]				w_T_RL_MRS2;
wire w_fsm_rst_b;

reg r_dfi_init_start;

reg  [1:0]		r_dfi_aw_ck_p0;
reg  [1:0]      r_dfi_aw_cke_p0;
reg  [1:0]      r_dfi_aw_ck_p1;
reg  [1:0]      r_dfi_aw_cke_p1;
reg  [3:0]   	cke_cnt; 

reg  [11:0]		r_precharge_lat_cnt;
reg				r_precharge_lat_done; 
reg  [3:0]   	r_phy_tg_ps;
reg	 [3:0]	    r_phy_tg_ns;


reg				r_fsm_rst_b;
reg				r_mrs_lat_cnt_done;
reg				r_state_counter_done;
reg	 [7:0]	    r_state_counter;
reg				r_state_chg;
reg	 [11:0]		r_activate_lat_cnt;
reg  [7:0]		r_mrs_reg_cnt;


reg		[11:0]	r_row_cmd_p0;
reg		[11:0]	r_row_cmd_p1;
reg		[15:0]	r_col_cmd_p0;
reg		[15:0]	r_col_cmd_p1;


wire            can_serve_actual_ras_ps0;
wire            can_serve_actual_ras_ps1;
wire            can_serve_actual_cas_ps0;
wire            can_serve_actual_cas_ps1;

wire            can_serve_actual_act_ps0;
wire            can_serve_actual_act_ps1;
wire            can_serve_actual_pre_ps0;
wire            can_serve_actual_pre_ps1;
wire            can_serve_actual_ref_ps0;
wire            can_serve_actual_ref_ps1;;

wire            can_serve_actual_wrt_ps0;
wire            can_serve_actual_wrt_ps1;
wire            can_serve_actual_rd_ps0;
wire            can_serve_actual_rd_ps1;


assign dfi_aw_ck_p0  = r_dfi_aw_ck_p0;
assign dfi_aw_cke_p0 = r_dfi_aw_cke_p0;
assign dfi_aw_ck_p1  = r_dfi_aw_ck_p1;
assign dfi_aw_cke_p1 = r_dfi_aw_cke_p1;

assign dfi_init_start = r_dfi_init_start;
assign w_precharge_lat_done = (r_precharge_lat_cnt >= P_DRIVE_PRECHARGE_CMD) ? 1'b1 : 1'b0;

assign dfi_aw_col_p0    =  r_col_cmd_p0;
assign dfi_aw_col_p1	=  r_col_cmd_p1;
assign dfi_aw_row_p0    =  r_row_cmd_p0;
assign dfi_aw_row_p1    =  r_row_cmd_p1;

reg [(P_BA_N_PS*2)-1:0] r_served_ras;
reg [(P_BA_N_PS*2)-1:0] r_served_cas;

assign served_ras = r_served_ras;
assign served_cas = r_served_cas;


assign ready_to_cmd_ras_ps0 = (r_phy_tg_ps == LP_CMD_WAIT) || ( (can_serve_actual_ras_ps0 || cmd_ras_ps0 == P_GENERAL_NOP) && r_phy_tg_ps == LP_CMD_WAIT_1 ) ? 1'b1 : 1'b0;
assign ready_to_cmd_cas_ps0 = (r_phy_tg_ps == LP_CMD_WAIT) || ( (can_serve_actual_cas_ps0 || cmd_cas_ps0 == P_GENERAL_NOP) && r_phy_tg_ps == LP_CMD_WAIT_1 ) ? 1'b1 : 1'b0;
assign ready_to_cmd_ras_ps1 = (r_phy_tg_ps == LP_CMD_WAIT) || ( (can_serve_actual_ras_ps1 || cmd_ras_ps1 == P_GENERAL_NOP) && r_phy_tg_ps == LP_CMD_WAIT_1 ) ? 1'b1 : 1'b0;
assign ready_to_cmd_cas_ps1 = (r_phy_tg_ps == LP_CMD_WAIT) || ( (can_serve_actual_cas_ps1 || cmd_cas_ps1 == P_GENERAL_NOP) && r_phy_tg_ps == LP_CMD_WAIT_1 ) ? 1'b1 : 1'b0;

reg [P_DATA_WIDTH-1 : 0] wrt_data_p0;
reg [P_DATA_WIDTH-1 : 0] wrt_data_p1;

reg [P_DATA_WIDTH-1 : 0] r_rd_data_ps0;
reg [P_DATA_WIDTH-1 : 0] r_rd_data_ps1;
reg [P_REQ_ID_WIDTH-1:0]               r_rd_data_req_id_ps0;
reg [P_REQ_ID_WIDTH-1:0]               r_rd_data_req_id_ps1;

assign rd_data_ps0 = r_rd_data_ps0;
assign rd_data_ps1 = r_rd_data_ps1;
assign rd_data_req_id_ps0 = r_rd_data_req_id_ps0;
assign rd_data_req_id_ps1 = r_rd_data_req_id_ps1;

assign dfi_dw_wrdata_p0 = wrt_data_p0;
assign dfi_dw_wrdata_p1 = wrt_data_p1;


reg r_reset_hbm_controller;
assign reset_hbm_controller = r_reset_hbm_controller;

/***************************************************************************/
/* Driving init_start signal after APB initialization sequence is complete */
/***************************************************************************/
always @ (posedge dfi_clk or negedge dfi_rst_n) begin : dfi_init_start_driver
    if (~dfi_rst_n) begin
        r_dfi_init_start <= 1'b0;
    end else if (dfi_rst_buf_n == 1'b1) begin
        r_dfi_init_start <= 1'b1;
    end
end


/******************************************/
/* Counter to wait for driving CKE signal */
/******************************************/
always @ (posedge dfi_clk or negedge dfi_rst_n) begin : cke_cnt_driver
    if (~dfi_rst_n) begin
        cke_cnt <= 4'h0;
    end else if (dfi_init_complete == 1'b1 && cke_cnt != 4'hf) begin
        cke_cnt <= cke_cnt + 1'b1;
    end
end

always @ (posedge dfi_clk or negedge dfi_rst_n) begin : dfi_cke_ck_driver
    if (~dfi_rst_n) begin
        r_dfi_aw_cke_p0 <= 2'b00;
        r_dfi_aw_cke_p1 <= 2'b00;
        r_dfi_aw_ck_p0  <= 2'b00;
        r_dfi_aw_ck_p1  <= 2'b00;
    end else if (cke_cnt == 4'he) begin
        r_dfi_aw_cke_p0 <= 2'b11;
        r_dfi_aw_cke_p1 <= 2'b11;
        r_dfi_aw_ck_p0  <= 2'b01;
        r_dfi_aw_ck_p1  <= 2'b01;
    end
end


/******************************************************************/
/* Counter to count pre-charge latency before issuing MR commands */
/******************************************************************/
always @ (posedge dfi_clk or negedge dfi_rst_n) begin
    if (~dfi_rst_n) begin
        r_precharge_lat_cnt <= 12'h000;
        r_precharge_lat_done <= 1'b0; 
    end else
    begin
        r_precharge_lat_done <= w_precharge_lat_done; 
        if (r_phy_tg_ps == LP_IDLE && dfi_init_complete == 1'b1 && r_precharge_lat_cnt != P_DRIVE_PRECHARGE_CMD) begin
            r_precharge_lat_cnt <= r_precharge_lat_cnt + 1'b1;
        end
    end
end

/*********************************************************************/
/* Counter to count activate latency before issuing activate command */
/*********************************************************************/
always @ (posedge dfi_clk or negedge dfi_rst_n) begin
  if (~dfi_rst_n) begin
    r_activate_lat_cnt <= 12'h000;
	r_mrs_lat_cnt_done	<= 1'b0; 
  end else
  begin
	r_mrs_lat_cnt_done	<= w_mrs_lat_cnt_done; 
  if (r_phy_tg_ps == LP_MRS && ( r_mrs_reg_cnt == P_MRS_CNT) && r_activate_lat_cnt != P_DRIVE_ACT_CMD) begin
    r_activate_lat_cnt <= r_activate_lat_cnt + 1'b1;
  end
  end
end

assign w_mrs_lat_cnt_done = (r_activate_lat_cnt >= P_DRIVE_ACT_CMD) ? 1'b1 : 0;

/*****************************************/
/* Counter to count the MR commands sent */
/*****************************************/
always @ (posedge dfi_clk or negedge dfi_rst_n) begin
  if (~dfi_rst_n) begin
    r_mrs_reg_cnt <= 8'h00;
  end else if ((r_phy_tg_ps == LP_MRS) && (r_mrs_reg_cnt != P_MRS_CNT)) begin
    r_mrs_reg_cnt <= r_mrs_reg_cnt + 1'b1;
  end
end


assign w_fsm_rst_b = r_precharge_lat_done && dfi_init_complete;

//rst_b pulse generation for PRBS SEED LOAD
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 )
    begin
        r_fsm_rst_b	 <= 1'b0;
    end
    else
    begin
        r_fsm_rst_b	 <= w_fsm_rst_b;
    end
end


/*****************/
/* STATE COUNTER */
/*****************/
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 )
    begin
        r_state_counter	<= 8'd0;
        r_state_chg		<= 1'b1;
        r_state_counter_done <= 1'b0;
    end
    else
    begin
        if( r_phy_tg_ps != r_phy_tg_ns )
        begin
            r_state_counter		 <= 8'd0;
            r_state_chg			 <= 1'b1;
            r_state_counter_done <= 1'b0;
        end
        else
        begin
            r_state_chg		<= 1'b0;
            case( r_phy_tg_ps )
                LP_IDLE:
                begin
                    r_state_counter	<= 8'd0;
                    r_state_counter_done <= 1'b0;
                end
                LP_MRS:
                begin
                    r_state_counter	<= 8'd0;
                    r_state_counter_done <= 1'b0;
                end
                LP_FETCH:
                begin
                    if( r_state_counter <= 8'd200)
                    begin
                        r_state_counter	<= r_state_counter + 8'd1;
                        r_state_counter_done <= 1'b0;
                    end
                    else
                    begin
                        r_state_counter_done <= 1'b1;
                        r_state_counter	<= r_state_counter;
                    end
                end
                default:
                begin
                    r_state_counter_done	<= 1'b0;
                    r_state_counter			<= 8'd0;
                end
            endcase
        end
    end
end

/****************/
/* STATE ASSIGN */
/****************/
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 )
    begin
        r_phy_tg_ps	<= LP_IDLE;
    end
    else
    begin
        r_phy_tg_ps	<= r_phy_tg_ns;
    end
end

/**************/
/* STATE TRAN */
/**************/
always @ ( * )
begin
    case( r_phy_tg_ps )
        LP_IDLE:
        begin
            if( r_fsm_rst_b == 1'b0  )
            begin
                r_phy_tg_ns	= LP_IDLE;
            end
            else
            begin
                    r_phy_tg_ns = LP_MRS;
            end
        end
        LP_MRS: 
        begin
            if( r_fsm_rst_b == 1'b0 )
            begin
                r_phy_tg_ns = LP_IDLE;
            end
            else
            begin
                if( r_mrs_lat_cnt_done == 1'b1 )
                begin
                    r_phy_tg_ns = LP_FETCH;
                end
                else
                begin
                    r_phy_tg_ns = LP_MRS;
                end
            end
        end
        
        LP_FETCH:
        begin
            if( r_fsm_rst_b == 1'b0 )
            begin
                r_phy_tg_ns = LP_IDLE;
            end
            else
            begin
                if( r_state_counter_done )
                begin
                    r_phy_tg_ns = LP_CMD_WAIT;
                end
                else
                begin
                    r_phy_tg_ns = LP_FETCH;
                end
            end
        end
       
        /* Init phase complete, here wait for a new command from extern */
        LP_CMD_WAIT:
        begin
            if( r_fsm_rst_b == 1'b0 ) begin
                r_phy_tg_ns = LP_IDLE;
            end
            else if ( (cmd_ras_ps0 != P_GENERAL_NOP) || (cmd_ras_ps1 != P_GENERAL_NOP) || (cmd_cas_ps0 != P_GENERAL_NOP) || (cmd_cas_ps0 != P_GENERAL_NOP) )  begin  /* c'è un comando in arrivo */
                r_phy_tg_ns <= LP_CMD_WAIT_1;
                
            end
            else begin
                r_phy_tg_ns <= LP_CMD_WAIT;
            end
        end  
        
        LP_CMD_WAIT_1:
        if( r_fsm_rst_b == 1'b0 )begin
                r_phy_tg_ns = LP_IDLE;
        end
        else begin
            r_phy_tg_ns <= LP_CMD_WAIT_1;
        end  
                   
                
        default:
        begin
            r_phy_tg_ns = LP_IDLE;
        end
    endcase
end

// MRS
assign w_T_WL_MRS2 = LP_T_WL + 5;
assign w_T_RL_MRS2 = 5'b1_0010;


/***********************************/
/* RESET HBM CONTROLLER MANAGEMENT */
/***********************************/


always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        r_reset_hbm_controller  <= 1'b0;
    end 
    else begin
        if (r_phy_tg_ns == LP_CMD_WAIT) begin
            r_reset_hbm_controller <= 1'b1;
        end
        else begin
            r_reset_hbm_controller <= r_reset_hbm_controller;
        end 
    end 
end



/**********************/
/*                    */
/*        DATA        */
/*                    */ 
/**********************/

/*******************************/
/*      WRDATA QUEUE PS0       */
/*******************************/
localparam INDEX_QUEUE_WIDTH = $clog2(P_WRT_DATA_BUFFER_LEN);

reg [P_DATA_WIDTH - 1    : 0 ]   wrt_data_buffer_ps0         [ 0 : P_WRT_DATA_BUFFER_LEN-1 ];                               
reg [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_head_ps0;
reg [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_tail_ps0; 
reg [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_tail_for_reset_ps0;
reg [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_tail_for_reset_ps1; 
reg [INDEX_QUEUE_WIDTH   : 0 ]   wrt_data_buffer_cnt_ps0; 

reg [2:0] wrt_to_data_cnt_ps0 [ 0 : P_WRT_DATA_BUFFER_LEN-1 ];


wire                              incr_wrt_data_buffer_cnt_ps0;
wire                              deincr_wrt_data_buffer_cnt_ps0;

wire                              rst_wrt_to_data_cnt_ps0;


assign     incr_wrt_data_buffer_cnt_ps0 = can_serve_actual_wrt_ps0;
assign     deincr_wrt_data_buffer_cnt_ps0 = (wrt_data_buffer_cnt_ps0 > 0) && (wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] == tWL-2'h2);


/****************************************/
/* WRITE DATA BUFFER COUNTER MANAGEMENT */
/****************************************/
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        wrt_data_buffer_cnt_ps0  <= {INDEX_QUEUE_WIDTH+1{1'b0}};
    end 
    else begin
        if ( incr_wrt_data_buffer_cnt_ps0 && ~deincr_wrt_data_buffer_cnt_ps0 ) begin
            wrt_data_buffer_cnt_ps0 <= wrt_data_buffer_cnt_ps0 + 1'b1;
            
        end 
        else if ( ~incr_wrt_data_buffer_cnt_ps0 && deincr_wrt_data_buffer_cnt_ps0 ) begin
            wrt_data_buffer_cnt_ps0 <= wrt_data_buffer_cnt_ps0 - 1'b1;
        end
        else if ( incr_wrt_data_buffer_cnt_ps0 && deincr_wrt_data_buffer_cnt_ps0 ) begin
            wrt_data_buffer_cnt_ps0 <= wrt_data_buffer_cnt_ps0;
        end
    end 
end

assign rst_wrt_to_data_cnt_ps0 = can_serve_actual_wrt_ps0 /*&& wrt_data_buffer_cnt_ps0 < P_WRT_DATA_BUFFER_LEN*/;

genvar i;
generate
    for ( i=0; i<P_WRT_DATA_BUFFER_LEN; i=i+1 ) begin
        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
            if( dfi_rst_n == 1'b0 ) begin
                wrt_to_data_cnt_ps0[i] <= {8{1'b0}};
            end
            else begin
                if (rst_wrt_to_data_cnt_ps0)  begin
                    if ( i == wrt_data_buffer_tail_for_reset_ps0 ) begin
                        wrt_to_data_cnt_ps0[i] <= {8{1'b0}};
                    end
                    else begin
                        wrt_to_data_cnt_ps0[i]  <= wrt_to_data_cnt_ps0[i] + 1'b1;
                    end
                end
                else begin
                    wrt_to_data_cnt_ps0[i]  <= wrt_to_data_cnt_ps0[i]  + 1'b1;
                end
            end
        end
    end
endgenerate


always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if( dfi_rst_n == 1'b0 ) begin
        wrt_data_buffer_tail_for_reset_ps0 <= { INDEX_QUEUE_WIDTH { 1'b0 } }; 
    end
    else begin
        if (rst_wrt_to_data_cnt_ps0)  begin
            wrt_data_buffer_tail_for_reset_ps0 <= wrt_data_buffer_tail_for_reset_ps0 + 1'b1;
        end
    end
end

/**************************/
/* FILL WRITE DATA BUFFER */
/**************************/
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if( dfi_rst_n == 1'b0 ) begin
        for ( integer i = 0; i < P_WRT_DATA_BUFFER_LEN; i = i + 1 ) wrt_data_buffer_ps0[i] <= {P_DATA_WIDTH { 1'b1 } };
        wrt_data_buffer_head_ps0 <= {INDEX_QUEUE_WIDTH{1'b0}};
    end
    else begin
        if ( can_serve_actual_wrt_ps0 ) begin      
            if ( wrt_data_buffer_cnt_ps0 < P_WRT_DATA_BUFFER_LEN ) begin
                wrt_data_buffer_ps0[wrt_data_buffer_head_ps0] <= wrt_data_cas_ps0;   
                wrt_data_buffer_head_ps0 <= wrt_data_buffer_head_ps0 + 1'b1;
            end
        end
    end
end

/******************************/
/* READ DATA REQ ID QUEUE PS0 */
/******************************/
localparam RD_INDEX_QUEUE_WIDTH = $clog2(P_RD_ID_BUFFER_LEN);
reg [RD_INDEX_QUEUE_WIDTH-1 : 0 ]   rd_req_id_buffer_head_ps0;
reg [RD_INDEX_QUEUE_WIDTH-1 : 0 ]   rd_req_id_buffer_tail_ps0; 
reg [RD_INDEX_QUEUE_WIDTH   : 0 ]   rd_req_id_buffer_cnt_ps0; 

wire                              incr_rd_req_id_buffer_cnt_ps0;
wire                              deincr_rd_req_id_buffer_cnt_ps0;

assign incr_rd_req_id_buffer_cnt_ps0    = rd_req_id_buffer_cnt_ps0 < P_RD_ID_BUFFER_LEN && can_serve_actual_rd_ps0;
assign deincr_rd_req_id_buffer_cnt_ps0  = rd_req_id_buffer_cnt_ps0 > 0 && dfi_dw_rddata_valid[1:0] == 2'b11;

reg rd_req_id_buffer_en_ps0;
wire [P_REQ_ID_WIDTH-1:0]rd_req_id_data_out_ps0;

block_ram #(
    .DATA_WIDTH(P_REQ_ID_WIDTH),
    .ADDR_WIDTH(RD_INDEX_QUEUE_WIDTH)
)
rd_req_id_buffer_ps0(
    .data_in(req_cas_id_ps0),
    .read_addr(rd_req_id_buffer_tail_ps0), 
    .write_addr(rd_req_id_buffer_head_ps0),
    .wr_en(rd_req_id_buffer_en_ps0), 
    .clk(dfi_clk),
    .data_out(rd_req_id_data_out_ps0)
); 

/* Req ID cnt management */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        rd_req_id_buffer_cnt_ps0  <= {RD_INDEX_QUEUE_WIDTH+1{1'b0}};
    end 
    else begin
        if ( incr_rd_req_id_buffer_cnt_ps0 && ~deincr_rd_req_id_buffer_cnt_ps0 ) begin
            rd_req_id_buffer_cnt_ps0 <= rd_req_id_buffer_cnt_ps0 + 1'b1;
        
        end 
        else if ( ~incr_rd_req_id_buffer_cnt_ps0 && deincr_rd_req_id_buffer_cnt_ps0 ) begin
            rd_req_id_buffer_cnt_ps0 <= rd_req_id_buffer_cnt_ps0 - 1'b1;
        end
        else if ( incr_rd_req_id_buffer_cnt_ps0 && deincr_rd_req_id_buffer_cnt_ps0 ) begin
            rd_req_id_buffer_cnt_ps0 <= rd_req_id_buffer_cnt_ps0;
        end
    end 
end

/* Fill req ID queue */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if( dfi_rst_n == 1'b0 ) begin
        rd_req_id_buffer_head_ps0 <= { RD_INDEX_QUEUE_WIDTH { 1'b0 } };
        rd_req_id_buffer_en_ps0 <= 1'b0;
    end
    else begin
        /* We are going to serve a RD cmd, so we store the req id in the queue */
        if ( rd_req_id_buffer_cnt_ps0 < P_RD_ID_BUFFER_LEN && can_serve_actual_rd_ps0 ) begin
            rd_req_id_buffer_en_ps0 <= 1'b1;
            rd_req_id_buffer_head_ps0 <= rd_req_id_buffer_head_ps0 + 1'b1;
        end
        else begin
            rd_req_id_buffer_en_ps0 <= 1'b0;
            rd_req_id_buffer_head_ps0 <= rd_req_id_buffer_head_ps0;
        end
    end
end

/* Get the data read and the associate req ID from the queue */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if( dfi_rst_n == 1'b0 ) begin
        r_rd_data_ps0             <= { P_DATA_WIDTH { 1'b1 } };
        r_rd_data_req_id_ps0      <= { P_REQ_ID_WIDTH { 1'b1 } };
        rd_req_id_buffer_tail_ps0 <= { RD_INDEX_QUEUE_WIDTH { 1'b0 } };
    end
    else begin
        if ( rd_req_id_buffer_cnt_ps0 > 0 && dfi_dw_rddata_valid[1:0] == 2'b11 ) begin
            r_rd_data_ps0[255:128]    <=  { dfi_dw_rddata_p0[191:128],   dfi_dw_rddata_p0[63:0]};
            r_rd_data_ps0[127:0]      <=  { dfi_dw_rddata_p1[191:128],   dfi_dw_rddata_p1[63:0]};
            r_rd_data_req_id_ps0      <=  rd_req_id_data_out_ps0;
            rd_req_id_buffer_tail_ps0 <= rd_req_id_buffer_tail_ps0 + 1'b1;
        end
    end
end


/*******************************/
/*      WRDATA QUEUE PS1       */
/*******************************/
reg [P_DATA_WIDTH - 1    : 0 ]   wrt_data_buffer_ps1         [ 0 : P_WRT_DATA_BUFFER_LEN-1 ];                               
reg [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_head_ps1;
reg [INDEX_QUEUE_WIDTH-1 : 0 ]   wrt_data_buffer_tail_ps1; 
reg [INDEX_QUEUE_WIDTH   : 0 ]   wrt_data_buffer_cnt_ps1; 

reg [2:0] wrt_to_data_cnt_ps1 [ 0 : P_WRT_DATA_BUFFER_LEN-1 ];


wire                              incr_wrt_data_buffer_cnt_ps1;
wire                              deincr_wrt_data_buffer_cnt_ps1;

wire                              rst_wrt_to_data_cnt_ps1;


assign     incr_wrt_data_buffer_cnt_ps1 = can_serve_actual_wrt_ps1;
assign     deincr_wrt_data_buffer_cnt_ps1 = (wrt_data_buffer_cnt_ps1 > 0) && (wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] == tWL-2'h1);


/****************************************/
/* WRITE DATA BUFFER COUNTER MANAGEMENT */
/****************************************/
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        wrt_data_buffer_cnt_ps1  <= {INDEX_QUEUE_WIDTH+1{1'b0}};
    end 
    else begin
        if ( incr_wrt_data_buffer_cnt_ps1 && ~deincr_wrt_data_buffer_cnt_ps1 ) begin
            wrt_data_buffer_cnt_ps1 <= wrt_data_buffer_cnt_ps1 + 1'b1;
            
        end 
        else if ( ~incr_wrt_data_buffer_cnt_ps1 && deincr_wrt_data_buffer_cnt_ps1 ) begin
            wrt_data_buffer_cnt_ps1 <= wrt_data_buffer_cnt_ps1 - 1'b1;
        end
        else if ( incr_wrt_data_buffer_cnt_ps1 && deincr_wrt_data_buffer_cnt_ps1 ) begin
            wrt_data_buffer_cnt_ps1 <= wrt_data_buffer_cnt_ps1;
        end
    end 
end

assign rst_wrt_to_data_cnt_ps1 = can_serve_actual_wrt_ps1 /*&&  (wrt_data_buffer_cnt_ps1 < P_WRT_DATA_BUFFER_LEN)*/;

generate
    for ( i=0; i<P_WRT_DATA_BUFFER_LEN; i=i+1 ) begin
        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
            if( dfi_rst_n == 1'b0 ) begin
                wrt_to_data_cnt_ps1[i] <= {8{1'b0}};
            end
            else begin
                if (rst_wrt_to_data_cnt_ps1)  begin
                    if ( i == wrt_data_buffer_tail_for_reset_ps1 ) begin
                        wrt_to_data_cnt_ps1[i] <= {8{1'b0}};
                    end
                    else begin
                        wrt_to_data_cnt_ps1[i]  <= wrt_to_data_cnt_ps1[i] + 1'b1;
                    end
                end
                else begin
                    wrt_to_data_cnt_ps1[i]  <= wrt_to_data_cnt_ps1[i]  + 1'b1;
                end
            end
        end
    end
endgenerate


always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if( dfi_rst_n == 1'b0 ) begin
        wrt_data_buffer_tail_for_reset_ps1 <= { INDEX_QUEUE_WIDTH { 1'b0 } }; 
    end
    else begin
        if (rst_wrt_to_data_cnt_ps1)  begin
            wrt_data_buffer_tail_for_reset_ps1 <= wrt_data_buffer_tail_for_reset_ps1 + 1'b1;
        end
    end
end


/**************************/
/* FILL WRITE DATA BUFFER */
/**************************/
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if( dfi_rst_n == 1'b0 ) begin   
        for ( integer i = 0; i < P_WRT_DATA_BUFFER_LEN; i = i + 1 ) wrt_data_buffer_ps1[i] <= {P_DATA_WIDTH { 1'b1 } };     
        wrt_data_buffer_head_ps1 <= {INDEX_QUEUE_WIDTH{1'b0}};
    end
    
    else begin
        if ( can_serve_actual_wrt_ps1 ) begin      
            if ( wrt_data_buffer_cnt_ps1 < P_WRT_DATA_BUFFER_LEN ) begin
                wrt_data_buffer_ps1[wrt_data_buffer_head_ps1] <= wrt_data_cas_ps1;   
                wrt_data_buffer_head_ps1 <= wrt_data_buffer_head_ps1 + 1'b1;    
            end 
        end
    end
end

/******************************/
/* READ DATA REQ ID QUEUE PS1 */
/******************************/

reg [RD_INDEX_QUEUE_WIDTH-1 : 0 ]   rd_req_id_buffer_head_ps1;
reg [RD_INDEX_QUEUE_WIDTH-1 : 0 ]   rd_req_id_buffer_tail_ps1; 
reg [RD_INDEX_QUEUE_WIDTH   : 0 ]   rd_req_id_buffer_cnt_ps1; 

wire                              incr_rd_req_id_buffer_cnt_ps1;
wire                              deincr_rd_req_id_buffer_cnt_ps1;

assign incr_rd_req_id_buffer_cnt_ps1    = rd_req_id_buffer_cnt_ps1 < P_RD_ID_BUFFER_LEN && can_serve_actual_rd_ps1;
assign deincr_rd_req_id_buffer_cnt_ps1  = rd_req_id_buffer_cnt_ps1 > 0 && dfi_dw_rddata_valid[1:0] == 2'b11;

reg rd_req_id_buffer_en_ps1;
wire [P_REQ_ID_WIDTH-1:0] rd_req_id_data_out_ps1;

block_ram #(
    .DATA_WIDTH(P_REQ_ID_WIDTH),
    .ADDR_WIDTH(RD_INDEX_QUEUE_WIDTH)
)
rd_req_id_buffer_ps1(
    .data_in(req_cas_id_ps1),
    .read_addr(rd_req_id_buffer_tail_ps1), 
    .write_addr(rd_req_id_buffer_head_ps1),
    .wr_en(rd_req_id_buffer_en_ps1), 
    .clk(dfi_clk),
    .data_out(rd_req_id_data_out_ps1)
); 

/* Req ID cnt management */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        rd_req_id_buffer_cnt_ps1  <= {RD_INDEX_QUEUE_WIDTH+1{1'b0}};
    end 
    else begin
        if ( incr_rd_req_id_buffer_cnt_ps1 && ~deincr_rd_req_id_buffer_cnt_ps1 ) begin
            rd_req_id_buffer_cnt_ps1 <= rd_req_id_buffer_cnt_ps1 + 1'b1;
        
        end 
        else if ( ~incr_rd_req_id_buffer_cnt_ps1 && deincr_rd_req_id_buffer_cnt_ps1 ) begin
            rd_req_id_buffer_cnt_ps1 <= rd_req_id_buffer_cnt_ps1 - 1'b1;
        end
        else if ( incr_rd_req_id_buffer_cnt_ps1 && deincr_rd_req_id_buffer_cnt_ps1 ) begin
            rd_req_id_buffer_cnt_ps1 <= rd_req_id_buffer_cnt_ps1;
        end
    end 
end

/* Fill req ID queue */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if( dfi_rst_n == 1'b0 ) begin
        rd_req_id_buffer_head_ps1 <= { RD_INDEX_QUEUE_WIDTH { 1'b0 } };
        rd_req_id_buffer_en_ps1 <= 1'b0;
    end
    else begin
        /* We are going to serve a RD cmd, so we store the req id in the queue */
        if ( rd_req_id_buffer_cnt_ps1 < P_RD_ID_BUFFER_LEN && can_serve_actual_rd_ps1 ) begin
            rd_req_id_buffer_en_ps1 <= 1'b1;
            rd_req_id_buffer_head_ps1 <= rd_req_id_buffer_head_ps1 + 1'b1;
        end
        else begin
            rd_req_id_buffer_en_ps1 <= 1'b0;
            rd_req_id_buffer_head_ps1 <= rd_req_id_buffer_head_ps1;
        end
    end
end

/* Get the data read and the associate req ID from the queue */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if( dfi_rst_n == 1'b0 ) begin
        r_rd_data_ps1             <= { P_DATA_WIDTH { 1'b1 } };
        r_rd_data_req_id_ps1      <= { P_REQ_ID_WIDTH { 1'b1 } };
        rd_req_id_buffer_tail_ps1 <= { RD_INDEX_QUEUE_WIDTH { 1'b0 } };
    end
    else begin
        if ( rd_req_id_buffer_cnt_ps1 > 0 && dfi_dw_rddata_valid[3:2] == 2'b11 ) begin
            r_rd_data_ps1[255:128]    <=  { dfi_dw_rddata_p1[255:192],   dfi_dw_rddata_p1[127:64]};
            r_rd_data_ps1[127:0]      <=  { dfi_dw_rddata_p0[255:192],   dfi_dw_rddata_p0[127:64]};
            r_rd_data_req_id_ps1      <=  rd_req_id_data_out_ps1;
            rd_req_id_buffer_tail_ps1 <= rd_req_id_buffer_tail_ps1 + 1'b1;
        end
    end
end


/********************/
/* SEND DATA TO HBM */
/********************/
/* Here we send data for PS0 and for PS1 together on different phase P0 and P1 */
/* To understand better this component you have to consider the phases, and of course you can read the documentation ;) */
reg wrt_sync_ps0;
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if( dfi_rst_n == 1'b0 ) begin
        wrt_data_p1         <=  { P_DATA_WIDTH { 1'b0 } };
        wrt_data_p0         <=  { P_DATA_WIDTH { 1'b0 } };
        wrt_data_buffer_tail_ps1 <= {INDEX_QUEUE_WIDTH{1'b0}};   
        wrt_data_buffer_tail_ps0 <= {INDEX_QUEUE_WIDTH{1'b0}}; 
        wrt_sync_ps0 <= 1'b0;
    end
    else begin
        // if ( wrt_data_buffer_cnt_ps1 > 0 ) begin
            /* Only PS0 has to be served (data) */
            if ( wrt_data_buffer_cnt_ps0 > 0 && wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] == tWL-2'h2 && wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] != tWL-2'h1  ) begin

                wrt_data_p0[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][63:0];
                wrt_data_p0[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][127:64];

                wrt_data_p1[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0][191:128];
                wrt_data_p1[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0][255:192];

                wrt_data_buffer_tail_ps0 <= wrt_data_buffer_tail_ps0 + 1'b1;
                wrt_sync_ps0 <= 1'b1;
            end
            /* PS0 and PS1 have to be served (data) */
            else if ( wrt_data_buffer_cnt_ps0 > 0 && wrt_data_buffer_cnt_ps1 > 0 && wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] == tWL-2'h2 && wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] == tWL-2'h1 ) begin
                wrt_data_p0[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][63:0];
                wrt_data_p0[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][127:64];

                wrt_data_p1[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0][191:128];
                wrt_data_p1[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0][255:192];

                wrt_data_buffer_tail_ps0 <= wrt_data_buffer_tail_ps0 + 1'b1;
                wrt_sync_ps0 <= 1'b1;

                wrt_data_p0[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][63:0];
                wrt_data_p0[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][127:64];

                wrt_data_p1[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][191:128];
                wrt_data_p1[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][255:192];

                wrt_data_buffer_tail_ps1 <= wrt_data_buffer_tail_ps1 + 1'b1;
            
            end
            /* Only PS1 has to be served, but we have residual data that have to be served for PS0 */
            else if ( wrt_data_buffer_cnt_ps1 > 0 && wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] != tWL-2'h2 && wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] == tWL-2'h1 && wrt_sync_ps0 ) begin
                wrt_data_p0[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][63:0];
                wrt_data_p0[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][127:64];
                wrt_sync_ps0 <= 1'b0;
                
                wrt_data_p0[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][63:0];
                wrt_data_p0[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][127:64];

                wrt_data_p1[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][191:128];
                wrt_data_p1[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][255:192];

                wrt_data_buffer_tail_ps1 <= wrt_data_buffer_tail_ps1 + 1'b1;
            end
            /* Only PS1 has to be served */
            else if ( wrt_data_buffer_cnt_ps1 > 0 && wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] != tWL-2'h2 && wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] == tWL-2'h1 && ~wrt_sync_ps0 ) begin                
                wrt_data_p0[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][63:0];
                wrt_data_p0[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][127:64];

                wrt_data_p1[127:64]   <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][191:128];
                wrt_data_p1[255:192]  <= wrt_data_buffer_ps1[wrt_data_buffer_tail_ps1][255:192];

                wrt_data_buffer_tail_ps1 <= wrt_data_buffer_tail_ps1 + 1'b1;
            end
            
            /* There are only data residuals for PS0 */
            else if ( wrt_sync_ps0 ) begin
                wrt_data_p0[63:0]     <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][63:0];
                wrt_data_p0[191:128]  <= wrt_data_buffer_ps0[wrt_data_buffer_tail_ps0-1'b1][127:64];
                wrt_sync_ps0 <= 1'b0;
            end

            else begin
                wrt_data_p0   <= { P_DATA_WIDTH { 1'b1 } };
                wrt_data_p1   <= { P_DATA_WIDTH { 1'b1 } };
            end
        // end
    end
end


/******************************/
/*                            */
/*          COMMANDS          */
/*                            */
/******************************/

reg double_act_ras_sync;
reg [3:0] sync_cmd_ras_ps1;
reg [P_BA_ADDR_WIDTH  -1 : 0] sync_bank_addr_ras_ps1;
reg [P_ROW_ADDR_WIDTH -1 : 0] sync_row_addr_ras_ps1;
reg [P_REQ_ID_WIDTH-1:0]                    sync_req_ras_id_ps1;
reg [P_CMD_ID_WIDTH-1:0]                    sync_cmd_ras_id_ps1;


always @( posedge dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        double_act_ras_sync <= 1'b0;
        sync_cmd_ras_ps1 <= P_GENERAL_NOP;
        sync_bank_addr_ras_ps1 <=  { P_BA_ADDR_WIDTH  { 1'b0 } };
        sync_row_addr_ras_ps1  <=  { P_ROW_ADDR_WIDTH { 1'b0 } };
        sync_req_ras_id_ps1    <=  { P_REQ_ID_WIDTH {1'b0} };
        sync_cmd_ras_id_ps1    <=  { P_CMD_ID_WIDTH {1'b0} };
    end 
    else begin 
        if ( (can_serve_actual_act_ps0 && can_serve_actual_ras_ps1) || (can_serve_actual_act_ps1 && can_serve_actual_ras_ps0) && ~double_act_ras_sync) begin
            double_act_ras_sync <= 1'b1;
            sync_cmd_ras_ps1 <= cmd_ras_ps1;
            sync_bank_addr_ras_ps1 <=  bank_address_ras_ps1;
            sync_row_addr_ras_ps1  <=  row_address_ras_ps1;
            sync_req_ras_id_ps1    <=  req_ras_id_ps1;
            sync_cmd_ras_id_ps1    <=  cmd_ras_id_ps1;
        end
        else if ( double_act_ras_sync ) begin
            double_act_ras_sync <= 1'b0;
            sync_cmd_ras_ps1 <= P_GENERAL_NOP;
            sync_bank_addr_ras_ps1 <=  { P_BA_ADDR_WIDTH  { 1'b0 } };
            sync_row_addr_ras_ps1  <=  { P_ROW_ADDR_WIDTH { 1'b0 } };
            sync_req_ras_id_ps1    <=  { P_REQ_ID_WIDTH {1'b0} };
            sync_cmd_ras_id_ps1    <=  { P_CMD_ID_WIDTH {1'b0} };
        end 
    end
end


/***********************/
/* SEND COMMAND TO HBM */
/***********************/

/****************/
/* RAS Commands */
/****************/
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin : ras_cmd_driver
    if( dfi_rst_n == 1'b0 ) begin
        r_row_cmd_p0    <= 12'hfff;
        r_row_cmd_p1    <= 12'hfff;      
        r_served_ras    <= { (P_BA_N_PS*2) {1'b0} };
          
    end
    
    else if( r_phy_tg_ps == LP_MRS ) begin
         r_row_cmd_p0    <= 12'hfff;
         r_row_cmd_p1    <= 12'hfff;
    end

    else begin
        
        if ( double_act_ras_sync ) begin
            if ( sync_cmd_ras_ps1 == P_ROW_ACT )  begin
                r_row_cmd_p0	 <= {sync_bank_addr_ras_ps1[3], sync_row_addr_ras_ps1[13], LP_BA4_1, LP_PAR, sync_row_addr_ras_ps1[12:11], sync_bank_addr_ras_ps1[2:0],1'b0/*r_RA[14]*/,P_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {sync_row_addr_ras_ps1[4:2], LP_PAR, sync_row_addr_ras_ps1[1:0], sync_row_addr_ras_ps1[10:5]};
                r_served_ras <= 1'b1 << {LP_BA4_1, sync_bank_addr_ras_ps1[3:0]};

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  sync_req_ras_id_ps1, sync_cmd_ras_id_ps1, sync_cmd_ras_ps1, $time);
                `endif
            end 
            else if ( sync_cmd_ras_ps1 == P_ROW_PRE ) begin
                r_row_cmd_p0		<= { sync_bank_addr_ras_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, sync_bank_addr_ras_ps1[2:0], P_ROW_PRE};
                r_row_cmd_p1		<= 12'hfff;
                r_served_ras <= 1'b1 << {LP_BA4_1, sync_bank_addr_ras_ps1[3:0]};

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  sync_req_ras_id_ps1, sync_cmd_ras_id_ps1, sync_cmd_ras_ps1, $time);
                `endif
            end
            else if ( sync_cmd_ras_ps1 == P_ROW_REFPB ) begin
                r_row_cmd_p0	 <= {sync_bank_addr_ras_ps1[3], 1'b0, LP_BA4_1, LP_PAR, 2'b11, sync_bank_addr_ras_ps1[2:0], P_ROW_REFPB[2:0]};
                r_row_cmd_p1	 <= 12'hfff;
                r_served_ras <= 1'b1 << {LP_BA4_1, sync_bank_addr_ras_ps1[3:0]};
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  sync_req_ras_id_ps1, sync_cmd_ras_id_ps1, sync_cmd_ras_ps1, $time);
                `endif
            end
            else begin
                r_served_ras    <= { (P_BA_N_PS*2) {1'b0} };
                
                r_row_cmd_p0        <= 12'hfff;
                r_row_cmd_p1		<= 12'hfff;
                
            end
        end
        else /*if ( (can_serve_actual_ras_ps0 && cmd_ras_ps0 != P_GENERAL_NOP) || (can_serve_actual_ras_ps1 && cmd_ras_ps1 != P_GENERAL_NOP) )*/ begin    /* Sono pronto a ricevere un comando e questo che ricevo è valido */
            if ((can_serve_actual_act_ps0 && can_serve_actual_ras_ps1) || (can_serve_actual_act_ps1 && can_serve_actual_ras_ps0)) begin
                if ( cmd_ras_ps0 == P_ROW_ACT )  begin
                    r_row_cmd_p0	 <= {bank_address_ras_ps0[3], row_address_ras_ps0[13], LP_BA4_0, LP_PAR, row_address_ras_ps0[12:11], bank_address_ras_ps0[2:0],1'b0/*r_RA[14]*/,P_ROW_ACT[1:0]};
                    r_row_cmd_p1	 <= {row_address_ras_ps0[4:2], LP_PAR, row_address_ras_ps0[1:0], row_address_ras_ps0[10:5]};
                    r_served_ras <= 1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]};

                    `ifdef DEBUG
                        $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    `endif 
                end 
                else if ( cmd_ras_ps0 == P_ROW_PRE ) begin
                    r_row_cmd_p0		<= { bank_address_ras_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_ras_ps0[2:0], P_ROW_PRE};
                    r_row_cmd_p1		<= 12'hfff;
                    r_served_ras <= 1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]};

                    `ifdef DEBUG
                        $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    `endif
                end
                else if ( cmd_ras_ps0 == P_ROW_REFPB ) begin
                    r_row_cmd_p0	 <= { bank_address_ras_ps0[3], 1'b0, LP_BA4_0, LP_PAR, 2'b11, bank_address_ras_ps0[2:0], P_ROW_REFPB[2:0]};
                    r_row_cmd_p1	 <= 12'hfff;
                    r_served_ras <= 1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]};
                    
                    `ifdef DEBUG
                        $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    `endif

                end
                else begin
                    r_served_ras    <= { (P_BA_N_PS*2) {1'b0} };
                end
            end
            
            else if ( can_serve_actual_act_ps0 && (cmd_ras_ps1 == P_GENERAL_NOP || ~can_serve_actual_ras_ps1 )) begin
                r_row_cmd_p0	 <= {bank_address_ras_ps0[3], row_address_ras_ps0[13], LP_BA4_0, LP_PAR, row_address_ras_ps0[12:11], bank_address_ras_ps0[2:0],1'b0/*r_RA[14]*/,P_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_ras_ps0[4:2], LP_PAR, row_address_ras_ps0[1:0], row_address_ras_ps0[10:5]};
                r_served_ras <= 1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]};

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                `endif
            end 
                        
            else if ( can_serve_actual_pre_ps0 && (cmd_ras_ps1 == P_GENERAL_NOP || ~can_serve_actual_ras_ps1 )  ) begin
                r_row_cmd_p0		<= { bank_address_ras_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_ras_ps0[2:0], P_ROW_PRE};
                r_row_cmd_p1		<= 12'hfff;
                r_served_ras <= 1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]};

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                `endif
            end
            
            else if ( can_serve_actual_pre_ps0 && (can_serve_actual_pre_ps1 )  ) begin
                r_row_cmd_p0		<= { bank_address_ras_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_ras_ps0[2:0], P_ROW_PRE};
                r_row_cmd_p1		<= { bank_address_ras_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, bank_address_ras_ps1[2:0], P_ROW_PRE};
                r_served_ras <= (1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif
            end
            
            else if ( (can_serve_actual_act_ps1) && (cmd_ras_ps0 == P_GENERAL_NOP || ~can_serve_actual_ras_ps0 )) begin
                r_row_cmd_p0	 <= {bank_address_ras_ps1[3], row_address_ras_ps1[13], LP_BA4_1, LP_PAR, row_address_ras_ps1[12:11], bank_address_ras_ps1[2:0],1'b0/*r_RA[14]*/,P_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_ras_ps1[4:2], LP_PAR, row_address_ras_ps1[1:0], row_address_ras_ps1[10:5]};
                r_served_ras <= (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif 
            end 
                        
            else if ( (can_serve_actual_pre_ps1) && (cmd_ras_ps0 == P_GENERAL_NOP || ~can_serve_actual_ras_ps0 )  ) begin
                r_row_cmd_p0		<= { bank_address_ras_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, bank_address_ras_ps1[2:0], P_ROW_PRE};
                r_row_cmd_p1		<= 12'hfff;
                r_served_ras <= (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif             
            end
            
            else if ( (can_serve_actual_ref_ps0) && (cmd_ras_ps1 == P_GENERAL_NOP || ~can_serve_actual_ras_ps1 ) ) begin
                r_row_cmd_p0	 <= { bank_address_ras_ps0[3], 1'b0, LP_BA4_0, LP_PAR, 2'b11, bank_address_ras_ps0[2:0], P_ROW_REFPB[2:0]};
                r_row_cmd_p1	 <= 12'hfff;
                r_served_ras <= (1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]});

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                `endif
            end
            
            else if ( (can_serve_actual_ref_ps1) && (cmd_ras_ps0 == P_GENERAL_NOP || ~can_serve_actual_ras_ps0 ) ) begin
                r_row_cmd_p0	 <= { bank_address_ras_ps1[3], 1'b0, LP_BA4_1, LP_PAR, 2'b11, bank_address_ras_ps1[2:0], P_ROW_REFPB[2:0]};
                r_row_cmd_p1	 <= 12'hfff;
                r_served_ras <= (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif
            end
            
            else if ( (can_serve_actual_ref_ps0) && (can_serve_actual_pre_ps1 ) ) begin
                r_row_cmd_p0	 <= { bank_address_ras_ps0[3], 1'b0, LP_BA4_0, LP_PAR, 2'b11, bank_address_ras_ps0[2:0], P_ROW_REFPB[2:0]};
                r_row_cmd_p1	 <= { bank_address_ras_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, bank_address_ras_ps1[2:0], P_ROW_PRE};
                r_served_ras <= (1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif
            end
            
            else if ( (can_serve_actual_ref_ps1) && (cmd_ras_ps0 == P_ROW_PRE && can_serve_actual_ras_ps0 ) ) begin
                r_row_cmd_p0	 <= { bank_address_ras_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_ras_ps0[2:0], P_ROW_PRE};
                r_row_cmd_p1	 <= { bank_address_ras_ps1[3], 1'b0, LP_BA4_1, LP_PAR, 2'b11, bank_address_ras_ps1[2:0], P_ROW_REFPB[2:0]};
                r_served_ras <= (1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif
            end
            
            else if ( (can_serve_actual_ref_ps0) && (can_serve_actual_ref_ps1 ) ) begin
                r_row_cmd_p0	 <= { bank_address_ras_ps0[3], 1'b0, LP_BA4_0, LP_PAR, 2'b11, bank_address_ras_ps0[2:0], P_ROW_REFPB[2:0]};
                r_row_cmd_p1	 <= { bank_address_ras_ps1[3], 1'b0, LP_BA4_1, LP_PAR, 2'b11, bank_address_ras_ps1[2:0], P_ROW_REFPB[2:0]};
                r_served_ras <= (1'b1 << {LP_BA4_0, bank_address_ras_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_ras_ps1[3:0]} );
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps0, cmd_ras_id_ps0, cmd_ras_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_ras_id_ps1, cmd_ras_id_ps1, cmd_ras_ps1, $time);
                `endif
            end
            
            else begin
                r_row_cmd_p0    <= 12'hfff;
                r_row_cmd_p1    <= 12'hfff;
                
                r_served_ras    <= { (P_BA_N_PS*2) {1'b0} };
                
            end
            
        end
        // else begin
        //     r_row_cmd_p0    <= 12'hfff;
        //     r_row_cmd_p1    <= 12'hfff;
            
        //     r_served_ras    <= { (P_BA_N_PS*2) {1'b0} };
            
        // end   
    end
end

/****************/
/* CAS Commands */
/****************/
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin : cas_cmd_driver
    if( dfi_rst_n == 1'b0 ) begin
        r_col_cmd_p0    <= 16'hffff;
        r_col_cmd_p1    <= 16'hffff;
        
        r_served_cas    <= { (P_BA_N_PS*2) {1'b0} };
        
    end
    
    else if( r_phy_tg_ps == LP_MRS )
        begin
          case (r_mrs_reg_cnt)
            8'h00: begin
              r_col_cmd_p0 <= 16'h0000; //MR-0
              r_col_cmd_p1 <= 16'hffff;
            end
         8'h10: begin
              r_col_cmd_p0 <= 16'hffff;
              //r_col_cmd_p1 <= 16'hea10; //MR-1
              r_col_cmd_p1 <= 16'ha010; //MR-1
            end
         8'h20: begin
              //r_col_cmd_p0 <= 16'h2e28; //w_T_WL_MRS2 MR-2
              r_col_cmd_p0 <= {w_T_RL_MRS2[3:0], w_T_WL_MRS2[2], LP_PAR, w_T_WL_MRS2[1:0], LP_MRS2_A, w_T_RL_MRS2[4],LP_MRS_CMD}; //MR-2
              r_col_cmd_p1 <= 16'hffff;
            end
         8'h30: begin
              r_col_cmd_p0 <= 16'hffff;
              //r_col_cmd_p1 <= 16'h4138; //MR-3
              r_col_cmd_p1 <= 16'hc138; //MR-3
            end
         8'h40: begin
              //r_col_cmd_p0 <= 16'h1c40; //MR-4
              r_col_cmd_p0 <= 16'h0440; //MR-4
              r_col_cmd_p1 <= 16'hffff;
            end
         8'h50: begin
              r_col_cmd_p0 <= 16'hffff;
              r_col_cmd_p1 <= 16'h0050; //MR-5
            end
         8'h60: begin
              r_col_cmd_p0 <= 16'hc060; //MR-6
              r_col_cmd_p1 <= 16'hffff;
            end
         8'h70: begin
              r_col_cmd_p0 <= 16'hffff;
              r_col_cmd_p1 <= 16'h0270; //MR-7
            end
         8'h80: begin
              r_col_cmd_p0 <= 16'h00f0;
              r_col_cmd_p1 <= 16'hffff; //MR-7
            end
            default : begin
              r_col_cmd_p0 <= 16'hffff;
              r_col_cmd_p1 <= 16'hffff;
            end
       endcase
    end

    else begin
        // if ( (can_serve_actual_cas_ps0 && cmd_cas_ps0 != P_GENERAL_NOP) || (can_serve_actual_cas_ps1 && cmd_cas_ps1 != P_GENERAL_NOP) ) begin    /* Sono pronto a ricevere un comando e questo che ricevo è valido */
            if ( (can_serve_actual_wrt_ps0 ) && ( cmd_cas_ps1 == P_GENERAL_NOP || ~can_serve_actual_cas_ps1 )  ) begin
                r_col_cmd_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_WRT[3:0]}; 
                r_col_cmd_p1        <= 16'hffff;
                r_served_cas <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]});

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
                `endif
            end 
                        
            else if ((can_serve_actual_wrt_ps0 ) && ( can_serve_actual_wrt_ps1 ) ) begin
                r_col_cmd_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_WRT[3:0]}; 
                r_col_cmd_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_WRT[3:0]}; 
                r_served_cas <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]}); 

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
                `endif
            end
            
            else if ((can_serve_actual_wrt_ps0 ) && ( can_serve_actual_rd_ps1 ) ) begin
                r_col_cmd_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_WRT[3:0]}; 
                r_col_cmd_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_RD};
                r_served_cas <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]}); 

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
                `endif
            end
            
            else if ( (can_serve_actual_rd_ps0 ) && ( cmd_cas_ps1 == P_GENERAL_NOP || ~can_serve_actual_cas_ps1 )  ) begin
                r_col_cmd_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_RD}; 
                r_col_cmd_p1        <= 16'hffff;                
                r_served_cas <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]}); 
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
                `endif
            end 
                        
            else if ((can_serve_actual_rd_ps0 ) && ( can_serve_actual_wrt_ps1 ) ) begin
                r_col_cmd_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_RD}; 
                r_col_cmd_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_WRT[3:0]}; 
                r_served_cas <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]}); 

                `ifdef DEBUG            
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
                `endif
            end
            
            else if ((can_serve_actual_rd_ps0 ) && ( can_serve_actual_rd_ps1 ) ) begin
                r_col_cmd_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_RD}; 
                r_col_cmd_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_RD};
                r_served_cas <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]}); 

                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
                `endif
            end
            
            else if ( (can_serve_actual_wrt_ps1 ) && ( cmd_cas_ps0 == P_GENERAL_NOP || ~can_serve_actual_cas_ps0 )  ) begin
                r_col_cmd_p0        <= 16'hffff;
                r_col_cmd_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_WRT[3:0]}; 
                r_served_cas <= (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]});
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
                `endif
            end 
            
            else if ( (can_serve_actual_rd_ps1 ) && ( cmd_cas_ps0 == P_GENERAL_NOP || ~can_serve_actual_cas_ps0 )  ) begin
                r_col_cmd_p0        <= 16'hffff;
                r_col_cmd_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_RD};
                r_served_cas <= (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]});
                
                `ifdef DEBUG
                    $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
                `endif
            end 
            
            else begin
                r_col_cmd_p0    <= 16'hffff;
                r_col_cmd_p1    <= 16'hffff;
                
                r_served_cas    <= { (P_BA_N_PS*2) {1'b0} };
                
            end
            
        // end
        // else begin
        //     r_col_cmd_p0    <= 16'hffff;
        //     r_col_cmd_p1    <= 16'hffff;
            
        //     r_served_cas    <= { (P_BA_N_PS*2) {1'b0} };
        // end   
    end
end

reg [3:0] last_wrt_bg_cnt_ps0 [0 : LP_BG_N - 1];  /*  Last write bank group counter, time elapsed from the last write in a given bank group in PS0  */
reg [3:0] last_rd_bg_cnt_ps0  [0 : LP_BG_N - 1];  /*  Last read bank group counter, time elapsed from the last read in a given bank group in PS0    */       
reg [3:0] last_wrt_bg_cnt_ps1 [0 : LP_BG_N - 1];  /*  Last write bank group counter, time elapsed from the last write in a given bank group in PS1  */
reg [3:0] last_rd_bg_cnt_ps1  [0 : LP_BG_N - 1];  /*  Last read bank group counter, time elapsed from the last read in a given bank group in PS1    */       

// reg  last_wrt_bg_cnt_ps0_for_CCDl [0 : LP_BG_N - 1];  /*  Last write bank group counter, time elapsed from the last write in a given bank group in PS0  */
// reg  last_rd_bg_cnt_ps0_for_CCDl  [0 : LP_BG_N - 1];  /*  Last read bank group counter, time elapsed from the last read in a given bank group in PS0    */       
// reg  last_wrt_bg_cnt_ps1_for_CCDl [0 : LP_BG_N - 1];  /*  Last write bank group counter, time elapsed from the last write in a given bank group in PS1  */
// reg  last_rd_bg_cnt_ps1_for_CCDl  [0 : LP_BG_N - 1];  /*  Last read bank group counter, time elapsed from the last read in a given bank group in PS1    */       


/*************************************************************/
/* WIRE TO SAY IF THE ACTUAL CAS COMMAND RESPECT CONSTRAINTS */
/*************************************************************/
wire [0 : LP_BG_N - 1] actual_wrt_respect_short_cnstr_ps0;
wire [0 : LP_BG_N - 1] actual_wrt_respect_long_cnstr_ps0;
wire [0 : LP_BG_N - 1] actual_wrt_respect_short_cnstr_ps1;
wire [0 : LP_BG_N - 1] actual_wrt_respect_long_cnstr_ps1;
wire [0 : LP_BG_N - 1] actual_rd_respect_short_cnstr_ps0;
wire [0 : LP_BG_N - 1] actual_rd_respect_long_cnstr_ps0;
wire [0 : LP_BG_N - 1] actual_rd_respect_short_cnstr_ps1;
wire [0 : LP_BG_N - 1] actual_rd_respect_long_cnstr_ps1;


reg [2:0] last_act_bg_cnt_ps0 [0 : LP_BG_N - 1];             /* Last act bank group counter, time elapsed from the last ACT in a given bank group in PS0 */
reg [4:0] last_pre_bg_cnt_ps0 [0 : LP_BG_N - 1];             /* Last pre bank group counter, time elapsed from the last PRE in a given bank group in PS0 */
reg [2:0] last_act_bg_cnt_ps1 [0 : LP_BG_N - 1];             /* Last act bank group counter, time elapsed from the last ACT in a given bank group in PS1 */
reg [4:0] last_pre_bg_cnt_ps1 [0 : LP_BG_N - 1];             /* Last pre bank group counter, time elapsed from the last PRE in a given bank group in PS1 */
reg [2:0] last_ref_bg_cnt_ps0_for_RREFD [0 : LP_BG_N - 1];   /* Last ref bank group counter, time elapsed from the last REF in a given bank group in PS0 to count RREFD */ 
reg [2:0] last_ref_bg_cnt_ps1_for_RREFD [0 : LP_BG_N - 1];   /* Last ref bank group counter, time elapsed from the last REF in a given bank group in PS1 to count RREFD */
reg [6:0] last_ref_bg_cnt_ps0_for_RFCpb [0 : LP_BG_N - 1];   /* Last ref bank group counter, time elapsed from the last REF in a given bank group in PS0 to count RFCpb */ 
reg [6:0] last_ref_bg_cnt_ps1_for_RFCpb [0 : LP_BG_N - 1];   /* Last ref bank group counter, time elapsed from the last REF in a given bank group in PS1 to count RFCpb */

reg [5:0] four_act_window_cnt_ps0;                /* tFAW counter ps0 */
reg [5:0] four_act_window_cnt_ps1;                /* tFAW counter ps1 */
reg [2:0] act_cnt_ps0;                  /* Number of ps0 ACT in a tFAW window */
reg [2:0] act_cnt_ps1;                  /* Number of ps1 ACT in a tFAW window */
reg [4:0] ref_cnt_ps0;                  /* Number of ps0 REF in a refresh window */
reg [4:0] ref_cnt_ps1;                  /* Number of ps0 REF in a refresh window */

/*************************************************************/
/* WIRE TO SAY IF THE ACTUAL RAS COMMAND RESPECT CONSTRAINTS */
/*************************************************************/
wire [0 : LP_BG_N - 1] actual_act_respect_cnstr_ps0;
wire [0 : LP_BG_N - 1] actual_act_respect_cnstr_ps1;
wire [0 : LP_BG_N - 1] actual_pre_respect_short_cnstr_ps0;
wire [0 : LP_BG_N - 1] actual_pre_respect_long_cnstr_ps0;
wire [0 : LP_BG_N - 1] actual_pre_respect_short_cnstr_ps1;
wire [0 : LP_BG_N - 1] actual_pre_respect_long_cnstr_ps1;

wire [0 : LP_BG_N - 1] actual_ref_respect_cnstr_ps0;
wire [0 : LP_BG_N - 1] actual_ref_respect_cnstr_ps1;



/***********************************************/
/* ACT COUNTS PS0 iN A tFAW WINDOWS MANAGEMENT */
/***********************************************/
always @ ( posedge /*negedge*/ dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        act_cnt_ps0 <= { 3 { 1'b0 } };
    end
    else begin
        if (( four_act_window_cnt_ps0 >= tFAW-1'b1) && ~(/*r_row_cmd_p0[2:0] == {1'b0, P_ROW_ACT[1:0]} && (r_row_cmd_p0[9] == LP_BA4_0*/ can_serve_actual_act_ps0 && ~double_act_ras_sync)) begin
            act_cnt_ps0 <= 1'b0;
        end
        else if ( ( four_act_window_cnt_ps0 >= tFAW-1'b1) && (/*r_row_cmd_p0[2:0] == {1'b0, P_ROW_ACT[1:0]} && (r_row_cmd_p0[9] == LP_BA4_0*/ can_serve_actual_act_ps0 && ~double_act_ras_sync)) begin
            act_cnt_ps0 <= 1'b1;
        end
        else if ( act_cnt_ps0 >= 4'd4 ) begin
            act_cnt_ps0 <= act_cnt_ps0;
        end
        else if ( /*r_row_cmd_p0[2:0] == {1'b0, P_ROW_ACT[1:0]} && (r_row_cmd_p0[9] == LP_BA4_0*/ can_serve_actual_act_ps0 && ~double_act_ras_sync ) begin
            act_cnt_ps0 <= act_cnt_ps0 + 1'b1;
        end
    end
end

/***********************************************/
/* ACT COUNTS PS1 iN A tFAW WINDOWS MANAGEMENT */
/***********************************************/
always @ ( posedge /*negedge*/ dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        act_cnt_ps1 <= { 3 { 1'b0 } };
    end
    else begin
        if (( four_act_window_cnt_ps1 >= tFAW-1'b1) && ~(/*r_row_cmd_p0[2:0] == {1'b0, P_ROW_ACT[1:0]} && (r_row_cmd_p0[9] == LP_BA4_1)*/ can_serve_actual_act_ps1 && ~double_act_ras_sync) ) begin
            act_cnt_ps1 <= 1'b0;
        end
        else if ( ( four_act_window_cnt_ps1 >= tFAW-1'b1) && ( /*r_row_cmd_p0[2:0] == {1'b0, P_ROW_ACT[1:0]} && (r_row_cmd_p0[9] == LP_BA4_1)*/ can_serve_actual_act_ps1 && ~double_act_ras_sync) ) begin
            act_cnt_ps1 <= 1'b1;
        end
        else if ( act_cnt_ps1 >= 4'd4 ) begin
            act_cnt_ps1 <= act_cnt_ps1;
        end
        else if ( /*r_row_cmd_p0[2:0] == {1'b0, P_ROW_ACT[1:0]} && (r_row_cmd_p0[9] == LP_BA4_1)*/ can_serve_actual_act_ps1 && ~double_act_ras_sync) begin
            act_cnt_ps1 <= act_cnt_ps1 + 1'b1;
        end
    end
end


/*******************/
/* PS0 tFAW UPDATE */
/*******************/
always @ ( posedge /*negedge*/ dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        four_act_window_cnt_ps0 <= { 6 { 1'b0 } };
    end
    else begin
        if ( /*(r_row_cmd_p0[2:0] == {1'b0, P_ROW_ACT[1:0]} ) && (r_row_cmd_p0[9] == LP_BA4_0)*/can_serve_actual_act_ps0 && ~double_act_ras_sync && ( four_act_window_cnt_ps0 >= tFAW-1'b1) ) begin
            four_act_window_cnt_ps0 <= 1'b0;
        end
        else if ( four_act_window_cnt_ps0 == { 6 { 1'b1 } } ) begin
            four_act_window_cnt_ps0 <= four_act_window_cnt_ps0;
        end
        else begin
            four_act_window_cnt_ps0 <= four_act_window_cnt_ps0 + 1'b1;
        end
    end
end

/*******************/
/* PS1 tFAW UPDATE */
/*******************/
always @ ( posedge /*negedge*/ dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        four_act_window_cnt_ps1 <= { 6 { 1'b0 } };
    end
    else begin
        if ( /*(r_row_cmd_p0[2:0] == {1'b0, P_ROW_ACT[1:0]} ) && (r_row_cmd_p0[9] == LP_BA4_1)*/ can_serve_actual_act_ps1 && ~double_act_ras_sync && ( four_act_window_cnt_ps1 >= tFAW-1'b1) ) begin
            four_act_window_cnt_ps1 <= 1'b0;
        end
        else if ( four_act_window_cnt_ps1 == { 6 { 1'b1 } } ) begin
            four_act_window_cnt_ps1 <= four_act_window_cnt_ps1;
        end
        else begin
            four_act_window_cnt_ps1 <= four_act_window_cnt_ps1 + 1'b1;
        end
    end
end

/**************************************************/
/* REF COUNTS PS0 iN A REFRESH WINDOWS MANAGEMENT */
/**************************************************/
always @ ( posedge /*negedge*/ dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        ref_cnt_ps0 <= { 5 { 1'b0 } };
    end
    else begin
        /* A ps0 REF is served */
//        if ( (r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1) && (((r_row_cmd_p0[2:0] == P_ROW_REFPB[2:0]) && (r_row_cmd_p0[9]==LP_BA4_0)) || ((r_row_cmd_p1[2:0] == P_ROW_REFPB[2:0]) && (r_row_cmd_p0[2:0] != {1'b0, P_ROW_ACT[1:0]}) && (r_row_cmd_p1[9]==LP_BA4_0)) )) begin
          if ( can_serve_actual_ref_ps0 && ~double_act_ras_sync ) begin
            /* The last REF is the last of a refresh window, reset the counter */
            if ( ref_cnt_ps0[4] == 1'b1/*P_BA_N_PS*/ ) begin
                ref_cnt_ps0 <= 5'b00001;
            end
            else begin
                ref_cnt_ps0 <= ref_cnt_ps0 + 1'b1;
            end
        end
    end
end

/**************************************************/
/* REF COUNTS PS0 iN A REFRESH WINDOWS MANAGEMENT */
/**************************************************/
always @ ( posedge /*negedge*/ dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        ref_cnt_ps1 <= { 5 { 1'b0 } };
    end
    else begin
        /* A ps1 REF is served */
//        if ( (r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1) && (((r_row_cmd_p0[2:0] == P_ROW_REFPB[2:0]) && (r_row_cmd_p0[9]==LP_BA4_1)) || ((r_row_cmd_p1[2:0] == P_ROW_REFPB[2:0]) && (r_row_cmd_p0[2:0] != {1'b0, P_ROW_ACT[1:0]}) && (r_row_cmd_p1[9]==LP_BA4_1)) )) begin
            /* The last REF is the last of a refresh window, reset the counter */
        if ( can_serve_actual_ref_ps1 && ~double_act_ras_sync ) begin
            if ( ref_cnt_ps1[4] == 1'b1/*P_BA_N_PS*/ ) begin
                ref_cnt_ps1 <= 5'b00001;
            end
            else begin
                ref_cnt_ps1 <= ref_cnt_ps1 + 1'b1;
            end
        end
    end
end





//genvar i;
generate
    for ( i = 0; i < LP_BG_N; i = i + 1) begin
    
        /********************************************/
        /* RAS TIMING CHECK AND COUNTERS MANAGEMENT */
        /********************************************/
        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin : last_wrt_bg_cnt_ps0_driver
            if ( dfi_rst_n == 1'b0 ) begin
                last_wrt_bg_cnt_ps0[i] <= { 4 { 1'b0 } };
            end 
            else begin
//                if ( (r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1) && (r_col_cmd_p0[3:0] == P_COL_WRT) && ( (r_col_cmd_p0[7:4] >= (i*P_BA_N_G)) && (r_col_cmd_p0[7:4] < ((i+1)*P_BA_N_G)) )) begin
                if ( can_serve_actual_wrt_ps0 && bank_group_cas_ps0 == i  ) begin
                    last_wrt_bg_cnt_ps0[i] <= { 4 { 1'b0 } };
                end
                else if ( last_wrt_bg_cnt_ps0[i][3] == 1'b1 /*{ 5 {1'b1 }}*/ ) begin
                    last_wrt_bg_cnt_ps0[i] <= last_wrt_bg_cnt_ps0[i];
                end
                else begin
                    last_wrt_bg_cnt_ps0[i] <= last_wrt_bg_cnt_ps0[i] + 1'b1;
                end
            end
        end 
        
        // always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin : last_wrt_bg_cnt_ps0_for_CCDl_driver
        //     if ( dfi_rst_n == 1'b0 ) begin
        //         last_wrt_bg_cnt_ps0_for_CCDl[i] <= 1'b0;
        //     end 
        //     else begin
        //         if ( can_serve_actual_wrt_ps0 && bank_group_cas_ps0 == i  ) begin
        //             last_wrt_bg_cnt_ps0_for_CCDl[i] <= 1'b0;
        //         end
        //         else if ( last_wrt_bg_cnt_ps0_for_CCDl[i] == 1'b1 ) begin
        //             last_wrt_bg_cnt_ps0_for_CCDl[i] <= last_wrt_bg_cnt_ps0_for_CCDl[i];
        //         end
        //         else begin
        //             last_wrt_bg_cnt_ps0_for_CCDl[i] <= last_wrt_bg_cnt_ps0_for_CCDl[i] + 1'b1;
        //         end
        //     end
        // end 

        always @ (posedge dfi_clk or negedge dfi_rst_n ) begin : last_wrt_bg_cnt_ps1_driver
            if ( dfi_rst_n == 1'b0 ) begin
                last_wrt_bg_cnt_ps1[i] <= { 4 { 1'b0 } };
            end 
            else begin
//                if ( (r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1) && ( r_col_cmd_p1[3:0] == P_COL_WRT) && ( ( r_col_cmd_p1[7:4] >= (i*P_BA_N_G)) && (r_col_cmd_p1[7:4] < ((i+1)*P_BA_N_G)) )) begin
                if ( can_serve_actual_wrt_ps1 && bank_group_cas_ps1 == i ) begin
                    last_wrt_bg_cnt_ps1[i] <= { 4 { 1'b0 } };
                end
                else if ( last_wrt_bg_cnt_ps1[i][3] == 1'b1 /*{ 5 {1'b1 }}*/ ) begin
                    last_wrt_bg_cnt_ps1[i] <= last_wrt_bg_cnt_ps1[i];
                end
                else begin
                    last_wrt_bg_cnt_ps1[i] <= last_wrt_bg_cnt_ps1[i] + 1'b1;
                end
            end
        end 

        // always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin : last_wrt_bg_cnt_ps1_for_CCDl_driver
        //     if ( dfi_rst_n == 1'b0 ) begin
        //         last_wrt_bg_cnt_ps1_for_CCDl[i] <= 1'b0;
        //     end 
        //     else begin
        //         if ( can_serve_actual_wrt_ps0 && bank_group_cas_ps0 == i  ) begin
        //             last_wrt_bg_cnt_ps1_for_CCDl[i] <= 1'b0;
        //         end
        //         else if ( last_wrt_bg_cnt_ps1_for_CCDl[i] == 1'b1 ) begin
        //             last_wrt_bg_cnt_ps1_for_CCDl[i] <= last_wrt_bg_cnt_ps1_for_CCDl[i];
        //         end
        //         else begin
        //             last_wrt_bg_cnt_ps1_for_CCDl[i] <= last_wrt_bg_cnt_ps1_for_CCDl[i] + 1'b1;
        //         end
        //     end
        // end 
        
        always @ (posedge dfi_clk or negedge dfi_rst_n ) begin : last_rd_bg_cnt_ps0_driver
            if ( dfi_rst_n == 1'b0 ) begin
                last_rd_bg_cnt_ps0[i] <= { 4 { 1'b0 } };
            end 
            else begin
//                if ((r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1) && (r_col_cmd_p0[3:0] == P_COL_RD) && ( ( r_col_cmd_p0[7:4] >= (i*P_BA_N_G)) && ( r_col_cmd_p0[7:4] < ((i+1)*P_BA_N_G)) )) begin
                if ( can_serve_actual_rd_ps0 && bank_group_cas_ps0 == i) begin
                    last_rd_bg_cnt_ps0[i] <= { 4 { 1'b0 } };
                end
                else if ( last_rd_bg_cnt_ps0[i][3] == 1'b1 /*{ 5 {1'b1 }}*/ ) begin
                    last_rd_bg_cnt_ps0[i] <= last_rd_bg_cnt_ps0[i];
                end
                else begin
                    last_rd_bg_cnt_ps0[i] <= last_rd_bg_cnt_ps0[i] + 1'b1;
                end
            end
        end

        // always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin : last_rd_bg_cnt_ps0_for_CCDl_driver
        //     if ( dfi_rst_n == 1'b0 ) begin
        //         last_rd_bg_cnt_ps0_for_CCDl[i] <= 1'b0;
        //     end 
        //     else begin
        //         if ( can_serve_actual_rd_ps0 && bank_group_cas_ps0 == i  ) begin
        //             last_rd_bg_cnt_ps0_for_CCDl[i] <= 1'b0;
        //         end
        //         else if ( last_rd_bg_cnt_ps0_for_CCDl[i] == 1'b1 ) begin
        //             last_rd_bg_cnt_ps0_for_CCDl[i] <= last_rd_bg_cnt_ps0_for_CCDl[i];
        //         end
        //         else begin
        //             last_rd_bg_cnt_ps0_for_CCDl[i] <= last_rd_bg_cnt_ps0_for_CCDl[i] + 1'b1;
        //         end
        //     end
        // end 
        
        always @ (posedge dfi_clk or negedge dfi_rst_n ) begin : last_rd_bg_cnt_ps1_driver
            if ( dfi_rst_n == 1'b0 ) begin
                last_rd_bg_cnt_ps1[i] <= { 4 { 1'b0 } };
            end
            else begin
//                if ((r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1) && (r_col_cmd_p1[3:0] == P_COL_RD) && ((r_col_cmd_p1[7:4] >= (i*P_BA_N_G)) && (r_col_cmd_p1[7:4] < ((i+1)*P_BA_N_G)) )) begin
                if ( can_serve_actual_rd_ps1 && bank_group_cas_ps1 == i) begin
                    last_rd_bg_cnt_ps1[i] <= { 4 { 1'b0 } };
                end
                else if ( last_rd_bg_cnt_ps1[i][3] == 1'b1 /*{ 5 {1'b1 }}*/ ) begin
                    last_rd_bg_cnt_ps1[i] <= last_rd_bg_cnt_ps1[i];
                end
                else begin
                    last_rd_bg_cnt_ps1[i] <= last_rd_bg_cnt_ps1[i] + 1'b1;
                end
            end
        end      

        // always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin : last_rd_bg_cnt_ps1_for_CCDl_driver
        //     if ( dfi_rst_n == 1'b0 ) begin
        //         last_rd_bg_cnt_ps1_for_CCDl[i] <= 1'b0;
        //     end 
        //     else begin
        //         if ( can_serve_actual_rd_ps1 && bank_group_cas_ps1 == i  ) begin
        //             last_rd_bg_cnt_ps1_for_CCDl[i] <= 1'b0;
        //         end
        //         else if ( last_rd_bg_cnt_ps1_for_CCDl[i] == 1'b1 ) begin
        //             last_rd_bg_cnt_ps1_for_CCDl[i] <= last_rd_bg_cnt_ps1_for_CCDl[i];
        //         end
        //         else begin
        //             last_rd_bg_cnt_ps1_for_CCDl[i] <= last_rd_bg_cnt_ps1_for_CCDl[i] + 1'b1;
        //         end
        //     end
        // end 
  
        
        assign actual_wrt_respect_long_cnstr_ps0[i]  = ( (cmd_cas_ps0 == P_COL_WRT) && (bank_group_cas_ps0 == i ) && ( last_wrt_bg_cnt_ps0/*_for_CCDl*/[i] /*== 1'b1*/ >= tCCDl ) && (last_rd_bg_cnt_ps0[i][3] == 1'b1 /*>= tRTW*/) );
        assign actual_wrt_respect_long_cnstr_ps1[i]  = ( (cmd_cas_ps1 == P_COL_WRT) && (bank_group_cas_ps1 == i ) && ( last_wrt_bg_cnt_ps1/*_for_CCDl*/[i] /*== 1'b1*/ >= tCCDl ) && (last_rd_bg_cnt_ps1[i][3] == 1'b1 /*>= tRTW*/) );
    
        assign actual_rd_respect_long_cnstr_ps0[i]   = ( (cmd_cas_ps0 == P_COL_RD)  && (bank_group_cas_ps0 == i ) && ( last_rd_bg_cnt_ps0/*_for_CCDl*/[i] /*== 1'b1*/ >= tCCDl )  && (last_wrt_bg_cnt_ps0[i][3] == 1'b1 /*>= tWTRl*/) );
        assign actual_rd_respect_long_cnstr_ps1[i]   = ( (cmd_cas_ps1 == P_COL_RD)  && (bank_group_cas_ps1 == i ) && ( last_rd_bg_cnt_ps1/*_for_CCDl*/[i] /*== 1'b1*/ >= tCCDl )  && (last_wrt_bg_cnt_ps1[i][3] == 1'b1 /*>= tWTRl*/) );
    
        assign actual_wrt_respect_short_cnstr_ps0[i] = ( (cmd_cas_ps0 == P_COL_WRT) /*&& ( last_wrt_bg_cnt_ps0[i] >= tCCDs )*/ && (last_rd_bg_cnt_ps0[i][3] == 1'b1 /*>= tRTW*/) );
        assign actual_wrt_respect_short_cnstr_ps1[i] = ( (cmd_cas_ps1 == P_COL_WRT) /*&& ( last_wrt_bg_cnt_ps1[i] >= tCCDs )*/ && (last_rd_bg_cnt_ps1[i][3] == 1'b1 /*>= tRTW*/) );
        
        assign actual_rd_respect_short_cnstr_ps0[i]  = ( (cmd_cas_ps0 == P_COL_RD)  /*&& ( last_rd_bg_cnt_ps0[i] >= tCCDs )*/ && (last_wrt_bg_cnt_ps0[i][3] == 1'b1 /*>= tWTRs*/) );
        assign actual_rd_respect_short_cnstr_ps1[i]  = ( (cmd_cas_ps1 == P_COL_RD)  /*&& ( last_rd_bg_cnt_ps1[i] >= tCCDs )*/ && (last_wrt_bg_cnt_ps1[i][3] == 1'b1 /*>= tWTRs*/) );
    
        /********************************************/
        /* RAS TIMING CHECK AND COUNTERS MANAGEMENT */
        /********************************************/
        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin : last_act_bg_cnt_ps0_driver
            if ( dfi_rst_n == 1'b0 ) begin
                last_act_bg_cnt_ps0[i] <= { 5 { 1'b0 } };
            end 
            else begin
//                if (  (r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1) && (r_row_cmd_p0[2:0] == {1'b0, P_ROW_ACT[1:0]}) && (r_row_cmd_p0[9] == LP_BA4_0) && ( ({r_row_cmd_p0[11] ,r_row_cmd_p0[5:3]} >= (i*P_BA_N_G)) && ({r_row_cmd_p0[11] ,r_row_cmd_p0[5:3]} < ((i+1)*P_BA_N_G)) )) begin
                if ( can_serve_actual_act_ps0 && ~double_act_ras_sync && bank_group_ras_ps0 == i  ) begin
                    last_act_bg_cnt_ps0[i] <= { 5 { 1'b0 } };
                end
                else if ( last_act_bg_cnt_ps0[i] ==  3'b101 /*{ 5 {1'b1 }}*/ ) begin
                    last_act_bg_cnt_ps0[i] <= last_act_bg_cnt_ps0[i];
                end
                else begin
                    last_act_bg_cnt_ps0[i] <= last_act_bg_cnt_ps0[i] + 1'b1;
                end
            end
        end
        
        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
            if ( dfi_rst_n == 1'b0 ) begin
                last_act_bg_cnt_ps1[i] <= { 5 { 1'b0 } };
            end 
            else begin
//                if ( (r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1) && ( r_row_cmd_p0[2:0] == {1'b0, P_ROW_ACT[1:0]}) && (r_row_cmd_p0[9] == LP_BA4_1) && ( ( {r_row_cmd_p0[11], r_row_cmd_p0[5:3]} >= (i*P_BA_N_G)) && ({r_row_cmd_p0[11] ,r_row_cmd_p0[5:3]} < ((i+1)*P_BA_N_G)) )) begin
                if ( can_serve_actual_act_ps1 && ~double_act_ras_sync && bank_group_ras_ps1 == i ) begin
                    last_act_bg_cnt_ps1[i] <= { 5 { 1'b0 } };
                end
                else if ( last_act_bg_cnt_ps1[i] == 3'b101/*{ 5 {1'b1 }}*/ ) begin
                    last_act_bg_cnt_ps1[i] <= last_act_bg_cnt_ps1[i];
                end
                else begin
                    last_act_bg_cnt_ps1[i] <= last_act_bg_cnt_ps1[i] + 1'b1;
                end
            end
        end 
        
        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
            if ( dfi_rst_n == 1'b0 ) begin
                last_pre_bg_cnt_ps0[i] <= { 5 { 1'b0 } };
            end 
            else begin
//                if ( (r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1) && ((( r_row_cmd_p0[2:0] == P_ROW_PRE && r_row_cmd_p0[9] == LP_BA4_0 ) && (({r_row_cmd_p0[11], r_row_cmd_p0[5:3]} >= (i*P_BA_N_G)) && ( {r_row_cmd_p0[11], r_row_cmd_p0[5:3]} < ((i+1)*P_BA_N_G)))) || (( r_row_cmd_p1[2:0] == P_ROW_PRE && r_row_cmd_p0[2:0] != {1'b0, P_ROW_ACT[1:0]}  && r_row_cmd_p1[9] == LP_BA4_0 ) && (({r_row_cmd_p1[11], r_row_cmd_p1[5:3]} >= (i*P_BA_N_G)) && ( {r_row_cmd_p1[11], r_row_cmd_p1[5:3]} < ((i+1)*P_BA_N_G)))) ) ) begin
                if ( can_serve_actual_pre_ps0 && ~double_act_ras_sync && bank_group_ras_ps0 == i ) begin
                    last_pre_bg_cnt_ps0[i] <= { 5 { 1'b0 } };
                end
                else if ( last_pre_bg_cnt_ps0[i] == { 5 {1'b1 }} ) begin
                    last_pre_bg_cnt_ps0[i] <= last_pre_bg_cnt_ps0[i];
                end
                else begin
                    last_pre_bg_cnt_ps0[i] <= last_pre_bg_cnt_ps0[i] + 1'b1;
                end
            end
        end
        
        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
            if ( dfi_rst_n == 1'b0 ) begin
                last_pre_bg_cnt_ps1[i] <= { 5 { 1'b0 } };
            end 
            else begin
                if ( can_serve_actual_pre_ps1 && ~double_act_ras_sync && bank_group_ras_ps1 == i  ) begin
                    last_pre_bg_cnt_ps1[i] <= { 5 { 1'b0 } };
                end
                else if ( last_pre_bg_cnt_ps1[i] == { 5 {1'b1 }} ) begin
                    last_pre_bg_cnt_ps1[i] <= last_pre_bg_cnt_ps1[i];
                end
                else begin
                    last_pre_bg_cnt_ps1[i] <= last_pre_bg_cnt_ps1[i] + 1'b1;
                end
            end
        end
        
        
        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
            if ( dfi_rst_n == 1'b0 ) begin
                last_ref_bg_cnt_ps0_for_RREFD[i] <= { 3 { 1'b0 } };
            end 
            else begin
                if ( can_serve_actual_ref_ps0 && ~double_act_ras_sync && bank_group_ras_ps0 == i ) begin
                    last_ref_bg_cnt_ps0_for_RREFD[i] <= { 3 { 1'b0 } };
                end
                else if ( last_ref_bg_cnt_ps0_for_RREFD[i][2] == 1'b1 /*{ 7 {1'b1 }}*/ ) begin
                    last_ref_bg_cnt_ps0_for_RREFD[i] <= last_ref_bg_cnt_ps0_for_RREFD[i];
                end
                else begin
                    last_ref_bg_cnt_ps0_for_RREFD[i] <= last_ref_bg_cnt_ps0_for_RREFD[i] + 1'b1;
                end
            end
        end

        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
            if ( dfi_rst_n == 1'b0 ) begin
                last_ref_bg_cnt_ps0_for_RFCpb[i] <= { 7 { 1'b0 } };
            end 
            else begin
                if ( can_serve_actual_ref_ps0 && ~double_act_ras_sync && bank_group_ras_ps0 == i ) begin
                    last_ref_bg_cnt_ps0_for_RFCpb[i] <= { 7 { 1'b0 } };
                end
                else if ( last_ref_bg_cnt_ps0_for_RFCpb[i][0] == 1'b1 && last_ref_bg_cnt_ps0_for_RFCpb[i][3] == 1'b1 && last_ref_bg_cnt_ps0_for_RFCpb[i][6] == 1'b1/*{ 7 {1'b1 }}*/ ) begin
                    last_ref_bg_cnt_ps0_for_RFCpb[i] <= last_ref_bg_cnt_ps0_for_RFCpb[i];
                end
                else begin
                    last_ref_bg_cnt_ps0_for_RFCpb[i] <= last_ref_bg_cnt_ps0_for_RFCpb[i] + 1'b1;
                end
            end
        end
        
        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
            if ( dfi_rst_n == 1'b0 ) begin
                last_ref_bg_cnt_ps1_for_RREFD[i] <= { 3 { 1'b0 } };
            end 
            else begin
                if ( can_serve_actual_ref_ps1 && ~double_act_ras_sync && bank_group_ras_ps1 == i ) begin
                    last_ref_bg_cnt_ps1_for_RREFD[i] <= { 3 { 1'b0 } };
                end
                else if ( last_ref_bg_cnt_ps1_for_RREFD[i][2] == 1'b1 /*{ 7 {1'b1 }}*/ ) begin
                    last_ref_bg_cnt_ps1_for_RREFD[i] <= last_ref_bg_cnt_ps1_for_RREFD[i];
                end
                else begin
                    last_ref_bg_cnt_ps1_for_RREFD[i] <= last_ref_bg_cnt_ps1_for_RREFD[i] + 1'b1;
                end
            end
        end
        
        always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
            if ( dfi_rst_n == 1'b0 ) begin
                last_ref_bg_cnt_ps1_for_RFCpb[i] <= { 7 { 1'b0 } };
            end 
            else begin
//                if ( (r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1) && ((((r_row_cmd_p0[2:0] == P_ROW_REFPB[2:0]) && (r_row_cmd_p0[9]==LP_BA4_1)) && (( {r_row_cmd_p0[11], r_row_cmd_p0[5:3]} >= (i*P_BA_N_G)) && ({r_row_cmd_p0[11], r_row_cmd_p0[5:3]} < ((i+1)*P_BA_N_G)))) || ((((r_row_cmd_p1[2:0] == P_ROW_REFPB[2:0]) && (r_row_cmd_p0[2:0] != {1'b0, P_ROW_ACT[1:0]}) && (r_row_cmd_p1[9]==LP_BA4_1)) && (( {r_row_cmd_p1[11], r_row_cmd_p1[5:3]} >= (i*P_BA_N_G)) && ({r_row_cmd_p1[11], r_row_cmd_p1[5:3]} < ((i+1)*P_BA_N_G))))) )) begin
                if ( can_serve_actual_ref_ps1 && ~double_act_ras_sync && bank_group_ras_ps1 == i) begin
                    last_ref_bg_cnt_ps1_for_RFCpb[i] <= { 7 { 1'b0 } };
                end
                else if ( last_ref_bg_cnt_ps1_for_RFCpb[i][0] == 1'b1 && last_ref_bg_cnt_ps1_for_RFCpb[i][3] == 1'b1 && last_ref_bg_cnt_ps1_for_RFCpb[i][6] == 1'b1/*{ 7 {1'b1 }}*/ ) begin
                    last_ref_bg_cnt_ps1_for_RFCpb[i] <= last_ref_bg_cnt_ps1_for_RFCpb[i];
                end
                else begin
                    last_ref_bg_cnt_ps1_for_RFCpb[i] <= last_ref_bg_cnt_ps1_for_RFCpb[i] + 1'b1;
                end
            end
        end
        
        assign actual_act_respect_cnstr_ps0[i] = ( /*(cmd_ras_ps0 == P_ROW_ACT) &&*/ ( last_act_bg_cnt_ps0[i][2] == 1'b1 & last_act_bg_cnt_ps0[i][0] == 1'b1 /* >=tRRD-1'b1*/ ) && ( (act_cnt_ps0 < 8'd4) || (four_act_window_cnt_ps0 >= tFAW-1'b1) ) && (last_ref_bg_cnt_ps0_for_RREFD[i][2] == 1'b1 /*>= tRREFD*/) );
        assign actual_act_respect_cnstr_ps1[i] = ( /*(cmd_ras_ps1 == P_ROW_ACT) &&*/ ( last_act_bg_cnt_ps1[i][2] == 1'b1 & last_act_bg_cnt_ps1[i][0] == 1'b1 /*>= tRRD-1'b1*/ ) && ( (act_cnt_ps1 < 8'd4) || (four_act_window_cnt_ps1 >= tFAW-1'b1) ) && (last_ref_bg_cnt_ps1_for_RREFD[i][2] == 1'b1 /*>= tRREFD)*/) );
    
        assign actual_pre_respect_long_cnstr_ps0[i]  = ( /*(cmd_ras_ps0 == P_ROW_PRE)  &&*/ (bank_group_ras_ps0 == i ) /* && ( last_rd_bg_cnt_ps0[i] >= tRTPl )*/  );
        assign actual_pre_respect_long_cnstr_ps1[i]  = ( /*(cmd_ras_ps1 == P_ROW_PRE)  &&*/ (bank_group_ras_ps1 == i ) /* && ( last_rd_bg_cnt_ps1[i] >= tRTPl )*/  );
    
        assign actual_pre_respect_short_cnstr_ps0[i] = ( (cmd_ras_ps0 == P_ROW_PRE)  /* && ( last_rd_bg_cnt_ps0[i] >= tRTPs )*/ );
        assign actual_pre_respect_short_cnstr_ps1[i] = ( (cmd_ras_ps1 == P_ROW_PRE)  /* && ( last_rd_bg_cnt_ps1[i] >= tRTPs )*/ );
         
        assign actual_ref_respect_cnstr_ps0[i] = ( /*(cmd_ras_ps0 == P_ROW_REFPB)  &&*/ ( last_ref_bg_cnt_ps0_for_RREFD[i][2] == 1'b1 /*>= tRREFD*/) && ( (ref_cnt_ps0[4] == 1'b1 /*P_BA_N_PS*/ && last_ref_bg_cnt_ps0_for_RFCpb[i][0] == 1'b1 && last_ref_bg_cnt_ps0_for_RFCpb[i][3] == 1'b1 && last_ref_bg_cnt_ps0_for_RFCpb[i][6] == 1'b1 /*>= tRFCpb*/) || ref_cnt_ps0[4] == 1'b0 /*!= P_BA_N_PS*/ ) && ( last_act_bg_cnt_ps0[i][2] == 1'b1 & last_act_bg_cnt_ps0[i][0] == 1'b1 /*>= tRRD-1'b1*/ ) );
        assign actual_ref_respect_cnstr_ps1[i] = ( /*(cmd_ras_ps1 == P_ROW_REFPB)  &&*/ ( last_ref_bg_cnt_ps1_for_RREFD[i][2] == 1'b1 /*>= tRREFD*/) && ( (ref_cnt_ps1[4] == 1'b1 /*P_BA_N_PS*/ && last_ref_bg_cnt_ps1_for_RFCpb[i][0] == 1'b1 && last_ref_bg_cnt_ps1_for_RFCpb[i][3] == 1'b1 && last_ref_bg_cnt_ps1_for_RFCpb[i][6] == 1'b1 /*>= tRFCpb*/) || ref_cnt_ps1[4] == 1'b0 /*!= P_BA_N_PS*/ ) && ( last_act_bg_cnt_ps1[i][2] == 1'b1 & last_act_bg_cnt_ps1[i][0] == 1'b1 /*>= tRRD-1'b1*/ ) );
    
    end
endgenerate


/******************************/
/* CAN SERVE ACTUAL COMMAND ? */
/******************************/

assign can_serve_actual_act_ps0 = (cmd_ras_ps0 == P_ROW_ACT) && (&actual_act_respect_cnstr_ps0);
assign can_serve_actual_act_ps1 = (cmd_ras_ps1 == P_ROW_ACT) && (&actual_act_respect_cnstr_ps1);
assign can_serve_actual_pre_ps0 = (cmd_ras_ps0 == P_ROW_PRE)  /*&& (|actual_pre_respect_long_cnstr_ps0) && (&actual_pre_respect_short_cnstr_ps0)*/;
assign can_serve_actual_pre_ps1 = (cmd_ras_ps1 == P_ROW_PRE)  /*&& (|actual_pre_respect_long_cnstr_ps1) && (&actual_pre_respect_short_cnstr_ps1)*/;
assign can_serve_actual_ref_ps0 = (cmd_ras_ps0 == P_ROW_REFPB)  && (&actual_ref_respect_cnstr_ps0);
assign can_serve_actual_ref_ps1 = (cmd_ras_ps1 == P_ROW_REFPB)  && (&actual_ref_respect_cnstr_ps1);

assign can_serve_actual_wrt_ps0 = (|actual_wrt_respect_long_cnstr_ps0) && (&actual_wrt_respect_short_cnstr_ps0);
assign can_serve_actual_wrt_ps1 = (|actual_wrt_respect_long_cnstr_ps1) && (&actual_wrt_respect_short_cnstr_ps1);
assign can_serve_actual_rd_ps0  = (|actual_rd_respect_long_cnstr_ps0) && (&actual_rd_respect_short_cnstr_ps0);
assign can_serve_actual_rd_ps1  = (|actual_rd_respect_long_cnstr_ps1) && (&actual_rd_respect_short_cnstr_ps1);

assign can_serve_actual_cas_ps0 = ( can_serve_actual_wrt_ps0  || can_serve_actual_rd_ps0 );
assign can_serve_actual_cas_ps1 = ( can_serve_actual_wrt_ps1 || can_serve_actual_rd_ps1 );

assign can_serve_actual_ras_ps0 = ( can_serve_actual_act_ps0 || can_serve_actual_ref_ps0 || can_serve_actual_pre_ps0 ) && ~double_act_ras_sync;
assign can_serve_actual_ras_ps1 = ( can_serve_actual_act_ps1 || can_serve_actual_ref_ps1 || can_serve_actual_pre_ps1 ) && ~double_act_ras_sync;

endmodule