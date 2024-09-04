`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.07.2024 11:44:15
// Design Name: 
// Module Name: reg_selection
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


module reg_selection(
        input logic clock,
        input logic reset,
        input logic [3:0] sel_in,
        output logic [3:0] sel_out
    );

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            sel_out <= 4'b0;
        end else begin
            sel_out <= sel_in[3:0];
        end
    end
endmodule