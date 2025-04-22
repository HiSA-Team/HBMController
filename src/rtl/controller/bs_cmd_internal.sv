`timescale 1ps/1ps

`include "commands.svh"
`include "hbm_controller.svh"
`include "hbm_timing_constraints.svh"

module bs_cmd_internal #(
    parameter P_BANK_INDEX = 0
) (

    // Input
    input logic clock_i, 
    input logic reset_ni, 

    input logic  [P_REQ_ID_WIDTH-1:0]   req_id_req_to_cmd_translator,
    input logic  [P_CMD_ID_WIDTH-1:0]   cmd_id_req_to_cmd_translator,
    input logic  [3:0]                  cmd_req_to_cmd_translator,
    input logic  [P_ROW_ADDR_WIDTH-1:0] row_addr_req_to_cmd_translator,

    input logic                         need_refresh, 
    input logic  [1:0]                  refresh_present_state, 
    input logic                         need_activate_after_refresh,
    input logic  [P_ROW_ADDR_WIDTH:0]   active_row,

    input logic  [3:0]                  cmd_bank, 
    input logic                         can_serve_actual_cmd, 
    input logic                         cmd_picked_bank,

    // Output 
    output logic [3:0]                  cmd_inter, 
    output logic [P_ROW_ADDR_WIDTH-1:0] row_address_inter,
    output logic [P_REQ_ID_WIDTH-1:0]   req_id_inter,
    output logic [P_CMD_ID_WIDTH-1:0]   cmd_id_inter,
    output logic [31:0]                 ref_occurrences_cnt, 

    output logic                        cmd_picked_req_to_cmd_translator,
    output logic                        busy


);

// TODO - REFACTOR
/* Refresh finite state machine signals, registers and states */
localparam LP_REF_IDLE     = 2'd0;
localparam LP_REF_PRE_WAIT = 2'd1;
localparam LP_REF_REF      = 2'd2;
localparam LP_REF_ACT      = 2'd3;


/************************/
/* CMD_INTER MANAGEMENT */
/************************/
/* Save the data and put the right data in case of refresh */
always @(posedge clock_i or negedge reset_ni) begin
    if ( reset_ni == 1'b0 ) begin
        cmd_inter <= P_GENERAL_NOP;
        row_address_inter <= {P_ROW_ADDR_WIDTH{1'b0}};
        req_id_inter <= {P_REQ_ID_WIDTH{1'b1}};
        cmd_id_inter <= {P_CMD_ID_WIDTH{1'b1}};
        ref_occurrences_cnt <= 32'd0;
    end
    else begin
        /* These cases follow the cases of BUSY MANAGEMENT when fill the cmd_inter */
        if ( cmd_req_to_cmd_translator != P_GENERAL_NOP && cmd_inter == P_GENERAL_NOP && ~need_refresh && busy == 1'b0 ) begin
            cmd_inter <= cmd_req_to_cmd_translator;
            row_address_inter <= row_addr_req_to_cmd_translator;
            req_id_inter <= req_id_req_to_cmd_translator;
            cmd_id_inter <= cmd_id_req_to_cmd_translator;
        end 
        else if ( ~need_refresh && busy == 1'b0 ) begin
            cmd_inter <= cmd_req_to_cmd_translator;        /* Get the next command if the actual one can be served */
            row_address_inter <= row_addr_req_to_cmd_translator;
            req_id_inter <= req_id_req_to_cmd_translator;
            cmd_id_inter <= cmd_id_req_to_cmd_translator;
        end
        else if ( busy == 1'b0 && need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter == P_GENERAL_NOP && active_row != {P_ROW_ADDR_WIDTH+1{1'b1}} ) begin
            cmd_inter <= P_ROW_PRE;
            cmd_id_inter <= 64'd0;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            row_address_inter <= active_row;
        end
        else if ( busy == 1'b0 &&  need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter != P_ROW_PRE && cmd_inter != P_GENERAL_NOP ) begin
            cmd_inter <= P_ROW_PRE;
            cmd_id_inter <= 64'd0;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            row_address_inter <= active_row;
        end

        else if ( busy == 1'b0 &&  need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter == P_GENERAL_NOP && active_row == {P_ROW_ADDR_WIDTH+1{1'b1}} ) begin
            cmd_inter <= P_ROW_REFPB;
            cmd_id_inter <= 64'd1;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            row_address_inter <= active_row;

            ref_occurrences_cnt <= ref_occurrences_cnt + 1'b1;
        end

        else if ( need_refresh && refresh_present_state == LP_REF_PRE_WAIT && busy == 1'b0 && cmd_inter != P_ROW_PRE ) begin
            cmd_inter <= P_ROW_PRE;
            cmd_id_inter <= 64'd0;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            row_address_inter <= active_row;
        end

        else if ( need_refresh && refresh_present_state == LP_REF_PRE_WAIT && busy == 1'b0 && cmd_inter == P_ROW_PRE ) begin
            cmd_inter <= P_ROW_REFPB;
            cmd_id_inter <= 64'd1;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            row_address_inter <= active_row;

            if ( ~need_activate_after_refresh ) begin
                ref_occurrences_cnt <= ref_occurrences_cnt + 1'b1;
            end
        end

        else if ( need_refresh && refresh_present_state == LP_REF_REF && busy == 1'b0 && cmd_req_to_cmd_translator != P_ROW_ACT && need_activate_after_refresh ) begin
            cmd_inter <= P_ROW_ACT;
            cmd_id_inter <= 64'd2;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            row_address_inter <= active_row;

            ref_occurrences_cnt <= ref_occurrences_cnt + 1'b1;
        end

        else if ( need_refresh && refresh_present_state == LP_REF_REF && busy == 1'b0 && cmd_req_to_cmd_translator == P_ROW_ACT ) begin
            cmd_inter <= cmd_req_to_cmd_translator;
             row_address_inter <= row_addr_req_to_cmd_translator;
            req_id_inter <= req_id_req_to_cmd_translator;
            cmd_id_inter <= cmd_id_req_to_cmd_translator;

            if ( need_activate_after_refresh ) begin
                ref_occurrences_cnt <= ref_occurrences_cnt + 1'b1;
            end
        end
    end
end

/*******************************************/
/* COMUNICATION WITH REQ-to-CMD-TRANSLATOR */
/*******************************************/
/* Telling that we want other data (we get the previous) */
always @(posedge clock_i or negedge reset_ni) begin
    if ( reset_ni == 1'b0 ) begin
        cmd_picked_req_to_cmd_translator <= 1'b0;
    end
    else begin
        /* Just to inform that we are ready to get data */
        if ( cmd_req_to_cmd_translator == P_GENERAL_NOP && cmd_inter == P_GENERAL_NOP && ~need_refresh && busy == 1'b0 ) begin     
            cmd_picked_req_to_cmd_translator <= 1'b1;
        end
        /* The cmd_inter is empty and the cmd_req_to_cmd_translator is not NOP, we can get it */
        else if ( busy == 1'b0 && cmd_req_to_cmd_translator != P_GENERAL_NOP && ~need_refresh && cmd_picked_req_to_cmd_translator == 1'b0 ) begin
            cmd_picked_req_to_cmd_translator <= 1'b1;
        end
        /* The refresh procedure is going on, we are in REF state and the req_to_cmd_translator provide us a beautiful ACT, let's get it!!! :) */
        else if  ( need_refresh && refresh_present_state == LP_REF_REF && cmd_req_to_cmd_translator == P_ROW_ACT && busy == 1'b0 && cmd_picked_req_to_cmd_translator == 1'b0 ) begin
            cmd_picked_req_to_cmd_translator <= 1'b1;
        end
        else begin
            cmd_picked_req_to_cmd_translator <= 1'b0;
        end
    end
end


/***********************/
/* REG BUSY MANAGEMENT */
/***********************/
/* Every time cmd_inter is filled busy is set and every time cmd_inter is empty busy is reset */
always @(posedge clock_i or negedge reset_ni) begin
    if ( reset_ni == 1'b0 ) begin
        busy <= 1'b0;
    end
    else begin

        /*************************/
        /* FILLING THE CMD_INTER */
        /*************************/

        /* cmd_req_to_cmd_translator give us a cmd, cmd_inter is empty, we can fill the cmd_inter */
        if ( cmd_req_to_cmd_translator != P_GENERAL_NOP && cmd_inter == P_GENERAL_NOP && ~need_refresh && busy == 1'b0 ) begin
            busy <= 1'b1;
        end
        /* Same case of before, maybe we can delete this... */
        else if (~need_refresh && busy == 1'b0 && cmd_req_to_cmd_translator != P_GENERAL_NOP ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty, we are going to fill it with a REF cmd */
        else if ( busy == 1'b0 && need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter == P_GENERAL_NOP && active_row != {P_ROW_ADDR_WIDTH+1{1'b1}} ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty, but the last cmd_inter was a no PRE cmd, we are going to fill it with a PRE cmd or a REF */
        else if ( busy == 1'b0 && need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter != P_ROW_PRE ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty, but the last cmd_inter was a no PRE cmd, we are going to fill it with a PRE cmd, now we are in wait state, see at FSM */
        else if ( need_refresh && refresh_present_state == LP_REF_PRE_WAIT && busy == 1'b0 && cmd_inter != P_ROW_PRE  ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty and the last cmd_inter was a PRE cmd, we are going to fill it with a REF cmd */
        else if ( need_refresh && refresh_present_state == LP_REF_PRE_WAIT && busy == 1'b0 && cmd_inter == P_ROW_PRE ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty and the cmd_req_to_cmd_translator is a non ACT cmd, we are going to fill it with a ACT cmd */
        else if ( need_refresh && refresh_present_state == LP_REF_REF && busy == 1'b0 && cmd_req_to_cmd_translator != P_ROW_ACT && need_activate_after_refresh ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty and the cmd_req_to_cmd_translator is a ACT cmd, we are going to fill it with the ACT coming from dispatcher */
        else if ( need_refresh && refresh_present_state == LP_REF_REF && busy == 1'b0 && cmd_req_to_cmd_translator == P_ROW_ACT ) begin
            busy <= 1'b1;
        end

        /*************************/
        /* EMPTING THE CMD_INTER */
        /*************************/

        /* The cmd_inter is full and ready and cmd_bank is empty */
        else if ( cmd_bank == P_GENERAL_NOP && can_serve_actual_cmd && busy == 1'b1 ) begin
            busy <= 1'b0;
        end
        /* The cmd_inter is full and ready and cmd_bank is going to be picked by channel scheduler */
        else if ( can_serve_actual_cmd && cmd_bank != P_GENERAL_NOP && cmd_picked_bank && busy == 1'b1  ) begin
            busy <= 1'b0;
        end
    end
end



endmodule 