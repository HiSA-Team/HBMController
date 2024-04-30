`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/27/2023 11:18:01 AM
// Design Name: 
// Module Name: RAS_arbiter
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


module RAS_arbiter#
(
    parameter       P_BA_N_PS        = 16,        /* Number of Banks per PS */
    parameter       P_BA_N_G         = 4,         /* Number of Banks per group */ 
    parameter		P_ROW_ADDR_WIDTH = 16,
    parameter		P_BA_ADDR_WIDTH	 = 5,

    /* COMMANDS */
    parameter       P_GENERAL_NOP    = 4'b1111,
    parameter       P_ROW_ACT		 = 3'b010,
    parameter       P_ROW_PRE		 = 3'b011,
    parameter       P_COL_WRT	     = 4'b0001,
    parameter       P_COL_RD         = 4'b0101,
    parameter       P_ROW_REFPB      = /*4'b1001*/ 4'b1100,
    parameter       P_REQ_ID_WIDTH = 32'd6,
    parameter       P_CMD_ID_WIDTH = 32'd3
)
(
    input            clk,
    input            rst_n,

    /* Interface to Bank Scheduler */
    output [0 : P_BA_N_PS - 1]       cmd_ras_bank_picked,
    input  [P_REQ_ID_WIDTH-1:0]      req_ras_id_bank         [0 : P_BA_N_PS - 1], 
    input  [P_CMD_ID_WIDTH-1:0]      cmd_ras_id_bank         [0 : P_BA_N_PS - 1],
    input  [3:0]                     cmd_ras_bank            [0 : P_BA_N_PS - 1],
    input  [P_BA_ADDR_WIDTH-1 : 0]   bank_address_bank       [0 : P_BA_N_PS - 1],
    input  [P_ROW_ADDR_WIDTH-1 : 0]  row_address_bank        [0 : P_BA_N_PS - 1],

    /* Interface to LLCF */
    input  ready_to_cmd_ras,
    output [3:0]cmd_ras,
    output [P_REQ_ID_WIDTH-1:0]         req_id_ras,
    output [P_CMD_ID_WIDTH-1:0]         cmd_id_ras,
    output [P_BA_ADDR_WIDTH-1 : 0]      bank_address_ras,
    output [P_ROW_ADDR_WIDTH-1 : 0]     row_address_ras 
    
);

localparam LP_BG_N = P_BA_N_PS/P_BA_N_G;
localparam ACTUAL_BG_SERVING_WIDTH = $clog2(P_BA_N_G);
localparam ACTUAL_BG_CMD_RAS_SERVING_WIDTH = $clog2(LP_BG_N);

reg [0 : P_BA_N_PS - 1] r_cmd_ras_bank_picked;
reg [3:0] r_cmd_ras;
reg [P_BA_ADDR_WIDTH-1 : 0] r_bank_address_ras;
reg [P_ROW_ADDR_WIDTH-1 : 0] r_row_address_ras;

reg [P_REQ_ID_WIDTH-1:0] r_req_id_ras;
reg [P_CMD_ID_WIDTH-1:0] r_cmd_id_ras;

reg [ACTUAL_BG_CMD_RAS_SERVING_WIDTH-1 : 0] actual_bank_group_serving; 
reg [ACTUAL_BG_SERVING_WIDTH-1 : 0] actual_bank_serving[0 : LP_BG_N - 1];

wire [3:0]                          cmd_inter_selected;
wire [P_REQ_ID_WIDTH-1:0]           req_id_selected_by_bg;
wire [P_CMD_ID_WIDTH-1:0]           cmd_id_selected_by_bg;
wire [P_BA_ADDR_WIDTH - 1 : 0]      bank_address_selected_by_bg;
wire [P_ROW_ADDR_WIDTH - 1 : 0]     row_address_selected_by_bg;


assign req_id_ras = r_req_id_ras;
assign cmd_id_ras = r_cmd_id_ras;
assign cmd_ras_bank_picked = r_cmd_ras_bank_picked;
assign cmd_ras = r_cmd_ras;
assign bank_address_ras = r_bank_address_ras;
assign row_address_ras = r_row_address_ras;

/*********************/
/* RAS CMD SELECTION */
/*********************/
assign cmd_inter_selected            =  cmd_ras_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];
assign req_id_selected_by_bg         =  req_ras_id_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];
assign cmd_id_selected_by_bg         =  cmd_ras_id_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];
assign bank_address_selected_by_bg   =  bank_address_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];
assign row_address_selected_by_bg    =  row_address_bank[(actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]];
 

/*********************************/
/* SEND RAS CMD SELECTED TO LLCF */
/*********************************/
always @ (posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        r_cmd_ras                 <=  P_GENERAL_NOP;
        r_bank_address_ras        <=  { P_BA_ADDR_WIDTH  { 1'b0 } };
        r_row_address_ras         <=  { P_ROW_ADDR_WIDTH { 1'b0 } };   
        r_req_id_ras              <=  { P_REQ_ID_WIDTH { 1'b1 } };
        r_cmd_id_ras              <=  { P_CMD_ID_WIDTH { 1'b1 } };
    end
    else begin
        if ( ready_to_cmd_ras && (cmd_inter_selected == P_ROW_ACT || cmd_inter_selected == P_ROW_PRE || cmd_inter_selected == P_ROW_REFPB)) begin
            r_cmd_ras            <=  cmd_inter_selected; 
            r_req_id_ras         <=  req_id_selected_by_bg;
            r_cmd_id_ras         <=  cmd_id_selected_by_bg; 
            r_bank_address_ras   <=  bank_address_selected_by_bg;
            r_row_address_ras    <=  row_address_selected_by_bg;
            $display("[ RAS ]: REQ: %d - CMD: %d (%d) sent at %d", req_id_selected_by_bg, cmd_id_selected_by_bg, cmd_inter_selected, $time);
        end
        else if (ready_to_cmd_ras) begin
            r_cmd_ras            <= P_GENERAL_NOP;
        end
    end
end 


/********************************************/
/* ACK THE BANK SCHEDULER THE CMD IS PICKED */
/********************************************/
genvar i;
generate
    for (i = 0; i < P_BA_N_PS; i = i + 1 ) begin
        always @ (posedge clk or negedge rst_n) begin
            if ( rst_n == 1'b0 ) begin
                r_cmd_ras_bank_picked[i] <= 1'b0;
            end
            else begin
                if ( ready_to_cmd_ras && (cmd_inter_selected == P_ROW_ACT || cmd_inter_selected == P_ROW_PRE || cmd_inter_selected == P_ROW_REFPB) && (i == ((actual_bank_group_serving*P_BA_N_G) + actual_bank_serving[actual_bank_group_serving]))) begin
                    r_cmd_ras_bank_picked[i] <= 1'b1;
                end
                else if ( r_cmd_ras_bank_picked[i] == 1'b1 && cmd_ras_bank[i] != P_GENERAL_NOP ) begin
                    r_cmd_ras_bank_picked[i] <= 1'b0;
                end
            end 
        end 
    end
endgenerate

/**********************************/
/* ACTUAL BANK SERVING MANAGEMENT */
/**********************************/
always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        foreach ( actual_bank_serving[i] ) actual_bank_serving[i] <= {ACTUAL_BG_SERVING_WIDTH{1'b0}};
    end
    else begin
        if ( ~(cmd_inter_selected == P_ROW_ACT || cmd_inter_selected == P_ROW_PRE || cmd_inter_selected == P_ROW_REFPB) || cmd_inter_selected == P_GENERAL_NOP /*&& ~change_round*/ ) begin
            actual_bank_serving[actual_bank_group_serving] <= actual_bank_serving[actual_bank_group_serving] + 1'b1;
        end 
        else if ( (cmd_inter_selected == P_ROW_ACT || cmd_inter_selected == P_ROW_PRE || cmd_inter_selected == P_ROW_REFPB) && ready_to_cmd_ras /* && ~change_round */ ) begin
            actual_bank_serving[actual_bank_group_serving] <= actual_bank_serving[actual_bank_group_serving] + 1'b1;
        end
    end
end 

/*********************************/
/* BANK GROUP SERVING MANAGEMENT */
/*********************************/
always @(posedge clk or negedge rst_n) begin : actual_bank_group_serving_driver
    if (rst_n == 1'b0) begin
        actual_bank_group_serving <= {ACTUAL_BG_CMD_RAS_SERVING_WIDTH {1'b0}};
    end
    else begin
        if ( (cmd_inter_selected == P_ROW_ACT || cmd_inter_selected == P_ROW_PRE || cmd_inter_selected == P_ROW_REFPB) && ready_to_cmd_ras) begin
            actual_bank_group_serving <= actual_bank_group_serving + 1'b1; 
        end
        else if ( ~(cmd_inter_selected == P_ROW_ACT || cmd_inter_selected == P_ROW_PRE || cmd_inter_selected == P_ROW_REFPB) || cmd_inter_selected == P_GENERAL_NOP  /*&& actual_bank_serving[actual_bank_group_serving] >= P_BA_N_G-1*/) begin
            actual_bank_group_serving <= actual_bank_group_serving + 1'b1; 
        end
    end
end

endmodule
