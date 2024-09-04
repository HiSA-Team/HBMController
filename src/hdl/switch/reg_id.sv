`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.07.2024 10:51:33
// Design Name: 
// Module Name: mux_id
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


module reg_id(
        input logic clock,
        input logic reset,
        input logic read,
        input logic [7:0] data_in,
        output logic [7:0] data_out
    );
    
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            data_out <= 8'b0;
        end else begin
            if (read) begin
                data_out <= data_in;
            end 
        end
    end
    
endmodule