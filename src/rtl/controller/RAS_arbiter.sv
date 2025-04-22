`timescale 1ps / 1ps

`include "commands.svh"
`include "hbm_controller.svh"


module RAS_arbiter (
    input  logic                            clock_i,
    input  logic                            reset_ni,

    /* Interface to Bank Scheduler */
    output logic  [0 : P_BA_N_PS - 1]       cmd_ras_bank_picked,
    input  logic  [P_REQ_ID_WIDTH-1:0]      req_ras_id_bank         [0 : P_BA_N_PS - 1], 
    input  logic  [P_CMD_ID_WIDTH-1:0]      cmd_ras_id_bank         [0 : P_BA_N_PS - 1],
    input  logic  [3:0]                     cmd_ras_bank            [0 : P_BA_N_PS - 1],
    input  logic  [P_ROW_ADDR_WIDTH-1 : 0]  row_address_bank        [0 : P_BA_N_PS - 1],

    /* Interface to LLCF */
    input  logic                            ready_to_cmd_ras,
    output logic [3:0]                      cmd_ras,
    output logic [P_REQ_ID_WIDTH-1:0]       req_id_ras,
    output logic [P_CMD_ID_WIDTH-1:0]       cmd_id_ras,
    output logic [1:0]                      bank_group_ras,
    output logic [P_BA_ADDR_WIDTH-1:0]      bank_address_ras,
    output logic [P_ROW_ADDR_WIDTH-1 : 0]   row_address_ras

);

localparam ACTUAL_BG_SERVING_WIDTH         = $clog2(P_BA_N_G);
localparam ACTUAL_BG_CMD_RAS_SERVING_WIDTH = $clog2(LP_BG_N);

logic [ACTUAL_BG_CMD_RAS_SERVING_WIDTH-1:0]   actual_bank_group_serving; 
logic [3:0]                                   actual_bank_serving [0:15];  
logic [3:0]                                   actual_bank_serving_index;
logic [3:0]                                   cmd_inter_selected;
 
logic [P_REQ_ID_WIDTH-1:0]                    req_id_selected_by_bg;
logic [P_CMD_ID_WIDTH-1:0]                    cmd_id_selected_by_bg;
logic [P_ROW_ADDR_WIDTH-1:0]                  row_address_selected_by_bg;


/*********************/
/* RAS CMD SELECTION */
/*********************/
assign cmd_inter_selected            =  cmd_ras_bank[actual_bank_serving[actual_bank_serving_index]];
assign req_id_selected_by_bg         =  req_ras_id_bank[actual_bank_serving[actual_bank_serving_index]];
assign cmd_id_selected_by_bg         =  cmd_ras_id_bank[actual_bank_serving[actual_bank_serving_index]];
assign row_address_selected_by_bg    =  row_address_bank[actual_bank_serving[actual_bank_serving_index]];


/*********************************/
/* SEND RAS CMD SELECTED TO LLCF */
/*********************************/
always @ (posedge clock_i or negedge reset_ni) begin
    if(reset_ni == 1'b0) begin
        cmd_ras                 <=  P_GENERAL_NOP;
        bank_address_ras        <=  { P_BA_ADDR_WIDTH  { 1'b0 } };
        bank_group_ras          <=  { 2 { 1'b0 } };   
        req_id_ras              <=  { P_REQ_ID_WIDTH { 1'b1 } };
        cmd_id_ras              <=  { P_CMD_ID_WIDTH { 1'b1 } };
        row_address_ras         <=  { P_ROW_ADDR_WIDTH { 1'b1 } };
    end
    else begin
        if ( ready_to_cmd_ras && (cmd_inter_selected == P_ROW_ACT || cmd_inter_selected == P_ROW_PRE || cmd_inter_selected == P_ROW_REFPB)) begin
            cmd_ras            <=  cmd_inter_selected;
            req_id_ras         <=  req_id_selected_by_bg;
            cmd_id_ras         <=  cmd_id_selected_by_bg;
            bank_group_ras     <=  actual_bank_group_serving;
            bank_address_ras   <=  actual_bank_serving[actual_bank_serving_index];
            row_address_ras    <=  row_address_selected_by_bg;
            
            
            `ifdef DEBUG
                $display("[ RAS ]: REQ: %d - CMD: %d (%d) sent at %d", req_id_selected_by_bg, cmd_id_selected_by_bg, cmd_inter_selected, $time);
            `endif
        end
        else if (ready_to_cmd_ras) begin
            cmd_ras            <= P_GENERAL_NOP;
        end
    end
end 


/********************************************/
/* ACK THE BANK SCHEDULER THE CMD IS PICKED */
/********************************************/
genvar i;
generate
    for (i = 0; i < P_BA_N_PS; i = i + 1 ) begin
        always @ (posedge clock_i or negedge reset_ni) begin
            if ( reset_ni == 1'b0 ) begin
                cmd_ras_bank_picked[i] <= 1'b0;
            end
            else begin
                if ( ready_to_cmd_ras && (cmd_inter_selected == P_ROW_ACT || cmd_inter_selected == P_ROW_PRE || cmd_inter_selected == P_ROW_REFPB) && (i == actual_bank_serving[actual_bank_serving_index])) begin
                    cmd_ras_bank_picked[i] <= 1'b1;
                end
                else if ( cmd_ras_bank_picked[i] == 1'b1 && cmd_ras_bank[i] != P_GENERAL_NOP ) begin
                    cmd_ras_bank_picked[i] <= 1'b0;
                end
            end 
        end 
    end
endgenerate

/**********************************/
/* ACTUAL BANK SERVING MANAGEMENT */
/**********************************/
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

/*********************************/
/* BANK GROUP SERVING MANAGEMENT */
/*********************************/
always @(posedge clock_i or negedge reset_ni) begin : actual_bank_group_serving_driver
    if (reset_ni == 1'b0) begin
        actual_bank_serving_index <= 4'd0;
        actual_bank_group_serving <= {ACTUAL_BG_CMD_RAS_SERVING_WIDTH {1'b0}};
    end
    else begin
        if ( (cmd_inter_selected == P_ROW_ACT || cmd_inter_selected == P_ROW_PRE || cmd_inter_selected == P_ROW_REFPB) && ready_to_cmd_ras) begin
            actual_bank_serving_index <= actual_bank_serving_index + 1'b1;
            actual_bank_group_serving <= actual_bank_group_serving + 1'b1; 
        end
        else if ( ~(cmd_inter_selected == P_ROW_ACT || cmd_inter_selected == P_ROW_PRE || cmd_inter_selected == P_ROW_REFPB) || cmd_inter_selected == P_GENERAL_NOP) begin
            actual_bank_serving_index <= actual_bank_serving_index + 1'b1;
            actual_bank_group_serving <= actual_bank_group_serving + 1'b1; 
        end
        else begin
            actual_bank_serving_index <= actual_bank_serving_index;
            actual_bank_group_serving <= actual_bank_group_serving;
        end
    end
end

endmodule
