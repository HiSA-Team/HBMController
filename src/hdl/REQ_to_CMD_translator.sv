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
    output [P_CMD_ID_WIDTH-1:0]        cmd_id,
    output [P_BA_ADDR_WIDTH-1  : 0]    bank_addr,
    output [P_ROW_ADDR_WIDTH-1 : 0]    row_addr,
    output [P_COL_ADDR_WIDTH-1 : 0]    col_addr
);

localparam INDEX_QUEUE_WIDTH = $clog2(P_QUEUE_LEN);

wire [P_REQ_ID_WIDTH+P_CMD_ID_WIDTH+4+P_BA_ADDR_WIDTH+P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH - 1 : 0] ram_data_in;
wire [P_REQ_ID_WIDTH+P_CMD_ID_WIDTH+4+P_BA_ADDR_WIDTH+P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH - 1 : 0] ram_data_out;

reg [P_CMD_ID_WIDTH-1:0] ram_cmd_id;
reg [3:0] ram_cmd;
reg ram_wrt_en;

assign ram_data_in = {input_req_id, ram_cmd_id, ram_cmd, bank_address, row_address, column_address};

reg [P_REQ_ID_WIDTH-1:0]      r_bank_req_id;
reg [P_CMD_ID_WIDTH-1:0]      r_bank_cmd_id;
reg [3:0]                     r_cmd;
reg [P_BA_ADDR_WIDTH-1  : 0]  r_bank_addr;
reg [P_ROW_ADDR_WIDTH-1 : 0]  r_row_addr;
reg [P_COL_ADDR_WIDTH-1 : 0]  r_col_addr;

assign req_id    = r_bank_req_id;
assign cmd_id    = r_bank_cmd_id;
assign cmd       = r_cmd;
assign bank_addr = r_bank_addr;
assign row_addr  = r_row_addr;
assign col_addr  = r_col_addr;

reg [INDEX_QUEUE_WIDTH-1 : 0] head;
reg [INDEX_QUEUE_WIDTH-1 : 0] tail;
reg [INDEX_QUEUE_WIDTH   : 0] queue_cnt;

reg r_request_picked;
assign request_picked = r_request_picked;

/* Actual active row */
reg [P_ROW_ADDR_WIDTH : 0]    actual_row_open;

wire incr_queue_cnt;
wire deincr_queue_cnt;
 
reg [1:0] push_three; 

assign incr_queue_cnt        =  (request_valid &&  push_three == 2'b00 && queue_cnt < P_QUEUE_LEN) || (push_three > 2'b00 && queue_cnt < P_QUEUE_LEN);
assign deincr_queue_cnt      =  cmd_picked && queue_cnt > 0;


/************************/
/* QUEUE CNT MANAGEMENT */
/************************/

always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        queue_cnt  <= {INDEX_QUEUE_WIDTH+1{1'b0}};
    end 
    else begin
        if ( incr_queue_cnt && ~deincr_queue_cnt ) begin
            queue_cnt <= queue_cnt + 1'b1;
        end 
        else if ( ~incr_queue_cnt && deincr_queue_cnt ) begin
            queue_cnt <= queue_cnt - 1'b1;
        end
        else if ( incr_queue_cnt && deincr_queue_cnt ) begin
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
        push_three <= 1'b0;
    end
    else begin
        if ( push_three == 2'b00 && request_valid && actual_row_open[P_ROW_ADDR_WIDTH:0] != row_address && queue_cnt < P_QUEUE_LEN) begin
            actual_row_open <= {1'b0, row_address};
            push_three <= 2'b01;
        end
        else if (push_three == 2'b01 && queue_cnt < P_QUEUE_LEN) begin
            push_three <= 2'b10;
        end
        else if (push_three == 2'b10 && queue_cnt < P_QUEUE_LEN) begin
            push_three <= 2'b00;
        end
        else begin
            actual_row_open <= actual_row_open;
            push_three <= push_three;
        end
    end
end


/**********************************/
/* TRANSLATION AND FILL THE QUEUE */
/**********************************/

always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        ram_cmd <= P_GENERAL_NOP;
        ram_cmd_id <= {P_CMD_ID_WIDTH{1'b1}};
        r_request_picked <= 1'b0;
        head <= { INDEX_QUEUE_WIDTH { 1'b0 } };
        ram_wrt_en <= 1'b0;
    end
    else begin
        if (push_three == 2'b00 && request_valid && actual_row_open[P_ROW_ADDR_WIDTH:0] == row_address && queue_cnt < P_QUEUE_LEN) begin
            if ( input_request == P_WRT_REQ ) begin
                ram_cmd <= P_COL_WRT;
            end 
            else if ( input_request == P_RD_REQ ) begin
                ram_cmd <= P_COL_RD;
            end
            ram_cmd_id           <= 1'b0;


            ram_wrt_en           <= 1'b1;
            head                 <= head + 1'b1;
            r_request_picked     <= 1'b1;
        end
        else if (push_three == 2'b00 && request_valid && actual_row_open[P_ROW_ADDR_WIDTH:0] != row_address && queue_cnt < P_QUEUE_LEN) begin
            ram_cmd              <= P_ROW_PRE;
            ram_cmd_id           <= 1'b0;
            
            ram_wrt_en           <= 1'b1;
            head                 <= head + 1'b1;
            r_request_picked     <= 1'b0;
            
        end
        else if (push_three == 2'b01 && queue_cnt < P_QUEUE_LEN) begin
            ram_cmd              <= P_ROW_ACT;
            ram_cmd_id           <= 1'b1;

            ram_wrt_en           <= 1'b1;
            head                 <= head + 1'b1;
            r_request_picked     <= 1'b0;    
        
        end
        else if (push_three == 2'b10 && queue_cnt < P_QUEUE_LEN) begin
            if ( input_request == P_WRT_REQ ) begin
                ram_cmd          <= P_COL_WRT;
            end
            else if ( input_request == P_RD_REQ ) begin
                ram_cmd          <= P_COL_RD;
            end
            ram_cmd_id           <= 2'b10;
            
            ram_wrt_en           <= 1'b1;
            head                 <= head + 1'b1;
            r_request_picked     <= 1'b1;
            
        end

        else begin
            head <= head;
            r_request_picked <= 1'b0;
            ram_wrt_en <= 1'b0;
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
        r_bank_req_id      <= { P_REQ_ID_WIDTH { 1'b0 } };
        r_bank_cmd_id      <= { P_CMD_ID_WIDTH { 1'b0 } };
    end
    else begin
        if ( cmd_picked && queue_cnt > 0 ) begin
            r_bank_req_id  <=    ram_data_out[P_REQ_ID_WIDTH+P_CMD_ID_WIDTH+4+P_BA_ADDR_WIDTH+P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:P_CMD_ID_WIDTH+4+P_BA_ADDR_WIDTH+P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH];
            r_bank_cmd_id  <=    ram_data_out[P_CMD_ID_WIDTH+4+P_BA_ADDR_WIDTH+P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:4+P_BA_ADDR_WIDTH+P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH];
            r_cmd          <=    ram_data_out[4+P_BA_ADDR_WIDTH+P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:P_BA_ADDR_WIDTH+P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH];
            r_bank_addr    <=    ram_data_out[P_BA_ADDR_WIDTH+P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH];
            r_row_addr     <=    ram_data_out[P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:P_COL_ADDR_WIDTH];
            r_col_addr     <=    ram_data_out[P_COL_ADDR_WIDTH-1:0];
            
             
            tail           <=    tail + 1'b1;
        end
        else if(cmd_picked && queue_cnt == 0)begin
            r_cmd          <=    P_GENERAL_NOP;
            tail           <=    tail;
        end
    end
end

block_ram # (
    .DATA_WIDTH(P_REQ_ID_WIDTH+P_CMD_ID_WIDTH+4+P_BA_ADDR_WIDTH+P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH),
    .ADDR_WIDTH(INDEX_QUEUE_WIDTH)
) ram_for_REQ_to_CMD_i (
    .data_in(ram_data_in),
    .read_addr(tail),
    .write_addr(head),
    .wr_en(ram_wrt_en), 
    .clk(clk),
    .data_out(ram_data_out)
);

endmodule
