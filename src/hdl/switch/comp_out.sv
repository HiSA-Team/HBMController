`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.07.2024 11:42:25
// Design Name: 
// Module Name: comp_out
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


module comp_out(
        input clock,
        input reset,
        input logic ok_read,
        input logic count_positive,
        output logic en_rd
    );
    
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        S1      = 2'b01,
        S2      = 2'b10,
        S3      = 2'b11             //nuovo stato
    } state_t;

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
                en_rd = 1'b0;
                if(count_positive)
                    stato_pros = S1;
                else stato_pros = IDLE;
            end
            S1: begin
                en_rd = 1'b1;
                stato_pros = S2;
            end
            S2: begin
                en_rd = 1'b0;
                if(ok_read & count_positive)
                    stato_pros = S1;
                else if (ok_read & ~count_positive) stato_pros = S3;
                else stato_pros = S2;
            end
            S3: begin
                en_rd = 1'b1;
                stato_pros = IDLE;
            end
            default: stato_pros = IDLE;
        endcase

    end
endmodule
