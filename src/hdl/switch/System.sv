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

module System (
        input logic clock,
        input logic clock_450,
        input logic reset,
        input logic [15:0] init_axi_txn ,
        output logic [15:0] txn_done ,
        output logic [15:0] error
    );
    
    //#(
        parameter integer C_M_AXI_AWUSER_WIDTH = 0;
        parameter integer C_M_AXI_WUSER_WIDTH = 0;
        parameter integer C_M_AXI_BUSER_WIDTH = 0;
        parameter integer C_M_AXI_ARUSER_WIDTH = 0;
        parameter integer C_M_AXI_RUSER_WIDTH = 0;
    //)
    
         logic [7:0] awlen_axi [15:0];
         logic [2:0] awsize_axi [15:0];
         logic [1:0] awburst_axi [15:0];
         logic awlock_axi [15:0];
         logic [3:0] awcache_axi [15:0];
         logic [2:0] awprot_axi [15:0];
         logic [3:0] awqos_axi [15:0];
         logic [C_M_AXI_AWUSER_WIDTH-1:0] awuser_axi [15:0];
         logic [63:0] wstrb_axi [15:0];
         logic wlast_axi [15:0];
         logic [C_M_AXI_WUSER_WIDTH-1:0] wuser_axi [15:0];
         logic [1:0] bresp_axi [15:0];
         logic [C_M_AXI_BUSER_WIDTH-1:0] buser_axi [15:0];
         logic [7:0] arlen_axi [15:0];
         logic [2:0] arsize_axi [15:0];
         logic [1:0] arburst_axi [15:0];
         logic arlock_axi [15:0];
         logic [3:0] arcache_axi [15:0];
         logic [2:0] arprot_axi [15:0];
         logic [3:0] arqos_axi [15:0];
         logic [C_M_AXI_ARUSER_WIDTH-1:0] aruser_axi [15:0];
         logic [1:0] rresp_axi [15:0];
         logic rlast_axi [15:0];
         logic [C_M_AXI_RUSER_WIDTH-1:0] ruser_axi [15:0];
    
    //connections axi-control
    logic arv_co_axi [15:0];
    logic awv_co_axi [15:0];
    logic wv_co_axi [15:0];
    logic br_co_axi [15:0];
    logic rr_co_axi [15:0];
    logic awr_co_axi [15:0];
    logic wr_co_axi [15:0];
    logic arr_co_axi [15:0];
    logic bv_co_axi [15:0];
    logic rv_co_axi [15:0];
    
    //connections axi-operational
    logic [32:0] addr_w_os_axi [15:0];
    logic [32:0] addr_r_os_axi [15:0];
    logic [511:0] write_os_axi [15:0];
    logic [511:0] read_os_axi [15:0];
    logic [7:0] ws_os_axi [15:0];
    logic [7:0] rs_os_axi [15:0];
    logic [7:0] wr_os_axi [15:0];
    logic [7:0] rr_os_axi [15:0];
    
    //connections control-operational
    logic addr_r_os_co [15:0];
    logic addr_w_os_co [15:0];
    logic write_os_co [15:0];
    logic read_os_co [15:0];
    logic valid_os_co [15:0];
    logic req_os_co [15:0];
    logic picked_os_co [15:0];
    logic ws_os_co [15:0];
    logic rs_os_co [15:0];
    logic wr_os_co [15:0];
    logic rr_os_co [15:0];
    logic ok_read_os_co [15:0];
    logic valid_read_os_co [15:0];
    logic read_complete [15:0];
    
    //connections channel-fifo
    logic [28:0] addr_ch_ff [15:0];
    logic [511:0] write_ch_ff [15:0];
    logic [511:0] read_ch_ff [15:0];
    logic [15:0] valid_ch_ff;
    logic [15:0] req_ch_ff;
    logic [15:0] picked_ch_ff;
    logic [7:0] ws_ch_ff [15:0];
    logic [7:0] wr_ch_ff [15:0];
    logic [7:0] rs_ch_ff [15:0];
    logic [7:0] rr_ch_ff [15:0];
    
    //connections fifo-operational
    logic [28:0] addr_ff_os [15:0] [15:0];
    logic [511:0] write_ff_os [15:0] [15:0];
    logic [511:0] read_ff_os [15:0] [15:0];
    logic [15:0] valid_ff_os [15:0];
    logic [15:0] req_ff_os [15:0];
    logic [15:0] picked_ff_os [15:0];
    logic [7:0] ws_ff_os [15:0] [15:0];
    logic [7:0] wr_ff_os [15:0] [15:0];
    logic [7:0] rs_ff_os [15:0] [15:0];
    logic [7:0] rr_ff_os [15:0] [15:0];
    
    logic [557:0] data_fifo_write_in_os [15:0][15:0];
    logic [557:0] data_fifo_write_in_ff [15:0][15:0];
    logic [557:0] data_fifo_write_out [15:0];
    logic [523:0] data_fifo_read_in [15:0];
    logic [523:0] data_fifo_read_out_os [15:0][15:0];
    logic [523:0] data_fifo_read_out_ff [15:0][15:0];
    
    //new
    
    logic [15:0] valid_read_ff_os [15:0];
    logic [15:0] ok_read_ff_os [15:0];
    
    logic [15:0] valid_read_ff_sw [15:0];
    logic [15:0] ok_read_ff_sw [15:0];
    logic [15:0] picked_ff_sw [15:0];
    logic [15:0] valid_ff_sw [15:0];
    
    genvar j;
    genvar k;
    generate
        for (k = 0; k < 16; k++) begin
            for (j = 0; j < 16; j++) begin
                assign data_fifo_write_in_os[k][j] = {req_ff_os[k][j], addr_ff_os[k][j], write_ff_os[k][j], ws_ff_os[k][j], rs_ff_os[k][j]};
                assign data_fifo_write_in_ff[j][k] = data_fifo_write_in_os[k][j];
                assign {req_ch_ff[j], addr_ch_ff[j], write_ch_ff[j], ws_ch_ff[j], rs_ch_ff[j]} = data_fifo_write_out[j];
                assign data_fifo_read_in[j] = {read_ch_ff[j], rr_ch_ff[j]};
                assign data_fifo_read_out_os [k][j] = data_fifo_read_out_ff [j][k];
                assign {read_ff_os[k][j], rr_ff_os[k][j]} = data_fifo_read_out_os[k][j];
                
                assign valid_read_ff_os[k][j] = valid_read_ff_sw[j][k];
                assign picked_ff_os[k][j] = picked_ff_sw[j][k];
                
                assign valid_ff_sw[j][k] = valid_ff_os[k][j];
                assign ok_read_ff_sw[j][k] = ok_read_ff_os[k][j];
            end
        end
    endgenerate


    //ch_controller
    
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen
        
            if(i==0) begin
            AXI4_peripheral_v00_0_M_AXI #(
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v00_0_M_AXI (
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==1) begin                             //MODIFY
            AXI4_peripheral_v01_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v01_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==2) begin                             //MODIFY
            AXI4_peripheral_v02_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v02_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==3) begin                             //MODIFY
            AXI4_peripheral_v03_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v03_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==4) begin                             //MODIFY
            AXI4_peripheral_v04_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v04_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==5) begin                             //MODIFY
            AXI4_peripheral_v05_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v05_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==6) begin                             //MODIFY
            AXI4_peripheral_v06_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v06_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==7) begin                             //MODIFY
            AXI4_peripheral_v07_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v07_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==8) begin                             //MODIFY
            AXI4_peripheral_v08_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v08_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==9) begin                             //MODIFY
            AXI4_peripheral_v09_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v09_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==10) begin                             //MODIFY
            AXI4_peripheral_v010_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v010_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==11) begin                             //MODIFY
            AXI4_peripheral_v011_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v011_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==12) begin                             //MODIFY
            AXI4_peripheral_v012_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v012_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==13) begin                             //MODIFY
            AXI4_peripheral_v013_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v013_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==14) begin                             //MODIFY
            AXI4_peripheral_v014_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v014_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            end else if(i==15) begin                             //MODIFY
            AXI4_peripheral_v015_0_M_AXI #(                      //MODIFY
                .C_M_TARGET_SLAVE_BASE_ADDR(33'h000000000),
                .C_M_AXI_BURST_LEN(1),
                .C_M_AXI_ID_WIDTH(8),
                .C_M_AXI_ADDR_WIDTH(33),
                .C_M_AXI_DATA_WIDTH(512),
                .C_M_AXI_AWUSER_WIDTH(0),
                .C_M_AXI_ARUSER_WIDTH(0),
                .C_M_AXI_WUSER_WIDTH(0),
                .C_M_AXI_RUSER_WIDTH(0),
                .C_M_AXI_BUSER_WIDTH(0)
            )
            inst_AXI4_peripheral_v015_0_M_AXI (                      //MODIFY
                .INIT_AXI_TXN(init_axi_txn[i]),               // Segnale di input
                .TXN_DONE(txn_done[i]),                       // Segnale di output
                .ERROR(error[i]),                             // Segnale di output
                .M_AXI_ACLK(clock),                        // Segnale di input
                .M_AXI_ARESETN(reset),                     // Segnale di input
                .M_AXI_AWID(ws_os_axi[i]),                     // Segnale di output
                .M_AXI_AWADDR(addr_w_os_axi[i]),              // Segnale di output
                .M_AXI_AWLEN(awlen_axi[i]),                   // Segnale di output
                .M_AXI_AWSIZE(awsize_axi[i]),                 // Segnale di output
                .M_AXI_AWBURST(awburst_axi[i]),               // Segnale di output
                .M_AXI_AWLOCK(awlock_axi[i]),                 // Segnale di output
                .M_AXI_AWCACHE(awcache_axi[i]),               // Segnale di output
                .M_AXI_AWPROT(awprot_axi[i]),                 // Segnale di output
                .M_AXI_AWQOS(awqos_axi[i]),                   // Segnale di output
                .M_AXI_AWUSER(awuser_axi[i]),                 // Segnale di output
                .M_AXI_AWVALID(awv_co_axi[i]),                // Segnale di output
                .M_AXI_AWREADY(awr_co_axi[i]),                // Segnale di input
                .M_AXI_WDATA(write_os_axi[i]),                // Segnale di output
                .M_AXI_WSTRB(wstrb_axi[i]),                   // Segnale di output
                .M_AXI_WLAST(wlast_axi[i]),                   // Segnale di output
                .M_AXI_WUSER(wuser_axi[i]),                   // Segnale di output
                .M_AXI_WVALID(wv_co_axi[i]),                  // Segnale di output
                .M_AXI_WREADY(wr_co_axi[i]),                  // Segnale di input
                .M_AXI_BID(wr_os_axi[i]),                       // Segnale di input
                .M_AXI_BRESP(bresp_axi[i]),                   // Segnale di input
                .M_AXI_BUSER(buser_axi[i]),                   // Segnale di input
                .M_AXI_BVALID(bv_co_axi[i]),                  // Segnale di input
                .M_AXI_BREADY(br_co_axi[i]),                  // Segnale di output
                .M_AXI_ARID(rs_os_axi[i]),                     // Segnale di output
                .M_AXI_ARADDR(addr_r_os_axi[i]),              // Segnale di output
                .M_AXI_ARLEN(arlen_axi[i]),                   // Segnale di output
                .M_AXI_ARSIZE(arsize_axi[i]),                 // Segnale di output
                .M_AXI_ARBURST(arburst_axi[i]),               // Segnale di output
                .M_AXI_ARLOCK(arlock_axi[i]),                 // Segnale di output
                .M_AXI_ARCACHE(arcache_axi[i]),               // Segnale di output
                .M_AXI_ARPROT(arprot_axi[i]),                 // Segnale di output
                .M_AXI_ARQOS(arqos_axi[i]),                   // Segnale di output
                .M_AXI_ARUSER(aruser_axi[i]),                 // Segnale di output
                .M_AXI_ARVALID(arv_co_axi[i]),                // Segnale di output
                .M_AXI_ARREADY(arr_co_axi[i]),                // Segnale di input
                .M_AXI_RID(rr_os_axi[i]),                       // Segnale di input
                .M_AXI_RDATA(read_os_axi[i]),                 // Segnale di input
                .M_AXI_RRESP(rresp_axi[i]),                   // Segnale di input
                .M_AXI_RLAST(rlast_axi[i]),                   // Segnale di input
                .M_AXI_RUSER(ruser_axi[i]),                   // Segnale di input
                .M_AXI_RVALID(rv_co_axi[i]),                  // Segnale di input
                .M_AXI_RREADY(rr_co_axi[i])                   // Segnale di output
            );
            
            end
        
                //control
            control_switch inst_control_switch (
                .clock(clock),
                .reset(reset),
                .ar_valid(arv_co_axi[i]),        
                .aw_valid(awv_co_axi[i]),        
                .w_valid(wv_co_axi[i]),         
                .b_ready(br_co_axi[i]),         
                .r_ready(rr_co_axi[i]),         
                .picked_c(picked_os_co[i]),        
                .aw_ready(awr_co_axi[i]),        
                .w_ready(wr_co_axi[i]),         
                .ar_ready(arr_co_axi[i]),        
                .b_valid(bv_co_axi[i]),         
                .r_valid(rv_co_axi[i]),         
                .read_en_addr_read(addr_r_os_co[i]),   
                .read_en_addr_write(addr_w_os_co[i]),  
                .read_en_write(write_os_co[i]),       
                .valid_c(valid_os_co[i]),             
                .req_c(req_os_co[i]),               
                .read_en_read(read_os_co[i]),
                .read_id_ws(ws_os_co[i]),
                .read_id_wr(wr_os_co[i]),
                .read_id_rs(rs_os_co[i]),
                .read_id_rr(rr_os_co[i]),
                
                .valid_read(valid_read_os_co[i]),
                .ok_read(ok_read_os_co[i]),
                .read_complete(read_complete[i])
            );
            //operational
            operational_switch inst_operational_switch (
                .clock(clock),
                .reset(reset),
                .read_en_addr_read(addr_r_os_co[i]),
                .read_en_addr_write(addr_w_os_co[i]),
                .read_en_write(write_os_co[i]),
                .valid(valid_os_co[i]),
                .req(req_os_co[i]),
                .read_en_read(read_os_co[i]),
                .picked_c(picked_ff_os[i]),
                .read_c(read_ff_os[i]),
                .address_write_r(addr_w_os_axi[i]),
                .address_read_r(addr_r_os_axi[i]),
                .write_r(write_os_axi[i]),
                .picked(picked_os_co[i]),
                .valid_c(valid_ff_os[i]),
                .req_c(req_ff_os[i]),
                .address_c(addr_ff_os[i]),
                .write_c(write_ff_os[i]),
                .read_r(read_os_axi[i]),
                
                .read_id_ws(ws_os_co[i]),
                .read_id_wr(wr_os_co[i]),
                .read_id_rs(rs_os_co[i]),
                .read_id_rr(rr_os_co[i]),
                
                .id_ws_r(ws_os_axi[i]),
                .id_rs_r(rs_os_axi[i]),
                .id_wr_r(wr_os_axi[i]),
                .id_rr_r(rr_os_axi[i]),
                
                .id_wr_c(wr_ff_os[i]),
                .id_rr_c(rr_ff_os[i]),
                .id_ws_c(ws_ff_os[i]),
                .id_rs_c(rs_ff_os[i]),
                
                .valid_read_out(valid_read_os_co[i]),
                .valid_read_c(valid_read_ff_os[i]),
                .ok_read(ok_read_os_co[i]),
                .ok_read_c(ok_read_ff_os[i]),
                .read_complete(read_complete[i])
            );
            
            CH_Controller ch_controller_inst (
                .clock(clock_450),
                .reset(reset),
                .valid(valid_ch_ff[i]),
                .req(req_ch_ff[i]),
                .address(addr_ch_ff[i]),
                .write(write_ch_ff[i]),
                .picked(picked_ch_ff[i]),
                .read(read_ch_ff[i]),
                
                .id_ws(ws_ch_ff[i]),
                .id_wr(wr_ch_ff[i]),
                .id_rs(rs_ch_ff[i]),
                .id_rr(rr_ch_ff[i])
            );
            
                FIFO_Switch fifo_switch_inst (
                .clock_250(clock),
                .clock_450(clock_450),
                .reset(reset),
                
                .data_req_os(data_fifo_write_in_ff[i]),
                .valid_c_os(valid_ff_sw[i]),
                .data_req_ch(data_fifo_write_out[i]),
                .valid_c_ch(valid_ch_ff[i]),
                
                .picked_c_ch(picked_ch_ff[i]),
                .picked_c_os(picked_ff_sw[i]),
                
                .data_read_ch(data_fifo_read_in[i]),
                .data_read_os(data_fifo_read_out_ff[i]),
                .ok_read_os(ok_read_ff_sw[i]),
                .read_valid_os(valid_read_ff_sw[i])
            );
            
        end
    endgenerate


    
endmodule