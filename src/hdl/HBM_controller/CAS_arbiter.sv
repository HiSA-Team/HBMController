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
    parameter       P_COL_RD          = 4'b0101

)
(
    input            clk,
    input            rst_n,
    
    output [0 : P_BA_N_PS - 1]       cmd_cas_bank_picked,
    input  [20:0]                    req_cas_id_bank        [0 : P_BA_N_PS - 1], 
    input  [20:0]                    cmd_cas_id_bank        [0 : P_BA_N_PS - 1],        
    input  [3:0]                     cmd_cas_bank           [0 : P_BA_N_PS - 1],
    input  [P_BA_ADDR_WIDTH-1 : 0]   bank_address_bank      [0 : P_BA_N_PS - 1],
    input  [P_COL_ADDR_WIDTH-1 : 0]  column_address_bank    [0 : P_BA_N_PS - 1],
    input  [P_DATA_WIDTH-1 : 0]      wrt_data_bank          [0 : P_BA_N_PS - 1],
//    output [P_DATA_WIDTH-1 : 0]    rd_data_bank [0 : P_BA_N_PS - 1],
    
    input  ready_to_cmd_cas,
    output [3:0]                        cmd_cas,
    output [20:0]                       req_id_cas,
    output [20:0]                       cmd_id_cas,
    output [P_BA_ADDR_WIDTH  - 1 : 0 ]  bank_address_cas,
    output [P_COL_ADDR_WIDTH - 1 : 0 ]  column_address_cas,
    output [P_DATA_WIDTH     - 1 : 0 ]  wrt_data_cas

);

localparam LP_BG_N = P_BA_N_PS/P_BA_N_G;
localparam LP_ACTUAL_BANK_GROUP_SERVING_WIDTH = $clog2(LP_BG_N);
localparam LP_ACTUAL_BANK_SERVING_WIDTH       = $clog2(P_BA_N_G);

reg    [ LP_ACTUAL_BANK_GROUP_SERVING_WIDTH - 1 : 0 ]  actual_bank_group_serving ;
reg    [ LP_ACTUAL_BANK_SERVING_WIDTH-1         : 0 ]            actual_bank_serving           [0 : LP_BG_N - 1];

reg [3:0] actual_cmd_serving_type;     /*  Bundling Type RD or WRT */
reg [20:0] r_req_id_cas;
reg [20:0] r_cmd_id_cas;
reg [3:0] r_cmd_cas;
reg [P_DATA_WIDTH - 1 : 0] r_wrt_data_cas;
reg [P_BA_ADDR_WIDTH - 1 : 0] r_bank_address_cas;
reg [P_COL_ADDR_WIDTH - 1 : 0] r_column_address_cas;
reg [0 : P_BA_N_PS - 1]r_cmd_cas_bank_picked;



wire [3:0]                          cmd_inter_selected;
wire [20:0]                         req_id_selected_by_bg;
wire [20:0]                         cmd_id_selected_by_bg;
wire [P_DATA_WIDTH - 1 : 0]         wrt_data_selected_by_bg;
wire [P_BA_ADDR_WIDTH - 1 : 0]      bank_address_selected_by_bg;
wire [P_COL_ADDR_WIDTH - 1 : 0]     column_address_selected_by_bg;


wire change_round;

assign req_id_cas = r_req_id_cas;
assign cmd_id_cas = r_cmd_id_cas;
assign cmd_cas = r_cmd_cas;
assign wrt_data_cas = r_wrt_data_cas;
assign bank_address_cas = r_bank_address_cas;
assign column_address_cas = r_column_address_cas;
assign cmd_cas_bank_picked = r_cmd_cas_bank_picked;


assign change_round =  actual_bank_group_serving == LP_BG_N-1 && actual_bank_serving[actual_bank_group_serving] ==  P_BA_N_G-1; 

/*********************/
/* CAS CMD SELECTION */
/*********************/
assign cmd_inter_selected            =   cmd_cas_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];
assign req_id_selected_by_bg         =   req_cas_id_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];
assign cmd_id_selected_by_bg         =   cmd_cas_id_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];
assign bank_address_selected_by_bg   =   bank_address_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];
assign column_address_selected_by_bg =   column_address_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];
assign wrt_data_selected_by_bg       =   wrt_data_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];


/*********************************/
/* SEND CAS CMD SELECTED TO LLCF */
/*********************************/
always @ ( posedge clk or negedge rst_n ) begin : cmd_driver
    if ( rst_n == 1'b0 ) begin
        r_cmd_cas                 <=  P_GENERAL_NOP;
        r_wrt_data_cas            <=  { P_DATA_WIDTH     { 1'b0 } };
        r_bank_address_cas        <=  { P_BA_ADDR_WIDTH  { 1'b0 } };
        r_column_address_cas      <=  { P_COL_ADDR_WIDTH { 1'b0 } };   
        r_req_id_cas              <=  { 64 { 1'b1 } };
        r_cmd_id_cas              <=  { 64 { 1'b1 } };
    end
    else begin
        if ( ready_to_cmd_cas &&  cmd_inter_selected == actual_cmd_serving_type ) begin
            r_cmd_cas            <=  cmd_inter_selected;
            r_req_id_cas         <=  req_id_selected_by_bg;
            r_cmd_id_cas         <=  cmd_id_selected_by_bg; 
            r_bank_address_cas   <=  bank_address_selected_by_bg;
            r_column_address_cas <=  column_address_selected_by_bg;
            r_wrt_data_cas       <=  wrt_data_selected_by_bg;
            $display("[ CAS ]: REQ: %d - CMD: %d (%d) sent at %d", req_id_selected_by_bg, cmd_id_selected_by_bg, cmd_inter_selected, $time);

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
                if (ready_to_cmd_cas && cmd_inter_selected == actual_cmd_serving_type && i == ((actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving])) begin
                    r_cmd_cas_bank_picked[i] <= 1'b1;
                end
                else if (r_cmd_cas_bank_picked[i] == 1'b1 && cmd_cas_bank[i] != P_GENERAL_NOP ) begin
                    r_cmd_cas_bank_picked[i] <= 1'b0;
                end 
            end
        end
    end
endgenerate

/**********************************/
/* ACTUAL BANK SERVING MANAGEMENT */
/**********************************/
always @(posedge clk or negedge rst_n)  begin : actual_bank_serving_driver
    if (rst_n == 1'b0 ) begin
        foreach (actual_bank_serving[i]) actual_bank_serving[i] <= {LP_ACTUAL_BANK_SERVING_WIDTH{1'b0}};
    end
    else begin
        if ( cmd_inter_selected != actual_cmd_serving_type) begin
            actual_bank_serving[actual_bank_group_serving] <= actual_bank_serving[actual_bank_group_serving] + 1'b1;
        end
        else if (cmd_inter_selected == actual_cmd_serving_type && ready_to_cmd_cas) begin
            actual_bank_serving[actual_bank_group_serving] <= actual_bank_serving[actual_bank_group_serving] + 1'b1;
        end
    end
end


/*********************************/
/* BANK GROUP SERVING MANAGEMENT */
/*********************************/
always @(posedge clk or negedge rst_n) begin : actual_bank_group_serving_driver
    if (rst_n == 1'b0) begin
        actual_bank_group_serving <= {LP_ACTUAL_BANK_GROUP_SERVING_WIDTH {1'b0}};
    end
    else begin
        if ( cmd_inter_selected == actual_cmd_serving_type && ready_to_cmd_cas) begin
            actual_bank_group_serving <= actual_bank_group_serving + 1'b1; 
        end
        else if ( cmd_inter_selected != actual_cmd_serving_type) begin
            actual_bank_group_serving <= actual_bank_group_serving + 1'b1;
        end
        else begin
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