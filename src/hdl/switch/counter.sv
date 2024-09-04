`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.07.2024 11:42:25
// Design Name: 
// Module Name: counter
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


module counter(
        input logic clock_250,
        input logic clock_450,
        input logic reset,
        input logic plus,
        input logic minus,
        output logic count_positive
    );
    
    integer count_wr=0;
    integer count_rd=0;
    
    always_ff @(posedge clock_250) begin
        if (reset)
            count_rd <= 0;
        else
            if(minus && (count_wr - count_rd > 0)) count_rd <= count_rd+1; ///ERA -1 e funzionava
            
    end
    
    always_ff @(posedge clock_450) begin
        if (reset)
            count_wr <= 0;
        else
            if(plus) count_wr <= count_wr+1;
    end
    
    always_ff @(posedge clock_250) begin
        if (reset) begin
            count_positive <= 0;
        end else begin
            if (count_wr - count_rd > 0) 
                count_positive <= 1;
            else
                count_positive <= 0;
        end
    end
    
endmodule
