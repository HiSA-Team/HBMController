`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.07.2024 11:36:46
// Design Name: 
// Module Name: reg_pipe
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


module reg_pipe(
        input logic clock,
        input logic reset,
        input logic [511:0] data_in,
        output logic [511:0] data_out
    );
    
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            data_out <= 512'b0;
        end else begin
            data_out <= data_in;
        end
    end
    
endmodule
