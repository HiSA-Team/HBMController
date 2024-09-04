`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.07.2024 19:28:19
// Design Name: 
// Module Name: Mux_FIFO_write
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


module Mux_FIFO_write(
        input  logic [3:0]    select,
        input  logic [557:0]  data_in [15:0],
        output logic [557:0]  data_out
    );
    
    always_comb begin
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
            if (select == i) data_out = data_in[i];
            end
    end
endmodule
