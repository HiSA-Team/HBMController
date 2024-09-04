`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.07.2024 15:05:39
// Design Name: 
// Module Name: Mux_Addr
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


module Mux_Addr(
    input  logic select,
    input  logic [28:0] addr_read,
    input  logic [28:0] addr_write,
    output  logic [28:0] addr_out
);

    always_comb begin
            if(select == 1'b0)
                addr_out = addr_write;
            else if(select == 1'b1)
                addr_out = addr_read;
        end

endmodule