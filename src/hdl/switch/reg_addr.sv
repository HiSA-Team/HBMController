`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.07.2024 12:47:06
// Design Name: 
// Module Name: reg_addr
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


module reg_addr_in(
        input logic clock,
        input logic reset,
        input logic read,
        input logic [32:0] addr_in,
        output logic [3:0] selection,
        output logic [28:0] addr_out
    );

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            addr_out <= 29'b0;
            selection <= 4'b0;
        end else begin
            if (read) begin
                selection <= addr_in[32:29];
                addr_out <= addr_in[28:0];
            end
        end
    end
    
endmodule

module reg_addr_out(
        input logic clock,
        input logic reset,
        input logic [28:0] addr_in,
        output logic [28:0] addr_out
    );

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            addr_out <= 29'b0;
        end else begin
            addr_out <= addr_in[28:0];
        end
    end
    
endmodule