`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.07.2024 19:28:19
// Design Name: 
// Module Name: MEM_id_axi_addr
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


module MEM_id_axi_addr(
    input logic clock,
    input logic reset,
    input logic [7:0] id_write,
    input logic [7:0] id_read,
    input logic [3:0] addr_in,
    input logic en_write,
    output logic [3:0] addr_out
);

    typedef struct {
        logic [7:0] id;
        logic [3:0] addr;
    } mem_entry_t;

    mem_entry_t mem [15:0];

    logic [3:0] count = 4'b0000;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 16; i++) begin
                mem[i].id <= 8'b0;
                mem[i].addr <= 4'b0;
            end
            addr_out <= 4'b0000;
            count <= 4'b0000;
        end else begin
            if (en_write) begin                     //WRITE
                mem[count].id <= id_write;
                mem[count].addr <= addr_in;
                count <= (count + 1) % 16;
            end
                                                    //READ
            for (int i = 0; i < 16; i++) begin
                if (mem[i].id == id_read) begin
                    addr_out <= mem[i].addr;
                    break;
                end
            end
        end
    end


endmodule

