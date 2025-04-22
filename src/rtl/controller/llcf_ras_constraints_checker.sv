`timescale 1ps/1ps

`include "commands.svh"
`include "hbm_controller.svh"
`include "hbm_timing_constraints.svh"

module llcf_ras_constraints_checker (
    input logic clock_i,
    input logic reset_ni,

    input logic [3:0] cmd_ras_ps0,
    input logic [3:0] cmd_ras_ps1,

    input logic [1:0] bank_group_ras_ps0,
    input logic [1:0] bank_group_ras_ps1,
    
    input logic double_act_ras_sync, 

    output logic can_serve_actual_ras_ps0,
    output logic can_serve_actual_ras_ps1, 
    output logic can_serve_actual_act_ps0,
    output logic can_serve_actual_act_ps1,
    output logic can_serve_actual_pre_ps0,
    output logic can_serve_actual_pre_ps1,
    output logic can_serve_actual_ref_ps0,
    output logic can_serve_actual_ref_ps1

);


logic [2:0] last_act_bg_cnt_ps0 [0 : LP_BG_N - 1];             /* Last act bank group counter, time elapsed from the last ACT in a given bank group in PS0 */
logic [4:0] last_pre_bg_cnt_ps0 [0 : LP_BG_N - 1];             /* Last pre bank group counter, time elapsed from the last PRE in a given bank group in PS0 */
logic [2:0] last_act_bg_cnt_ps1 [0 : LP_BG_N - 1];             /* Last act bank group counter, time elapsed from the last ACT in a given bank group in PS1 */
logic [4:0] last_pre_bg_cnt_ps1 [0 : LP_BG_N - 1];             /* Last pre bank group counter, time elapsed from the last PRE in a given bank group in PS1 */
logic [2:0] last_ref_bg_cnt_ps0_for_RREFD [0 : LP_BG_N - 1];   /* Last ref bank group counter, time elapsed from the last REF in a given bank group in PS0 to count RREFD */ 
logic [2:0] last_ref_bg_cnt_ps1_for_RREFD [0 : LP_BG_N - 1];   /* Last ref bank group counter, time elapsed from the last REF in a given bank group in PS1 to count RREFD */
logic [6:0] last_ref_bg_cnt_ps0_for_RFCpb [0 : LP_BG_N - 1];   /* Last ref bank group counter, time elapsed from the last REF in a given bank group in PS0 to count RFCpb */ 
logic [6:0] last_ref_bg_cnt_ps1_for_RFCpb [0 : LP_BG_N - 1];   /* Last ref bank group counter, time elapsed from the last REF in a given bank group in PS1 to count RFCpb */

logic [5:0] four_act_window_cnt_ps0;                           /* tFAW counter ps0 */
logic [5:0] four_act_window_cnt_ps1;                           /* tFAW counter ps1 */
logic [2:0] act_cnt_ps0;                                       /* Number of ps0 ACT in a tFAW window */
logic [2:0] act_cnt_ps1;                                       /* Number of ps1 ACT in a tFAW window */
logic [4:0] ref_cnt_ps0;                                       /* Number of ps0 REF in a refresh window */
logic [4:0] ref_cnt_ps1;                                       /* Number of ps0 REF in a refresh window */

/**************************************************************/
/* WIRES TO SAY IF THE ACTUAL RAS COMMAND RESPECT CONSTRAINTS */
/**************************************************************/
logic [0 : LP_BG_N - 1] actual_act_respect_cnstr_ps0;
logic [0 : LP_BG_N - 1] actual_act_respect_cnstr_ps1;
logic [0 : LP_BG_N - 1] actual_pre_respect_short_cnstr_ps0;
logic [0 : LP_BG_N - 1] actual_pre_respect_long_cnstr_ps0;
logic [0 : LP_BG_N - 1] actual_pre_respect_short_cnstr_ps1;
logic [0 : LP_BG_N - 1] actual_pre_respect_long_cnstr_ps1;

logic [0 : LP_BG_N - 1] actual_ref_respect_cnstr_ps0;
logic [0 : LP_BG_N - 1] actual_ref_respect_cnstr_ps1;


assign can_serve_actual_act_ps0 = (cmd_ras_ps0 == P_ROW_ACT) && (&actual_act_respect_cnstr_ps0);
assign can_serve_actual_act_ps1 = (cmd_ras_ps1 == P_ROW_ACT) && (&actual_act_respect_cnstr_ps1);
assign can_serve_actual_pre_ps0 = (cmd_ras_ps0 == P_ROW_PRE)  /*&& (|actual_pre_respect_long_cnstr_ps0) && (&actual_pre_respect_short_cnstr_ps0)*/;
assign can_serve_actual_pre_ps1 = (cmd_ras_ps1 == P_ROW_PRE)  /*&& (|actual_pre_respect_long_cnstr_ps1) && (&actual_pre_respect_short_cnstr_ps1)*/;
assign can_serve_actual_ref_ps0 = (cmd_ras_ps0 == P_ROW_REFPB)  && (&actual_ref_respect_cnstr_ps0);
assign can_serve_actual_ref_ps1 = (cmd_ras_ps1 == P_ROW_REFPB)  && (&actual_ref_respect_cnstr_ps1);

assign can_serve_actual_ras_ps0 = ( can_serve_actual_act_ps0 || can_serve_actual_ref_ps0 || can_serve_actual_pre_ps0 ) && ~double_act_ras_sync;
assign can_serve_actual_ras_ps1 = ( can_serve_actual_act_ps1 || can_serve_actual_ref_ps1 || can_serve_actual_pre_ps1 ) && ~double_act_ras_sync;

/***********************************************/
/* ACT COUNTS PS0 iN A tFAW WINDOWS MANAGEMENT */
/***********************************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        act_cnt_ps0 <= { 3 { 1'b0 } };
    end
    else begin
        if (( four_act_window_cnt_ps0 >= tFAW-1'b1) && ~( can_serve_actual_act_ps0 && ~double_act_ras_sync)) begin
            act_cnt_ps0 <= 1'b0;
        end
        else if ( ( four_act_window_cnt_ps0 >= tFAW-1'b1) && ( can_serve_actual_act_ps0 && ~double_act_ras_sync)) begin
            act_cnt_ps0 <= 1'b1;
        end
        else if ( act_cnt_ps0 >= 4'd4 ) begin
            act_cnt_ps0 <= act_cnt_ps0;
        end
        else if (  can_serve_actual_act_ps0 && ~double_act_ras_sync ) begin
            act_cnt_ps0 <= act_cnt_ps0 + 1'b1;
        end
    end
end

/***********************************************/
/* ACT COUNTS PS1 iN A tFAW WINDOWS MANAGEMENT */
/***********************************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        act_cnt_ps1 <= { 3 { 1'b0 } };
    end
    else begin
        if (( four_act_window_cnt_ps1 >= tFAW-1'b1) && ~(can_serve_actual_act_ps1 && ~double_act_ras_sync) ) begin
            act_cnt_ps1 <= 1'b0;
        end
        else if ( ( four_act_window_cnt_ps1 >= tFAW-1'b1) && (can_serve_actual_act_ps1 && ~double_act_ras_sync) ) begin
            act_cnt_ps1 <= 1'b1;
        end
        else if ( act_cnt_ps1 >= 4'd4 ) begin
            act_cnt_ps1 <= act_cnt_ps1;
        end
        else if (can_serve_actual_act_ps1 && ~double_act_ras_sync) begin
            act_cnt_ps1 <= act_cnt_ps1 + 1'b1;
        end
    end
end


/*******************/
/* PS0 tFAW UPDATE */
/*******************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        four_act_window_cnt_ps0 <= { 6 { 1'b0 } };
    end
    else begin
        if ( can_serve_actual_act_ps0 && ~double_act_ras_sync && ( four_act_window_cnt_ps0 >= tFAW-1'b1) ) begin
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
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        four_act_window_cnt_ps1 <= { 6 { 1'b0 } };
    end
    else begin
        if ( can_serve_actual_act_ps1 && ~double_act_ras_sync && ( four_act_window_cnt_ps1 >= tFAW-1'b1) ) begin
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
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        ref_cnt_ps0 <= { 5 { 1'b0 } };
    end
    else begin
        /* A ps0 REF is served */
        if ( can_serve_actual_ref_ps0 && ~double_act_ras_sync ) begin
            /* The last REF is the last of a refresh window, reset the counter */
            if ( ref_cnt_ps0[4] == 1'b1 /*P_BA_N_PS*/ ) begin
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
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        ref_cnt_ps1 <= { 5 { 1'b0 } };
    end
    else begin
        /* A ps1 REF is served */
        /* The last REF is the last of a refresh window, reset the counter */
        if ( can_serve_actual_ref_ps1 && ~double_act_ras_sync ) begin
            if ( ref_cnt_ps1[4] == 1'b1 /*P_BA_N_PS*/ ) begin
                ref_cnt_ps1 <= 5'b00001;
            end
            else begin
                ref_cnt_ps1 <= ref_cnt_ps1 + 1'b1;
            end
        end
    end
end

genvar i; 
generate
    for ( i = 0; i < LP_BG_N; i = i + 1) begin

        /********************************************/
        /* RAS TIMING CHECK AND COUNTERS MANAGEMENT */
        /********************************************/
        always @ ( posedge clock_i or negedge reset_ni ) begin : last_act_bg_cnt_ps0_driver
            if ( reset_ni == 1'b0 ) begin
                last_act_bg_cnt_ps0[i] <= { 5 { 1'b0 } };
            end 
            else begin
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
        
        always @ ( posedge clock_i or negedge reset_ni ) begin
            if ( reset_ni == 1'b0 ) begin
                last_act_bg_cnt_ps1[i] <= { 5 { 1'b0 } };
            end 
            else begin
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
        
        always @ ( posedge clock_i or negedge reset_ni ) begin
            if ( reset_ni == 1'b0 ) begin
                last_pre_bg_cnt_ps0[i] <= { 5 { 1'b0 } };
            end 
            else begin
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
        
        always @ ( posedge clock_i or negedge reset_ni ) begin
            if ( reset_ni == 1'b0 ) begin
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
        
        
        always @ ( posedge clock_i or negedge reset_ni ) begin
            if ( reset_ni == 1'b0 ) begin
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

        always @ ( posedge clock_i or negedge reset_ni ) begin
            if ( reset_ni == 1'b0 ) begin
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
        
        always @ ( posedge clock_i or negedge reset_ni ) begin
            if ( reset_ni == 1'b0 ) begin
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
        
        always @ ( posedge clock_i or negedge reset_ni ) begin
            if ( reset_ni == 1'b0 ) begin
                last_ref_bg_cnt_ps1_for_RFCpb[i] <= { 7 { 1'b0 } };
            end 
            else begin
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

    
endmodule