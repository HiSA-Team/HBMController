`timescale 1ps/1ps

`include "commands.svh"
`include "hbm_controller.svh"
`include "hbm_timing_constraints.svh"

module llcf_init_sequence_driver (
    input logic clock_i,     
    input logic reset_ni,
    input logic dfi_rst_buf_n, 
    input logic dfi_init_complete,

    input logic [3:0] cmd_ras_ps0, 
    input logic [3:0] cmd_ras_ps1, 
    input logic [3:0] cmd_cas_ps0, 
    input logic [3:0] cmd_cas_ps1, 


    output logic       dfi_init_start, 
    output logic [1:0] dfi_aw_cke_p0,
    output logic [1:0] dfi_aw_cke_p1,
    output logic [1:0] dfi_aw_ck_p0, 
    output logic [1:0] dfi_aw_ck_p1, 


    output logic [3:0] r_phy_tg_ps, // Present state TODO refactor
    output logic [7:0] r_mrs_reg_cnt,  // TODO maybe refactor
    output logic reset_hbm_controller

);

localparam P_DRIVE_PRECHARGE_CMD = 114;
localparam P_PRECHG_THR          = 200;
localparam P_ACT_THR	         = 40;
localparam P_WRT_THR	         = 60;
localparam P_RD_THR	             = 60;
localparam P_DRIVE_ACT_CMD       = 240;
localparam P_MRS_CNT             = 8'hc0;

/* STATES */
localparam LP_IDLE			     = 4'd0;
localparam LP_MRS			     = 4'd1;
localparam LP_FETCH			     = 4'd2;
localparam LP_CMD_WAIT           = 4'd3;
localparam LP_CMD_WAIT_1         = 4'd4;

logic [3:0]   r_phy_tg_ns; // Next state

logic         w_fsm_rst_b;
logic         w_mrs_lat_cnt_done;
logic         w_precharge_lat_done;

logic [3:0]   cke_cnt;
logic [11:0]  r_precharge_lat_cnt;
logic         r_precharge_lat_done; 

logic         r_fsm_rst_b;
logic         r_mrs_lat_cnt_done;
logic         r_state_counter_done;
logic [7:0]   r_state_counter;

logic         r_state_chg;
logic [11:0]  r_activate_lat_cnt;
// logic [7:0]   r_mrs_reg_cnt;

assign w_precharge_lat_done = (r_precharge_lat_cnt >= P_DRIVE_PRECHARGE_CMD) ? 1'b1 : 1'b0;

/***************************************************************************/
/* Driving init_start signal after APB initialization sequence is complete */
/***************************************************************************/
always @ (posedge clock_i or negedge reset_ni) begin : dfi_init_start_driver
    if (~reset_ni) begin
        dfi_init_start <= 1'b0;
    end else if (dfi_rst_buf_n == 1'b1) begin
        dfi_init_start <= 1'b1;
    end
end

/******************************************/
/* Counter to wait for driving CKE signal */
/******************************************/
always @ (posedge clock_i or negedge reset_ni) begin : cke_cnt_driver
    if (~reset_ni) begin
        cke_cnt <= 4'h0;
    end else if (dfi_init_complete == 1'b1 && cke_cnt != 4'hf) begin
        cke_cnt <= cke_cnt + 1'b1;
    end
end

always @ (posedge clock_i or negedge reset_ni) begin : dfi_cke_ck_driver
    if (~reset_ni) begin
        dfi_aw_cke_p0 <= 2'b00;
        dfi_aw_cke_p1 <= 2'b00;
        dfi_aw_ck_p0  <= 2'b00;
        dfi_aw_ck_p1  <= 2'b00;
    end else if (cke_cnt == 4'he) begin
        dfi_aw_cke_p0 <= 2'b11;
        dfi_aw_cke_p1 <= 2'b11;
        dfi_aw_ck_p0  <= 2'b01;
        dfi_aw_ck_p1  <= 2'b01;
    end
end


/******************************************************************/
/* Counter to count pre-charge latency before issuing MR commands */
/******************************************************************/
always @ (posedge clock_i or negedge reset_ni) begin
    if (~reset_ni) begin
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
always @ (posedge clock_i or negedge reset_ni) begin
  if (~reset_ni) begin
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
always @ (posedge clock_i or negedge reset_ni) begin
  if (~reset_ni) begin
    r_mrs_reg_cnt <= 8'h00;
  end else if ((r_phy_tg_ps == LP_MRS) && (r_mrs_reg_cnt != P_MRS_CNT)) begin
    r_mrs_reg_cnt <= r_mrs_reg_cnt + 1'b1;
  end
end


assign w_fsm_rst_b = r_precharge_lat_done && dfi_init_complete;

//rst_b pulse generation for PRBS SEED LOAD
always @ ( posedge clock_i or negedge reset_ni )
begin
    if( reset_ni == 1'b0 )
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
always @ ( posedge clock_i or negedge reset_ni )
begin
    if( reset_ni == 1'b0 )
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
always @ ( posedge clock_i or negedge reset_ni )
begin
    if( reset_ni == 1'b0 )
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
            else if ( (cmd_ras_ps0 != P_GENERAL_NOP) || (cmd_ras_ps1 != P_GENERAL_NOP) || (cmd_cas_ps0 != P_GENERAL_NOP) || (cmd_cas_ps0 != P_GENERAL_NOP) )  begin 
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


/***********************************/
/* RESET HBM CONTROLLER MANAGEMENT */
/***********************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        reset_hbm_controller  <= 1'b0;
    end 
    else begin
        if (r_phy_tg_ns == LP_CMD_WAIT) begin
            reset_hbm_controller <= 1'b1;
        end
        else begin
            reset_hbm_controller <= reset_hbm_controller;
        end 
    end 
end


endmodule