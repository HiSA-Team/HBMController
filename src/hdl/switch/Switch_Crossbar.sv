`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.07.2024 12:21:11
// Design Name: 
// Module Name: operational_switch
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

module control_switch(
    input logic clock,      //from system
    input logic reset,
    
    input logic ar_valid,    //from requester
    input logic aw_valid,
    input logic w_valid,
    input logic b_ready,
    input logic r_ready,
    
    input logic picked_c,   //from operational
    input logic valid_read,
    input logic read_complete,
    
    output logic aw_ready,  //to requester
    output logic w_ready,
    output logic ar_ready,
    output logic b_valid,
    output logic r_valid,
    
    output logic read_en_addr_read,        //to operational
    output logic read_en_addr_write,
    output logic read_en_write,
    output logic valid_c,
    output logic req_c,
    output logic read_en_read,
    output logic ok_read,
    
    output logic read_id_ws,
    output logic read_id_wr,
    output logic read_id_rs,
    output logic read_id_rr
);

    typedef enum logic [3:0] {
        IDLE    = 4'b0000,
        W1      = 4'b0001,
        W2      = 4'b0010,
        W4      = 4'b0011,
        W5      = 4'b0100,
        R1      = 4'b0101,
        R2      = 4'b0110,
        R4      = 4'b0111,
        R5      = 4'b1000,
        W3  = 4'b1001,
        R3  = 4'b1010,
        IDLE1 = 4'b1011,
        R6 = 4'b1100
    } state_t;

    state_t stato_corr, stato_pros, stato_corr1, stato_pros1;

    always_ff @(posedge clock) begin
        if (reset) begin
            stato_corr <= IDLE;
            stato_corr1 <= IDLE1;
        end
        else begin
            stato_corr <= stato_pros;
            stato_corr1 <= stato_pros1;
        end
    end

    always_comb begin

        case (stato_corr)
            IDLE: begin
                // Valori di default per le uscite
                /*read_en_addr_r = 1'b0;
                read_en_write_r = 1'b0;
                picked_r = 1'b0;
                valid_c = 1'b0;
                write_en_addr_c = 1'b0;
                write_en_write_c = 1'b0;
                read_en_read_c_read_r = 1'b0;*/
                b_valid = 1'b0;
                if (ar_valid == 1'b1) 
                    stato_pros = R1;
                else if (aw_valid == 1'b1 & w_valid == 1'b1)
                    stato_pros = W1;
                else stato_pros = IDLE;
            end
            W1: begin
                
                read_en_addr_write = 1'b1;
                read_en_write = 1'b1;
                aw_ready = 1'b1;
                w_ready = 1'b1;
                req_c = 1'b0;
                read_id_ws = 1'b1;
                stato_pros = W2;
            end
            W2: begin
                read_en_addr_write = 1'b0;
                read_en_write = 1'b0;
                aw_ready = 1'b0;
                w_ready = 1'b0;
                read_id_ws = 1'b0;
                valid_c = 1'b1;
                stato_pros = W3;
            end
            W3: begin
                valid_c = 1'b0;
                if(picked_c == 1'b1)
                    stato_pros = W4;
                else stato_pros = W3;
            end
            W4: begin
                read_id_wr = 1'b1;
                stato_pros = W5;
            end
            W5: begin
                read_id_wr = 1'b0;
                b_valid = 1'b1;
                if (b_ready == 1'b1 & ar_valid == 1'b0)
                    stato_pros = IDLE;
                else if (b_ready == 1'b1 & ar_valid == 1'b1)
                    stato_pros = R1;
            end
            R1: begin
                b_valid = 1'b0;
                
                read_id_rs = 1'b1;
                read_en_addr_read = 1'b1;
                req_c = 1'b1;
                ar_ready = 1'b1;
                stato_pros = R2;
            end
            R2: begin
                read_en_addr_read = 1'b0;
                ar_ready = 1'b0;
                read_id_rs = 1'b0;
                
                valid_c = 1'b1;
                stato_pros = R3;
            end
            R3: begin
                valid_c = 1'b0;
                if(picked_c == 1'b1 & (aw_valid == 1'b0 | w_valid == 1'b0))
                    stato_pros = IDLE;
                else if (picked_c == 1'b1 & aw_valid == 1'b1 & w_valid == 1'b1)
                    stato_pros = W1;
            end
            
            default: stato_pros = IDLE;
        endcase
    end
    
    
    always_comb begin

        case (stato_corr1)
            IDLE1: begin
                if (valid_read == 1'b1)
                    stato_pros1 = R4;
            end
            R4: begin
                read_en_read = 1'b1;
                read_id_rr = 1'b1;
                ok_read = 1'b1;
                stato_pros1 = R5;
            end
            R5: begin
                read_en_read = 1'b0;
                read_id_rr = 1'b0;
                ok_read = 1'b0;
                
                r_valid = 1'b1;
                if (r_ready == 1'b1)
                    stato_pros1 = R6;
            end
            R6: begin
                r_valid = 1'b0;
                if (read_complete == 1'b1)
                    stato_pros1 = IDLE1;
            end
                default: stato_pros1 = IDLE1;
        endcase
    end
endmodule
