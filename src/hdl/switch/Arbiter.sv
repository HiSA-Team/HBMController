`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.07.2024 19:28:19
// Design Name: 
// Module Name: Arbiter
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


module Arbiter(
    input logic clock,
    input logic [15:0] prenota,
    input logic complete,
    output logic [3:0] addr_chosen
);

    logic [3:0] j = 4'b0000;
    logic occupato = 1'b0;

    always_ff @(posedge clock) begin
        if (complete) begin
            j = (j + 1) % 16;
            occupato = 1'b0;
            addr_chosen = 4'bx;
        end
        
        else if (~occupato) begin
            for (int i = 0; i < 16; i++) begin
                if (prenota[j] == 1) begin
                    addr_chosen = j;
                    occupato = 1'b1;
                    break;
                end
                j = (j + 1) % 16;
            end
        end
    end

endmodule

module Arbiter_read(
    input logic clock,
    input logic [15:0] prenota,
    output logic complete,
    output logic [3:0] addr_chosen
);

    logic [3:0] j = 4'b0000;
    logic occupato = 1'b0;

    always_ff @(posedge clock) begin
        if (!occupato) begin
            complete <= 1'b0;
            for (int i = 0; i < 16; i++) begin
                if (prenota[(j+i)%16] == 1) begin
                    j <= (j + i) % 16;
                    addr_chosen <= (j + i) % 16;
                    occupato <= 1'b1;
                    break;
                end
            end
        end else begin
            if (prenota[j] == 0) begin
                occupato <= 1'b0;
                complete <= 1'b1;
            end
        end
    end

endmodule



