`timescale 1ps/1ps

`include "commands.svh"
`include "hbm_controller.svh"

module llcf_read_data_driver (
    // Clock and reset
    input logic                       clock_i,
    input logic                       reset_ni,

    // Input request ID
    input logic [P_REQ_ID_WIDTH-1:0]  rd_req_id_ps0_i,  // req_cas_id_ps0
    input logic [P_REQ_ID_WIDTH-1:0]  rd_req_id_ps1_i,  // req_cas_id_ps1
    input logic                       rd_req_id_ps0_valid_i,
    input logic                       rd_req_id_ps1_valid_i,

    // Input data directly from the HBM
    input logic [P_DATA_WIDTH-1:0]    rd_data_p0_i,
    input logic [P_DATA_WIDTH-1:0]    rd_data_p1_i, 
    input logic [3:0]                 rd_data_valid_i,  // TODO - parametrize it (?) 

    // Output data and ID
    output logic [P_DATA_WIDTH-1:0]   rd_data_ps0_o,
    output logic [P_DATA_WIDTH-1:0]   rd_data_ps1_o,
    output logic [P_REQ_ID_WIDTH-1:0] rd_data_req_id_ps0_o,
    output logic [P_REQ_ID_WIDTH-1:0] rd_data_req_id_ps1_o,
    output logic                      rd_data_valid_ps0_o,
    output logic                      rd_data_valid_ps1_o

);


/******************************/
/* READ DATA REQ ID QUEUE PS0 */
/******************************/
localparam RD_INDEX_QUEUE_WIDTH = $clog2(P_RD_ID_BUFFER_LEN);
logic [RD_INDEX_QUEUE_WIDTH-1 : 0 ]   rd_req_id_buffer_head_ps0;
logic [RD_INDEX_QUEUE_WIDTH-1 : 0 ]   rd_req_id_buffer_tail_ps0; 
logic [RD_INDEX_QUEUE_WIDTH   : 0 ]   rd_req_id_buffer_cnt_ps0; 

logic                              incr_rd_req_id_buffer_cnt_ps0;
logic                              deincr_rd_req_id_buffer_cnt_ps0;

assign incr_rd_req_id_buffer_cnt_ps0    = rd_req_id_buffer_cnt_ps0 < P_RD_ID_BUFFER_LEN && rd_req_id_ps0_valid_i;
assign deincr_rd_req_id_buffer_cnt_ps0  = rd_req_id_buffer_cnt_ps0 > 0 && rd_data_valid_i[1:0] == 2'b11;

logic  rd_req_id_buffer_en_ps0;
logic  [P_REQ_ID_WIDTH-1:0] rd_req_id_data_in_ps0;
logic  [P_REQ_ID_WIDTH-1:0] rd_req_id_data_out_ps0;

distributed_ram #(
    .DATA_WIDTH(P_REQ_ID_WIDTH),
    .ADDR_WIDTH(RD_INDEX_QUEUE_WIDTH)
)
rd_req_id_buffer_ps0(
    .data_in(rd_req_id_data_in_ps0),
    .read_addr(rd_req_id_buffer_tail_ps0), 
    .write_addr(rd_req_id_buffer_head_ps0),
    .wr_en(rd_req_id_buffer_en_ps0), 
    .clk(clock_i),
    .data_out(rd_req_id_data_out_ps0)
); 

/* Data in PS0 */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        rd_req_id_data_in_ps0 <= { P_REQ_ID_WIDTH { 1'b0 } }; 
    end
    else begin
        rd_req_id_data_in_ps0 <= rd_req_id_ps0_i;
    end
end

/* Req ID cnt management */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        rd_req_id_buffer_cnt_ps0  <= {RD_INDEX_QUEUE_WIDTH+1{1'b0}};
    end 
    else begin
        if ( incr_rd_req_id_buffer_cnt_ps0 && ~deincr_rd_req_id_buffer_cnt_ps0 ) begin
            rd_req_id_buffer_cnt_ps0 <= rd_req_id_buffer_cnt_ps0 + 1'b1;
        
        end 
        else if ( ~incr_rd_req_id_buffer_cnt_ps0 && deincr_rd_req_id_buffer_cnt_ps0 ) begin
            rd_req_id_buffer_cnt_ps0 <= rd_req_id_buffer_cnt_ps0 - 1'b1;
        end
        else if ( incr_rd_req_id_buffer_cnt_ps0 && deincr_rd_req_id_buffer_cnt_ps0 ) begin
            rd_req_id_buffer_cnt_ps0 <= rd_req_id_buffer_cnt_ps0;
        end
    end 
end

/* Fill req ID queue */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin
        rd_req_id_buffer_head_ps0 <= { RD_INDEX_QUEUE_WIDTH { 1'b1 } };
        rd_req_id_buffer_en_ps0 <= 1'b0;
    end
    else begin
        /* We are going to serve a RD cmd, so we store the req id in the queue */
        if ( rd_req_id_buffer_cnt_ps0 < P_RD_ID_BUFFER_LEN && rd_req_id_ps0_valid_i ) begin
            rd_req_id_buffer_en_ps0 <= 1'b1;
            rd_req_id_buffer_head_ps0 <= rd_req_id_buffer_head_ps0 + 1'b1;
        end
        else begin
            rd_req_id_buffer_en_ps0 <= 1'b0;
            rd_req_id_buffer_head_ps0 <= rd_req_id_buffer_head_ps0;
        end
    end
end

/* Get the data read and the associate req ID from the queue */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin
        rd_data_ps0_o             <= { P_DATA_WIDTH { 1'b1 } };
        rd_data_req_id_ps0_o      <= { P_REQ_ID_WIDTH { 1'b1 } };
        rd_req_id_buffer_tail_ps0 <= { RD_INDEX_QUEUE_WIDTH { 1'b0 } };
        rd_data_valid_ps0_o         <=  1'b0;
    end
    else begin
        if ( rd_req_id_buffer_cnt_ps0 > 0 && rd_data_valid_i[1:0] == 2'b11 ) begin
            rd_data_ps0_o[255:128]    <=  { rd_data_p0_i[191:128],   rd_data_p0_i[63:0]};
            rd_data_ps0_o[127:0]      <=  { rd_data_p1_i[191:128],   rd_data_p1_i[63:0]};
            rd_data_valid_ps0_o         <=  1'b1;
            rd_data_req_id_ps0_o      <=  rd_req_id_data_out_ps0;
            rd_req_id_buffer_tail_ps0 <= rd_req_id_buffer_tail_ps0 + 1'b1;
        end
        else begin
            rd_data_valid_ps0_o         <=  1'b0; 
        end
    end
end


/******************************/
/* READ DATA REQ ID QUEUE PS1 */
/******************************/

logic [RD_INDEX_QUEUE_WIDTH-1 : 0 ]   rd_req_id_buffer_head_ps1;
logic [RD_INDEX_QUEUE_WIDTH-1 : 0 ]   rd_req_id_buffer_tail_ps1; 
logic [RD_INDEX_QUEUE_WIDTH   : 0 ]   rd_req_id_buffer_cnt_ps1; 

logic                              incr_rd_req_id_buffer_cnt_ps1;
logic                              deincr_rd_req_id_buffer_cnt_ps1;

assign incr_rd_req_id_buffer_cnt_ps1    = rd_req_id_buffer_cnt_ps1 < P_RD_ID_BUFFER_LEN && rd_req_id_ps1_valid_i;
assign deincr_rd_req_id_buffer_cnt_ps1  = rd_req_id_buffer_cnt_ps1 > 0 && rd_data_valid_i[1:0] == 2'b11;

logic  rd_req_id_buffer_en_ps1;
logic  [P_REQ_ID_WIDTH-1:0] rd_req_id_data_in_ps1;
logic [P_REQ_ID_WIDTH-1:0] rd_req_id_data_out_ps1;

distributed_ram #(
    .DATA_WIDTH(P_REQ_ID_WIDTH),
    .ADDR_WIDTH(RD_INDEX_QUEUE_WIDTH)
)
rd_req_id_buffer_ps1(
    .data_in(rd_req_id_data_in_ps1),
    .read_addr(rd_req_id_buffer_tail_ps1), 
    .write_addr(rd_req_id_buffer_head_ps1),
    .wr_en(rd_req_id_buffer_en_ps1), 
    .clk(clock_i),
    .data_out(rd_req_id_data_out_ps1)
); 

/* Data in PS1 */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        rd_req_id_data_in_ps1 <= { P_REQ_ID_WIDTH { 1'b0 } }; 
    end
    else begin
        rd_req_id_data_in_ps1 <= rd_req_id_ps1_i;
    end
end

/* Req ID cnt management */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        rd_req_id_buffer_cnt_ps1  <= {RD_INDEX_QUEUE_WIDTH+1{1'b0}};
    end 
    else begin
        if ( incr_rd_req_id_buffer_cnt_ps1 && ~deincr_rd_req_id_buffer_cnt_ps1 ) begin
            rd_req_id_buffer_cnt_ps1 <= rd_req_id_buffer_cnt_ps1 + 1'b1;
        
        end 
        else if ( ~incr_rd_req_id_buffer_cnt_ps1 && deincr_rd_req_id_buffer_cnt_ps1 ) begin
            rd_req_id_buffer_cnt_ps1 <= rd_req_id_buffer_cnt_ps1 - 1'b1;
        end
        else if ( incr_rd_req_id_buffer_cnt_ps1 && deincr_rd_req_id_buffer_cnt_ps1 ) begin
            rd_req_id_buffer_cnt_ps1 <= rd_req_id_buffer_cnt_ps1;
        end
    end 
end

/* Fill req ID queue */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin
        rd_req_id_buffer_head_ps1 <= { RD_INDEX_QUEUE_WIDTH { 1'b1 } };
        rd_req_id_buffer_en_ps1 <= 1'b0;
    end
    else begin
        /* We are going to serve a RD cmd, so we store the req id in the queue */
        if ( rd_req_id_buffer_cnt_ps1 < P_RD_ID_BUFFER_LEN && rd_req_id_ps1_valid_i ) begin
            rd_req_id_buffer_en_ps1 <= 1'b1;
            rd_req_id_buffer_head_ps1 <= rd_req_id_buffer_head_ps1 + 1'b1;
        end
        else begin
            rd_req_id_buffer_en_ps1 <= 1'b0;
            rd_req_id_buffer_head_ps1 <= rd_req_id_buffer_head_ps1;
        end
    end
end

/* Get the data read and the associate req ID from the queue */
always @ ( posedge clock_i or negedge reset_ni ) begin
    if( reset_ni == 1'b0 ) begin
        rd_data_ps1_o             <= { P_DATA_WIDTH { 1'b1 } };
        rd_data_req_id_ps1_o      <= { P_REQ_ID_WIDTH { 1'b1 } };
        rd_req_id_buffer_tail_ps1 <= { RD_INDEX_QUEUE_WIDTH { 1'b0 } };
        rd_data_valid_ps1_o       <=  1'b0;
    end
    else begin
        if ( rd_req_id_buffer_cnt_ps1 > 0 && rd_data_valid_i[3:2] == 2'b11 ) begin
            rd_data_ps1_o[255:128]    <=  { rd_data_p1_i[255:192],   rd_data_p1_i[127:64]};
            rd_data_ps1_o[127:0]      <=  { rd_data_p0_i[255:192],   rd_data_p0_i[127:64]};
            rd_data_req_id_ps1_o      <=  rd_req_id_data_out_ps1;
            rd_data_valid_ps1_o       <=  1'b1;
            rd_req_id_buffer_tail_ps1 <=  rd_req_id_buffer_tail_ps1 + 1'b1;
        end
        else begin
            rd_data_valid_ps1_o         <=  1'b0;
        end
    end
end



endmodule