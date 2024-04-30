`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/27/2023 10:51:07 AM
// Design Name: 
// Module Name: channel_scheduler
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


module channel_scheduler#
(
    parameter       P_DRIVE_PRECHARGE_CMD    = 114,
    parameter		P_PRECHG_THR             = 200,
    parameter		P_ACT_THR	             = 40,
    parameter		P_WRT_THR	             = 60,
    parameter		P_RD_THR	             = 60,
    parameter		P_DRIVE_ACT_CMD          = 240,
    parameter		P_MRS_CNT                = 8'hc0,

    parameter		P_ROW_ADDR_WIDTH            = 14,
    parameter		P_COL_ADDR_WIDTH            = 6,
    parameter		P_BA_ADDR_WIDTH	            = 5, 
    parameter       P_BA_N_PS                   = 16,        /* Number of Banks per PS, here we consider half bank for PS */
    parameter       P_BA_N_G                    = 4,         /* Number of Banks per group */ 
    parameter       P_DATA_WIDTH                = 256,
    parameter       P_TOTAL_PER_CHANNEL_BANK_N  = 32,        /* Number of Banks per channel, again we consider half bank */

    parameter       P_WRT_DATA_BUFFER_LEN       = 16,

    /* COMMANDS */
    /* COLUMN COMMANDS */
    parameter       P_COL_NOP		    = 4'b1111,
    parameter       P_COL_RD		    = 4'b0101,
    parameter       P_COL_RD_AP		    = 4'b1101,
    parameter       P_COL_WRT		    = 4'b0001,
    parameter       P_COL_WRT_AP	    = 4'b1001,
    parameter       P_COL_MRS		    = 4'b0000,

    /* ROW COMMANDS */
    parameter       P_ROW_NOP		    = 4'b1111,
    parameter       P_ROW_ACT		    = 3'b010,
    parameter       P_ROW_PRE		    = 3'b011, 
    parameter       P_ROW_PREA		    = 3'b011,  
    parameter       P_ROW_REFPB         = /*4'b1001*/ 4'b1100, 
    parameter       P_GENERAL_NOP       = 4'b1111,

    /* HBM INTRA AND INTER BANK TIMING CONSTRAINTS */
    parameter       tWL        =  32'd4  ,      
    parameter       tRL        =  32'd14 ,
    parameter       tCCDl      =  32'd1  ,      
    parameter       tRTW       =  32'd8  ,
    parameter       tWTRl      =  32'd8  ,      
    parameter       tRRD       =  32'd8  , 
    parameter       tFAW       =  32'd30 ,
    parameter       tWTRs      =  32'd8  ,
    parameter       tRFCpb     =  32'd73,
    parameter       tRREFD     =  32'd4
)
(
    //DFI INTERFACE SIGNALS
    input               dfi_clk,
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
    output              dfi_lp_pwr_x_e_req,

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
    
    /* Interface to bank scheduler */
    output [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1]  cmd_picked_bank,
    input  [20:0]                                req_id_bank                 [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    input  [20:0]                                cmd_id_bank                 [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    input  [3:0]                                 cmd_bank                    [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    input  [P_BA_ADDR_WIDTH-1 : 0]               bank_address_bank           [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    input  [P_ROW_ADDR_WIDTH-1 : 0]              row_address_bank            [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    input  [P_COL_ADDR_WIDTH-1 : 0]              column_address_bank         [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    input  [P_DATA_WIDTH-1 : 0]                  wrt_data_bank               [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    
    output ready_to_cmd_ras_ps0,
    output ready_to_cmd_cas_ps0,
    output ready_to_cmd_ras_ps1,
    output ready_to_cmd_cas_ps1,
    
    output [(P_BA_N_PS*2)-1:0]          served_ras,
    output [(P_BA_N_PS*2)-1:0]          served_cas,

    output reset_hbm_controller,

    output [20:0]                       rd_data_req_id_ps0,
    output [P_DATA_WIDTH-1:0]           rd_data_ps0,
    output [20:0]                       rd_data_req_id_ps1,
    output [P_DATA_WIDTH-1:0]           rd_data_ps1
    
       
);


/* To ll_command_forwarder */
wire [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1] cmd_picked_ras;
wire [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1] cmd_picked_cas;

genvar i;
generate 
    for ( i = 0; i <  P_TOTAL_PER_CHANNEL_BANK_N; i = i + 1) begin
        assign cmd_picked_bank[i] = cmd_picked_ras[i] || cmd_picked_cas[i];
    end
endgenerate

/* From arbiters to LLCF */
/* RAS cmd PS0 */
wire [3:0]                         cmd_ras_ps0;
wire [20:0]                        req_ras_id_ps0;
wire [20:0]                        cmd_ras_id_ps0;
wire [ P_BA_ADDR_WIDTH  - 1 : 0 ]  bank_address_ras_ps0;
wire [ P_ROW_ADDR_WIDTH - 1 : 0 ]  row_address_ras_ps0;
    
/* CAS cmd PS0 */
wire [3:0]                         cmd_cas_ps0;
wire [20:0]                        req_cas_id_ps0;
wire [20:0]                        cmd_cas_id_ps0;
wire [ P_BA_ADDR_WIDTH  - 1 : 0 ]  bank_address_cas_ps0;
wire [ P_COL_ADDR_WIDTH - 1 : 0 ]  column_address_cas_ps0;
wire [ P_DATA_WIDTH     - 1 : 0 ]  wrt_data_cas_ps0;
    
/* RAS cmd PS1 */
wire [3:0]                         cmd_ras_ps1;
wire [20:0]                        req_ras_id_ps1;
wire [20:0]                        cmd_ras_id_ps1;
wire [ P_BA_ADDR_WIDTH  - 1 : 0 ]  bank_address_ras_ps1;
wire [ P_ROW_ADDR_WIDTH - 1 : 0 ]  row_address_ras_ps1;

/* CAS cmd PS1 */
wire [3:0]                         cmd_cas_ps1;
wire [20:0]                        req_cas_id_ps1;
wire [20:0]                        cmd_cas_id_ps1;
wire [ P_BA_ADDR_WIDTH  - 1 : 0 ]  bank_address_cas_ps1;
wire [ P_COL_ADDR_WIDTH - 1 : 0 ]  column_address_cas_ps1;
wire [ P_DATA_WIDTH     - 1 : 0 ]  wrt_data_cas_ps1;


RAS_arbiter #(
    .P_BA_N_PS         (P_BA_N_PS        ),
    .P_BA_N_G          (P_BA_N_G         ), 
    .P_ROW_ADDR_WIDTH  (P_ROW_ADDR_WIDTH ),
    .P_BA_ADDR_WIDTH   (P_BA_ADDR_WIDTH  ),
 
    .P_GENERAL_NOP     (P_GENERAL_NOP),
    .P_COL_WRT	       (P_COL_WRT    ),
    .P_COL_RD          (P_COL_RD     ),
    .P_ROW_ACT		   (P_ROW_ACT    ),
    .P_ROW_PRE		   (P_ROW_PRE    ),
    .P_ROW_REFPB       (P_ROW_REFPB  )

) RAS_arbiter_ps0 (
    .clk(dfi_clk),
    .rst_n (reset_hbm_controller),

    .cmd_ras_bank_picked        (cmd_picked_ras       [0:P_BA_N_PS-1]),
    .req_ras_id_bank            (req_id_bank          [0:P_BA_N_PS-1]),
    .cmd_ras_id_bank            (cmd_id_bank          [0:P_BA_N_PS-1]),
    .cmd_ras_bank               (cmd_bank             [0:P_BA_N_PS-1]),
    .bank_address_bank          (bank_address_bank    [0:P_BA_N_PS-1]),
    .row_address_bank           (row_address_bank     [0:P_BA_N_PS-1]),

    .ready_to_cmd_ras           (ready_to_cmd_ras_ps0 ),
    .cmd_ras                    (cmd_ras_ps0          ),
    .req_id_ras                 (req_ras_id_ps0       ),
    .cmd_id_ras                 (cmd_ras_id_ps0       ),
    .bank_address_ras           (bank_address_ras_ps0 ),
    .row_address_ras            (row_address_ras_ps0  ) 
);

RAS_arbiter #(
    .P_BA_N_PS         (P_BA_N_PS        ),
    .P_BA_N_G          (P_BA_N_G         ), 
    .P_ROW_ADDR_WIDTH  (P_ROW_ADDR_WIDTH ),
    .P_BA_ADDR_WIDTH   (P_BA_ADDR_WIDTH  ),

    .P_GENERAL_NOP     (P_GENERAL_NOP ),
    .P_COL_WRT	       (P_COL_WRT     ),
    .P_COL_RD          (P_COL_RD      ),
    .P_ROW_ACT		   (P_ROW_ACT    ),
    .P_ROW_PRE		   (P_ROW_PRE    ),
    .P_ROW_REFPB       (P_ROW_REFPB   )

) RAS_arbiter_ps1 (
    .clk(dfi_clk),
    .rst_n (reset_hbm_controller),
    
    .cmd_ras_bank_picked        (cmd_picked_ras       [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .req_ras_id_bank            (req_id_bank          [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .cmd_ras_id_bank            (cmd_id_bank          [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .cmd_ras_bank               (cmd_bank             [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .bank_address_bank          (bank_address_bank    [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .row_address_bank           (row_address_bank     [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    
    .ready_to_cmd_ras           (ready_to_cmd_ras_ps1 ),
    .cmd_ras                    (cmd_ras_ps1          ),
    .req_id_ras                 (req_ras_id_ps1       ),
    .cmd_id_ras                 (cmd_ras_id_ps1       ),
    .bank_address_ras           (bank_address_ras_ps1 ),
    .row_address_ras            (row_address_ras_ps1  ) 
);


CAS_arbiter #(
    .P_BA_N_PS          (P_BA_N_PS        ),
    .P_BA_N_G           (P_BA_N_G         ), 
    .P_COL_ADDR_WIDTH   (P_COL_ADDR_WIDTH ),
    .P_BA_ADDR_WIDTH    (P_BA_ADDR_WIDTH  ),
    .P_DATA_WIDTH       (P_DATA_WIDTH     ),
    
    .P_GENERAL_NOP      (P_GENERAL_NOP ),
    .P_COL_WRT		    (P_COL_WRT     ),
    .P_COL_RD           (P_COL_RD      )

) CAS_arbiter_ps0 (
    .clk                        (dfi_clk   ),
    .rst_n                      (reset_hbm_controller ),
    
    .cmd_cas_bank_picked        (cmd_picked_cas       [0:P_BA_N_PS-1]),
    .req_cas_id_bank            (req_id_bank          [0:P_BA_N_PS-1]),
    .cmd_cas_id_bank            (cmd_id_bank          [0:P_BA_N_PS-1]),
    .cmd_cas_bank               (cmd_bank             [0:P_BA_N_PS-1]),
    .bank_address_bank          (bank_address_bank    [0:P_BA_N_PS-1]),
    .column_address_bank        (column_address_bank  [0:P_BA_N_PS-1]),
    .wrt_data_bank              (wrt_data_bank        [0:P_BA_N_PS-1]),

    .ready_to_cmd_cas           (ready_to_cmd_cas_ps0   ),
    .cmd_cas                    (cmd_cas_ps0            ),
    .req_id_cas                 (req_cas_id_ps0         ),
    .cmd_id_cas                 (cmd_cas_id_ps0         ), 
    .bank_address_cas           (bank_address_cas_ps0   ),
    .column_address_cas         (column_address_cas_ps0 ),
    .wrt_data_cas               (wrt_data_cas_ps0       )
);

CAS_arbiter #(
    .P_BA_N_PS                  (P_BA_N_PS        ),
    .P_BA_N_G                   (P_BA_N_G         ), 
    .P_COL_ADDR_WIDTH           (P_COL_ADDR_WIDTH ),
    .P_BA_ADDR_WIDTH            (P_BA_ADDR_WIDTH  ),
    .P_DATA_WIDTH               (P_DATA_WIDTH     ),

    .P_GENERAL_NOP      (P_GENERAL_NOP ),
    .P_COL_WRT		    (P_COL_WRT     ),
    .P_COL_RD           (P_COL_RD      )

) CAS_arbiter_ps1 (
    .clk(dfi_clk),
    .rst_n (reset_hbm_controller),

    .cmd_cas_bank_picked        (cmd_picked_cas       [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .req_cas_id_bank            (req_id_bank          [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .cmd_cas_id_bank            (cmd_id_bank          [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .cmd_cas_bank               (cmd_bank             [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .bank_address_bank          (bank_address_bank    [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .column_address_bank        (column_address_bank  [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .wrt_data_bank              (wrt_data_bank        [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),

    .ready_to_cmd_cas           (ready_to_cmd_cas_ps1   ),
    .cmd_cas                    (cmd_cas_ps1            ),
    .req_id_cas                 (req_cas_id_ps1         ),
    .cmd_id_cas                 (cmd_cas_id_ps1         ), 
    .bank_address_cas           (bank_address_cas_ps1   ),
    .column_address_cas         (column_address_cas_ps1 ),
    .wrt_data_cas               (wrt_data_cas_ps1       )
);


ll_command_forwarder_RAS_CAS_PS0_PS1_queue #(
    .P_ROW_ADDR_WIDTH         (P_ROW_ADDR_WIDTH     ),
    .P_COL_ADDR_WIDTH         (P_COL_ADDR_WIDTH     ),
    .P_BA_ADDR_WIDTH          (P_BA_ADDR_WIDTH      ),
    .P_WRT_DATA_BUFFER_LEN    (P_WRT_DATA_BUFFER_LEN),

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

    .tWL          (tWL   ),      
    .tRL          (tRL   ), 
    .tCCDl        (tCCDl ),      
    .tRTW         (tRTW  ),
    .tWTRl        (tWTRl ),
    .tRRD         (tRRD  ), 
    .tFAW         (tFAW  ),
    .tWTRs        (tWTRs ),
    .tRFCpb       (tRFCpb),
    .tRREFD       (tRREFD)


) ll_command_forwarder_i (
    .dfi_clk                               (dfi_clk),
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
    .dfi_lp_pwr_x_e_req                    (dfi_lp_pwr_x_e_req),
    .dfi_aw_tx_indx_ld                     (dfi_aw_tx_indx_ld      ),
    .dfi_dw_tx_indx_ld                     (dfi_dw_tx_indx_ld      ),
    .dfi_dw_rx_indx_ld                     (dfi_dw_rx_indx_ld      ),
    .dfi_ctrlupd_ack                       (dfi_ctrlupd_ack        ),
    .dfi_phyupd_req                        (dfi_phyupd_req         ),

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
        
    /* RAS cmd PS0 */
    .ready_to_cmd_ras_ps0     (ready_to_cmd_ras_ps0 ),
    .cmd_ras_ps0              (cmd_ras_ps0          ),
    .req_ras_id_ps0           (req_ras_id_ps0       ),
    .cmd_ras_id_ps0           (cmd_ras_id_ps0       ),
    .bank_address_ras_ps0     (bank_address_ras_ps0 ),
    .row_address_ras_ps0      (row_address_ras_ps0  ),
    
    /* CAS cmd PS0 */
    .ready_to_cmd_cas_ps0     (ready_to_cmd_cas_ps0   ),
    .cmd_cas_ps0              (cmd_cas_ps0            ),
    .req_cas_id_ps0           (req_cas_id_ps0         ),
    .cmd_cas_id_ps0           (cmd_cas_id_ps0         ),
    .bank_address_cas_ps0     (bank_address_cas_ps0   ),
    .column_address_cas_ps0   (column_address_cas_ps0 ),
    .wrt_data_cas_ps0         (wrt_data_cas_ps0       ),
    
    /* RAS cmd PS1 */
    .ready_to_cmd_ras_ps1     (ready_to_cmd_ras_ps1 ),
    .cmd_ras_ps1              (cmd_ras_ps1          ),
    .req_ras_id_ps1           (req_ras_id_ps1       ),
    .cmd_ras_id_ps1           (cmd_ras_id_ps1       ),
    .bank_address_ras_ps1     (bank_address_ras_ps1 ),
    .row_address_ras_ps1      (row_address_ras_ps1  ),
    
    /* CAS cmd PS1 */
    .ready_to_cmd_cas_ps1     (ready_to_cmd_cas_ps1   ),
    .cmd_cas_ps1              (cmd_cas_ps1            ),
    .req_cas_id_ps1           (req_cas_id_ps1         ),
    .cmd_cas_id_ps1           (cmd_cas_id_ps1         ),
    .bank_address_cas_ps1     (bank_address_cas_ps1   ),
    .column_address_cas_ps1   (column_address_cas_ps1 ),
    .wrt_data_cas_ps1         (wrt_data_cas_ps1       ),
    
    .served_ras(served_ras),
    .served_cas(served_cas),

    .reset_hbm_controller(reset_hbm_controller),

    .rd_data_req_id_ps0(rd_data_req_id_ps0),
    .rd_data_ps0(rd_data_ps0),
    .rd_data_req_id_ps1(rd_data_req_id_ps1),
    .rd_data_ps1(rd_data_ps1)
);


endmodule
