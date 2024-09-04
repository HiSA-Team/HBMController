`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.07.2024 19:58:01
// Design Name: 
// Module Name: reg_signal
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


module reg_signal(
        input clock,
        input reset,
        input signal_in,
        output reg signal_out
    );
    
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            signal_out <= 1'b0;
        end else begin
            signal_out <= signal_in;
        end
    end
    
endmodule

