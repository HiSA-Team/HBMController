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


module HBM_controller # (
    parameter       P_DRIVE_PRECHARGE_CMD  = 114,
    parameter		P_PRECHG_THR           = 200,
    parameter		P_ACT_THR	           = 40,
    parameter		P_WRT_THR	           = 60,
    parameter		P_RD_THR	           = 60,
    parameter		P_DRIVE_ACT_CMD        = 240,
    parameter		P_MRS_CNT              = 8'hc0,

    parameter		P_ROW_ADDR_WIDTH           = 16,
    parameter		P_COL_ADDR_WIDTH           = 12,
    parameter		P_BA_ADDR_WIDTH	           = 5, 
    parameter       P_BA_N_PS                  = 16,        /* Number of Banks per PS, here we consider half bank for PS */
    parameter       P_BA_N_G                   = 4,         /* Number of Banks per group */
    parameter       P_DATA_WIDTH               = 256,
    parameter       P_TOTAL_PER_CHANNEL_BANK_N = 32,        /* Number of Banks per channel, again we consider half bank */

    /* FIFO QUEUE LEN */
    parameter       P_QUEUE_LEN             = 128,

    /* WRT BUFFER LEN */
    parameter       P_WRT_DATA_BUFFER_LEN   = 128,
    
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
    parameter       P_ROW_REFPB       =  4'b1001, 
    

    /* HBM INTRA BANK TIMING CONSTRAINTS  */
    parameter    tRCD     =  32'd14,
    parameter    tRP      =  32'd14,
    parameter    tRC      =  32'd1,
    parameter    tRAS     =  32'd34,
    parameter    tWL      =  32'd4,
    parameter    tRL      =  32'd14,
    parameter    tRTPl    =  32'd6,
    parameter    tWR      =  32'd16,
    parameter    tBURST   =  32'd2,
    parameter    tRFCpb   =  32'd20,
    parameter    tREFP    =  32'd1450,

    /* HBM INTRA AND INTER BANK TIMING CONSTRAINTS */      
    parameter    tCCDl    =  32'd1,
    parameter    tRTW     =  32'd8, 
    parameter    tWTRl    =  32'd8, /* 32'd10 */
    parameter    tRRD     =  32'd8,
    parameter    tFAW     =  32'd30,
    parameter    tWTRs    =  32'd8,
    parameter    tRREFD   =  32'd4

)(

    input HBM_REF_CLK_0_buf,
 
    input dfi_0_clk_buf,
    input dfi_0_rst_n,
    
    input APB_0_PCLK_BUF,
    input APB_0_PRESET_N_sync  
);

wire           dfi_0_init_start;
wire   [1:0]   dfi_0_aw_ck_p0;
wire   [1:0]   dfi_0_aw_cke_p0;
wire   [11:0]  dfi_0_aw_row_p0;
wire   [15:0]  dfi_0_aw_col_p0;
wire   [255:0] dfi_0_dw_wrdata_p0;
wire   [31:0]  dfi_0_dw_wrdata_mask_p0;
wire   [31:0]  dfi_0_dw_wrdata_dbi_p0;
wire   [7:0]   dfi_0_dw_wrdata_par_p0;
wire   [7:0]   dfi_0_dw_wrdata_dq_en_p0;
wire   [7:0]   dfi_0_dw_wrdata_par_en_p0;
wire   [1:0]   dfi_0_aw_ck_p1;
wire   [1:0]   dfi_0_aw_cke_p1;
wire   [11:0]  dfi_0_aw_row_p1;
wire   [15:0]  dfi_0_aw_col_p1;
wire   [255:0] dfi_0_dw_wrdata_p1;
wire   [31:0]  dfi_0_dw_wrdata_mask_p1;
wire   [31:0]  dfi_0_dw_wrdata_dbi_p1;
wire   [7:0]   dfi_0_dw_wrdata_par_p1;
wire   [7:0]   dfi_0_dw_wrdata_dq_en_p1;
wire   [7:0]   dfi_0_dw_wrdata_par_en_p1;
wire           dfi_0_aw_ck_dis;
wire           dfi_0_lp_pwr_e_req;
wire           dfi_0_lp_sr_e_req;
wire           dfi_0_lp_pwr_x_e_req;
wire           dfi_0_aw_tx_indx_ld;
wire           dfi_0_dw_tx_indx_ld;
wire           dfi_0_dw_rx_indx_ld;
wire           dfi_0_ctrlupd_ack;
wire           dfi_0_phyupd_req;
wire           dfi_0_init_complete;
wire   [255:0] dfi_0_dw_rddata_p0;
wire   [31:0]  dfi_0_dw_rddata_dm_p0;
wire   [31:0]  dfi_0_dw_rddata_dbi_p0;
wire   [7:0]   dfi_0_dw_rddata_par_p0;
wire   [255:0] dfi_0_dw_rddata_p1;
wire   [31:0]  dfi_0_dw_rddata_dm_p1;
wire   [31:0]  dfi_0_dw_rddata_dbi_p1;
wire   [7:0]   dfi_0_dw_rddata_par_p1;
wire   [15:0]  dfi_0_dbi_byte_disable;
wire   [3:0]   dfi_0_dw_rddata_valid;
wire   [7:0]   dfi_0_dw_derr_n;
wire   [1:0]   dfi_0_aw_aerr_n;
wire           dfi_0_ctrlupd_req;
wire           dfi_0_phyupd_ack;
wire           dfi_0_clk_init;
wire           dfi_0_out_rst_n;
wire   [7:0]   dfi_0_dw_wrdata_dqs_p0;
wire   [7:0]   dfi_0_dw_wrdata_dqs_p1;


wire          DRAM_0_STAT_CATTRIP;
wire [  6:0]  DRAM_0_STAT_TEMP;


wire     [ 31:0]  APB_0_PWDATA = 32'b0;
wire     [ 21:0]  APB_0_PADDR  = 22'b0;
wire              APB_0_PENABLE = 1'b0;
wire              APB_0_PSEL = 1'b0;
wire              APB_0_PWRITE = 1'b0;
wire     [ 31:0]  APB_0_PRDATA;
wire              APB_0_PREADY;
wire              APB_0_PSLVERR;
wire              apb_seq_complete_0_s;


wire  [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1]    cmd_picked_bank;
wire  [3:0]                                   cmd_bank                 [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire  [P_BA_ADDR_WIDTH-1 : 0]                 bank_address_bank        [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire  [P_ROW_ADDR_WIDTH-1 : 0]                row_address_bank         [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire  [P_COL_ADDR_WIDTH-1 : 0]                column_address_bank      [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire  [P_DATA_WIDTH-1 : 0]                    wrt_data_bank            [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];


wire ready_to_cmd_ras_ps0;
wire ready_to_cmd_cas_ps0;
wire ready_to_cmd_ras_ps1;
wire ready_to_cmd_cas_ps1;


wire [3:0]                       cmd_dispatcher            [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire [P_BA_ADDR_WIDTH-1  : 0]    bank_addr_dispatcher      [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire [P_ROW_ADDR_WIDTH-1 : 0]    row_addr_dispatcher       [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire [P_COL_ADDR_WIDTH-1 : 0]    col_addr_dispatcher       [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire [P_DATA_WIDTH-1     : 0]    wrt_data_dispatcher       [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
wire                             cmd_picked_dispatcher     [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];

reg [1:0]                                                       input_request [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];
reg [P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH+P_BA_ADDR_WIDTH-1 : 0 ]  input_address [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];
reg [P_DATA_WIDTH-1 : 0]                                        input_data    [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];

reg   request_valid    [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];
wire  request_picked   [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];


wire [(P_BA_N_PS*2)-1:0]          served_ras;
wire [(P_BA_N_PS*2)-1:0]          served_cas;


/* Request ID and command ID - for tracking and debugging */
/* From extern to dispatcher */
reg  [63:0] r_input_req_id  [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];
wire [63:0] input_req_id    [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];

/* From dispatcher to bank scheduler */
wire [63:0] req_id          [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];
wire [63:0] cmd_id          [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];

/* From bank scheduler to channel scheduler */
wire [63:0] req_id_bank     [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];
wire [63:0] cmd_id_bank     [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];

assign input_req_id = r_input_req_id;


/* SIMULATION */

integer fd;
string  line;
string  request;
reg [31:0] address;

reg cnt_ps = 0;
reg [63:0]counter_requests; 

initial begin
    counter_requests <= {64{1'b0}};
    wait(dfi_0_rst_n == 1'b1);
    
    fd = $fopen("/home/manuel/VivadoProjects/HBMController_0/HBMController_0.srcs/sources_1/new/fwd_softmax_workload.txt", "r");
    while(!$feof(fd))begin
        $fgets(line, fd);
        
        request = line.substr(0,1);
        address = line.substr(4,35).atobin();
        if (request == "RD") begin
            input_request[{address[2], address[6:3]}] <= 2'b01;
        end
        else begin
            input_request[{address[2], address[6:3]}] <= 2'b00;
        end
        
        input_address[{address[2], address[6:3]}] <= {1'b0,  address};
        r_input_req_id[{address[2], address[6:3]}] <= counter_requests;
        
        request_valid[{address[2], address[6:3]}] <= 1'b1;
        wait(request_picked[{address[2], address[6:3]}] == 1'b1);
        request_valid[{address[2], address[6:3]}] <= 1'b0;   
        
        $display("[ CONTROLLER %d ]: REQ: %d - CMD: %d (%d) sent at %d", 1'b0, counter_requests, 1'b0, 1'b0, $time);

        wait(request_picked[{address[2], address[6:3]}] == 1'b0);
        cnt_ps = cnt_ps + 1'b1;
        counter_requests <= counter_requests + 1'b1;
    end
    
    $fclose(fd);
    $finish;
end


/* END SIMULATION */

genvar i;
generate 
    for ( i = 0; i < P_TOTAL_PER_CHANNEL_BANK_N; i = i + 1 ) begin : dispatcher_bank_scheduler
            command_dispatcher #(
                .P_REQ_WIDTH       (2),
                .P_ADDR_WIDTH      (P_ROW_ADDR_WIDTH+P_COL_ADDR_WIDTH+P_BA_ADDR_WIDTH),
                .P_DATA_WIDTH      (P_DATA_WIDTH),
                .P_ROW_ADDR_WIDTH  (P_ROW_ADDR_WIDTH),
                .P_COL_ADDR_WIDTH  (P_COL_ADDR_WIDTH),
                .P_BA_ADDR_WIDTH   (P_BA_ADDR_WIDTH),


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
            ) command_dispatcher (
                .clk               (dfi_0_clk_buf     ),
                .rst_n             (dfi_0_rst_n       ),
                
                .input_req_id      (input_req_id[i]   ), 
                .input_request     (input_request[i]  ),
                .input_address     (input_address[i]  ),
                .input_data        (input_data[i]     ),
                .request_valid     (request_valid[i]  ),
                .request_picked    (request_picked[i] ),
               
                .req_id            (req_id[i]                ),
                .cmd_id            (cmd_id[i]                ),
                .cmd_picked        (cmd_picked_dispatcher[i] ),
                .cmd               (cmd_dispatcher[i]        ),
                .bank_addr         (bank_addr_dispatcher[i]  ),
                .row_addr          (row_addr_dispatcher[i]   ),
                .col_addr          (col_addr_dispatcher[i]   ),
                .wrt_data          (wrt_data_dispatcher[i]   )
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


            ) bank_scheduler(
                .clk                       (dfi_0_clk_buf ),
                .rst_n                     (dfi_0_rst_n   ),
                 
                .req_id_dispatcher         (req_id[i]                ),
                .cmd_id_dispatcher         (cmd_id[i]                ),
                .cmd_dispatcher            (cmd_dispatcher[i]        ),
                .bank_addr_dispatcher      (bank_addr_dispatcher[i]  ),
                .row_addr_dispatcher       (row_addr_dispatcher[i]   ),
                .col_addr_dispatcher       (col_addr_dispatcher[i]   ),
                .wrt_data_dispatcher       (wrt_data_dispatcher[i]   ),
                .cmd_picked_dispatcher     (cmd_picked_dispatcher[i] ),
                

                .cmd_picked_bank           (cmd_picked_bank[i]     ),
                .req_id_bank               (req_id_bank[i]         ),
                .cmd_id_bank               (cmd_id_bank[i]         ),
                .cmd_bank                  (cmd_bank[i]            ),
                .bank_address_bank         (bank_address_bank[i]   ),
                .row_address_bank          (row_address_bank[i]    ),
                .column_address_bank       (column_address_bank[i] ),
                .wrt_data_bank             (wrt_data_bank[i]       ),
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

    .tWL        (tWL   ),      
    .tRL        (tRL   ),
    .tCCDl      (tCCDl ),      
    .tRTW       (tRTW  ),
    .tWTRl      (tWTRl ),      
    .tRRD       (tRRD  ), 
    .tFAW       (tFAW  ),
    .tWTRs      (tWTRs ),
    .tRREFD     (tRREFD)

)
channel_0_scheduler
(
    .dfi_clk                               (dfi_0_clk_buf),
    .dfi_rst_n                             (dfi_0_rst_n),
    
    .dfi_rst_buf_n                         (dfi_0_out_rst_n),
    .dfi_init_start                        (dfi_0_init_start         ),
    .dfi_aw_ck_p0                          (dfi_0_aw_ck_p0           ),
    .dfi_aw_cke_p0                         (dfi_0_aw_cke_p0          ),
    .dfi_aw_row_p0                         (dfi_0_aw_row_p0          ),
    .dfi_aw_col_p0                         (dfi_0_aw_col_p0          ),
    .dfi_dw_wrdata_p0                      (dfi_0_dw_wrdata_p0       ),
    .dfi_dw_wrdata_mask_p0                 (dfi_0_dw_wrdata_mask_p0  ),
    .dfi_dw_wrdata_dbi_p0                  (dfi_0_dw_wrdata_dbi_p0   ),
    .dfi_dw_wrdata_par_p0                  (dfi_0_dw_wrdata_par_p0   ),
    .dfi_dw_wrdata_dq_en_p0                (dfi_0_dw_wrdata_dq_en_p0 ),
    .dfi_dw_wrdata_par_en_p0               (dfi_0_dw_wrdata_par_en_p0),
    .dfi_aw_ck_p1                          (dfi_0_aw_ck_p1           ),
    .dfi_aw_cke_p1                         (dfi_0_aw_cke_p1          ),
    .dfi_aw_row_p1                         (dfi_0_aw_row_p1          ),
    .dfi_aw_col_p1                         (dfi_0_aw_col_p1          ),
    .dfi_dw_wrdata_p1                      (dfi_0_dw_wrdata_p1       ),
    .dfi_dw_wrdata_mask_p1                 (dfi_0_dw_wrdata_mask_p1  ),
    .dfi_dw_wrdata_dbi_p1                  (dfi_0_dw_wrdata_dbi_p1   ),
    .dfi_dw_wrdata_par_p1                  (dfi_0_dw_wrdata_par_p1   ),
    .dfi_dw_wrdata_dq_en_p1                (dfi_0_dw_wrdata_dq_en_p1 ),
    .dfi_dw_wrdata_par_en_p1               (dfi_0_dw_wrdata_par_en_p1),
    .dfi_aw_ck_dis                         (dfi_0_aw_ck_dis          ),
    .dfi_lp_pwr_e_req                      (dfi_0_lp_pwr_e_req       ),
    .dfi_lp_sr_e_req                       (dfi_0_lp_sr_e_req        ),
    .dfi_lp_pwr_x_e_req                    (dfi_0_lp_pwr_x_e_req     ),
    .dfi_aw_tx_indx_ld                     (dfi_0_aw_tx_indx_ld      ),
    .dfi_dw_tx_indx_ld                     (dfi_0_dw_tx_indx_ld      ),
    .dfi_dw_rx_indx_ld                     (dfi_0_dw_rx_indx_ld      ),
    .dfi_ctrlupd_ack                       (dfi_0_ctrlupd_ack        ),
    .dfi_phyupd_req                        (dfi_0_phyupd_req         ),

    .dfi_init_complete                     (dfi_0_init_complete   ),
    .dfi_dw_rddata_valid                   (dfi_0_dw_rddata_valid ),
    .dfi_dw_rddata_p0                      (dfi_0_dw_rddata_p0    ),
    .dfi_dw_rddata_dm_p0                   (dfi_0_dw_rddata_dm_p0 ),
    .dfi_dw_rddata_dbi_p0                  (dfi_0_dw_rddata_dbi_p0),
    .dfi_dw_rddata_par_p0                  (dfi_0_dw_rddata_par_p0),
    .dfi_dw_rddata_p1                      (dfi_0_dw_rddata_p1    ),
    .dfi_dw_rddata_dm_p1                   (dfi_0_dw_rddata_dm_p1 ),
    .dfi_dw_rddata_dbi_p1                  (dfi_0_dw_rddata_dbi_p1),
    .dfi_dw_rddata_par_p1                  (dfi_0_dw_rddata_par_p1),
    .dfi_ctrlupd_req                       (dfi_0_ctrlupd_req     ),
    .dfi_phyupd_ack                        (dfi_0_phyupd_ack      ),
    
    .cmd_picked_bank             (cmd_picked_bank),
    .req_id_bank                 (req_id_bank),
    .cmd_id_bank                 (cmd_id_bank),
    .cmd_bank                    (cmd_bank),
    .bank_address_bank           (bank_address_bank),
    .row_address_bank            (row_address_bank),
    .column_address_bank         (column_address_bank),
    .wrt_data_bank               (wrt_data_bank),
    
    .ready_to_cmd_ras_ps0        (ready_to_cmd_ras_ps0),
    .ready_to_cmd_cas_ps0        (ready_to_cmd_cas_ps0),
    .ready_to_cmd_ras_ps1        (ready_to_cmd_ras_ps1),
    .ready_to_cmd_cas_ps1        (ready_to_cmd_cas_ps1),
    
    
    .served_ras(served_ras),
    .served_cas(served_cas)
);


hbm_0 hbm_0_i
(
    .HBM_REF_CLK_0                 (HBM_REF_CLK_0_buf)
    ,.dfi_0_clk                    (dfi_0_clk_buf)
    ,.dfi_0_rst_n                  (dfi_0_rst_n   )
    ,.dfi_0_init_start             (dfi_0_init_start         )
    ,.dfi_0_aw_ck_p0               (dfi_0_aw_ck_p0           )
    ,.dfi_0_aw_cke_p0              (dfi_0_aw_cke_p0          )
    ,.dfi_0_aw_row_p0              (dfi_0_aw_row_p0          )
    ,.dfi_0_aw_col_p0              (dfi_0_aw_col_p0          )
    ,.dfi_0_dw_wrdata_p0           (dfi_0_dw_wrdata_p0       )
    ,.dfi_0_dw_wrdata_mask_p0      (dfi_0_dw_wrdata_mask_p0  )
    ,.dfi_0_dw_wrdata_dbi_p0       (dfi_0_dw_wrdata_dbi_p0   )
    ,.dfi_0_dw_wrdata_par_p0       (dfi_0_dw_wrdata_par_p0   )
    ,.dfi_0_dw_wrdata_dq_en_p0     (dfi_0_dw_wrdata_dq_en_p0 )
    ,.dfi_0_dw_wrdata_par_en_p0    (dfi_0_dw_wrdata_par_en_p0)
    ,.dfi_0_aw_ck_p1               (dfi_0_aw_ck_p1           )
    ,.dfi_0_aw_cke_p1              (dfi_0_aw_cke_p1          )
    ,.dfi_0_aw_row_p1              (dfi_0_aw_row_p1          )
    ,.dfi_0_aw_col_p1              (dfi_0_aw_col_p1          )
    ,.dfi_0_dw_wrdata_p1           (dfi_0_dw_wrdata_p1       )
    ,.dfi_0_dw_wrdata_mask_p1      (dfi_0_dw_wrdata_mask_p1  )
    ,.dfi_0_dw_wrdata_dbi_p1       (dfi_0_dw_wrdata_dbi_p1   )
    ,.dfi_0_dw_wrdata_par_p1       (dfi_0_dw_wrdata_par_p1   )
    ,.dfi_0_dw_wrdata_dq_en_p1     (dfi_0_dw_wrdata_dq_en_p1 )
    ,.dfi_0_dw_wrdata_par_en_p1    (dfi_0_dw_wrdata_par_en_p1)
    ,.dfi_0_aw_ck_dis              (dfi_0_aw_ck_dis          )
    ,.dfi_0_lp_pwr_e_req           (dfi_0_lp_pwr_e_req       )
    ,.dfi_0_lp_sr_e_req            (dfi_0_lp_sr_e_req        )
    ,.dfi_0_lp_pwr_x_req           (dfi_0_lp_pwr_x_e_req     )
    ,.dfi_0_aw_tx_indx_ld          (dfi_0_aw_tx_indx_ld      )
    ,.dfi_0_dw_tx_indx_ld          (dfi_0_dw_tx_indx_ld      )
    ,.dfi_0_dw_rx_indx_ld          (dfi_0_dw_rx_indx_ld      )
    ,.dfi_0_ctrlupd_ack            (dfi_0_ctrlupd_ack        )
    ,.dfi_0_phyupd_req             (dfi_0_phyupd_req         )
    ,.dfi_0_dw_wrdata_dqs_p0       (8'hff)
    ,.dfi_0_dw_wrdata_dqs_p1       (8'hff)

    ,.APB_0_PCLK                   (APB_0_PCLK_BUF)
    ,.APB_0_PRESET_N               (APB_0_PRESET_N_sync)
//    ,.APB_0_PWDATA                 (APB_0_PWDATA  )
//    ,.APB_0_PADDR                  (APB_0_PADDR   )
//    ,.APB_0_PENABLE                (APB_0_PENABLE )
//    ,.APB_0_PSEL                   (APB_0_PSEL    )
//    ,.APB_0_PWRITE                 (APB_0_PWRITE  )

    ,.dfi_0_dw_rddata_p0           (dfi_0_dw_rddata_p0    )
    ,.dfi_0_dw_rddata_dm_p0        (dfi_0_dw_rddata_dm_p0 )
    ,.dfi_0_dw_rddata_dbi_p0       (dfi_0_dw_rddata_dbi_p0)
    ,.dfi_0_dw_rddata_par_p0       (dfi_0_dw_rddata_par_p0)
    ,.dfi_0_dw_rddata_p1           (dfi_0_dw_rddata_p1    )
    ,.dfi_0_dw_rddata_dm_p1        (dfi_0_dw_rddata_dm_p1 )
    ,.dfi_0_dw_rddata_dbi_p1       (dfi_0_dw_rddata_dbi_p1)
    ,.dfi_0_dw_rddata_par_p1       (dfi_0_dw_rddata_par_p1)
    ,.dfi_0_dbi_byte_disable       ( /* Not Connected */  )
    ,.dfi_0_dw_rddata_valid        (dfi_0_dw_rddata_valid)
    ,.dfi_0_dw_derr_n              ( /* Not Connected */  )
    ,.dfi_0_aw_aerr_n              ( /* Not Connected */  )
    ,.dfi_0_ctrlupd_req            (dfi_0_ctrlupd_req)
    ,.dfi_0_phyupd_ack             (dfi_0_phyupd_ack )
    ,.dfi_0_clk_init               ( /* Not Connected */  )
    ,.dfi_0_init_complete          (dfi_0_init_complete)
    ,.dfi_0_out_rst_n              (dfi_0_out_rst_n    )

    ,.apb_complete_0               (apb_seq_complete_0_s)
//    ,.APB_0_PRDATA                 (APB_0_PRDATA )
//    ,.APB_0_PREADY                 (APB_0_PREADY )
//    ,.APB_0_PSLVERR                (APB_0_PSLVERR)

    ,.DRAM_0_STAT_CATTRIP          (DRAM_0_STAT_CATTRIP)
    ,.DRAM_0_STAT_TEMP             (DRAM_0_STAT_TEMP   )
);

endmodule