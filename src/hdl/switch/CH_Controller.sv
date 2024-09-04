`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.07.2024 09:31:44
// Design Name: 
// Module Name: CH_Controller
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


module CH_Controller(

        input logic clock,      //from system
        input logic reset,
        
        input logic valid,         //from operational
        input logic req,
        input logic [28:0] address,
        input logic [511:0] write,
        
        input logic [7:0] id_ws,
        input logic [7:0] id_rs,
        
        output logic picked,       //to operational
        output logic [511:0] read,
        
        output logic [7:0] id_wr,
        output logic [7:0] id_rr
    );
    
    //integer count = 0;
    logic [511:0] read_data [7:0];
    logic [7:0] id_data [7:0];
    logic [511:0] buffer;
    logic [511:0] data [15:0];
    integer timer = 0;
    integer diff = 0;
    logic [511:0] READ;
    assign read = READ;
    
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        R      = 2'b01,
        W      = 2'b10
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
                picked = 1'b0;
                if (valid == 1'b1 & req == 1'b0)
                    stato_pros = W;
                else if (valid == 1'b1 & req == 1'b1)
                    stato_pros = R;
                else stato_pros = IDLE;
            end
            W: begin
                if (address[28] == 1'b1)
                    data[15] = write;
                else if (address[27] == 1'b1)
                    data[14] = write;
                else if (address[26] == 1'b1)
                    data[13] = write;
                else if (address[25] == 1'b1)
                    data[12] = write;
                else if (address[24] == 1'b1)
                    data[11] = write;
                else if (address[23] == 1'b1)
                    data[10] = write;
                else if (address[22] == 1'b1)
                    data[9] = write;
                else if (address[21] == 1'b1)
                    data[8] = write;
                else if (address[7] == 1'b1)
                    data[7] = write;
                else if (address[6] == 1'b1)
                    data[6] = write;
                else if (address[5] == 1'b1)
                    data[5] = write;
                else if (address[4] == 1'b1)
                    data[4] = write;
                else if (address[3] == 1'b1)
                    data[3] = write;
                else if (address[2] == 1'b1)
                    data[2] = write;
                else if (address[1] == 1'b1)
                    data[1] = write;
                else if (address[0] == 1'b1)
                    data[0] = write;
                
                picked = 1'b1;
                stato_pros = IDLE;
            end
            
            R: begin
                if (address[28])
                    buffer = data[15];
                else if (address[27])
                    buffer = data[14];
                else if (address[26])
                    buffer = data[13];
                else if (address[25])
                    buffer = data[12];
                else if (address[24])
                    buffer = data[11];
                else if (address[23])
                    buffer = data[10];
                else if (address[22])
                    buffer = data[9];
                else if (address[21])
                    buffer = data[8];
                else if (address[7])
                    buffer = data[7];
                else if (address[6])
                    buffer = data[6];
                else if (address[5])
                    buffer = data[5];
                else if (address[4])
                    buffer = data[4];
                else if (address[3])
                    buffer = data[3];
                else if (address[2])
                    buffer = data[2];
                else if (address[1])
                    buffer = data[1];
                else if (address[0])
                    buffer = data[0];
                
                READ = buffer;
                id_rr = id_rs;
                
                picked = 1'b1;
                
                stato_pros = IDLE;
            end
            default: stato_pros = IDLE;
        endcase
    end
    
    
endmodule
