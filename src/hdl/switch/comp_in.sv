`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.07.2024 11:47:02
// Design Name: 
// Module Name: comp_in
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


module comp_in(
        input clock,
        input reset,
        input logic [523:0] din,
        output logic en_wr
    );
    
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        S1      = 2'b01,
        S2      = 2'b10,
        S3      = 2'b11
    } state_t;
    
    reg [523:0] current = 0;

    state_t stato_corr, stato_pros;

    always_ff @(posedge clock) begin
        if (reset)
            stato_corr <= IDLE;
        else
            stato_corr <= stato_pros;
    end

    always_comb begin
        
        case (stato_corr)
            IDLE: begin
                en_wr = 1'b0;
                if(current != din)
                    stato_pros = S1;
                else stato_pros = IDLE;
            end
            S1: begin
                en_wr = 1'b1;
                current = din;
                stato_pros = IDLE;
            end
            default: stato_pros = IDLE;
        endcase
    end
endmodule
