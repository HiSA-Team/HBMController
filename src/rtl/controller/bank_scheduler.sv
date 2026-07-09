`timescale 1ps/1ps

`include "commands.svh"
`include "hbm_controller.svh"
`include "hbm_timing_constraints.svh"

module bank_scheduler # 
(
    parameter P_BANK_INDEX = 0
) (
    input logic   clock_i,
    input logic   reset_ni,

    /* Interface to the REQ-to-CMD-Translator */
    input logic [P_REQ_ID_WIDTH-1:0]        req_id_req_to_cmd_translator,
    input logic [P_CMD_ID_WIDTH-1:0]        cmd_id_req_to_cmd_translator,
    input logic [3:0]                       cmd_req_to_cmd_translator,
    input logic [P_ROW_ADDR_WIDTH-1 : 0]    row_addr_req_to_cmd_translator,

    output logic                            cmd_picked_req_to_cmd_translator,

    /* Interface to channel_scheduler */
    input  logic                             cmd_picked_bank,
    output logic  [3:0]                      cmd_bank,
    output logic  [P_ROW_ADDR_WIDTH-1 : 0]   row_address_bank,
    output logic  [P_REQ_ID_WIDTH-1:0]       req_id_bank,
    output logic  [P_CMD_ID_WIDTH-1:0]       cmd_id_bank,           
    
    input  logic   served_ras,
    input  logic   served_cas

);


/**********************************/
/* BANK SCHEDULER HIGH LEVEL VIEW */ 
/**********************************/

/*************************************************************************/
/*    ____________                                        ___________    */
/*   |            |      _________       __________      |           |   */
/*   |    CMD     |     |         |     |          |     |  CHANNEL  |   */
/*   | DISPATCHER |---->|cmd_inter|---->| cmd_bank |---->| SCHEDULER |   */
/*   |____________|     |_________|     |__________|     |___________|   */
/*                            |               |                          */
/*            ___________     |               |                          */
/*           |           |    |               |                          */
/*           |  REFRESH  |    |               |                          */
/*           | PROCEDURE |--->/       can_serve_actual_cmd               */
/*           |    FSM    |                                               */
/*           |___________|                                               */
/*                                                                       */
/*************************************************************************/


/* These registers serves to store the command data coming from Command Dispatcher */
logic  [3:0] cmd_inter;
logic  [P_ROW_ADDR_WIDTH-1 : 0]        row_address_inter;
logic  [P_REQ_ID_WIDTH-1:0]            req_id_inter;
logic  [P_CMD_ID_WIDTH-1:0]            cmd_id_inter; 


logic [11:0] last_ref_cnt_for_need_refresh;


/* These signals tell us if the command in cmd_inter_dispatcher stisfy timing constraints */
logic can_serve_actual_cmd;
logic can_serve_actual_act;
logic can_serve_actual_pre;
logic can_serve_actual_ref;
logic can_serve_actual_rd;
logic can_serve_actual_wrt;

reg [P_ROW_ADDR_WIDTH:0] active_row; /* Actual row open, unfortunatly we need it here :( */

/* Refresh finite state machine signals, registers and states */
localparam LP_REF_IDLE     = 2'd0;
localparam LP_REF_PRE_WAIT = 2'd1;
localparam LP_REF_REF      = 2'd2;
localparam LP_REF_ACT      = 2'd3;

reg [1:0] refresh_present_state;
reg [1:0] refresh_next_state;

reg need_refresh;
reg [31:0] ref_occurrences_cnt; /* Counter just to give some id to refresh generated commands */

reg need_activate_after_refresh;

reg busy;

logic [1:0]  waiting_for_ref_serve;

bs_constraints_checker bs_constraints_checker_u (
    // Input 
    .clock_i      ( clock_i   ), 
    .reset_ni     ( reset_ni  ), 

    .cmd_inter    ( cmd_inter ), 
    .need_refresh ( need_refresh ), 

    .served_ras   ( served_ras ),
    .served_cas   ( served_cas ), 

    .cmd_picked_bank (cmd_picked_bank), 
    
    .busy(busy),
    .cmd_bank(cmd_bank),

    .last_ref_cnt_for_need_refresh(last_ref_cnt_for_need_refresh),

    // Output
    .waiting_for_ref_serve (waiting_for_ref_serve),
    .can_serve_actual_cmd (can_serve_actual_cmd),
    .can_serve_actual_act (can_serve_actual_act),
    .can_serve_actual_pre (can_serve_actual_pre),
    .can_serve_actual_ref (can_serve_actual_ref),
    .can_serve_actual_rd  (can_serve_actual_rd),
    .can_serve_actual_wrt (can_serve_actual_wrt)
);

bs_cmd_internal # (
    .P_BANK_INDEX(P_BANK_INDEX)
) bs_cmd_internal_u (

    // Input
    .clock_i     (clock_i), 
    .reset_ni    (reset_ni), 

    .req_id_req_to_cmd_translator   (req_id_req_to_cmd_translator),
    .cmd_id_req_to_cmd_translator   (cmd_id_req_to_cmd_translator),
    .cmd_req_to_cmd_translator      (cmd_req_to_cmd_translator),
    .row_addr_req_to_cmd_translator (row_addr_req_to_cmd_translator),

    .need_refresh                   (need_refresh), 
    .refresh_present_state          (refresh_present_state),  
    .need_activate_after_refresh    (need_activate_after_refresh),
    .active_row                     (active_row),

    .cmd_bank                       (cmd_bank), 
    .can_serve_actual_cmd           (can_serve_actual_cmd), 
    .cmd_picked_bank                (cmd_picked_bank),

    // Output 
    .cmd_inter                      (cmd_inter), 
    .row_address_inter              (row_address_inter),
    .req_id_inter                   (req_id_inter),
    .cmd_id_inter                   (cmd_id_inter),
    .ref_occurrences_cnt            (ref_occurrences_cnt), 

    .cmd_picked_req_to_cmd_translator (cmd_picked_req_to_cmd_translator),
    .busy (busy)
);

/*************************************/
/* ASSIGN CMD DISPATCHER TO CMD BANK */
/*************************************/
/* Here we get the cmd_inter e put it into cmd_bank if we can */
always @(posedge clock_i or negedge reset_ni) begin
    if ( reset_ni == 1'b0 ) begin
        cmd_bank <= P_GENERAL_NOP;
        row_address_bank <= {P_ROW_ADDR_WIDTH{1'b0}};
        req_id_bank <= {P_REQ_ID_WIDTH{1'b0}};
        cmd_id_bank <= {P_CMD_ID_WIDTH{1'b0}};
    end 
    else begin
        /* The case when cmd_bank is empty and we have a cmd_inter ready */
        if ( cmd_bank == P_GENERAL_NOP && can_serve_actual_cmd && busy == 1'b1) begin
            cmd_bank <= cmd_inter;
            row_address_bank <= row_address_inter;
            req_id_bank <= req_id_inter;
            cmd_id_bank <= cmd_id_inter;

            `ifdef DEBUG
                $display("[ BS %d ]: REQ: %d - CMD: %d (%d) sent at %d", P_BANK_INDEX, req_id_inter, cmd_id_inter, cmd_inter, $time);
            `endif
        end
        /* The case when channel scheduler get the cmd and we have another cmd_inter ready */
        else if ( can_serve_actual_cmd && cmd_bank != P_GENERAL_NOP && cmd_picked_bank && busy == 1'b1) begin
            cmd_bank <= cmd_inter;
            row_address_bank <= row_address_inter;
            req_id_bank <= req_id_inter;
            cmd_id_bank <= cmd_id_inter;

            `ifdef DEBUG
                $display("[ BS %d ]: REQ: %d - CMD: %d (%d) sent at %d", P_BANK_INDEX, req_id_inter, cmd_id_inter, cmd_inter, $time);
            `endif
        end
        /* The case when channel scheduler get the cmd but we don't have another cmd_inter ready so just empty the cmd_bank */
        else if ( ~can_serve_actual_cmd && cmd_picked_bank && cmd_bank != P_GENERAL_NOP ) begin
            cmd_bank <= P_GENERAL_NOP;
        end
    end
end



/*************************/
/* ACTIVE ROW MANAGEMENT */
/*************************/
always @(posedge clock_i or negedge reset_ni) begin
    if ( reset_ni == 1'b0 ) begin
        active_row <= {P_ROW_ADDR_WIDTH+1{1'b1}};
    end
    else begin
        if ( cmd_bank == P_ROW_ACT && cmd_picked_bank ) begin
            active_row <= row_address_bank;
        end 
        else if ( cmd_bank == P_ROW_PRE && cmd_picked_bank && (~need_refresh || ( need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter == P_ROW_PRE))) begin
            active_row <= {P_ROW_ADDR_WIDTH+1{1'b1}};
        end
        else begin
            active_row <= active_row;
        end 
    end
end

/*******************************************/
/* ACT IS NEEDED AFTER REFRESH PROCEDURE ? */
/*******************************************/
always @(posedge clock_i or negedge reset_ni) begin
    if ( reset_ni == 1'b0 ) begin
        need_activate_after_refresh <= 1'b0;
    end
    else begin
        if ( refresh_present_state == LP_REF_IDLE && need_refresh && cmd_inter == P_ROW_PRE ) begin
            need_activate_after_refresh <= 1'b0;
        end
        else if ( refresh_present_state == LP_REF_IDLE && need_refresh && cmd_inter != P_ROW_PRE && cmd_inter != P_GENERAL_NOP) begin
            need_activate_after_refresh <= 1'b1;
        end
        else if ( refresh_present_state == LP_REF_IDLE && need_refresh && cmd_inter == P_GENERAL_NOP && active_row != {P_ROW_ADDR_WIDTH+1{1'b1}} ) begin
            need_activate_after_refresh <= 1'b1;
        end
    end
end


/***************************/
/* NEED REFRESH MANAGEMENT */
/***************************/
wire need_refresh_reset;
assign need_refresh_reset = (need_refresh == 1'b1) && (( refresh_present_state == LP_REF_REF && busy == 1'b0 && cmd_inter == P_ROW_REFPB && cmd_req_to_cmd_translator == P_ROW_ACT) || (refresh_present_state == LP_REF_ACT && busy == 1'b0 && cmd_inter == P_ROW_ACT) || ( busy == 1'b0 && cmd_inter == P_ROW_REFPB && cmd_req_to_cmd_translator != P_ROW_ACT && ~need_activate_after_refresh ) );
always @(posedge clock_i or negedge reset_ni) begin
    if ( reset_ni == 1'b0 ) begin
        need_refresh <= 1'b0;
    end
    else begin
        /* need_refresh is set when time is up, we are in normal execution (need_refresh is 0) and the last refresh is obviously served... */
        if ( last_ref_cnt_for_need_refresh == tREFP/*>= tREFP*/ && need_refresh == 1'b0 && waiting_for_ref_serve == 2'b00 ) begin
            need_refresh <= 1'b1;
        end
        else if (need_refresh_reset) begin
            need_refresh <= 1'b0;
        end
        else begin
            need_refresh <= need_refresh;
        end
    end
end


/********************************/
/* REFRESH FINITE STATE MACHINE */
/********************************/
always @(posedge clock_i or negedge reset_ni) begin
    if ( reset_ni == 1'b0 ) begin
        refresh_present_state <= LP_REF_IDLE;
    end
    else begin
        refresh_present_state <= refresh_next_state;
    end
end

always @( * ) begin
    case( refresh_present_state )
        LP_REF_IDLE:
        begin
            if( need_refresh ) begin
                if ( active_row != {P_ROW_ADDR_WIDTH+1{1'b1}} || cmd_inter != P_GENERAL_NOP ) begin
                    refresh_next_state <= LP_REF_PRE_WAIT;
                end
                else begin
                    refresh_next_state <= LP_REF_REF;
                end 
            end
            else begin
                refresh_next_state <= refresh_present_state;
            end
        end
        LP_REF_PRE_WAIT:
        begin
            if ( busy == 1'b0 && cmd_inter == P_ROW_PRE ) begin
                refresh_next_state <= LP_REF_REF;
            end
            else begin
                refresh_next_state <= refresh_present_state;
            end           
        end
        LP_REF_REF:
        begin
            if ( busy == 1'b0 && cmd_inter == P_ROW_REFPB && cmd_req_to_cmd_translator != P_ROW_ACT && need_activate_after_refresh ) begin
                refresh_next_state <= LP_REF_ACT;
            end

            else if ( busy == 1'b0 && cmd_inter == P_ROW_REFPB && cmd_req_to_cmd_translator != P_ROW_ACT && ~need_activate_after_refresh) begin
                refresh_next_state <= LP_REF_IDLE;
            end
            
            else if ( busy == 1'b0 && cmd_inter == P_ROW_REFPB && cmd_req_to_cmd_translator == P_ROW_ACT) begin
                refresh_next_state <= LP_REF_IDLE;
            end

            else begin
                refresh_next_state <= refresh_present_state;
            end
        end
        LP_REF_ACT:
        begin
            if ( busy == 1'b0 && cmd_inter == P_ROW_ACT ) begin
                refresh_next_state <= LP_REF_IDLE;
            end
            else begin
                refresh_next_state <= refresh_present_state;
            end
        end
    endcase
end



endmodule