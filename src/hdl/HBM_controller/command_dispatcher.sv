`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/25/2023 09:05:44 AM
// Design Name: 
// Module Name: command_dispatcher
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

/* Prende in ingresso richieste, le traduce in comandi appena arrivano e accoda i comandi verso i bank scheduler */
module command_dispatcher# 
(
    parameter P_REQ_WIDTH       = 2,
    parameter P_ADDR_WIDTH      = 33,
    parameter P_DATA_WIDTH      = 256,
    parameter P_ROW_ADDR_WIDTH  = 16,
    parameter P_COL_ADDR_WIDTH  = 12,
    parameter P_BA_ADDR_WIDTH   = 5,
    parameter P_QUEUE_LEN       = 16

)
(
    input clk,
    input rst_n,
    
    /* Interfaccia verso l'esterno */
    input [P_REQ_WIDTH-1  : 0]    input_request,
    input [P_ADDR_WIDTH-1 : 0]    input_address,
    input [P_DATA_WIDTH-1 : 0]    input_data,
    input                         request_valid,
    output                        request_picked,
   
    /* Interfaccia verso il bank scheduler */
//    input  [P_ROW_ADDR_WIDTH-1 : 0]    actual_row_open,
    input                              cmd_picked,
    output [3:0]                       cmd,
    output [P_BA_ADDR_WIDTH-1  : 0]    bank_addr,
    output [P_ROW_ADDR_WIDTH-1 : 0]    row_addr,
    output [P_COL_ADDR_WIDTH-1 : 0]    col_addr,
    output [P_DATA_WIDTH-1     : 0]    wrt_data

);

/* Command Queue */
/* Coda dei comandi dopo che sono stati tradotti */
reg [3:0]                     cmd_queue          [0 : P_QUEUE_LEN-1];
reg [P_BA_ADDR_WIDTH-1  : 0]  bank_address_queue [0 : P_QUEUE_LEN-1];
reg [P_ROW_ADDR_WIDTH-1 : 0]  row_address_queue  [0 : P_QUEUE_LEN-1];
reg [P_COL_ADDR_WIDTH-1 : 0]  col_address_queue  [0 : P_QUEUE_LEN-1]; 
reg [P_DATA_WIDTH-1     : 0]  data_queue         [0 : P_QUEUE_LEN-1];

reg [3:0]                     r_cmd;
reg [P_BA_ADDR_WIDTH-1  : 0]  r_bank_addr;
reg [P_ROW_ADDR_WIDTH-1 : 0]  r_row_addr;
reg [P_COL_ADDR_WIDTH-1 : 0]  r_col_addr;
reg [P_DATA_WIDTH-1     : 0]  r_wrt_data;

assign cmd       = r_cmd;
assign bank_addr = r_bank_addr;
assign row_addr  = r_row_addr;
assign col_addr  = r_col_addr;
assign wrt_data  = r_wrt_data;

localparam INDEX_QUEUE_WIDTH = $clog2(P_QUEUE_LEN);

reg [INDEX_QUEUE_WIDTH-1 : 0] head;
reg [INDEX_QUEUE_WIDTH-1 : 0] tail;
reg [INDEX_QUEUE_WIDTH   : 0] queue_cnt;

/* REQUESTS */
localparam LP_WRT_REQ = 2'd0;
localparam LP_RD_REQ  = 2'd1;

/* COMMANDS */
localparam LP_GENERAL_NOP   =  4'b1111;

/* ROW COMMANDS */
localparam LP_ROW_NOP		= 3'b111;
localparam LP_ROW_ACT		= 3'b010;
localparam LP_ROW_PRE		= 3'b011;  //WITH R[10] -> L
localparam LP_ROW_PREA		= 3'b011;  // WITH R[10] -> H

/* COL COMMANDS */
localparam LP_COL_WRT		= 4'b0001;
localparam LP_COL_RD        = 4'b0101;

reg r_request_picked;
assign request_picked = r_request_picked;

/* Registro per tenere traccia dell'attuale riga attiva */
reg [P_ROW_ADDR_WIDTH : 0]    actual_row_open;

wire incr_queue_cnt;
wire incr_three_queue_cnt;
wire deincr_queue_cnt;

assign incr_queue_cnt        =  request_valid && (actual_row_open == input_address[(P_ROW_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH): P_COL_ADDR_WIDTH]) && (queue_cnt < P_QUEUE_LEN);
assign incr_three_queue_cnt  =  request_valid && actual_row_open != input_address[(P_ROW_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH): P_COL_ADDR_WIDTH] && queue_cnt < P_QUEUE_LEN-3;
assign deincr_queue_cnt      =  cmd_picked && queue_cnt > 0;

always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        queue_cnt <= { INDEX_QUEUE_WIDTH+1 { 1'b0 } };
    end
    else begin
        if ( incr_queue_cnt && ~incr_three_queue_cnt && ~deincr_queue_cnt ) begin
            queue_cnt <= queue_cnt + 1'b1;
        end
        else if ( ~incr_queue_cnt && incr_three_queue_cnt && ~deincr_queue_cnt) begin
            queue_cnt <= queue_cnt + 2'b11;
        end
        else if (~incr_queue_cnt && ~incr_three_queue_cnt && deincr_queue_cnt) begin
            queue_cnt <= queue_cnt - 1'b1;
        end
        else if (incr_queue_cnt && ~incr_three_queue_cnt && deincr_queue_cnt) begin
            queue_cnt <= queue_cnt;
        end
        else if (~incr_queue_cnt && incr_three_queue_cnt && deincr_queue_cnt) begin
            queue_cnt <= queue_cnt + 2'b10;
        end
        else begin
            queue_cnt <= queue_cnt;
        end
    end
end


always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        actual_row_open <= { P_ROW_ADDR_WIDTH+1 { 1'b1 } };
        
    end
    else begin
        if (request_valid && actual_row_open != input_address[(P_ROW_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH): P_COL_ADDR_WIDTH] && queue_cnt < P_QUEUE_LEN-3) begin
            actual_row_open <= input_address[(P_ROW_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH): P_COL_ADDR_WIDTH];
        end
        else begin
            actual_row_open <= actual_row_open;
        end
    end
end

always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        r_request_picked <= 1'b0;
        head <= { INDEX_QUEUE_WIDTH { 1'b0 } };
        for ( integer i = 0; i < P_QUEUE_LEN; i = i + 1 ) begin
            cmd_queue[i]               <= 4'b1111;
            bank_address_queue[i]      <= { P_BA_ADDR_WIDTH  { 1'b0 } };
            row_address_queue[i]       <= { P_ROW_ADDR_WIDTH { 1'b0 } };
            col_address_queue[i]       <= { P_COL_ADDR_WIDTH { 1'b0 } };
            data_queue[i]              <= { { 1'b0 } };
        end


    end
    else begin
        if ( request_valid ) begin
            if ( actual_row_open == input_address[(P_ROW_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH): P_COL_ADDR_WIDTH] ) begin
                if ( queue_cnt < P_QUEUE_LEN ) begin
                    if ( input_request == LP_WRT_REQ ) begin
                        cmd_queue      [head]  <= LP_COL_WRT;
                    end 
                    else if ( input_request == LP_RD_REQ ) begin
                        cmd_queue      [head]  <= LP_COL_RD;
                    end
                    
                    bank_address_queue [head]  <= input_address[(P_BA_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH+P_ROW_ADDR_WIDTH): P_COL_ADDR_WIDTH+P_ROW_ADDR_WIDTH];
                    row_address_queue  [head]  <= input_address[(P_ROW_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH): P_COL_ADDR_WIDTH];
                    col_address_queue  [head]  <= input_address[P_COL_ADDR_WIDTH-1 : 0];
                    data_queue         [head]  <= input_data;
                    
                    head <= head + 1'b1;
                    r_request_picked <= 1'b1;
                end
                else begin
                    head <= head;
                    r_request_picked <= 1'b0;
                end
            end
            else begin
                if ( queue_cnt < P_QUEUE_LEN-3 ) begin
                    cmd_queue          [head]        <= LP_ROW_PRE;
                    bank_address_queue [head]        <= input_address[(P_BA_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH+P_ROW_ADDR_WIDTH): P_COL_ADDR_WIDTH+P_ROW_ADDR_WIDTH];
                    row_address_queue  [head]        <= input_address[(P_ROW_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH): P_COL_ADDR_WIDTH];
                    col_address_queue  [head]        <= input_address[P_COL_ADDR_WIDTH-1 : 0];
                    data_queue         [head]        <= input_data;
                    
                    cmd_queue          [head+1'b1]   <= LP_ROW_ACT;
                    bank_address_queue [head+1'b1]   <= input_address[(P_BA_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH+P_ROW_ADDR_WIDTH): P_COL_ADDR_WIDTH+P_ROW_ADDR_WIDTH];
                    row_address_queue  [head+1'b1]   <= input_address[(P_ROW_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH): P_COL_ADDR_WIDTH];
                    col_address_queue  [head+1'b1]   <= input_address[P_COL_ADDR_WIDTH-1 : 0];
                    data_queue         [head+1'b1]   <= input_data;
                    
                    if ( input_request == LP_WRT_REQ ) begin
                        cmd_queue      [head+2'b10]  <= LP_COL_WRT;
                    end
                    else if ( input_request == LP_RD_REQ ) begin
                        cmd_queue      [head+2'b10]  <= LP_COL_RD;
                    end
                    bank_address_queue [head+2'b10]  <= input_address[(P_BA_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH+P_ROW_ADDR_WIDTH): P_COL_ADDR_WIDTH+P_ROW_ADDR_WIDTH];
                    row_address_queue  [head+2'b10]  <= input_address[(P_ROW_ADDR_WIDTH-1 + P_COL_ADDR_WIDTH): P_COL_ADDR_WIDTH];
                    col_address_queue  [head+2'b10]  <= input_address[P_COL_ADDR_WIDTH-1 : 0];
                    data_queue         [head+2'b10]  <= input_data;
                    
                    head <= head + 2'b11;
                    r_request_picked <= 1'b1;
                end
                else begin
                    head <= head;
                    r_request_picked <= 1'b0;
                end
            end            
        end
        else begin
            head <= head;
            r_request_picked <= 1'b0;
        end
    end
end


always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        tail               <= { INDEX_QUEUE_WIDTH { 1'b0 } };
        r_cmd              <= LP_GENERAL_NOP;
        r_bank_addr        <= { P_BA_ADDR_WIDTH  { 1'b0 } };
        r_row_addr         <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        r_col_addr         <= { P_COL_ADDR_WIDTH { 1'b0 } };
        r_wrt_data         <= { { 1'b0 } };
    end
    else begin
        if ( cmd_picked && queue_cnt > 0 ) begin
            r_cmd          <=    cmd_queue          [tail];
            r_bank_addr    <=    bank_address_queue [tail];
            r_row_addr     <=    row_address_queue  [tail];
            r_col_addr     <=    col_address_queue  [tail];
            r_wrt_data     <=    data_queue         [tail];
            
            tail           <=    tail + 1'b1;
        end
    end
end

endmodule
