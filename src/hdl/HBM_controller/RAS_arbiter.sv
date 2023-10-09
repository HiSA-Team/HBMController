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
    parameter       P_BA_N_PS        = 16,        /* Nunmero di Bank per PS */
    parameter       P_BA_N_G         = 8,         /* Numero di Bank per gruppo */ 
    parameter		P_ROW_ADDR_WIDTH = 16,
    parameter		P_BA_ADDR_WIDTH	 = 5     
)
(
    
    /* Clock e Reset */
    input            clk,
    input            rst_n,

    /* Interfaccia verso i command bank register */
    output [0 : P_BA_N_PS - 1]  cmd_ras_bank_picked,
    input  [3:0] cmd_ras_bank  [0 : P_BA_N_PS - 1],
    input  [P_BA_ADDR_WIDTH-1 : 0] bank_address_bank [0 : P_BA_N_PS - 1],
    input  [P_ROW_ADDR_WIDTH-1 : 0] row_address_bank [0 : P_BA_N_PS - 1],
    

    /* Interfaccia verso il ll_command_forwarder */
    input  ready_to_cmd_ras,
    output [3:0]cmd_ras,
    output [P_BA_ADDR_WIDTH-1 : 0] bank_address_ras,
    output [P_ROW_ADDR_WIDTH-1 : 0] row_address_ras 
    
);

localparam LP_GENERAL_NOP = 4'b1111;
localparam LP_COL_WRT	  = 4'b0001;
localparam LP_COL_RD      = 4'b0101;


reg [0 : P_BA_N_PS - 1] r_cmd_ras_bank_picked ;
assign cmd_ras_bank_picked = r_cmd_ras_bank_picked;

reg [3:0] r_cmd_ras;
reg [P_BA_ADDR_WIDTH-1 : 0] r_bank_address_ras;
reg [P_ROW_ADDR_WIDTH-1 : 0] r_row_address_ras; 

localparam LP_BG_N = P_BA_N_PS/P_BA_N_G;      /* Numero di Bank Groups per PS */
localparam ACTUAL_BG_CMD_RAS_SERVING_WIDTH = $clog2(P_BA_N_G);
localparam ACTUAL_BG_SERVING_WIDTH = $clog2(LP_BG_N);

reg [ACTUAL_BG_CMD_RAS_SERVING_WIDTH-1 : 0] actual_bg_cmd_ras_serving [0 : LP_BG_N - 1]; 
reg [ACTUAL_BG_SERVING_WIDTH - 1 : 0] actual_bg_serving;

reg [ACTUAL_BG_CMD_RAS_SERVING_WIDTH:0] selected_cmd_index;

assign cmd_ras = r_cmd_ras;
assign bank_address_ras = r_bank_address_ras;
assign row_address_ras = r_row_address_ras;

/* Cerco il cmd da prendere all'interno del gruppo che sto servendo al momento */
always_comb begin
    if (rst_n == 1'b0 ) begin
        selected_cmd_index <= {ACTUAL_BG_CMD_RAS_SERVING_WIDTH+1 { 1'b1 } };
    end
    else begin
        for ( integer i = actual_bg_cmd_ras_serving[actual_bg_serving]; i < P_BA_N_G; i = i + 1 ) begin
            selected_cmd_index <= i;
            if ( cmd_ras_bank[i+(actual_bg_serving*P_BA_N_G)] != LP_GENERAL_NOP && cmd_ras_bank[i+(actual_bg_serving*P_BA_N_G)] != LP_COL_WRT && cmd_ras_bank[i+(actual_bg_serving*P_BA_N_G)] != LP_COL_RD ) begin    /* Ho trovato il primo CMD Bank buono */
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
                r_cmd_ras_bank_picked[j] <= 1'b0;
            end
            else begin
                if (ready_to_cmd_ras && ((cmd_ras_bank[j] != LP_GENERAL_NOP) && (cmd_ras_bank[j] != LP_COL_WRT) && (cmd_ras_bank[j] != LP_COL_RD) )  && (selected_cmd_index != { ACTUAL_BG_CMD_RAS_SERVING_WIDTH+1 { 1'b1 }  } )  &&  ( (j >= (actual_bg_cmd_ras_serving[actual_bg_serving] + (actual_bg_serving*P_BA_N_G)))  && (j <= (selected_cmd_index + (actual_bg_serving*P_BA_N_G))) )) begin
                    r_cmd_ras_bank_picked[j] <= 1'b1;
                end
                else begin
                    r_cmd_ras_bank_picked[j] <= 1'b0;
                end 
            end
        end
    end
endgenerate


always @( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0 ) begin
        r_cmd_ras                 <= LP_GENERAL_NOP;
        r_bank_address_ras        <= { P_BA_ADDR_WIDTH  { 1'b0 } };
        r_row_address_ras         <= { P_ROW_ADDR_WIDTH { 1'b0 } };   
    end
    else begin
        if ( ready_to_cmd_ras && (cmd_ras_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)] != LP_GENERAL_NOP) && (cmd_ras_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)] != LP_COL_WRT) && (cmd_ras_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)] != LP_COL_RD) && (selected_cmd_index != { ACTUAL_BG_CMD_RAS_SERVING_WIDTH+1 { 1'b1 }  } )) begin
            r_cmd_ras           <= cmd_ras_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)];
            r_bank_address_ras  <= bank_address_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)] ;
            r_row_address_ras   <= row_address_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)];
        end 
        else if (ready_to_cmd_ras && ((cmd_ras_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)] == LP_GENERAL_NOP) || ( cmd_ras_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)] != LP_COL_WRT ) || ( cmd_ras_bank[selected_cmd_index+(actual_bg_serving*P_BA_N_G)] != LP_COL_RD ) )  && (selected_cmd_index != { ACTUAL_BG_CMD_RAS_SERVING_WIDTH+1 { 1'b1 }  } )) begin
            r_cmd_ras <= LP_GENERAL_NOP;
        end
    end         
end

always @( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0 ) begin        
        /* Solitamente ci sono 2 Bank Group a PS (è quasi sempre così, credo che nelle Alveo sia sempre così) */
        actual_bg_cmd_ras_serving[0] <= { ACTUAL_BG_CMD_RAS_SERVING_WIDTH { 1'b0 } };
        actual_bg_cmd_ras_serving[1] <= { ACTUAL_BG_CMD_RAS_SERVING_WIDTH { 1'b0 } };
        
     end
     else begin
        if ( ( ready_to_cmd_ras ) && (selected_cmd_index != { ACTUAL_BG_CMD_RAS_SERVING_WIDTH+1 { 1'b1 }  } )) begin 
            if ( actual_bg_cmd_ras_serving[actual_bg_serving] <  P_BA_N_G -1 ) begin
                actual_bg_cmd_ras_serving[actual_bg_serving] <= selected_cmd_index + 1'b1;
            end
            else begin
                actual_bg_cmd_ras_serving[actual_bg_serving] <= { ACTUAL_BG_CMD_RAS_SERVING_WIDTH {1'b0} };
            end
        end
    end
end

always @( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0 ) begin        
        actual_bg_serving <= { ACTUAL_BG_SERVING_WIDTH { 1'b0 } };
    end
    else begin
        if ( (ready_to_cmd_ras) && (selected_cmd_index != { ACTUAL_BG_CMD_RAS_SERVING_WIDTH+1 { 1'b1 }  } )) begin 
            if ( actual_bg_serving < LP_BG_N - 1 ) begin
                actual_bg_serving <= actual_bg_serving + 1'b1;
            end
            else begin
                actual_bg_serving <= {ACTUAL_BG_SERVING_WIDTH { 1'b0 } };
            end
        end
    end
end

endmodule
