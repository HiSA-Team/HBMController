`timescale 1ps / 1ps

`include "commands.svh"
`include "hbm_controller.svh"

module CAS_arbiter (
    input  logic                                       clock_i,
    input  logic                                       reset_ni,
    
    output logic  [0 : P_BA_N_PS - 1]                  cmd_cas_bank_picked,
    input  logic  [P_REQ_ID_WIDTH-1:0]                 req_cas_id_bank        [0 : P_BA_N_PS - 1], 
    input  logic  [P_CMD_ID_WIDTH-1:0]                 cmd_cas_id_bank        [0 : P_BA_N_PS - 1],        
    input  logic  [3:0]                                cmd_cas_bank           [0 : P_BA_N_PS - 1],
    
    input  logic                                       ready_to_cmd_cas,
    output logic [3:0]                                 cmd_cas,
    output logic [P_REQ_ID_WIDTH-1:0]                  req_id_cas,
    output logic [P_CMD_ID_WIDTH-1:0]                  cmd_id_cas,
    output logic [1:0]                                 bank_group_cas,

    output logic [P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-2:0]  wr_ram_cas_req_id,
    output logic [P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-2:0]  rd_ram_cas_req_id

);

localparam LP_ACTUAL_BANK_GROUP_SERVING_WIDTH = $clog2(LP_BG_N);
localparam LP_ACTUAL_BANK_SERVING_WIDTH       = $clog2(P_BA_N_G);

logic [LP_ACTUAL_BANK_GROUP_SERVING_WIDTH-1:0]  actual_bank_group_serving;
logic [3:0]                                     actual_bank_serving  [0:15];  
logic [3:0]                                     actual_bank_serving_index;
logic [3:0]                                     actual_cmd_serving_type;     /*  Bundling Type RD or WRT */

logic [3:0]                                     cmd_inter_selected;
logic [P_REQ_ID_WIDTH-1:0]                      req_id_selected_by_bg;
logic [P_CMD_ID_WIDTH-1:0]                      cmd_id_selected_by_bg;

logic change_round;

always_latch begin
    if ( ready_to_cmd_cas &&  cmd_inter_selected == actual_cmd_serving_type) begin
        if (actual_cmd_serving_type == P_COL_WRT) begin
            wr_ram_cas_req_id <= {req_id_selected_by_bg, actual_bank_serving[actual_bank_serving_index]};
            rd_ram_cas_req_id <= rd_ram_cas_req_id;
        end
        else begin
            rd_ram_cas_req_id <= {req_id_selected_by_bg, actual_bank_serving[actual_bank_serving_index]};
            wr_ram_cas_req_id <= wr_ram_cas_req_id;
        end
    end
    else begin
        wr_ram_cas_req_id <= wr_ram_cas_req_id;
        rd_ram_cas_req_id <= rd_ram_cas_req_id;
    end
end

/* TODO Here there is a bug for predictability (maybe) */
assign change_round =  actual_bank_serving_index == 4'd15 && ((cmd_inter_selected == actual_cmd_serving_type && ready_to_cmd_cas) || (cmd_inter_selected != actual_cmd_serving_type))/*actual_bank_group_serving == LP_BG_N-1 && actual_bank_serving[actual_bank_group_serving] ==  P_BA_N_G-1*/; 

/*********************/
/* CAS CMD SELECTION */
/*********************/
assign cmd_inter_selected            =   cmd_cas_bank[actual_bank_serving[actual_bank_serving_index]];
assign req_id_selected_by_bg         =   req_cas_id_bank[actual_bank_serving[actual_bank_serving_index]];
assign cmd_id_selected_by_bg         =   cmd_cas_id_bank[actual_bank_serving[actual_bank_serving_index]];

/*********************************/
/* SEND CAS CMD SELECTED TO LLCF */
/*********************************/
always @ ( posedge clock_i or negedge reset_ni ) begin : cmd_driver
    if ( reset_ni == 1'b0 ) begin
        cmd_cas                 <=  P_GENERAL_NOP;
        bank_group_cas          <=  { 2  { 1'b0 } };
        req_id_cas              <=  { P_REQ_ID_WIDTH { 1'b1 } };
        cmd_id_cas              <=  { P_CMD_ID_WIDTH { 1'b1 } };
    end
    else begin
        if ( ready_to_cmd_cas &&  cmd_inter_selected == actual_cmd_serving_type ) begin
            cmd_cas            <=  cmd_inter_selected;
            req_id_cas         <=  req_id_selected_by_bg;
            cmd_id_cas         <=  cmd_id_selected_by_bg; 
            bank_group_cas     <=  actual_bank_group_serving;
            `ifdef DEBUG
                $display("[ CAS ]: REQ: %d - CMD: %d (%d) sent at %d", req_id_selected_by_bg, cmd_id_selected_by_bg, cmd_inter_selected, $time);
            `endif
        end 
        else if (ready_to_cmd_cas && cmd_inter_selected != actual_cmd_serving_type ) begin
            cmd_cas           <= P_GENERAL_NOP;
        end        
    end
end

/********************************************/
/* ACK THE BANK SCHEDULER THE CMD IS PICKED */
/********************************************/
genvar i;
generate 
    for ( i = 0; i < P_BA_N_PS; i = i + 1 ) begin
        always @ ( posedge clock_i or negedge reset_ni ) begin    
            if (reset_ni == 1'b0 ) begin
                cmd_cas_bank_picked[i] <= 1'b0;
            end
            else begin
                if (ready_to_cmd_cas && cmd_inter_selected == actual_cmd_serving_type && i == (actual_bank_serving[actual_bank_serving_index])) begin
                    cmd_cas_bank_picked[i] <= 1'b1;
                end
                else if (cmd_cas_bank_picked[i] == 1'b1 && cmd_cas_bank[i] != P_GENERAL_NOP ) begin
                    cmd_cas_bank_picked[i] <= 1'b0;
                end 
            end
        end
    end
endgenerate

/*********************************/
/* BANK GROUP SERVING MANAGEMENT */
/*********************************/
always @(posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        actual_bank_serving[0]  <= 4'd0;
        actual_bank_serving[1]  <= 4'd4;
        actual_bank_serving[2]  <= 4'd8;
        actual_bank_serving[3]  <= 4'd12;
        actual_bank_serving[4]  <= 4'd1;
        actual_bank_serving[5]  <= 4'd5;
        actual_bank_serving[6]  <= 4'd9;
        actual_bank_serving[7]  <= 4'd13;
        actual_bank_serving[8]  <= 4'd2;
        actual_bank_serving[9]  <= 4'd6;
        actual_bank_serving[10] <= 4'd10;
        actual_bank_serving[11] <= 4'd14;
        actual_bank_serving[12] <= 4'd3;
        actual_bank_serving[13] <= 4'd7;
        actual_bank_serving[14] <= 4'd11;
        actual_bank_serving[15] <= 4'd15;
    end
end

always @(posedge clock_i or negedge reset_ni) begin : actual_bank_group_serving_driver
    if (reset_ni == 1'b0) begin
        actual_bank_serving_index <= 4'd0;
        actual_bank_group_serving <= {LP_ACTUAL_BANK_GROUP_SERVING_WIDTH {1'b0}};
    end
    else begin
        if ( cmd_inter_selected == actual_cmd_serving_type && ready_to_cmd_cas) begin
            actual_bank_serving_index <= actual_bank_serving_index + 1'b1;
            actual_bank_group_serving <= actual_bank_group_serving + 1'b1;
        end
        else if ( cmd_inter_selected != actual_cmd_serving_type) begin
            actual_bank_serving_index <= actual_bank_serving_index + 1'b1;
            actual_bank_group_serving <= actual_bank_group_serving + 1'b1;
        end
        else begin
            actual_bank_serving_index <= actual_bank_serving_index;
            actual_bank_group_serving <= actual_bank_group_serving;
        end
    end
end

/****************************/
/* BUNDLING TYPE MANAGEMENT */
/****************************/
always @(posedge clock_i or negedge reset_ni) begin : actual_cmd_serving_type_driver
    if (reset_ni == 1'b0) begin
        actual_cmd_serving_type <= P_COL_RD;
    end
    else begin
        if (change_round) begin
            if (actual_cmd_serving_type == P_COL_RD) begin
                actual_cmd_serving_type <= P_COL_WRT;
            end
            else begin
                actual_cmd_serving_type <= P_COL_RD;
            end
        end
        else begin
            actual_cmd_serving_type <= actual_cmd_serving_type; 
        end
    end
end

endmodule