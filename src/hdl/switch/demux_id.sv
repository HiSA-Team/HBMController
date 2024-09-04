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


module demux_id(
    input  logic [3:0]    select,
    input  logic [7:0]  data_in,
    output logic [7:0]  data_out [15:0]
);

    always_comb begin
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
            if (select == i) data_out[i] = data_in;
            else data_out[i] = 8'b0;
            end
        end

endmodule