`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.07.2024 17:26:34
// Design Name: 
// Module Name: Demux_Read
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

module Mux_Read(
        input  logic [3:0]    select,
        input  logic [511:0]  data_in [15:0],
        output logic [511:0]  data_out
    );
    
    always_comb begin
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
            if (select == i) data_out = data_in[i];
            end
    end

endmodule
