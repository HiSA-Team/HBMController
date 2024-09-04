`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2024 10:28:23
// Design Name: 
// Module Name: reg_data_req
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

module reg_data_req(
        input logic clock,
        input logic reset,
        input logic [557:0] data_in,
        output logic [557:0] data_out
    );

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            data_out <= 558'b0;
        end else begin
            data_out <= data_in[557:0];
        end
    end
    
endmodule
