`timescale 1ps/1ps

`include "commands.svh"
`include "hbm_controller.svh"

module llcf_cas_cmd_driver (

    input logic clock_i,
    input logic reset_ni,

    input logic [3:0] r_phy_tg_ps, 
    input logic [7:0] r_mrs_reg_cnt, 

    input logic can_serve_actual_cas_ps0, 
    input logic can_serve_actual_cas_ps1,
    input logic can_serve_actual_wrt_ps0, 
    input logic can_serve_actual_wrt_ps1,
    input logic can_serve_actual_rd_ps0, 
    input logic can_serve_actual_rd_ps1,

    input logic [3:0]                  cmd_cas_ps0,
    input logic [P_BA_ADDR_WIDTH-1:0]  bank_address_cas_ps0, 
    input logic [P_COL_ADDR_WIDTH-1:0] column_address_cas_ps0,

    input logic [3:0]                  cmd_cas_ps1,
    input logic [P_BA_ADDR_WIDTH-1:0]  bank_address_cas_ps1, 
    input logic [P_COL_ADDR_WIDTH-1:0] column_address_cas_ps1,

    `ifdef DEBUG
        input logic [P_REQ_ID_WIDTH-1:0] req_cas_id_ps0, 
        input logic [P_CMD_ID_WIDTH-1:0] cmd_cas_id_ps0,
        input logic [P_REQ_ID_WIDTH-1:0] req_cas_id_ps1, 
        input logic [P_CMD_ID_WIDTH-1:0] cmd_cas_id_ps1,
    `endif

    output logic [(P_BA_N_PS*2)-1:0]     served_cas, 
    output logic [15:0]                  dfi_aw_col_p0,
    output logic [15:0]                  dfi_aw_col_p1

);

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

localparam LP_T_WL   = 1;

// MRS
logic [2:0]   w_T_WL_MRS2;
logic [4:0]   w_T_RL_MRS2;


assign w_T_WL_MRS2 = LP_T_WL + 5;
assign w_T_RL_MRS2 = 5'b1_0010;


/***********************/
/* SEND COMMAND TO HBM */
/***********************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin
        dfi_aw_col_p0    <= 16'hffff;
        dfi_aw_col_p1    <= 16'hffff;
        served_cas       <= { (P_BA_N_PS*2) {1'b0} };      
    end
    
    // Mode registers configuration
    else if( r_phy_tg_ps == LP_MRS ) begin
          case ( r_mrs_reg_cnt )
            8'h00: begin
                dfi_aw_col_p0 <= 16'h0000; //MR-0
                dfi_aw_col_p1 <= 16'hffff;
            end
            8'h10: begin
                dfi_aw_col_p0 <= 16'hffff;
                //dfi_aw_col_p1 <= 16'hea10; //MR-1
                dfi_aw_col_p1 <= 16'ha010; //MR-1
            end
            8'h20: begin
                //dfi_aw_col_p0 <= 16'h2e28; //w_T_WL_MRS2 MR-2
                dfi_aw_col_p0 <= {w_T_RL_MRS2[3:0], w_T_WL_MRS2[2], LP_PAR, w_T_WL_MRS2[1:0], LP_MRS2_A, w_T_RL_MRS2[4],LP_MRS_CMD}; //MR-2
                dfi_aw_col_p1 <= 16'hffff;
            end
            8'h30: begin
                dfi_aw_col_p0 <= 16'hffff;
                //dfi_aw_col_p1 <= 16'h4138; //MR-3
                dfi_aw_col_p1 <= 16'hc138; //MR-3
            end
            8'h40: begin
                //dfi_aw_col_p0 <= 16'h1c40; //MR-4
                dfi_aw_col_p0 <= 16'h0440; //MR-4
                dfi_aw_col_p1 <= 16'hffff;
            end
            8'h50: begin
                dfi_aw_col_p0 <= 16'hffff;
                dfi_aw_col_p1 <= 16'h0050; //MR-5
            end
            8'h60: begin
                dfi_aw_col_p0 <= 16'hc060; //MR-6
                dfi_aw_col_p1 <= 16'hffff;
            end
            8'h70: begin
                dfi_aw_col_p0 <= 16'hffff;
                dfi_aw_col_p1 <= 16'h0270; //MR-7
            end
            8'h80: begin
                dfi_aw_col_p0 <= 16'h00f0;
                dfi_aw_col_p1 <= 16'hffff; //MR-7
            end
            default : begin
                dfi_aw_col_p0 <= 16'hffff;
                dfi_aw_col_p1 <= 16'hffff;
            end
        endcase
    end

    else begin
        if ( (can_serve_actual_wrt_ps0 ) && ( cmd_cas_ps1 == P_GENERAL_NOP || ~can_serve_actual_cas_ps1 )  ) begin
            
            dfi_aw_col_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_WRT[3:0]}; 
            dfi_aw_col_p1        <= 16'hffff;
            served_cas           <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]});

            `ifdef DEBUG
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
            `endif
        end 
                    
        else if ((can_serve_actual_wrt_ps0 ) && ( can_serve_actual_wrt_ps1 ) ) begin
            
            dfi_aw_col_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_WRT[3:0]}; 
            dfi_aw_col_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_WRT[3:0]}; 
            served_cas           <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]}); 

            `ifdef DEBUG
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
            `endif
        end
        
        else if ((can_serve_actual_wrt_ps0 ) && ( can_serve_actual_rd_ps1 ) ) begin
            
            dfi_aw_col_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_WRT[3:0]}; 
            dfi_aw_col_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_RD};
            served_cas           <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]}); 

            `ifdef DEBUG
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
            `endif
        end
        
        else if ( (can_serve_actual_rd_ps0 ) && ( cmd_cas_ps1 == P_GENERAL_NOP || ~can_serve_actual_cas_ps1 )  ) begin
            
            dfi_aw_col_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_RD}; 
            dfi_aw_col_p1        <= 16'hffff;                
            served_cas           <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]}); 
            
            `ifdef DEBUG
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
            `endif
        end 
                    
        else if ((can_serve_actual_rd_ps0 ) && ( can_serve_actual_wrt_ps1 ) ) begin
            
            dfi_aw_col_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_RD}; 
            dfi_aw_col_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_WRT[3:0]}; 
            served_cas           <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]}); 

            `ifdef DEBUG            
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
            `endif
        end
        
        else if ((can_serve_actual_rd_ps0 ) && ( can_serve_actual_rd_ps1 ) ) begin
            
            dfi_aw_col_p0        <= { LP_BA4_0, column_address_cas_ps0[5:2], LP_PAR, column_address_cas_ps0[1], 1'b0, bank_address_cas_ps0[3:0], P_COL_RD}; 
            dfi_aw_col_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_RD};
            served_cas           <= (1'b1 << {LP_BA4_0, bank_address_cas_ps0[3:0]}) + (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]}); 

            `ifdef DEBUG
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps0, cmd_cas_id_ps0, cmd_cas_ps0, $time);
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
            `endif
        end
        
        else if ( (can_serve_actual_wrt_ps1 ) && ( cmd_cas_ps0 == P_GENERAL_NOP || ~can_serve_actual_cas_ps0 )  ) begin
            
            dfi_aw_col_p0        <= 16'hffff;
            dfi_aw_col_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_WRT[3:0]}; 
            served_cas           <= (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]});
            
            `ifdef DEBUG
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
            `endif
        end 
        
        else if ( (can_serve_actual_rd_ps1 ) && ( cmd_cas_ps0 == P_GENERAL_NOP || ~can_serve_actual_cas_ps0 )  ) begin
            
            dfi_aw_col_p0        <= 16'hffff;
            dfi_aw_col_p1        <= { LP_BA4_1, column_address_cas_ps1[5:2], LP_PAR, column_address_cas_ps1[1], 1'b0, bank_address_cas_ps1[3:0], P_COL_RD};
            served_cas           <= (1'b1 << {LP_BA4_1, bank_address_cas_ps1[3:0]});
            
            `ifdef DEBUG
                $display("[ LLCF ]: REQ: %d - CMD: %d (%d) served at %d",  req_cas_id_ps1, cmd_cas_id_ps1, cmd_cas_ps1, $time);
            `endif
        end
        else begin
            dfi_aw_col_p0    <= 16'hffff;
            dfi_aw_col_p1    <= 16'hffff;
            served_cas       <= { (P_BA_N_PS*2) {1'b0} };
        end
    end
end

endmodule