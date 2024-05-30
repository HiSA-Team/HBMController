`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/26/2023 02:23:55 PM
// Design Name: 
// Module Name: HBM_controller
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


module HBM_channel_controller # (
    parameter       P_DRIVE_PRECHARGE_CMD  = 114,
    parameter		P_PRECHG_THR           = 200,
    parameter		P_ACT_THR	           = 40,
    parameter		P_WRT_THR	           = 60,
    parameter		P_RD_THR	           = 60,
    parameter		P_DRIVE_ACT_CMD        = 240,
    parameter		P_MRS_CNT              = 8'hc0,

    parameter		P_ROW_ADDR_WIDTH           = 14,
    parameter		P_COL_ADDR_WIDTH           = 6,
    parameter		P_BA_ADDR_WIDTH	           = 5, 
    parameter       P_BA_N_PS                  = 16,        /* Number of Banks per PS, here we consider half bank for PS */
    parameter       P_BA_N_G                   = 4,         /* Number of Banks per group */
    parameter       P_DATA_WIDTH               = 256,
    parameter       P_TOTAL_PER_CHANNEL_BANK_N = 32,        /* Number of Banks per channel, again we consider half bank */

    /* FIFO QUEUE LEN */
    parameter       P_QUEUE_LEN             = 8,

    /* WRT BUFFER LEN */
    parameter       P_WRT_DATA_BUFFER_LEN   = 4,
    
    /* REQUESTS       */
    parameter       P_WRT_REQ         =  2'd0,
    parameter       P_RD_REQ          =  2'd1,

    /* COMMANDS        */
    parameter       P_GENERAL_NOP     =  4'b1111,

    /* COLUMN COMMANDS */ 
    parameter       P_COL_WRT		  =  4'b0001,
    parameter       P_COL_RD          =  4'b0101,
    parameter       P_COL_NOP         =  4'b1111,
    parameter       P_COL_RD_AP		  =  4'b1101,
    parameter       P_COL_WRT_AP	  =  4'b1001,
    parameter       P_COL_MRS		  =  4'b0000,

    /* ROW COMMANDS    */
    parameter       P_ROW_NOP		  =  3'b111,
    parameter       P_ROW_ACT		  =  3'b010,
    parameter       P_ROW_PRE		  =  3'b011,
    parameter       P_ROW_PREA	      =  3'b011,
    parameter       P_ROW_REFPB       =  4'b1100, 
    

    /* EXCLUSIVELY HBM INTRA BANK TIMING CONSTRAINTS - FOR BANK SCHEDULERS  */
    parameter    tRCD     =  32'd14,
    parameter    tRP      =  32'd14 ,
    parameter    tRC      =  32'd1,
    parameter    tRAS     =  32'd34,
    parameter    tWL      =  32'd4,
    parameter    tRL      =  32'd14,
    parameter    tRTPl    =  32'd6,
    parameter    tWR      =  32'd16,
    parameter    tBURST   =  32'd2,
    parameter    tRFCpb   =  32'd73,
    parameter    tREFP    =  32'd1220,      /* Refresh Period*/  /* Maybe it is too conservative ? */

    /* HBM INTRA AND INTER BANK TIMING CONSTRAINTS - FOR LLCF */      
    parameter    tCCDl    =  32'd1,
    parameter    tRTW     =  32'd8, 
    parameter    tWTRl    =  32'd8,
    parameter    tRRD     =  32'd6,
    parameter    tFAW     =  32'd30,
    parameter    tWTRs    =  32'd6,
    parameter    tRREFD   =  32'd4,

    parameter    P_REQ_ID_WIDTH = $clog2(P_BA_N_PS*P_QUEUE_LEN*2),
    parameter    P_CMD_ID_WIDTH = 32'd3

)( 
    //DFI INTERFACE SIGNALS
    input               dfi_clk_buf,
    input           	dfi_rst_n,
    input            	dfi_rst_buf_n,

    output	           	dfi_init_start,
    output	[1:0]   	dfi_aw_ck_p0,
    output  [1:0]   	dfi_aw_cke_p0,
    output	[11:0]  	dfi_aw_row_p0,
    output	[15:0]		dfi_aw_col_p0,
    output	[255:0] 	dfi_dw_wrdata_p0,
    output  [31:0]		dfi_dw_wrdata_mask_p0,
    output  [31:0]		dfi_dw_wrdata_dbi_p0,
    output  [7:0]		dfi_dw_wrdata_par_p0,
    output  [7:0]		dfi_dw_wrdata_dq_en_p0,
    output  [7:0]		dfi_dw_wrdata_par_en_p0,

    output  [1:0]		dfi_aw_ck_p1,
    output  [1:0]		dfi_aw_cke_p1,
    output	[11:0]		dfi_aw_row_p1,
    output	[15:0]		dfi_aw_col_p1,
    output	[255:0]		dfi_dw_wrdata_p1,
    output  [31:0]		dfi_dw_wrdata_mask_p1,
    output  [31:0]		dfi_dw_wrdata_dbi_p1,
    output  [7:0]		dfi_dw_wrdata_par_p1,
    output  [7:0]		dfi_dw_wrdata_dq_en_p1,
    output  [7:0]		dfi_dw_wrdata_par_en_p1,

    output           dfi_aw_ck_dis,
    output           dfi_lp_pwr_e_req,
    output           dfi_lp_sr_e_req,
    output           dfi_lp_pwr_x_req,
    output           dfi_aw_tx_indx_ld,
    output           dfi_dw_tx_indx_ld,
    output           dfi_dw_rx_indx_ld,
    output           dfi_ctrlupd_ack,
    output           dfi_phyupd_req,
    output           dfi_lp_pwr_x_e_req,


    input            dfi_init_complete,

    input   [3:0]    dfi_dw_rddata_valid,
    input   [255:0]  dfi_dw_rddata_p0,
    input   [31:0]   dfi_dw_rddata_dm_p0,
    input   [31:0]   dfi_dw_rddata_dbi_p0,
    input   [7:0]    dfi_dw_rddata_par_p0,

    input   [255:0]  dfi_dw_rddata_p1,
    input   [31:0]   dfi_dw_rddata_dm_p1,
    input   [31:0]   dfi_dw_rddata_dbi_p1,
    input   [7:0]    dfi_dw_rddata_par_p1,

    input            dfi_ctrlupd_req,
    input            dfi_phyupd_ack,

    /* Extern interface to the top switch */
    input [31:0] input_address,
    input [1:0] input_request,
    input [P_DATA_WIDTH-1:0] input_write_data,
    input  input_request_valid,
    output output_request_picked,
    output reset_hbm_controller,

    output [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps0,
    output [P_DATA_WIDTH-1:0]           rd_data_ps0,
    output [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps1,
    output [P_DATA_WIDTH-1:0]           rd_data_ps1
    
);

wire [P_ROW_ADDR_WIDTH-1 : 0] row_address;
wire [P_COL_ADDR_WIDTH-1 : 0] column_address;
wire [P_BA_ADDR_WIDTH-1  : 0] bank_address;

wire  [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1]    cmd_picked_bank;
wire  [3:0]                                   cmd_bank                 [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire  [P_BA_ADDR_WIDTH-1 : 0]                 bank_address_bank        [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire  [P_ROW_ADDR_WIDTH-1 : 0]                row_address_bank         [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire  [P_COL_ADDR_WIDTH-1 : 0]                column_address_bank      [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];


wire [3:0]                       cmd_dispatcher            [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire [P_BA_ADDR_WIDTH-1  : 0]    bank_addr_dispatcher      [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire [P_ROW_ADDR_WIDTH-1 : 0]    row_addr_dispatcher       [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire [P_COL_ADDR_WIDTH-1 : 0]    col_addr_dispatcher       [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire                             cmd_picked_dispatcher     [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];

wire [(P_BA_N_PS*2)-1:0]          served_ras;
wire [(P_BA_N_PS*2)-1:0]          served_cas;


/* Request ID and command ID - for tracking and debugging */
/* From extern to dispatcher */
reg [P_REQ_ID_WIDTH-1:0] input_req_id    [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];

/* From dispatcher to bank scheduler */
wire [P_REQ_ID_WIDTH-1:0] req_id          [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];
wire [P_CMD_ID_WIDTH-1:0] cmd_id          [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];

/* From bank scheduler to channel scheduler */
wire [P_REQ_ID_WIDTH-1:0] req_id_bank     [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];
wire [P_CMD_ID_WIDTH-1:0] cmd_id_bank     [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];


wire [P_TOTAL_PER_CHANNEL_BANK_N-1:0] request_picked;
wire [P_TOTAL_PER_CHANNEL_BANK_N-1:0] request_valid;

assign request_valid = input_request_valid << bank_address; 
 
reg [P_REQ_ID_WIDTH-1:0] counter_requests;

assign output_request_picked = |(request_picked);

wire blk_ram_write_en_ps0;
assign blk_ram_write_en_ps0 = request_valid[bank_address];

wire blk_ram_write_en_ps1;
assign blk_ram_write_en_ps1 = request_valid[bank_address];

wire [P_REQ_ID_WIDTH-1:0] blk_ram_wrt_addr;
assign blk_ram_wrt_addr = counter_requests;

wire  [P_DATA_WIDTH-1 : 0] blk_ram_data_out_ps0;
wire  [P_DATA_WIDTH-1 : 0] blk_ram_data_out_ps1;

wire  [P_REQ_ID_WIDTH-1:0] wrt_data_req_id_ps0;
wire  [P_REQ_ID_WIDTH-1:0] wrt_data_req_id_ps1;



/* ADDRESS MAPPING POLICY */
/* 14R-6C-2BG-2B-PC-2C */
`ifdef ADDRESS_MAPPING_1
    assign row_address    =  input_address[26:13];
    assign column_address =  {input_address[12:7]};
    assign bank_address   =  {input_address[2], input_address[6:3]};
`endif
/* 14R-6C-2B-2BG-PC-2C */
`ifdef ADDRESS_MAPPING_2
    assign row_address    =  input_address[26:13];
    assign column_address =  {input_address[12:7]};
    assign bank_address   =  {input_address[2], input_address[4:3],input_address[6:5]};
`endif
/* PC-2BG-2B-14R-6C */
`ifdef ADDRESS_MAPPING_3
    assign row_address    =  {input_address[21:8]};
    assign column_address =  {input_address[7:2]};
    assign bank_address   =  {input_address[26:22]};
`endif
/* 14R-PC-2BG-2B-6C */ 
`ifdef ADDRESS_MAPPING_4
    assign row_address    =  {input_address[26:13]};
    assign column_address =  {input_address[7:2]};
    assign bank_address   =  {input_address[12:8]};
`endif
/* 14R-2BG-2B-6C-PC */
`ifdef ADDRESS_MAPPING_5
    assign row_address    =  input_address[26:13];
    assign column_address =  {input_address[8:3]};
    assign bank_address   =  {input_address[2], input_address[12:9]};
`endif
/* END ADDRESS MAPPING POLICY */

/* TRACK THE NUMBER OF REQUESTS */
always @(posedge dfi_clk_buf or negedge reset_hbm_controller ) begin 
    if ( reset_hbm_controller == 1'b0 ) begin
        counter_requests <= { P_REQ_ID_WIDTH { 1'b0 } };
    end
    else begin
        if ( request_picked[bank_address] == 1'b1 ) begin
            counter_requests <= counter_requests + 1'b1;
            `ifdef DEBUG
                $display("[ CONTROLLER %d ]: REQ: %d - CMD: %d (%d) sent at %d", 1'b0, counter_requests, 1'b0, 1'b0, $time);
            `endif
        end
    end
end

// always_comb begin 
//     if ( reset_hbm_controller == 1'b0 ) begin
//         foreach(input_req_id[i]) input_req_id[i] <= {P_REQ_ID_WIDTH {1'b0}};
//     end
//     else begin
//         input_req_id[bank_address] <= counter_requests;
//     end
// end

/* To be tested */
always_comb begin
    input_req_id[bank_address] <= counter_requests;
end



/* COMPONENTS INSTANTIATION */

/* WRITE BUFFERS */
block_ram #
(
    .ADDR_WIDTH(P_REQ_ID_WIDTH),
    .DATA_WIDTH(P_DATA_WIDTH)
)
block_ram_data_ps0
(
    .data_in(input_write_data),
    .read_addr(wrt_data_req_id_ps0), 
    .write_addr(blk_ram_wrt_addr),
    .wr_en(blk_ram_write_en_ps0), 
    .clk(dfi_clk_buf),
    .data_out(blk_ram_data_out_ps0)
);

block_ram #
(
    .ADDR_WIDTH(P_REQ_ID_WIDTH),
    .DATA_WIDTH(P_DATA_WIDTH)
)
block_ram_data_ps1
(
    .data_in(input_write_data),
    .read_addr(wrt_data_req_id_ps1), 
    .write_addr(blk_ram_wrt_addr),
    .wr_en(blk_ram_write_en_ps1), 
    .clk(dfi_clk_buf),
    .data_out(blk_ram_data_out_ps1)
);

genvar i;
generate 
    for ( i = 0; i < P_TOTAL_PER_CHANNEL_BANK_N; i = i + 1 ) begin : translator_bank_scheduler
            REQ_to_CMD_translator #(
                .P_REQ_WIDTH       (2),
                .P_ADDR_WIDTH      (32),
                .P_DATA_WIDTH      (P_DATA_WIDTH),
                .P_ROW_ADDR_WIDTH  (P_ROW_ADDR_WIDTH),
                .P_COL_ADDR_WIDTH  (P_COL_ADDR_WIDTH),
                .P_BA_ADDR_WIDTH   (P_BA_ADDR_WIDTH),
                .P_REQ_ID_WIDTH    (P_REQ_ID_WIDTH),
                .P_CMD_ID_WIDTH    (P_CMD_ID_WIDTH),                


                .P_QUEUE_LEN       (P_QUEUE_LEN  ),
                .P_WRT_REQ         (P_WRT_REQ    ),
                .P_RD_REQ          (P_RD_REQ     ),
                .P_GENERAL_NOP     (P_GENERAL_NOP),
                .P_ROW_NOP		   (P_ROW_NOP    ),
                .P_ROW_ACT		   (P_ROW_ACT    ),
                .P_ROW_PRE		   (P_ROW_PRE    ),
                .P_ROW_PREA	       (P_ROW_PREA   ),
                .P_COL_WRT		   (P_COL_WRT    ),
                .P_COL_RD          (P_COL_RD     )
            ) REQ_to_CMD_translator_i (
                .clk               (dfi_clk_buf         ),
                .rst_n             (reset_hbm_controller),
                
                .input_req_id      (input_req_id[i]     ), 
                .input_request     (input_request    ),
                
                .row_address(row_address),
                .column_address(column_address),
                .bank_address(bank_address),

                .request_valid     (request_valid[i]  ),
                .request_picked    (request_picked[i] ),
               
                .req_id            (req_id[i]                ),
                .cmd_id            (cmd_id[i]                ),
                .cmd_picked        (cmd_picked_dispatcher[i] ),
                .cmd               (cmd_dispatcher[i]        ),
                .bank_addr         (bank_addr_dispatcher[i]  ),
                .row_addr          (row_addr_dispatcher[i]   ),
                .col_addr          (col_addr_dispatcher[i]   )
            );
    
    
            bank_scheduler#(
                .P_ROW_ADDR_WIDTH          (P_ROW_ADDR_WIDTH ),
                .P_COL_ADDR_WIDTH          (P_COL_ADDR_WIDTH ),
                .P_BA_ADDR_WIDTH           (P_BA_ADDR_WIDTH  ), 
                .P_DATA_WIDTH              (P_DATA_WIDTH     ),
                .P_BANK_INDEX              (i                ),
                .P_GENERAL_NOP             (P_GENERAL_NOP    ),
                .P_ROW_NOP                 (P_ROW_NOP        ),
                .P_ROW_ACT                 (P_ROW_ACT        ),
                .P_ROW_PRE                 (P_ROW_PRE        ),  
                .P_ROW_PREA                (P_ROW_PREA       ),  
                .P_ROW_REFPB               (P_ROW_REFPB      ), 
                .P_COL_WRT                 (P_COL_WRT        ),
                .P_COL_RD                  (P_COL_RD         ),
                .P_REQ_ID_WIDTH            (P_REQ_ID_WIDTH   ),
                .P_CMD_ID_WIDTH            (P_CMD_ID_WIDTH   ),

                .tRCD                      (tRCD   ),
                .tRP                       (tRP    ),
                .tRC                       (tRC    ),
                .tRAS                      (tRAS   ),
                .tWL                       (tWL    ),
                .tRL                       (tRL    ),
                .tRTPl                     (tRTPl  ),
                .tWR                       (tWR    ),
                .tBURST                    (tBURST ),
                .tRFCpb                    (tRFCpb ),
                .tREFP                     (tREFP  )  


            ) bank_scheduler_i (
                .clk                       (dfi_clk_buf ),
                .rst_n                     (reset_hbm_controller   ),
                 
                .req_id_dispatcher         (req_id[i]                ),
                .cmd_id_dispatcher         (cmd_id[i]                ),
                .cmd_dispatcher            (cmd_dispatcher[i]        ),
                .bank_addr_dispatcher      (bank_addr_dispatcher[i]  ),
                .row_addr_dispatcher       (row_addr_dispatcher[i]   ),
                .col_addr_dispatcher       (col_addr_dispatcher[i]   ),
                .cmd_picked_dispatcher     (cmd_picked_dispatcher[i] ),
                

                .cmd_picked_bank           (cmd_picked_bank[i]     ),
                .req_id_bank               (req_id_bank[i]         ),
                .cmd_id_bank               (cmd_id_bank[i]         ),
                .cmd_bank                  (cmd_bank[i]            ),
                .bank_address_bank         (bank_address_bank[i]   ),
                .row_address_bank          (row_address_bank[i]    ),
                .column_address_bank       (column_address_bank[i] ),
                .served_ras                (served_ras[i]          ),
                .served_cas                (served_cas[i]          )
            );
    end
endgenerate


channel_scheduler#(
    .P_TOTAL_PER_CHANNEL_BANK_N( P_TOTAL_PER_CHANNEL_BANK_N),
    .P_WRT_DATA_BUFFER_LEN (P_WRT_DATA_BUFFER_LEN),

    .P_COL_NOP		    (P_COL_NOP    ),
    .P_COL_RD		    (P_COL_RD     ),
    .P_COL_RD_AP		(P_COL_RD_AP  ),
    .P_COL_WRT		    (P_COL_WRT    ),
    .P_COL_WRT_AP	    (P_COL_WRT_AP ),
    .P_COL_MRS		    (P_COL_MRS    ),

    .P_ROW_NOP		    (P_ROW_NOP    ),
    .P_ROW_ACT		    (P_ROW_ACT    ),
    .P_ROW_PRE		    (P_ROW_PRE    ), 
    .P_ROW_PREA		    (P_ROW_PREA   ),  
    .P_ROW_REFPB        (P_ROW_REFPB  ), 
    .P_GENERAL_NOP      (P_GENERAL_NOP),
    
    .P_REQ_ID_WIDTH    (P_REQ_ID_WIDTH),
    .P_CMD_ID_WIDTH    (P_CMD_ID_WIDTH),

    .tWL        (tWL   ),      
    .tRL        (tRL   ),
    .tCCDl      (tCCDl ),      
    .tRTW       (tRTW  ),
    .tWTRl      (tWTRl ),      
    .tRRD       (tRRD  ), 
    .tFAW       (tFAW  ),
    .tWTRs      (tWTRs ),
    .tRFCpb     (tRFCpb),
    .tRREFD     (tRREFD)

)
channel_0_scheduler
(
    .dfi_clk                               (dfi_clk_buf),
    .dfi_rst_n                             (dfi_rst_n),
    
    .dfi_rst_buf_n                         (dfi_rst_buf_n),
    .dfi_init_start                        (dfi_init_start         ),
    .dfi_aw_ck_p0                          (dfi_aw_ck_p0           ),
    .dfi_aw_cke_p0                         (dfi_aw_cke_p0          ),
    .dfi_aw_row_p0                         (dfi_aw_row_p0          ),
    .dfi_aw_col_p0                         (dfi_aw_col_p0          ),
    .dfi_dw_wrdata_p0                      (dfi_dw_wrdata_p0       ),
    .dfi_dw_wrdata_mask_p0                 (dfi_dw_wrdata_mask_p0  ),
    .dfi_dw_wrdata_dbi_p0                  (dfi_dw_wrdata_dbi_p0   ),
    .dfi_dw_wrdata_par_p0                  (dfi_dw_wrdata_par_p0   ),
    .dfi_dw_wrdata_dq_en_p0                (dfi_dw_wrdata_dq_en_p0 ),
    .dfi_dw_wrdata_par_en_p0               (dfi_dw_wrdata_par_en_p0),
    .dfi_aw_ck_p1                          (dfi_aw_ck_p1           ),
    .dfi_aw_cke_p1                         (dfi_aw_cke_p1          ),
    .dfi_aw_row_p1                         (dfi_aw_row_p1          ),
    .dfi_aw_col_p1                         (dfi_aw_col_p1          ),
    .dfi_dw_wrdata_p1                      (dfi_dw_wrdata_p1       ),
    .dfi_dw_wrdata_mask_p1                 (dfi_dw_wrdata_mask_p1  ),
    .dfi_dw_wrdata_dbi_p1                  (dfi_dw_wrdata_dbi_p1   ),
    .dfi_dw_wrdata_par_p1                  (dfi_dw_wrdata_par_p1   ),
    .dfi_dw_wrdata_dq_en_p1                (dfi_dw_wrdata_dq_en_p1 ),
    .dfi_dw_wrdata_par_en_p1               (dfi_dw_wrdata_par_en_p1),
    .dfi_aw_ck_dis                         (dfi_aw_ck_dis          ),
    .dfi_lp_pwr_e_req                      (dfi_lp_pwr_e_req       ),
    .dfi_lp_sr_e_req                       (dfi_lp_sr_e_req        ),
    .dfi_lp_pwr_x_req                      (dfi_lp_pwr_x_req     ),
    .dfi_aw_tx_indx_ld                     (dfi_aw_tx_indx_ld      ),
    .dfi_dw_tx_indx_ld                     (dfi_dw_tx_indx_ld      ),
    .dfi_dw_rx_indx_ld                     (dfi_dw_rx_indx_ld      ),
    .dfi_ctrlupd_ack                       (dfi_ctrlupd_ack        ),
    .dfi_phyupd_req                        (dfi_phyupd_req         ),
    .dfi_lp_pwr_x_e_req                    (dfi_lp_pwr_x_e_req),

    .dfi_init_complete                     (dfi_init_complete   ),
    .dfi_dw_rddata_valid                   (dfi_dw_rddata_valid ),
    .dfi_dw_rddata_p0                      (dfi_dw_rddata_p0    ),
    .dfi_dw_rddata_dm_p0                   (dfi_dw_rddata_dm_p0 ),
    .dfi_dw_rddata_dbi_p0                  (dfi_dw_rddata_dbi_p0),
    .dfi_dw_rddata_par_p0                  (dfi_dw_rddata_par_p0),
    .dfi_dw_rddata_p1                      (dfi_dw_rddata_p1    ),
    .dfi_dw_rddata_dm_p1                   (dfi_dw_rddata_dm_p1 ),
    .dfi_dw_rddata_dbi_p1                  (dfi_dw_rddata_dbi_p1),
    .dfi_dw_rddata_par_p1                  (dfi_dw_rddata_par_p1),
    .dfi_ctrlupd_req                       (dfi_ctrlupd_req     ),
    .dfi_phyupd_ack                        (dfi_phyupd_ack      ),
    
    .cmd_picked_bank             (cmd_picked_bank),
    .req_id_bank                 (req_id_bank),
    .cmd_id_bank                 (cmd_id_bank),
    .cmd_bank                    (cmd_bank),
    .bank_address_bank           (bank_address_bank),
    .row_address_bank            (row_address_bank),
    .column_address_bank         (column_address_bank),
    
    .served_ras(served_ras),
    .served_cas(served_cas),

    .reset_hbm_controller(reset_hbm_controller),

    .wrt_data_cas_ps0(blk_ram_data_out_ps0),
    .wrt_data_cas_ps1(blk_ram_data_out_ps1),

    .wrt_data_req_id_ps0(wrt_data_req_id_ps0),
    .wrt_data_req_id_ps1(wrt_data_req_id_ps1),

    .rd_data_req_id_ps0(rd_data_req_id_ps0),
    .rd_data_ps0(rd_data_ps0),
    .rd_data_req_id_ps1(rd_data_req_id_ps1),
    .rd_data_ps1(rd_data_ps1)
);

endmodule