`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.07.2024 17:59:15
// Design Name: 
// Module Name: Demux_Addr
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


module Demux_Signal (
    input  logic [3:0] select,
    input  logic data_in,
    output logic data_out [15:0]
);

    always_comb begin
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
            if (select == i) data_out[i] = data_in;
            else data_out[i] = 1'b0;
            end
        end

endmodule
