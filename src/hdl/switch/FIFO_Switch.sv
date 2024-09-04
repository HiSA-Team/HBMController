`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.07.2024 19:28:19
// Design Name: 
// Module Name: FIFO_Switch
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


module FIFO_Switch(

        input logic clock_250,   //system
        input logic clock_450,
        input logic reset,
        
        input logic [557:0] data_req_os [15:0],       //request
        input logic [15:0] valid_c_os,
        output logic [557:0] data_req_ch,
        output logic valid_c_ch,
        
        input logic picked_c_ch,
        output logic [15:0] picked_c_os,
        
        input logic [523:0] data_read_ch,       //read
        output logic [523:0] data_read_os [15:0],
        input logic [15:0] ok_read_os,
        output logic [15:0] read_valid_os
    );
    
    logic valid_c_pipe [15:0];
    logic picked_c_pipe [15:0];
    logic [3:0] axi_addr_req;
    logic wr_en_fifo_write;
    logic rd_en_fifo_write;
    logic valid_write;
    logic full_fw, empty_fw, wr_rst_busy_W, rd_rst_busy_W; //unused
    logic [557:0] data_req_pipe [15:0];
    logic [557:0] data_req_in;
    logic [7:0] id_in;
    
    logic din_p = 1'b1;
    logic dout_p;
    logic rd_en_fifo_picked;
    logic valid_picked;
    logic full_fp, empty_fp, wr_rst_busy_P, rd_rst_busy_P; //unused
    
    logic wr_en_fifo_read;
    logic [523:0] data_fifo_read_out;
    logic [3:0] axi_addr_answ;
    logic read_valid_to_demux;
    logic ok_read_mux;
    logic ok_read;
    logic ok_read_pipe [15:0];
    logic read_valid_pipe [15:0];
    logic full_fr, empty_fr, wr_rst_busy_R, rd_rst_busy_R; //unused
    logic [523:0] data_read_pipe [15:0];
    logic [7:0] id_out;
    logic [523:0] data_read_demux;
    logic reset_control_to_reg [15:0];
    logic req;
    logic [15:0] or_valid;
    logic count_positive;
    logic wr_ack_read;
    logic rd_en_read;
    
    assign valid_c_ch = valid_write;
    assign id_in = data_req_in[7:0];
    assign id_out = data_fifo_read_out[7:0];
    assign req = data_req_in[557];
    
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_reg
            reg_signal reg_pipe_valid_c (
                .clock(clock_250),
                .reset(reset),
                .signal_in((valid_c_os[i] | valid_c_pipe[i]) & ~reset_control_to_reg[i]),
                .signal_out(valid_c_pipe[i])
            );
            
            reg_data_req reg_data_req_inst (
                .clock(clock_250),
                .reset(reset),
                .data_in(data_req_os[i]),
                .data_out(data_req_pipe[i])
            );
            
            reg_signal reg_pipe_picked_c (
                .clock(clock_250),
                .reset(reset),
                .signal_in(picked_c_pipe[i]),
                .signal_out(picked_c_os[i])
            );
            
            reg_signal reg_pipe_ok_read (
                .clock(clock_250),
                .reset(reset),
                .signal_in(ok_read_os[i]),
                .signal_out(ok_read_pipe[i])
            );
            
            reg_signal reg_pipe_read_valid (
                .clock(clock_250),
                .reset(reset),
                .signal_in(read_valid_pipe[i]),
                .signal_out(read_valid_os[i])
            );
            
            reg_data_read u_reg_data_read (
                .clock(clock_250),
                .reset(reset),
                .data_in(data_read_pipe[i]),
                .data_out(data_read_os[i])
            );
            
            assign or_valid[i] = valid_c_os[i] | valid_c_pipe[i];
        end
    endgenerate
    
    Mux_Signal mux_valid (
        .select(axi_addr_req),
        .data_in(valid_c_pipe),
        .data_out(wr_en_fifo_write)
    );
    
    Mux_FIFO_write mux_fifo_write_inst (
        .select(axi_addr_req),
        .data_in(data_req_pipe),
        .data_out(data_req_in)
    );
    
    fifo_generator_0 fifo_write(
        .srst(reset),
        .wr_clk(clock_250),
        .rd_clk(clock_450),
        .din(data_req_in),
        .wr_en(wr_en_fifo_write),
        .rd_en(rd_en_fifo_write|valid_write),
        .dout(data_req_ch),
        .full(full_fw),
        .empty(empty_fw),
        .wr_ack(rd_en_fifo_write),
        .valid(valid_write),
                    
        .wr_rst_busy(wr_rst_busy_W),
        .rd_rst_busy(rd_rst_busy_W)
    );
    
    Arbiter Arbiter_inst (
        .clock(clock_250),
        .prenota(or_valid),
        .complete(valid_picked),
        .addr_chosen(axi_addr_req)
    );
    
    Demux_Signal demux_reset (
        .select(axi_addr_req),
        .data_in(1'b1),
        .data_out(reset_control_to_reg)
    );
    
    MEM_id_axi_addr mem_id_axi_addr_inst (
        .clock(clock_250),
        .reset(reset),
        .id_write(id_in),
        .id_read(id_out),
        .addr_in(axi_addr_req),
        .en_write(rd_en_fifo_write & req),
        .addr_out(axi_addr_answ)
    );
    
    fifo_generator_2 fifo_picked(
        .srst(reset),
        .wr_clk(clock_450),
        .rd_clk(clock_250),
        .din(din_p),
        .wr_en(picked_c_ch),
        .rd_en(rd_en_fifo_picked|valid_picked),
        .dout(dout_p),
        .full(full_fp),
        .empty(empty_fp),
        .wr_ack(rd_en_fifo_picked),
        .valid(valid_picked),
                    
        .wr_rst_busy(wr_rst_busy_P),
        .rd_rst_busy(rd_rst_busy_P)
    );
    
    Demux_Signal demux_picked_c (
        .select(axi_addr_req),
        .data_in(valid_picked),
        .data_out(picked_c_pipe)
    );
    
    Demux_Signal demux_read_valid (
        .select(axi_addr_answ),
        .data_in(read_valid_to_demux),
        .data_out(read_valid_pipe)
    );
    
    Mux_Signal mux_ok_read (
        .select(axi_addr_answ),
        .data_in(ok_read_pipe),
        .data_out(ok_read_mux)
    );
    
    reg_signal reg_rd_valid (
        .clock(clock_250),
        .reset(reset),
        .signal_in(read_valid),
        .signal_out(read_valid_to_demux)
    );
    
    reg_signal reg_ok_read (
        .clock(clock_250),
        .reset(reset),
        .signal_in(ok_read_mux),
        .signal_out(ok_read)
    );
    
    Demux_FIFO_read demux_fifo_read_inst (
        .select(axi_addr_answ),
        .data_in(data_read_demux),
        .data_out(data_read_pipe)
    );
    
    reg_data_read reg_data_read_inst (
        .clock(clock_250),
        .reset(reset),
        .data_in(data_fifo_read_out),
        .data_out(data_read_demux)
    );
    
    fifo_generator_1 fifo_read(
        .srst(reset),
        .wr_clk(clock_450),
        .rd_clk(clock_250),
        .din(data_read_ch),
        .wr_en(wr_en_fifo_read),
        .rd_en(rd_en_read),
        .dout(data_fifo_read_out),
        .full(full_fr),
        .empty(empty_fr),
        .wr_ack(wr_ack_read),
        .valid(read_valid),
                    
        .wr_rst_busy(wr_rst_busy_R),
        .rd_rst_busy(rd_rst_busy_R)
    );
    
    comp_in comp_in_inst(
        .clock(clock_450),
        .reset(reset),
        .din(data_read_ch),
        .en_wr(wr_en_fifo_read)
    );
    
    comp_out comp_out_inst(
        .clock(clock_250),
        .reset(reset),
        .ok_read(ok_read),
        .count_positive(count_positive),
        .en_rd(rd_en_read)
    );
    
    counter counter_inst(
        .clock_250(clock_250),
        .clock_450(clock_450),
        .reset(reset),
        .plus(wr_en_fifo_read),
        .minus(rd_en_read),
        .count_positive(count_positive)
    );
    
endmodule


