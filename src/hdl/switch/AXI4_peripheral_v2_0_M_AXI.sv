`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.07.2024 15:47:49
// Design Name: 
// Module Name: AXI4_peripheral_v2_0_M_AXI
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

module AXI4_peripheral_v00_0_M_AXI#
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Base address of targeted slave
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		// Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
		parameter integer C_M_AXI_BURST_LEN	= 1,
		// Thread ID Width
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		// Width of Address Bus
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		// Width of Data Bus
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		// Width of User Write Address Bus
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		// Width of User Read Address Bus
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		// Width of User Write Data Bus
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		// Width of User Read Data Bus
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		// Width of User Response Bus
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line

		// Initiate AXI transactions
		input wire  INIT_AXI_TXN,
		// Asserts when transaction is complete
		output wire  TXN_DONE,
		// Asserts when ERROR is detected
		output reg  ERROR,
		// Global Clock Signal.
		input wire  M_AXI_ACLK,
		// Global Reset Singal. This Signal is Active Low
		input wire  M_AXI_ARESETN,
		// Master Interface Write Address ID
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		// Master Interface Write Address
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		output wire [7 : 0] M_AXI_AWLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		output wire [2 : 0] M_AXI_AWSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		output wire [1 : 0] M_AXI_AWBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		output wire  M_AXI_AWLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		output wire [3 : 0] M_AXI_AWCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_AWPROT,
		// Quality of Service, QoS identifier sent for each write transaction.
		output wire [3 : 0] M_AXI_AWQOS,
		// Optional User-defined signal in the write address channel.
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid write address and control information.
		output wire  M_AXI_AWVALID,
		// Write address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
		input wire  M_AXI_AWREADY,
		// Master Interface Write Data.
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		// Write strobes. This signal indicates which byte
    // lanes hold valid data. There is one write strobe
    // bit for each eight bits of the write data bus.
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		// Write last. This signal indicates the last transfer in a write burst.
		output wire  M_AXI_WLAST,
		// Optional User-defined signal in the write data channel.
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		// Write valid. This signal indicates that valid write
    // data and strobes are available
		output wire  M_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    // can accept the write data.
		input wire  M_AXI_WREADY,
		// Master Interface Write Response.
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		// Write response. This signal indicates the status of the write transaction.
		input wire [1 : 0] M_AXI_BRESP,
		// Optional User-defined signal in the write response channel
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		// Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
		input wire  M_AXI_BVALID,
		// Response ready. This signal indicates that the master
    // can accept a write response.
		output wire  M_AXI_BREADY,
		// Master Interface Read Address.
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		// Read address. This signal indicates the initial
    // address of a read burst transaction.
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		// Burst length. The burst length gives the exact number of transfers in a burst
		output wire [7 : 0] M_AXI_ARLEN,
		// Burst size. This signal indicates the size of each transfer in the burst
		output wire [2 : 0] M_AXI_ARSIZE,
		// Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
		output wire [1 : 0] M_AXI_ARBURST,
		// Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
		output wire  M_AXI_ARLOCK,
		// Memory type. This signal indicates how transactions
    // are required to progress through a system.
		output wire [3 : 0] M_AXI_ARCACHE,
		// Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
		output wire [2 : 0] M_AXI_ARPROT,
		// Quality of Service, QoS identifier sent for each read transaction
		output wire [3 : 0] M_AXI_ARQOS,
		// Optional User-defined signal in the read address channel.
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		// Write address valid. This signal indicates that
    // the channel is signaling valid read address and control information
		output wire  M_AXI_ARVALID,
		// Read address ready. This signal indicates that
    // the slave is ready to accept an address and associated control signals
		input wire  M_AXI_ARREADY,
		// Read ID tag. This signal is the identification tag
    // for the read data group of signals generated by the slave.
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		// Master Read Data
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		// Read response. This signal indicates the status of the read transfer
		input wire [1 : 0] M_AXI_RRESP,
		// Read last. This signal indicates the last transfer in a read burst
		input wire  M_AXI_RLAST,
		// Optional User-defined signal in the read address channel.
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		// Read valid. This signal indicates that the channel
    // is signaling the required read data.
		input wire  M_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    // accept the read data and response information.
		output wire  M_AXI_RREADY
	);


	// function called clogb2 that returns an integer which has the
	//value of the ceiling of the log base 2

	  // function called clogb2 that returns an integer which has the 
	  // value of the ceiling of the log base 2.                      
	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     

	// C_TRANSACTIONS_NUM is the width of the index counter for 
	// number of write or read transaction.
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);

	// Burst length for transactions, in C_M_AXI_DATA_WIDTHs.
	// Non-2^n lengths will eventually cause bursts across 4K address boundaries.
	 localparam integer C_MASTER_LENGTH	= 12;
	// total number of burst transfers is master length divided by burst length and burst size
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	// Example State machine to initialize counter, initialize write transactions, 
	// initialize read transactions and comparison of read data with the 
	// written data words.
	parameter [1:0] IDLE = 2'b00, // This state initiates AXI4Lite transaction 
			// after the state machine changes state to INIT_WRITE 
			// when there is 0 to 1 transition on INIT_AXI_TXN
		INIT_WRITE   = 2'b01, // This state initializes write transaction,
			// once writes are done, the state machine 
			// changes state to INIT_READ 
		INIT_READ = 2'b10, // This state initializes read transaction
			// once reads are done, the state machine 
			// changes state to INIT_COMPARE 
		INIT_COMPARE = 2'b11; // This state issues the status of comparison 
			// of the written data with the read data	

	 reg [1:0] mst_exec_state;

	// AXI4LITE signals
	//AXI4 internal temp signals
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	//write beat count in a burst
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	//read beat count in a burst
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	//size of C_M_AXI_BURST_LEN length burst in bytes
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	//The burst counters are used to track the number of burst transfers of C_M_AXI_BURST_LEN burst length needed to transfer 2^C_MASTER_LENGTH bytes of data.
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	//Interface response error flags
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	// I/O Connections assignments

	//I/O Connections. Write Address (AW)
	assign M_AXI_AWID	= axi_awid;
	//The AXI address is a concatenation of the target base address + active offset range
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	//Burst LENgth is number of transaction beats, minus 1
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	//Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	//INCR burst type is usually used, except for keyhole bursts
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	//Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache. 
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	//Write Data(W)
	assign M_AXI_WDATA	= axi_wdata;
	//All bursts are complete and aligned in this example
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	//Write Response (B)
	assign M_AXI_BREADY	= axi_bready;
	//Read Address (AR)
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	//Burst LENgth is number of transaction beats, minus 1
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	//Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	//INCR burst type is usually used, except for keyhole bursts
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	//Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache. 
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	//Read and Read Response (R)
	assign M_AXI_RREADY	= axi_rready;
	//Example design I/O
	assign TXN_DONE	= compare_done;
	//Burst size in bytes
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b0000;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_0.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v01_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b0001;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_1.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v02_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b0010;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_2.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v03_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b0011;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_3.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v04_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b0100;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_4.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v05_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b0101;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_5.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v06_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b0110;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_6.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v07_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b0111;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_7.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v08_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b1000;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_8.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule

///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v09_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b1001;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_9.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v010_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b1010;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_10.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v011_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b1011;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_11.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v012_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b1100;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_12.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v013_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b1101;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_13.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v014_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b1110;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_14.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
	///////////////////////////////////////////////////////////////////////////
	module AXI4_peripheral_v015_0_M_AXI#                //MODIFY
	(
		parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 33'h00000000,
		parameter integer C_M_AXI_BURST_LEN	= 1,
		parameter integer C_M_AXI_ID_WIDTH	= 8,
		parameter integer C_M_AXI_ADDR_WIDTH	= 33,
		parameter integer C_M_AXI_DATA_WIDTH	= 512,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0
	)
	(
		
		input wire  INIT_AXI_TXN,
		output wire  TXN_DONE,
		output reg  ERROR,
		input wire  M_AXI_ACLK,
		input wire  M_AXI_ARESETN,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_AWID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
		output wire [7 : 0] M_AXI_AWLEN,
		output wire [2 : 0] M_AXI_AWSIZE,
		output wire [1 : 0] M_AXI_AWBURST,
		output wire  M_AXI_AWLOCK,
		output wire [3 : 0] M_AXI_AWCACHE,
		output wire [2 : 0] M_AXI_AWPROT,
		output wire [3 : 0] M_AXI_AWQOS,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0] M_AXI_AWUSER,
		output wire  M_AXI_AWVALID,
		input wire  M_AXI_AWREADY,
		output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
		output wire  M_AXI_WLAST,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0] M_AXI_WUSER,
		output wire  M_AXI_WVALID,
		input wire  M_AXI_WREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_BID,
		input wire [1 : 0] M_AXI_BRESP,
		input wire [C_M_AXI_BUSER_WIDTH-1 : 0] M_AXI_BUSER,
		input wire  M_AXI_BVALID,
		output wire  M_AXI_BREADY,
		output wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_ARID,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
		output wire [7 : 0] M_AXI_ARLEN,
		output wire [2 : 0] M_AXI_ARSIZE,
		output wire [1 : 0] M_AXI_ARBURST,
		output wire  M_AXI_ARLOCK,
		output wire [3 : 0] M_AXI_ARCACHE,
		output wire [2 : 0] M_AXI_ARPROT,
		output wire [3 : 0] M_AXI_ARQOS,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0] M_AXI_ARUSER,
		output wire  M_AXI_ARVALID,
		input wire  M_AXI_ARREADY,
		input wire [C_M_AXI_ID_WIDTH-1 : 0] M_AXI_RID,
		input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
		input wire [1 : 0] M_AXI_RRESP,
		input wire  M_AXI_RLAST,
		input wire [C_M_AXI_RUSER_WIDTH-1 : 0] M_AXI_RUSER,
		input wire  M_AXI_RVALID,
		output wire  M_AXI_RREADY
	);

	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     
	  
	 localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
	 localparam integer C_MASTER_LENGTH	= 12;
	 localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
	parameter [1:0] IDLE = 2'b00, 
		INIT_WRITE   = 2'b01,  
		INIT_READ = 2'b10, 
		INIT_COMPARE = 2'b11; 

	 reg [1:0] mst_exec_state;

	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awvalid = 1'b0;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
	reg  	axi_wlast;
	reg  	axi_wvalid = 1'b0;
	reg  	axi_bready = 1'b0;
	reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arvalid = 1'b0;
	reg  	axi_rready = 1'b0;
	reg [C_TRANSACTIONS_NUM : 0] 	write_index;
	reg [C_TRANSACTIONS_NUM : 0] 	read_index;
	wire [C_TRANSACTIONS_NUM+2 : 0] 	burst_size_bytes;
	reg [C_NO_BURSTS_REQ : 0] 	write_burst_counter;
	reg [C_NO_BURSTS_REQ : 0] 	read_burst_counter;
	reg  	start_single_burst_write;
	reg  	start_single_burst_read;
	reg  	writes_done;
	reg  	reads_done;
	reg  	error_reg;
	reg  	compare_done;
	reg  	read_mismatch;
	reg  	burst_write_active;
	reg  	burst_read_active;
	reg [C_M_AXI_DATA_WIDTH-1 : 0] 	expected_rdata;
	wire  	write_resp_error;
	wire  	read_resp_error;
	wire  	wnext;
	wire  	rnext;
	reg  	init_txn_ff;
	reg  	init_txn_ff2;
	reg  	init_txn_edge;
	wire  	init_txn_pulse;
	
	//nuovo segnale
	reg [C_M_AXI_ID_WIDTH-1:0] axi_awid;
	reg [C_M_AXI_ID_WIDTH-1:0] axi_arid;


	assign M_AXI_AWID	= axi_awid;
	assign M_AXI_AWADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_awaddr;
	assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_AWBURST	= 2'b01;
	assign M_AXI_AWLOCK	= 1'b0;
	assign M_AXI_AWCACHE	= 4'b0010;
	assign M_AXI_AWPROT	= 3'h0;
	assign M_AXI_AWQOS	= 4'h0;
	assign M_AXI_AWUSER	= 'b1;
	assign M_AXI_AWVALID	= axi_awvalid;
	assign M_AXI_WDATA	= axi_wdata;
	assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
	assign M_AXI_WLAST	= axi_wlast;
	assign M_AXI_WUSER	= 'b0;
	assign M_AXI_WVALID	= axi_wvalid;
	assign M_AXI_BREADY	= axi_bready;
	assign M_AXI_ARID	= axi_arid;
	assign M_AXI_ARADDR	= C_M_TARGET_SLAVE_BASE_ADDR + axi_araddr;
	assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
	assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
	assign M_AXI_ARBURST	= 2'b01;
	assign M_AXI_ARLOCK	= 1'b0;
	assign M_AXI_ARCACHE	= 4'b0010;
	assign M_AXI_ARPROT	= 3'h0;
	assign M_AXI_ARQOS	= 4'h0;
	assign M_AXI_ARUSER	= 'b1;
	assign M_AXI_ARVALID = axi_arvalid;
	assign M_AXI_RREADY	= axi_rready;
	assign TXN_DONE	= compare_done;
	assign burst_size_bytes	= C_M_AXI_BURST_LEN * C_M_AXI_DATA_WIDTH/8;
	assign init_txn_pulse	= (!init_txn_ff2) && init_txn_ff;
	
	reg [C_M_AXI_DATA_WIDTH-1 : 0] data;
	reg [C_M_AXI_ID_WIDTH-1:0] id;

    //CUSTOM    
    
    int file, r, f2, status;
    string line, str_addr, str_data;
    logic [35:0] addr_buf;
    logic [3:0] count_id = 4'b0000;;
    logic [3:0] id_base = 4'b1111;                              //MODIFY!!!
    
    initial begin
        
        file = $fopen("mem_access/axi_15.txt", "r");            //MODIFY!!!
        
        while (!$feof(file)) begin
            r=$fgets(line, file);
            if (line[0]=="W") begin
                str_addr = line.substr(8,16);                     //SCRITTURA
                addr_buf = str_addr.atohex();
                axi_awaddr = addr_buf[32:0];
                str_data = line.substr(18,145);
                status = $sscanf(str_data, "%h", axi_wdata);
                
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
                wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
                
                axi_awvalid = 1'b0;
                axi_wvalid = 1'b0;
                axi_bready = 1'b1;
                #10;
                axi_bready = 1'b0;
                #10;
                
            end else if(line[0]=="R") begin
                str_addr = line.substr(7,15);                     //LETTURA
                addr_buf = str_addr.atohex();
                axi_araddr = addr_buf[32:0];    
                axi_arid = {id_base, count_id};            
                axi_arvalid = 1'b1;
                #10;
                wait (M_AXI_ARREADY == 1'b1);
                count_id = count_id + 1;
                axi_arvalid = 1'b0;
                #100;
            end
        end
        $fclose(file);
    end
    
    always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
    end

	endmodule
	
/*
    initial begin
        //wait (INIT_AXI_TXN == 1'b1);
        ///////////////////////////////////////////////////////////SCRITTURA
        axi_awaddr = 33'h1FFFFFFFF;
        axi_wdata = {512{1'b1}};
        //axi_awid = {8{1'b1}};
        //invio id M_AXI_AWID ()
        axi_awvalid = 1'b1;
        axi_wvalid = 1'b1;
        wait (M_AXI_AWREADY == 1'b1 & M_AXI_WREADY == 1'b1);
        wait (M_AXI_BVALID == 1'b1);                            //attesa scrittura
        //lettura id M_AXI_BID
        axi_awvalid = 1'b0;
        axi_wvalid = 1'b0;
        axi_bready = 1'b1;
        #10;
        axi_bready = 1'b0;
        #10;
        
        ///////////////////////////////////////////////////////////LETTURA
        axi_araddr = 33'h1FFFFFFFF;
        //invio id M_ARI_AWID ()
        axi_arid = {8{1'b1}};
        axi_arvalid = 1'b1;
        #10;
        wait (M_AXI_ARREADY == 1'b1);
        axi_arvalid = 1'b0;
        #100;
*/        
    
 /*   always_ff@(posedge M_AXI_ACLK) begin
    
        if(M_AXI_RVALID == 1'b0) begin
            axi_rready = 1'b0;
        end
        if (M_AXI_RVALID == 1'b1) begin
            axi_rready = 1'b1;
            data = M_AXI_RDATA;
            id = M_AXI_RID;
        end
 */       
        