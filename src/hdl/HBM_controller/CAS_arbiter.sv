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
    parameter       P_BA_N_PS       = 16,        /* Nunmero di Bank per PS */
    parameter       P_BA_N_G        = 8,         /* Numero di Bank per gruppo */ 
    parameter		P_COL_ADDR_WIDTH = 16,
    parameter		P_BA_ADDR_WIDTH	 = 5,
    parameter       P_DATA_WIDTH     = 256
)
(
    /* Clock e Reset */
    input            clk,
    input            rst_n,
    
    /* Interfaccia verso i command bank register */
    output [0 : P_BA_N_PS - 1] cmd_cas_bank_picked,
    input  [3:0] cmd_cas_bank  [0 : P_BA_N_PS - 1],
    input  [P_BA_ADDR_WIDTH-1 : 0] bank_address_bank [0 : P_BA_N_PS - 1],
    input  [P_COL_ADDR_WIDTH-1 : 0] column_address_bank [0 : P_BA_N_PS - 1],
    input  [P_DATA_WIDTH-1 : 0] wrt_data_bank [0 : P_BA_N_PS - 1],
//    output [P_DATA_WIDTH-1 : 0] rd_data_bank [0 : P_BA_N_PS - 1],
    
    /* Interfaccia verso il ll_command_forwarder */
    input  ready_to_cmd_cas,
    output [3:0] cmd_cas,
    output [P_BA_ADDR_WIDTH-1 : 0] bank_address_cas,
    output [P_COL_ADDR_WIDTH-1 : 0] column_address_cas,
    output [P_DATA_WIDTH-1   :  0 ] wrt_data_cas

);

localparam LP_GENERAL_NOP = 4'b1111;
localparam LP_COL_WRT		= 4'b0001;
localparam LP_COL_RD        = 4'b0101;

localparam LP_BG_N = P_BA_N_PS/P_BA_N_G;
localparam LP_ACTUAL_BANK_GROUP_SERVING_WIDTH = $clog2(LP_BG_N);
localparam LP_ACTUAL_BANK_SERVING_WIDTH       = $clog2(P_BA_N_G);

reg [ LP_ACTUAL_BANK_GROUP_SERVING_WIDTH - 1 : 0 ] actual_bank_group_serving ;
reg [ LP_ACTUAL_BANK_SERVING_WIDTH : 0 ] actual_bank_serving [0 : LP_BG_N - 1];
reg [ LP_ACTUAL_BANK_SERVING_WIDTH : 0 ] selected_bank_index;

reg [3:0] actual_cmd_serving_type;     /* Comando attuale RD o WRT */

wire incr_cmd_cnt_cas;
wire deincr_cmd_cnt_cas;

reg [3:0] r_cmd_cas;
assign cmd_cas = r_cmd_cas;

reg [P_DATA_WIDTH - 1 : 0] r_wrt_data_cas;
assign wrt_data_cas = r_wrt_data_cas;

reg [P_BA_ADDR_WIDTH - 1 : 0] r_bank_address_cas;
assign bank_address_cas = r_bank_address_cas;

reg [P_COL_ADDR_WIDTH - 1 : 0] r_column_address_cas;
assign column_address_cas = r_column_address_cas;

reg [0 : P_BA_N_PS - 1]r_cmd_cas_bank_picked;
assign cmd_cas_bank_picked = r_cmd_cas_bank_picked;

reg all_bad_type; 

//reg [7:0] bank_done_cnt [0:LP_BG_N-1];  /* Da vedere bene */

always_comb begin
    if ( rst_n == 1'b0 ) begin
        selected_bank_index <= { LP_ACTUAL_BANK_SERVING_WIDTH + 1 {1'b1} };
    end
    else begin
        all_bad_type <= 1'b1;
        for ( integer i = actual_bank_serving[actual_bank_group_serving]; i < P_BA_N_G; i = i + 1 ) begin
            selected_bank_index <= i;
            if ( cmd_cas_bank[i + (actual_bank_group_serving*P_BA_N_G)] != LP_GENERAL_NOP && cmd_cas_bank[i + (actual_bank_group_serving*P_BA_N_G)] == actual_cmd_serving_type ) begin
                all_bad_type <= 1'b0;
                break;
            end
        end
    end
end



genvar j;
generate 
    for ( j = 0; j < P_BA_N_PS; j = j + 1 ) begin
        always @ ( posedge clk or negedge rst_n ) begin    
            if (rst_n == 1'b0 ) begin
                r_cmd_cas_bank_picked[j] <= 1'b0;
            end
            else begin
                if ( ready_to_cmd_cas && ( (cmd_cas_bank[j] == actual_cmd_serving_type) /*|| (cmd_cas_bank[j] == LP_GENERAL_NOP) */ ) && (selected_bank_index != { LP_ACTUAL_BANK_SERVING_WIDTH+1 { 1'b1 }  } )  &&  ( (j >= ((actual_bank_serving[actual_bank_group_serving] + (actual_bank_group_serving*P_BA_N_G))))  && (j <= (selected_bank_index + (actual_bank_group_serving*P_BA_N_G))) )) begin
                    r_cmd_cas_bank_picked[j] <= 1'b1;
                end
                else begin
                    r_cmd_cas_bank_picked[j] <= 1'b0;
                end 
            end
        end
    end
endgenerate


always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        r_cmd_cas                 <= LP_GENERAL_NOP;
        r_wrt_data_cas            <=  { P_DATA_WIDTH     { 1'b0 } };
        r_bank_address_cas        <=  { P_BA_ADDR_WIDTH  { 1'b0 } };
        r_column_address_cas      <=  { P_COL_ADDR_WIDTH { 1'b0 } };   
    end
    else begin
        if ( ready_to_cmd_cas &&  all_bad_type == 1'b0 ) begin
            r_cmd_cas <= cmd_cas_bank[selected_bank_index + ( actual_bank_group_serving * P_BA_N_G )];
            r_bank_address_cas   <= bank_address_bank[selected_bank_index + ( actual_bank_group_serving * P_BA_N_G )];
            r_column_address_cas <= column_address_bank[selected_bank_index + ( actual_bank_group_serving * P_BA_N_G )];
            r_wrt_data_cas       <= wrt_data_bank[selected_bank_index + ( actual_bank_group_serving * P_BA_N_G )];
        end 
        else if (ready_to_cmd_cas &&  all_bad_type == 1'b1) begin
            r_cmd_cas           <= LP_GENERAL_NOP;
        end        
    end
end

wire  [0 : LP_BG_N-1] round_done;

always @ ( posedge clk or negedge rst_n ) begin 
    if ( rst_n == 1'b0 ) begin
        actual_bank_group_serving <= { LP_ACTUAL_BANK_GROUP_SERVING_WIDTH { 1'b0 } };
    end
    else begin
        if ( ready_to_cmd_cas ) begin
            if ( actual_bank_group_serving < LP_BG_N - 1 ) begin
                actual_bank_group_serving <= actual_bank_group_serving + 1'b1;
            end
            else begin
                actual_bank_group_serving <= { LP_ACTUAL_BANK_GROUP_SERVING_WIDTH { 1'b0 } };
            end
        end
        if ( &round_done ) begin
            actual_bank_group_serving <= actual_bank_group_serving;
        end
    end
end 


always @ ( posedge clk or negedge rst_n ) begin 
    if ( rst_n == 1'b0 ) begin
        actual_cmd_serving_type <= LP_COL_RD;
    end
    else begin
    if ( &round_done ) begin
            if (actual_cmd_serving_type == LP_COL_RD ) begin
                actual_cmd_serving_type <= LP_COL_WRT;
            end
            else begin
                actual_cmd_serving_type <= LP_COL_RD;
            end 
        end
    end
end

genvar k;
generate
    for ( k = 0; k <  LP_BG_N ; k = k + 1) begin
        assign round_done[k] = (actual_bank_serving[k] == P_BA_N_G) ? 1'b1 : 1'b0; 
        
        
        always @ ( posedge clk or negedge rst_n ) begin 
            if ( rst_n == 1'b0 ) begin        
                actual_bank_serving[k] <= { LP_ACTUAL_BANK_SERVING_WIDTH+1 { 1'b0 } };
            end
            else begin
                if ( ready_to_cmd_cas ) begin
                    if ( (k == actual_bank_group_serving) && ( actual_bank_serving[k] < P_BA_N_G )) begin
                        actual_bank_serving[k] <= selected_bank_index + 1'b1;
                    end 
                end
                if ( &round_done ) begin
                    actual_bank_serving[k] <= { LP_ACTUAL_BANK_SERVING_WIDTH+1 { 1'b0 } };
                end
            end
        end 
    end
endgenerate

 

endmodule
