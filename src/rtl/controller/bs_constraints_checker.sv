
`timescale 1ps/1ps

`include "commands.svh"
`include "hbm_controller.svh"
`include "hbm_timing_constraints.svh"

module bs_constraints_checker (
    // Input 
    input logic clock_i, 
    input logic reset_ni, 

    input logic [3:0] cmd_inter, 
    input logic need_refresh, 

    input  logic   served_ras,
    input  logic   served_cas, 

    input  logic   cmd_picked_bank, 
    input  logic   busy,
    input  logic [3:0] cmd_bank,

    output logic [11:0] last_ref_cnt_for_need_refresh,

    // Output
    output logic [1:0]  waiting_for_ref_serve, // TODO - REFACTOR
    output logic can_serve_actual_cmd,
    output logic can_serve_actual_act,
    output logic can_serve_actual_pre,
    output logic can_serve_actual_ref,
    output logic can_serve_actual_rd,
    output logic can_serve_actual_wrt 

);

/* Counters registers */
logic [6:0]  last_ref_cnt;
logic [5:0]  last_act_cnt;
logic [3:0]  last_pre_cnt;
logic [4:0]  last_wrt_cnt;
logic [2:0]  last_rd_cnt;

/* Waiting registers, need to wait that a CMD is served by LLCF */
logic [1:0]  waiting_for_rd_serve;
logic [1:0]  waiting_for_wrt_serve;
logic [1:0]  waiting_for_act_serve;
logic [1:0]  waiting_for_pre_serve;
// logic [1:0]  waiting_for_ref_serve; TODO -REFACTOR

logic [3:0]  previous_cmd;  /* Previous executed command */

/* Can serve actual command combinatorial logic */
assign can_serve_actual_act = (cmd_inter == P_ROW_ACT) && (last_pre_cnt[3:1] == 3'b111 /*last_pre_cnt >= tRP*/) && (last_act_cnt >= tRC) && (last_ref_cnt == tRFCpb/*>= tRFCpb*/) && ( (previous_cmd == P_ROW_PRE && waiting_for_pre_serve == 2'b00) || (previous_cmd == P_ROW_REFPB && waiting_for_ref_serve == 2'b00) );  
assign can_serve_actual_pre = (cmd_inter == P_ROW_PRE) && (last_act_cnt >= tRAS) && (last_rd_cnt[2:1] == 2'b11/*last_rd_cnt  >= tRTPl*/) && (last_wrt_cnt[4] == 1'b1 && last_wrt_cnt[2:1] == 2'b11/*last_wrt_cnt >= (tWL + tWR + tBURST)*/) && ( (previous_cmd == P_COL_RD && waiting_for_rd_serve == 2'b00) || ( previous_cmd == P_COL_WRT && waiting_for_wrt_serve == 2'b00 ) || (previous_cmd == P_ROW_ACT && waiting_for_act_serve == 2'b00) || (previous_cmd == P_ROW_REFPB) );
assign can_serve_actual_ref = (cmd_inter == P_ROW_REFPB) && (last_pre_cnt[3:1] == 3'b111 /*last_pre_cnt >= tRP*/) && (last_act_cnt >= tRC) && (last_ref_cnt == tRFCpb/*>= tRFCpb*/) && (( previous_cmd == P_ROW_PRE && waiting_for_pre_serve == 2'b00 ) || (previous_cmd != P_ROW_PRE) );
assign can_serve_actual_rd  = (cmd_inter == P_COL_RD) && (last_act_cnt >= tRCD) && ((previous_cmd == P_ROW_ACT && waiting_for_act_serve == 2'b00 ) || ( previous_cmd == P_COL_WRT && waiting_for_wrt_serve == 2'b00 ) || (previous_cmd == P_COL_RD && waiting_for_rd_serve == 2'b00 ));
assign can_serve_actual_wrt = (cmd_inter == P_COL_WRT) && (last_act_cnt >= tRCD ) && ((previous_cmd == P_ROW_ACT && waiting_for_act_serve == 2'b00 ) || ( previous_cmd == P_COL_WRT && waiting_for_wrt_serve == 2'b00 ) || (previous_cmd == P_COL_RD && waiting_for_rd_serve == 2'b00 ));
assign can_serve_actual_cmd = (can_serve_actual_act | can_serve_actual_pre | can_serve_actual_ref | can_serve_actual_rd | can_serve_actual_wrt) && busy == 1'b1;

/***********************/
/* PREVIOUS CMD UPDATE */
/***********************/
always @(posedge clock_i or negedge reset_ni) begin
    if ( reset_ni == 1'b0 ) begin
        // previous_cmd <= P_GENERAL_NOP;
        previous_cmd <= P_COL_RD;
    end
    else begin
        if ( cmd_bank != P_GENERAL_NOP /*&& cmd_picked_bank*/ ) begin
            previous_cmd <= cmd_bank;
        end
        else begin
            previous_cmd <= previous_cmd;
        end
    end
end

/***********************/
/* COUNTERS MANAGEMENT */
/***********************/

/*******************/
/* REFRESH COUNTER */
/*******************/

/* Last REFRESH counter for need_refresh driver */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        last_ref_cnt_for_need_refresh <= { 12 { 1'b0 } };
    end
    else begin
        /* Reset when need_refresh is set */
        if ( last_ref_cnt_for_need_refresh == /*>=*/ tREFP && need_refresh == 1'b1 ) begin
            last_ref_cnt_for_need_refresh <= { 12 { 1'b0 } };
        end
        else if (last_ref_cnt_for_need_refresh == tREFP /*{12{1'b1}}*/) begin
            last_ref_cnt_for_need_refresh <= last_ref_cnt_for_need_refresh;
        end
        else begin
            last_ref_cnt_for_need_refresh <= last_ref_cnt_for_need_refresh + 1'b1;
        end
    end
end

/* Last REFRESH counter driver */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        last_ref_cnt <= { 7 { 1'b0 } };
    end
    else begin
        if ( waiting_for_ref_serve == 2'b10 && served_ras ) begin
            last_ref_cnt <= { 7 { 1'b0 } };
        end
        else if (last_ref_cnt == tRFCpb /*{ 7 { 1'b1 } }*/) begin
            last_ref_cnt <= last_ref_cnt;
        end
        else begin
            last_ref_cnt <= last_ref_cnt + 1'b1;
        end
    end
end
/* Waiting for REF serve management */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        waiting_for_ref_serve <=  2'b00;
    end
    else begin
        if (cmd_bank == P_ROW_REFPB && waiting_for_ref_serve == 2'b00 && ~cmd_picked_bank) begin
            waiting_for_ref_serve <= 2'b01;
        end
        else if (cmd_bank == P_ROW_REFPB && waiting_for_ref_serve == 2'b00 && cmd_picked_bank) begin
            waiting_for_ref_serve <= 2'b10;
        end
        else if ( cmd_picked_bank && (cmd_bank == P_ROW_REFPB) && waiting_for_ref_serve == 2'b01 ) begin
            waiting_for_ref_serve <= 2'b10;
        end
        else if (waiting_for_ref_serve == 2'b10 && served_ras) begin
            waiting_for_ref_serve <=  2'b00;
        end
        else begin
            waiting_for_ref_serve <= waiting_for_ref_serve;
        end
    end
end

/********************/
/* ACTIVATE COUNTER */
/********************/
/* Last ACTIVATE counter driver */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        last_act_cnt <= { 6 { 1'b0 } };
    end
    else begin
        if ( waiting_for_act_serve == 2'b10 && served_ras ) begin
            last_act_cnt <= { 6 { 1'b0 } };
        end
        else if (last_act_cnt == {6{1'b1}}) begin
            last_act_cnt <= last_act_cnt;
        end
        else begin
            last_act_cnt <= last_act_cnt + 1'b1;
        end
    end
end
/* Waiting for ACT serve management */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        waiting_for_act_serve <=  2'b00;
    end
    else begin
        if (cmd_bank == P_ROW_ACT && waiting_for_act_serve == 2'b00 && ~cmd_picked_bank) begin
            waiting_for_act_serve <= 2'b01;
        end
        else if (cmd_bank == P_ROW_ACT && waiting_for_act_serve == 2'b00 && cmd_picked_bank) begin
            waiting_for_act_serve <= 2'b10;
        end
        else if ( cmd_picked_bank && (cmd_bank == P_ROW_ACT) && waiting_for_act_serve == 2'b01 ) begin
            waiting_for_act_serve <= 2'b10;
        end
        else if (waiting_for_act_serve == 2'b10 && served_ras) begin
            waiting_for_act_serve <=  2'b00;
        end
        else begin
            waiting_for_act_serve <= waiting_for_act_serve;
        end
    end
end

/*********************/
/* PRECHARGE COUNTER */
/*********************/
/* Last PRECHARGE counter driver */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        last_pre_cnt <= { 4 { 1'b0 } };
    end
    else begin
        if ( waiting_for_pre_serve == 2'b10 && served_ras ) begin
            last_pre_cnt <= { 4 { 1'b0 } };
        end
        else if (last_pre_cnt[3:1] == 3'b111/*{6{1'b1}}*/) begin
            last_pre_cnt <= last_pre_cnt;
        end
        else begin
            last_pre_cnt <= last_pre_cnt + 1'b1;
        end
    end
end
/* Waiting for PRE serve management */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        waiting_for_pre_serve <=  2'b00;
    end
    else begin
        if (cmd_bank == P_ROW_PRE && waiting_for_pre_serve == 2'b00 && ~cmd_picked_bank) begin
            waiting_for_pre_serve <= 2'b01;
        end
        else if (cmd_bank == P_ROW_PRE && waiting_for_pre_serve == 2'b00 && cmd_picked_bank) begin
            waiting_for_pre_serve <= 2'b10;
        end
        else if ( cmd_picked_bank && (cmd_bank == P_ROW_PRE) && waiting_for_pre_serve == 2'b01 ) begin
            waiting_for_pre_serve <= 2'b10;
        end
        else if (waiting_for_pre_serve == 2'b10 && served_ras) begin
            waiting_for_pre_serve <=  2'b00;
        end
        else begin
            waiting_for_pre_serve <= waiting_for_pre_serve;
        end
    end
end

/****************/
/* READ COUNTER */
/****************/
/* Last READ counter driver */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        last_rd_cnt <= { 3 { 1'b0 } };
    end
    else begin
        if ( waiting_for_rd_serve == 2'b10 && served_cas ) begin
            last_rd_cnt <= { 3 { 1'b0 } };
        end
        else if (last_rd_cnt[2:1] == 2'b11/*== {3{1'b1}}*/) begin
            last_rd_cnt <= last_rd_cnt;
        end
        else begin
            last_rd_cnt <= last_rd_cnt + 1'b1;
        end
    end
end
/* Waiting for RD serve management */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        waiting_for_rd_serve <=  2'b00;
    end
    else begin
        if (cmd_bank == P_COL_RD && waiting_for_rd_serve == 2'b00 && ~cmd_picked_bank) begin
            waiting_for_rd_serve <= 2'b01;
        end
        else if (cmd_bank == P_COL_RD && waiting_for_rd_serve == 2'b00 && cmd_picked_bank) begin
            waiting_for_rd_serve <= 2'b10;
        end
        else if ( cmd_picked_bank && (cmd_bank == P_COL_RD) && waiting_for_rd_serve == 2'b01 ) begin
            waiting_for_rd_serve <= 2'b10;
        end
        else if (waiting_for_rd_serve == 2'b10 && served_cas) begin
            waiting_for_rd_serve <=  2'b00;
        end
        else begin
            waiting_for_rd_serve <= waiting_for_rd_serve;
        end
    end
end

/*****************/
/* WRITE COUNTER */
/*****************/
/* Last WRITE counter driver */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        last_wrt_cnt <= { 5 { 1'b0 } };
    end
    else begin
        if ( waiting_for_wrt_serve == 2'b10 && served_cas ) begin
            last_wrt_cnt <= { 5 { 1'b0 } };
        end
        else if (last_wrt_cnt[4] == 1'b1 && last_wrt_cnt[2:1] == 2'b11 /*== {5{1'b1}}*/) begin
            last_wrt_cnt <= last_wrt_cnt;
        end
        else begin
            last_wrt_cnt <= last_wrt_cnt + 1'b1;
        end
    end
end
/* Waiting for WRT serve management */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if (reset_ni == 1'b0) begin
        waiting_for_wrt_serve <=  2'b00;
    end
    else begin
        if (cmd_bank == P_COL_WRT && waiting_for_wrt_serve == 2'b00 && ~cmd_picked_bank) begin
            waiting_for_wrt_serve <= 2'b01;
        end
        else if (cmd_bank == P_COL_WRT && waiting_for_wrt_serve == 2'b00 && cmd_picked_bank) begin
            waiting_for_wrt_serve <= 2'b10;
        end
        else if ( cmd_picked_bank && (cmd_bank == P_COL_WRT) && waiting_for_wrt_serve == 2'b01 ) begin
            waiting_for_wrt_serve <= 2'b10;
        end
        else if (waiting_for_wrt_serve == 2'b10 && served_cas) begin
            waiting_for_wrt_serve <=  2'b00;
        end
        else begin
            waiting_for_wrt_serve <= waiting_for_wrt_serve;
        end
    end
end



endmodule