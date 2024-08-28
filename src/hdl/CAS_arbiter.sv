`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/27/2023 11:33:27 AM
// Design Name: 
// Module Name: CAS_arbiter
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


module CAS_arbiter# 
(
    parameter       P_BA_N_PS         = 16,        /* Number of Banks per PS */
    parameter       P_BA_N_G          = 4,         /* Number of Banks per group */ 
    parameter		P_COL_ADDR_WIDTH  = 16,
    parameter		P_BA_ADDR_WIDTH	  = 5,
    parameter       P_DATA_WIDTH      = 256,

    /* COMMANDS */
    parameter       P_GENERAL_NOP     = 4'b1111,
    parameter       P_COL_WRT		  = 4'b0001,
    parameter       P_COL_RD          = 4'b0101,
    
    parameter       P_REQ_ID_WIDTH = 32'd6,
    parameter       P_CMD_ID_WIDTH = 32'd3

)
(
    input            clk,
    input            rst_n,
    
    output [0 : P_BA_N_PS - 1]       cmd_cas_bank_picked,
    input  [P_REQ_ID_WIDTH-1:0]      req_cas_id_bank        [0 : P_BA_N_PS - 1], 
    input  [P_CMD_ID_WIDTH-1:0]      cmd_cas_id_bank        [0 : P_BA_N_PS - 1],        
    input  [3:0]                     cmd_cas_bank           [0 : P_BA_N_PS - 1],
    
    input  ready_to_cmd_cas,
    output [3:0]                        cmd_cas,
    output [P_REQ_ID_WIDTH-1:0]         req_id_cas,
    output [P_CMD_ID_WIDTH-1:0]         cmd_id_cas,
    output [1:0]                        bank_group_cas,

    output [P_REQ_ID_WIDTH-1:0]         ram_cas_req_id

);

localparam LP_BG_N = P_BA_N_PS/P_BA_N_G;
localparam LP_ACTUAL_BANK_GROUP_SERVING_WIDTH = $clog2(LP_BG_N);
localparam LP_ACTUAL_BANK_SERVING_WIDTH       = $clog2(P_BA_N_G);

reg    [ LP_ACTUAL_BANK_GROUP_SERVING_WIDTH - 1 : 0 ]  actual_bank_group_serving;
reg    [3:0]    actual_bank_serving  [0:15];  
reg    [3:0]    actual_bank_serving_index;

reg [3:0] actual_cmd_serving_type;     /*  Bundling Type RD or WRT */
reg [P_REQ_ID_WIDTH-1:0] r_req_id_cas;
reg [P_CMD_ID_WIDTH-1:0] r_cmd_id_cas;
reg [3:0] r_cmd_cas;
reg [1:0] r_bank_group_cas;
reg [0 : P_BA_N_PS - 1]r_cmd_cas_bank_picked;

wire [3:0]                          cmd_inter_selected;
wire [P_REQ_ID_WIDTH-1:0]           req_id_selected_by_bg;
wire [P_CMD_ID_WIDTH-1:0]           cmd_id_selected_by_bg;
wire [P_BA_ADDR_WIDTH - 1 : 0]      bank_group_selected_by_bg;

wire change_round;

reg [P_REQ_ID_WIDTH-1:0] r_ram_cas_req_id;
assign ram_cas_req_id = r_ram_cas_req_id;

always_latch begin
    if ( ready_to_cmd_cas &&  cmd_inter_selected == actual_cmd_serving_type) begin
        r_ram_cas_req_id <= req_id_selected_by_bg;
    end
    else begin
        r_ram_cas_req_id <= r_ram_cas_req_id;
    end
end

assign req_id_cas = r_req_id_cas;
assign cmd_id_cas = r_cmd_id_cas;
assign cmd_cas = r_cmd_cas;
assign bank_group_cas = r_bank_group_cas;
assign cmd_cas_bank_picked = r_cmd_cas_bank_picked;

/* Here there is a bug for predictability */
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
always @ ( posedge clk or negedge rst_n ) begin : cmd_driver
    if ( rst_n == 1'b0 ) begin
        r_cmd_cas                 <=  P_GENERAL_NOP;
        r_bank_group_cas          <=  { 2  { 1'b0 } };
        r_req_id_cas              <=  { P_REQ_ID_WIDTH { 1'b1 } };
        r_cmd_id_cas              <=  { P_CMD_ID_WIDTH { 1'b1 } };
    end
    else begin
        if ( ready_to_cmd_cas &&  cmd_inter_selected == actual_cmd_serving_type ) begin
            r_cmd_cas            <=  cmd_inter_selected;
            r_req_id_cas         <=  req_id_selected_by_bg;
            r_cmd_id_cas         <=  cmd_id_selected_by_bg; 
            r_bank_group_cas     <=  actual_bank_group_serving;
            `ifdef DEBUG
                $display("[ CAS ]: REQ: %d - CMD: %d (%d) sent at %d", req_id_selected_by_bg, cmd_id_selected_by_bg, cmd_inter_selected, $time);
            `endif
        end 
        else if (ready_to_cmd_cas && cmd_inter_selected != actual_cmd_serving_type ) begin
            r_cmd_cas           <= P_GENERAL_NOP;
        end        
    end
end

/********************************************/
/* ACK THE BANK SCHEDULER THE CMD IS PICKED */
/********************************************/
genvar i;
generate 
    for ( i = 0; i < P_BA_N_PS; i = i + 1 ) begin
        always @ ( posedge clk or negedge rst_n ) begin    
            if (rst_n == 1'b0 ) begin
                r_cmd_cas_bank_picked[i] <= 1'b0;
            end
            else begin
                if (ready_to_cmd_cas && cmd_inter_selected == actual_cmd_serving_type && i == (actual_bank_serving[actual_bank_serving_index])) begin
                    r_cmd_cas_bank_picked[i] <= 1'b1;
                end
                else if (r_cmd_cas_bank_picked[i] == 1'b1 && cmd_cas_bank[i] != P_GENERAL_NOP ) begin
                    r_cmd_cas_bank_picked[i] <= 1'b0;
                end 
            end
        end
    end
endgenerate

/*********************************/
/* BANK GROUP SERVING MANAGEMENT */
/*********************************/
always @(posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
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

always @(posedge clk or negedge rst_n) begin : actual_bank_group_serving_driver
    if (rst_n == 1'b0) begin
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
always @(posedge clk or negedge rst_n) begin : actual_cmd_serving_type_driver
    if (rst_n == 1'b0) begin
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