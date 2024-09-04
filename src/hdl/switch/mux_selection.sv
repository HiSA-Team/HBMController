`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.07.2024 11:43:34
// Design Name: 
// Module Name: mux_selection
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


module mux_selection(
        input logic req,
        input logic [3:0] sel_read,
        input logic [3:0] sel_write,
        output logic [3:0] selection
    );
    
    always_comb begin
        if (req == 1'b0)
            selection = sel_write;
        else selection = sel_read;
    end
endmodule
