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
    parameter       P_DATA_WIDTH     = 256,
    parameter       P_QUEUE_LEN = 16
)

(
    /* Clock e Reset */
    input            clk,
    input            rst_n,
    
    /* Interfaccia verso i command bank register */
//    output cmd_cas_bank_picked [0 : P_BA_N_PS - 1],
//    input  [3:0] cmd_cas_bank  [0 : P_BA_N_PS - 1],
    
    /* Interfaccia verso il ll_command_forwarder */
    input  ready_to_cmd_cas,
    output [3:0] cmd_cas,
    output [P_BA_ADDR_WIDTH-1 : 0] bank_address_cas,
    output [P_COL_ADDR_WIDTH-1 : 0] column_address_cas,
    output [P_DATA_WIDTH-1   :  0 ] wrt_data_cas


);
endmodule
