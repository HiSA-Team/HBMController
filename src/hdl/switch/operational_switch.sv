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


module operational_switch(
        input logic clock,      //from system
        input logic reset,
        
        input logic read_en_addr_read,       //from control
        input logic read_en_addr_write,
        input logic read_en_write,
        input logic valid,
        input logic req,
        input logic read_en_read,
        input logic ok_read,
        
        input logic read_id_ws,
        input logic read_id_wr,
        input logic read_id_rs,
        input logic read_id_rr,
        
        input logic [15:0] picked_c,          //from custom
        input logic [511:0] read_c [15:0],
        input logic [7:0] id_wr_c [15:0],
        input logic [7:0] id_rr_c [15:0],
        input logic [15:0] valid_read_c,
        
        input logic [32:0] address_write_r,   //from requester
        input logic [32:0] address_read_r,
        input logic [511:0] write_r,
        input logic [7:0] id_ws_r,
        input logic [7:0] id_rs_r,
        
        output logic picked,              //to control
        output logic valid_read_out,
        output logic read_complete,
        
        output logic [15:0] valid_c,          //to custom
        output logic [15:0] req_c,
        output logic [28:0] address_c [15:0],
        output logic [511:0] write_c [15:0],
        output logic [7:0] id_ws_c [15:0],
        output logic [7:0] id_rs_c [15:0],
        output logic [15:0] ok_read_c,
        
        output logic [511:0] read_r,         //to requester
        output logic [7:0] id_wr_r,
        output logic [7:0] id_rr_r
        
    );
    
    
    logic [3:0] selection_write;
    logic [3:0] selection_read;
    logic [3:0] selection_reg;
    logic [3:0] selection;
    logic [511:0] data_write_to_demux;
    logic [511:0] data_read_from_mux;
    logic [28:0] address_to_demux;
    logic [28:0] address_to_demux_reg;
    logic [28:0] address_r_to_demux;
    logic [28:0] address_w_to_demux;
    logic [28:0] address_to_reg [15:0];
    logic [511:0] write_to_reg [15:0];
    logic [511:0] read_from_reg [15:0];
    logic picked_reg [15:0];
    logic req_reg [15:0];
    logic valid_reg [15:0];
    logic req_pipe;
    logic [511:0] write_pipe;
    logic valid_pipe;
    
    //new signals [7]
    logic [7:0] id_ws_to_pipe; //da in a pipe
    logic [7:0] id_rs_to_pipe;
    logic [7:0] id_wr_to_reg; // da mux a in
    logic [7:0] id_rr_to_reg;
    logic [7:0] id_ws_to_demux; //da pipe a demux
    logic [7:0] id_rs_to_demux;
    //new signals [7] [15]
    logic [7:0] id_ws_out [15:0];
    logic [7:0] id_wr_out [15:0];
    logic [7:0] id_rs_out [15:0];
    logic [7:0] id_rr_out [15:0];
    
    //new signals read
    logic valid_read_pipe [15:0];
    logic [3:0] addr_selection_read;
    logic ok_read_pipe [15:0];
    
    
    // Istanziamento dei moduli

    reg_read reg_read_inst (
        .clock(clock),
        .reset(reset),
        .read(read_en_read),
        .data_in(data_read_from_mux),
        .data_out(read_r)
    );

    reg_write reg_write_inst (
        .clock(clock),
        .reset(reset),
        .read(read_en_write),
        .data_in(write_r),
        .data_out(write_pipe)
    );

    reg_addr_in reg_addr_in_read (
        .clock(clock),
        .reset(reset),
        .read(read_en_addr_read),
        .addr_in(address_read_r),
        .selection(selection_read),
        .addr_out(address_r_to_demux)
    );
    
    reg_addr_in reg_addr_in_write (
        .clock(clock),
        .reset(reset),
        .read(read_en_addr_write),
        .addr_in(address_write_r),
        .selection(selection_write),
        .addr_out(address_w_to_demux)
    );
    
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : gen_my_modules
            reg_addr_out reg_addr_out_inst (
                .clock(clock),
                .reset(reset),
                .addr_in(address_to_reg[i]),
                .addr_out(address_c[i])
            );
            
            reg_pipe reg_write (
                .clock(clock),
                .reset(reset),
                .data_in(write_to_reg[i]),
                .data_out(write_c[i])
            );
            
            reg_pipe reg_read (
                .clock(clock),
                .reset(reset),
                .data_in(read_c[i]),
                .data_out(read_from_reg[i])
            );
            
            reg_signal reg_valid(
                .clock(clock),
                .reset(reset),
                .signal_in(valid_reg[i]),
                .signal_out(valid_c[i])
            );
            
            reg_signal reg_req(
                .clock(clock),
                .reset(reset),
                .signal_in(req_reg[i]),
                .signal_out(req_c[i])
            );
            
            reg_signal reg_picked(
                .clock(clock),
                .reset(reset),
                .signal_in(picked_c[i]),
                .signal_out(picked_reg[i])
            );
            
            reg_id_pipe reg_id_ws_out (
                .clock(clock),
                .reset(reset),
                .data_in(id_ws_out[i]),
                .data_out(id_ws_c[i])
            );
            
            reg_id_pipe reg_id_wr_out (
                .clock(clock),
                .reset(reset),
                .data_in(id_wr_c[i]),
                .data_out(id_wr_out[i])
            );
            
            reg_id_pipe reg_id_rs_out (
                .clock(clock),
                .reset(reset),
                .data_in(id_rs_out[i]),
                .data_out(id_rs_c[i])
            );
            
            reg_id_pipe reg_id_rr_out (
                .clock(clock),
                .reset(reset),
                .data_in(id_rr_c[i]),
                .data_out(id_rr_out[i])
            );
            
            reg_signal reg_valid_read(
                .clock(clock),
                .reset(reset),
                .signal_in(valid_read_c[i]),
                .signal_out(valid_read_pipe[i])
            );
            
            reg_signal reg_ok_read(
                .clock(clock),
                .reset(reset),
                .signal_in(ok_read_pipe[i]),
                .signal_out(ok_read_c[i])
            );
            
        end
    endgenerate
    
    mux_selection sel_mux (
        .req(req_pipe),
        .sel_read(selection_read),
        .sel_write(selection_write),
        .selection(selection_reg)
    );
    
    reg_selection reg_sel(
         .clock(clock),
         .reset(reset),
         .sel_in(selection_reg),
         .sel_out(selection)
    );
    
    reg_pipe write_reg_pipe(
        .clock(clock),
        .reset(reset),
        .data_in(write_pipe),
        .data_out(data_write_to_demux)
    );
    
    reg_signal reg_req_pipe(
        .clock(clock),
        .reset(reset),
        .signal_in(req),
        .signal_out(req_pipe)
    );
    
    reg_signal reg_valid_pipe(
        .clock(clock),
        .reset(reset),
        .signal_in(valid),
        .signal_out(valid_pipe)
    );
    
    Mux_Addr mux_addr_inst(
        .select(req),
        .addr_read(address_r_to_demux),
        .addr_write(address_w_to_demux),
        .addr_out(address_to_demux_reg)
    );
    
    reg_addr_out reg_addr_out_inst (
         .clock(clock),
         .reset(reset),
         .addr_in(address_to_demux_reg),
         .addr_out(address_to_demux)
    );
    
    Demux_Addr demux_addr_inst (
        .select(selection),
        .data_in(address_to_demux),
        .data_out(address_to_reg)
    );

    Mux_Signal mux_picked (
        .select(selection),
        .data_in(picked_reg),
        .data_out(picked)
    );

    Demux_Write demux_write_inst(
        .select(selection),
        .data_in(data_write_to_demux),
        .data_out(write_to_reg)
    );

    Mux_Read mux_read_inst (
        .select(addr_selection_read),
        .data_in(read_from_reg),
        .data_out(data_read_from_mux)
    );

    Demux_Signal demux_req (
        .select(selection),
        .data_in(req_pipe),
        .data_out(req_reg)
    );
    
    Demux_Signal demux_valid (
        .select(selection),
        .data_in(valid_pipe),
        .data_out(valid_reg)
    );
    
    //ID_PARTS
    reg_id reg_id_ws (
        .clock(clock),
        .reset(reset),
        .read(read_id_ws),
        .data_in(id_ws_r),
        .data_out(id_ws_to_pipe)
    );
    
    reg_id reg_id_wr (
        .clock(clock),
        .reset(reset),
        .read(read_id_wr),
        .data_in(id_wr_to_reg),
        .data_out(id_wr_r)
    );
    
    reg_id reg_id_rs (
        .clock(clock),
        .reset(reset),
        .read(read_id_rs),
        .data_in(id_rs_r),
        .data_out(id_rs_to_pipe)
    );
    
    reg_id reg_id_rr (
        .clock(clock),
        .reset(reset),
        .read(read_id_rr),
        .data_in(id_rr_to_reg),
        .data_out(id_rr_r)
    );
    
    reg_id_pipe reg_pipe_ws(
        .clock(clock),
        .reset(reset),
        .data_in(id_ws_to_pipe),
        .data_out(id_ws_to_demux)
    );
    
    reg_id_pipe reg_pipe_rs(
        .clock(clock),
        .reset(reset),
        .data_in(id_rs_to_pipe),
        .data_out(id_rs_to_demux)
    );
    
    demux_id demux_ws(
        .select(selection),
        .data_in(id_ws_to_demux),
        .data_out(id_ws_out)
    );
    
    demux_id demux_rs(
        .select(selection),
        .data_in(id_rs_to_demux),
        .data_out(id_rs_out)
    );
    
    mux_id mux_wr(
        .select(selection),
        .data_in(id_wr_out),
        .data_out(id_wr_to_reg)
    );
    
    mux_id mux_rr(
        .select(addr_selection_read),
        .data_in(id_rr_out),
        .data_out(id_rr_to_reg)
    );
    
    Mux_Signal mux_valid_read(
        .select(addr_selection_read),
        .data_in(valid_read_pipe),
        .data_out(valid_read_out)
    );
    
    Demux_Signal demux_ok_read (
        .select(addr_selection_read),
        .data_in(ok_read),
        .data_out(ok_read_pipe)
    );
    
    Arbiter_read Arbiter_inst (
        .clock(clock),
        .prenota(valid_read_c),
        .complete(read_complete),
        .addr_chosen(addr_selection_read)
    );
    
endmodule
