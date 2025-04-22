`timescale 1ps/1ps

`include "commands.svh"
`include "hbm_controller.svh"
`include "hbm_timing_constraints.svh"

module llcf_cas_constraints_checker (
    input logic clock_i,
    input logic reset_ni,

    input logic [3:0] cmd_cas_ps0,
    input logic [3:0] cmd_cas_ps1,
    
    input logic [1:0] bank_group_cas_ps0,
    input logic [1:0] bank_group_cas_ps1,

    output logic can_serve_actual_cas_ps0,
    output logic can_serve_actual_cas_ps1, 
    output logic can_serve_actual_wrt_ps0,
    output logic can_serve_actual_wrt_ps1,
    output logic can_serve_actual_rd_ps0,
    output logic can_serve_actual_rd_ps1

);

logic [3:0] last_wrt_bg_cnt_ps0 [0 : LP_BG_N - 1];  /*  Last write bank group counter, time elapsed from the last write in a given bank group in PS0  */
logic [3:0] last_rd_bg_cnt_ps0  [0 : LP_BG_N - 1];  /*  Last read bank group counter, time elapsed from the last read in a given bank group in PS0    */       
logic [3:0] last_wrt_bg_cnt_ps1 [0 : LP_BG_N - 1];  /*  Last write bank group counter, time elapsed from the last write in a given bank group in PS1  */
logic [3:0] last_rd_bg_cnt_ps1  [0 : LP_BG_N - 1];  /*  Last read bank group counter, time elapsed from the last read in a given bank group in PS1    */       

/*************************************************************/
/* WIRE TO SAY IF THE ACTUAL CAS COMMAND RESPECT CONSTRAINTS */
/*************************************************************/
logic [0 : LP_BG_N - 1] actual_wrt_respect_short_cnstr_ps0;
logic [0 : LP_BG_N - 1] actual_wrt_respect_long_cnstr_ps0;
logic [0 : LP_BG_N - 1] actual_wrt_respect_short_cnstr_ps1;
logic [0 : LP_BG_N - 1] actual_wrt_respect_long_cnstr_ps1;
logic [0 : LP_BG_N - 1] actual_rd_respect_short_cnstr_ps0;
logic [0 : LP_BG_N - 1] actual_rd_respect_long_cnstr_ps0;
logic [0 : LP_BG_N - 1] actual_rd_respect_short_cnstr_ps1;
logic [0 : LP_BG_N - 1] actual_rd_respect_long_cnstr_ps1;

assign can_serve_actual_wrt_ps0 = (|actual_wrt_respect_long_cnstr_ps0) && (&actual_wrt_respect_short_cnstr_ps0);
assign can_serve_actual_wrt_ps1 = (|actual_wrt_respect_long_cnstr_ps1) && (&actual_wrt_respect_short_cnstr_ps1);
assign can_serve_actual_rd_ps0  = (|actual_rd_respect_long_cnstr_ps0) && (&actual_rd_respect_short_cnstr_ps0);
assign can_serve_actual_rd_ps1  = (|actual_rd_respect_long_cnstr_ps1) && (&actual_rd_respect_short_cnstr_ps1);

assign can_serve_actual_cas_ps0 = ( can_serve_actual_wrt_ps0  || can_serve_actual_rd_ps0 );
assign can_serve_actual_cas_ps1 = ( can_serve_actual_wrt_ps1 || can_serve_actual_rd_ps1 );

genvar i;
generate
    for ( i = 0; i < LP_BG_N; i = i + 1) begin
    
        /********************************************/
        /* CAS TIMING CHECK AND COUNTERS MANAGEMENT */
        /********************************************/
        always @ ( posedge clock_i or negedge reset_ni ) begin : last_wrt_bg_cnt_ps0_driver
            if ( reset_ni == 1'b0 ) begin
                last_wrt_bg_cnt_ps0[i] <= { 4 { 1'b0 } };
            end 
            else begin
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

        always @ (posedge clock_i or negedge reset_ni ) begin : last_wrt_bg_cnt_ps1_driver
            if ( reset_ni == 1'b0 ) begin
                last_wrt_bg_cnt_ps1[i] <= { 4 { 1'b0 } };
            end 
            else begin
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

        always @ (posedge clock_i or negedge reset_ni ) begin : last_rd_bg_cnt_ps0_driver
            if ( reset_ni == 1'b0 ) begin
                last_rd_bg_cnt_ps0[i] <= { 4 { 1'b0 } };
            end 
            else begin
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

        always @ (posedge clock_i or negedge reset_ni ) begin : last_rd_bg_cnt_ps1_driver
            if ( reset_ni == 1'b0 ) begin
                last_rd_bg_cnt_ps1[i] <= { 4 { 1'b0 } };
            end
            else begin
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
        
        assign actual_wrt_respect_long_cnstr_ps0[i]  = ( (cmd_cas_ps0 == P_COL_WRT) && (bank_group_cas_ps0 == i ) && ( last_wrt_bg_cnt_ps0/*_for_CCDl*/[i] /*== 1'b1*/ >= tCCDl ) && (last_rd_bg_cnt_ps0[i][3] == 1'b1 /*>= tRTW*/) );
        assign actual_wrt_respect_long_cnstr_ps1[i]  = ( (cmd_cas_ps1 == P_COL_WRT) && (bank_group_cas_ps1 == i ) && ( last_wrt_bg_cnt_ps1/*_for_CCDl*/[i] /*== 1'b1*/ >= tCCDl ) && (last_rd_bg_cnt_ps1[i][3] == 1'b1 /*>= tRTW*/) );
    
        assign actual_rd_respect_long_cnstr_ps0[i]   = ( (cmd_cas_ps0 == P_COL_RD)  && (bank_group_cas_ps0 == i ) && ( last_rd_bg_cnt_ps0/*_for_CCDl*/[i] /*== 1'b1*/ >= tCCDl )  && (last_wrt_bg_cnt_ps0[i][3] == 1'b1 /*>= tWTRl*/) );
        assign actual_rd_respect_long_cnstr_ps1[i]   = ( (cmd_cas_ps1 == P_COL_RD)  && (bank_group_cas_ps1 == i ) && ( last_rd_bg_cnt_ps1/*_for_CCDl*/[i] /*== 1'b1*/ >= tCCDl )  && (last_wrt_bg_cnt_ps1[i][3] == 1'b1 /*>= tWTRl*/) );
    
        assign actual_wrt_respect_short_cnstr_ps0[i] = ( (cmd_cas_ps0 == P_COL_WRT) /*&& ( last_wrt_bg_cnt_ps0[i] >= tCCDs )*/ && (last_rd_bg_cnt_ps0[i][3] == 1'b1 /*>= tRTW*/) );
        assign actual_wrt_respect_short_cnstr_ps1[i] = ( (cmd_cas_ps1 == P_COL_WRT) /*&& ( last_wrt_bg_cnt_ps1[i] >= tCCDs )*/ && (last_rd_bg_cnt_ps1[i][3] == 1'b1 /*>= tRTW*/) );
        
        assign actual_rd_respect_short_cnstr_ps0[i]  = ( (cmd_cas_ps0 == P_COL_RD)  /*&& ( last_rd_bg_cnt_ps0[i] >= tCCDs )*/ && (last_wrt_bg_cnt_ps0[i][3] == 1'b1 /*>= tWTRs*/) );
        assign actual_rd_respect_short_cnstr_ps1[i]  = ( (cmd_cas_ps1 == P_COL_RD)  /*&& ( last_rd_bg_cnt_ps1[i] >= tCCDs )*/ && (last_wrt_bg_cnt_ps1[i][3] == 1'b1 /*>= tWTRs*/) );
    
    end 
endgenerate

endmodule