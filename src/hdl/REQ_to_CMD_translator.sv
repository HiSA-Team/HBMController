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

module REQ_to_CMD_translator# 
(
    parameter P_REQ_WIDTH       = 2,
    parameter P_ADDR_WIDTH      = 33,
    parameter P_DATA_WIDTH      = 256,
    parameter P_ROW_ADDR_WIDTH  = 14,
    parameter P_COL_ADDR_WIDTH  = 6,
    parameter P_BA_ADDR_WIDTH   = 5,
    parameter P_QUEUE_LEN       = 32,
    
    /* REQUESTS */
    parameter P_WRT_REQ        = 2'd0,
    parameter P_RD_REQ         = 2'd1,

    /* COMMANDS */
    parameter P_GENERAL_NOP    =  4'b1111,

    /* ROW COMMANDS */
    parameter P_ROW_NOP		   = 3'b111,
    parameter P_ROW_ACT		   = 3'b010,
    parameter P_ROW_PRE		   = 3'b011, 
    parameter P_ROW_PREA	   = 3'b011,

    /* COL COMMANDS */
    parameter P_COL_WRT		   = 4'b0001,
    parameter P_COL_RD         = 4'b0101,
    
    parameter       P_REQ_ID_WIDTH = 32'd6,
    parameter       P_CMD_ID_WIDTH = 32'd3

)
(
    input clk,
    input rst_n,
    
    input [P_REQ_ID_WIDTH-1:0]     input_req_id,
    input [P_REQ_WIDTH-1  : 0]     input_request,

    input [P_ROW_ADDR_WIDTH-1 : 0] row_address,
    input [P_COL_ADDR_WIDTH-1 : 0] column_address,
    input [P_BA_ADDR_WIDTH-1  : 0] bank_address,

    input                         request_valid,
    output                        request_picked,
   
    input                              cmd_picked,
    output [3:0]                       cmd,
    output [P_REQ_ID_WIDTH-1:0]        req_id,
    output [P_CMD_ID_WIDTH-1:0]       cmd_id,
    output [P_BA_ADDR_WIDTH-1  : 0]    bank_addr,
    output [P_ROW_ADDR_WIDTH-1 : 0]    row_addr,
    output [P_COL_ADDR_WIDTH-1 : 0]    col_addr
);

/* Command Queue */
/* CMD queue after the translation */
(* rw_addr_collision = "yes" *)(* ram_style = "auto" *) reg [P_REQ_ID_WIDTH-1:0]      req_id_queue       [0 : P_QUEUE_LEN-1];
(* rw_addr_collision = "yes" *)(* ram_style = "auto" *) reg [P_CMD_ID_WIDTH-1:0]      cmd_id_queue       [0 : P_QUEUE_LEN-1];
(* rw_addr_collision = "yes" *)(* ram_style = "auto" *) reg [3:0]                     cmd_queue          [0 : P_QUEUE_LEN-1];
(* rw_addr_collision = "yes" *)(* ram_style = "auto" *) reg [P_BA_ADDR_WIDTH-1  : 0]  bank_address_queue [0 : P_QUEUE_LEN-1];
(* rw_addr_collision = "yes" *)(* ram_style = "auto" *) reg [P_ROW_ADDR_WIDTH-1 : 0]  row_address_queue  [0 : P_QUEUE_LEN-1];
(* rw_addr_collision = "yes" *)(* ram_style = "auto" *) reg [P_COL_ADDR_WIDTH-1 : 0]  col_address_queue  [0 : P_QUEUE_LEN-1]; 
// reg [P_DATA_WIDTH-1     : 0]  data_queue         [0 : P_QUEUE_LEN-1];

reg [P_REQ_ID_WIDTH-1:0]      r_bank_req_id;
reg [P_CMD_ID_WIDTH-1:0]      r_bank_cmd_id;
reg [3:0]                     r_cmd;
reg [P_BA_ADDR_WIDTH-1  : 0]  r_bank_addr;
reg [P_ROW_ADDR_WIDTH-1 : 0]  r_row_addr;
reg [P_COL_ADDR_WIDTH-1 : 0]  r_col_addr;
// reg [P_DATA_WIDTH-1     : 0]  r_wrt_data;


assign req_id    = r_bank_req_id;
assign cmd_id    = r_bank_cmd_id;
assign cmd       = r_cmd;
assign bank_addr = r_bank_addr;
assign row_addr  = r_row_addr;
assign col_addr  = r_col_addr;
// assign wrt_data  = r_wrt_data;

localparam INDEX_QUEUE_WIDTH = $clog2(P_QUEUE_LEN);

reg [INDEX_QUEUE_WIDTH-1 : 0] head;
reg [INDEX_QUEUE_WIDTH-1 : 0] tail;
reg [INDEX_QUEUE_WIDTH   : 0] queue_cnt;



reg r_request_picked;
assign request_picked = r_request_picked;

/* Actual active row */
reg [P_ROW_ADDR_WIDTH : 0]    actual_row_open;

wire incr_queue_cnt;
wire incr_three_queue_cnt;
wire deincr_queue_cnt;
 

assign incr_queue_cnt        =  request_valid && (actual_row_open == row_address) && (queue_cnt < P_QUEUE_LEN);
assign incr_three_queue_cnt  =  request_valid && actual_row_open != row_address && queue_cnt < P_QUEUE_LEN-3;

assign deincr_queue_cnt      =  cmd_picked && queue_cnt > 0;



/************************/
/* QUEUE CNT MANAGEMENT */
/************************/

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


/**************************************************/ 
/* ACTUAL ACTIVE ROW MANAGEMENT - OPEN ROW POLICY */
/**************************************************/ 

always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        actual_row_open <= { P_ROW_ADDR_WIDTH+1 { 1'b1 } };
    end
    else begin
        if (request_valid && actual_row_open[P_ROW_ADDR_WIDTH:0] != row_address && queue_cnt < P_QUEUE_LEN-3) begin
            actual_row_open <= {1'b0, row_address};
        end
        else begin
            actual_row_open <= actual_row_open;
        end
    end
end


/**********************************/
/* TRANSLATION AND FILL THE QUEUE */
/**********************************/

always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        r_request_picked <= 1'b0;
        head <= { INDEX_QUEUE_WIDTH { 1'b0 } };
        for ( integer i = 0; i < P_QUEUE_LEN; i = i + 1 ) begin
            cmd_queue[i]               <= 4'b1111;
            bank_address_queue[i]      <= { P_BA_ADDR_WIDTH  { 1'b0 } };
            row_address_queue[i]       <= { P_ROW_ADDR_WIDTH { 1'b0 } };
            col_address_queue[i]       <= { P_COL_ADDR_WIDTH { 1'b0 } };
            // data_queue[i]              <= { P_DATA_WIDTH { 1'b0 } };
            req_id_queue[i]            <= { P_REQ_ID_WIDTH { 1'b0 } };
            cmd_id_queue[i]            <= { P_CMD_ID_WIDTH { 1'b0 } };
        end
    end
    else begin
        if ( request_valid && actual_row_open[P_ROW_ADDR_WIDTH:0] == row_address && queue_cnt < P_QUEUE_LEN) begin
            // if ( actual_row_open[P_ROW_ADDR_WIDTH:0] == row_address ) begin
                // if ( queue_cnt < P_QUEUE_LEN ) begin
                    if ( input_request == P_WRT_REQ ) begin
                        cmd_queue      [head]  <= P_COL_WRT;
                    end 
                    else if ( input_request == P_RD_REQ ) begin
                        cmd_queue      [head]  <= P_COL_RD;
                    end
                    
                    bank_address_queue [head]  <= bank_address;
                    row_address_queue  [head]  <= row_address;
                    col_address_queue  [head]  <= column_address;
                    // data_queue         [head]  <= input_data;
                    req_id_queue       [head]  <= input_req_id;
                    cmd_id_queue       [head]  <= 1'b0;

    
                    head <= head + 1'b1;
                    r_request_picked <= 1'b1;
                // end
                // else begin
                //     head <= head;
                //     r_request_picked <= 1'b0;
                // end
            end
            else if (request_valid && queue_cnt < P_QUEUE_LEN-3) begin
                // if ( queue_cnt < P_QUEUE_LEN-3 ) begin
                    cmd_queue          [head]        <= P_ROW_PRE;
                    bank_address_queue [head]        <= bank_address;
                    row_address_queue  [head]        <= row_address;
                    col_address_queue  [head]        <= column_address;
                    // data_queue         [head]        <= input_data;
                    req_id_queue       [head]        <= input_req_id;
                    cmd_id_queue       [head]        <= 1'b0;
                    
                    cmd_queue          [head+1'b1]   <= P_ROW_ACT;
                    bank_address_queue [head+1'b1]   <= bank_address;
                    row_address_queue  [head+1'b1]   <= row_address;
                    col_address_queue  [head+1'b1]   <= column_address;
                    // data_queue         [head+1'b1]   <= input_data;
                    req_id_queue       [head+1'b1]   <= input_req_id;
                    cmd_id_queue       [head+1'b1]   <= 1'b1;
                    
                    if ( input_request == P_WRT_REQ ) begin
                        cmd_queue      [head+2'b10]  <= P_COL_WRT;
                    end
                    else if ( input_request == P_RD_REQ ) begin
                        cmd_queue      [head+2'b10]  <= P_COL_RD;
                    end
                    bank_address_queue [head+2'b10]  <= bank_address;
                    row_address_queue  [head+2'b10]  <= row_address;
                    col_address_queue  [head+2'b10]  <= column_address;
                    // data_queue         [head+2'b10]  <= input_data;
                    req_id_queue       [head+2'b10]  <= input_req_id;
                    cmd_id_queue       [head+2'b10]  <= 2'b10;
                    
                    head <= head + 2'b11;
                    r_request_picked <= 1'b1;
                // end
                // else begin
                //     head <= head;
                //     r_request_picked <= 1'b0;
                // end
            end            
        // end
        else begin
            head <= head;
            r_request_picked <= 1'b0;
        end
    end
end

/************************************/
/* SEND A COMMAND TO BANK SCHEDULER */
/************************************/
always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        tail               <= { INDEX_QUEUE_WIDTH { 1'b0 } };
        r_cmd              <= P_GENERAL_NOP;
        r_bank_addr        <= { P_BA_ADDR_WIDTH  { 1'b0 } };
        r_row_addr         <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        r_col_addr         <= { P_COL_ADDR_WIDTH { 1'b0 } };
        // r_wrt_data         <= { P_DATA_WIDTH { 1'b0 } };
        r_bank_req_id      <= { P_REQ_ID_WIDTH { 1'b0 } };
        r_bank_cmd_id      <= { P_CMD_ID_WIDTH { 1'b0 } };
    end
    else begin
        if ( cmd_picked && queue_cnt > 0 ) begin
            r_cmd          <=    cmd_queue          [tail];
            r_bank_addr    <=    bank_address_queue [tail];
            r_row_addr     <=    row_address_queue  [tail];
            r_col_addr     <=    col_address_queue  [tail];
            r_bank_req_id  <=    req_id_queue       [tail];
            r_bank_cmd_id  <=    cmd_id_queue       [tail];
             
            tail           <=    tail + 1'b1;
        end
        else if(cmd_picked && queue_cnt == 0)begin
            r_cmd          <=    P_GENERAL_NOP;
            tail           <=    tail;
        end
    end
end

endmodule
