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
    parameter       P_DRIVE_PRECHARGE_CMD = 114,
    parameter		P_PRECHG_THR= 200,
    parameter		P_ACT_THR	= 40,
    parameter		P_WRT_THR	= 60,
    parameter		P_RD_THR	= 60,
    parameter		P_DRIVE_ACT_CMD = 240,
    parameter		P_MRS_CNT = 8'hc0,
    parameter		P_ROW_ADDR_WIDTH = 16,
    parameter		P_COL_ADDR_WIDTH = 12,
    parameter		P_BA_ADDR_WIDTH	= 5, 
    parameter       P_BA_N_PS       = 16,        /* Nunmero di Bank per PS */
    parameter       P_BA_N_G        = 8,         /* Numero di Bank per gruppo */ 
    parameter       P_DATA_WIDTH     = 256,
    parameter       P_TOTAL_PER_CHANNEL_BANK_N = 32         /* Numero totali di bank per canale */
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
    output           dfi_lp_pwr_x_e_req,
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
    
    /* Interfaccia verso i bank scheduler */
    output [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1]  cmd_picked_bank,
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
    output [(P_BA_N_PS*2)-1:0]          served_cas
    
       
);

localparam LP_GENERAL_NOP = 4'b1111;

/* ROW COMMANDS */
localparam LP_ROW_NOP		= 3'b111;
localparam LP_ROW_ACT		= 3'b010;
localparam LP_ROW_PRE		= 3'b011;  //WITH R[10] -> L
localparam LP_ROW_PREA		= 3'b011;  // WITH R[10] -> H

/* COL COMMANDS */
localparam LP_COL_WRT		= 4'b0001;
localparam LP_COL_RD        = 4'b0101;


/* Verso il ll_command_forwarder */
wire [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1] cmd_picked_ras;
wire [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1] cmd_picked_cas;


genvar i;
generate 
    for ( i = 0; i <  P_TOTAL_PER_CHANNEL_BANK_N; i = i + 1) begin
        assign cmd_picked_bank[i] = cmd_picked_ras[i] || cmd_picked_cas[i];
    end
endgenerate


/* RAS cmd PS0 */
//wire ready_to_cmd_ras_ps0;
wire [3:0] cmd_ras_ps0;
wire [ P_BA_ADDR_WIDTH - 1 : 0 ]  bank_address_ras_ps0;
wire [ P_ROW_ADDR_WIDTH - 1 : 0 ]  row_address_ras_ps0;
    
/* CAS cmd PS0 */
//wire ready_to_cmd_cas_ps0;
wire [3:0] cmd_cas_ps0;
wire [ P_BA_ADDR_WIDTH - 1 : 0 ] bank_address_cas_ps0;
wire [ P_COL_ADDR_WIDTH - 1 : 0 ] column_address_cas_ps0;
wire [ P_DATA_WIDTH - 1 : 0 ] wrt_data_cas_ps0;
    
/* RAS cmd PS1 */
//wire ready_to_cmd_ras_ps1;
wire [3:0] cmd_ras_ps1;
wire [ P_BA_ADDR_WIDTH - 1 : 0 ]  bank_address_ras_ps1;
wire [ P_ROW_ADDR_WIDTH - 1 : 0 ]  row_address_ras_ps1;

/* CAS cmd PS1 */
//wire ready_to_cmd_cas_ps1;
wire [3:0] cmd_cas_ps1;
wire [ P_BA_ADDR_WIDTH - 1 : 0 ] bank_address_cas_ps1;
wire [ P_COL_ADDR_WIDTH - 1 : 0 ] column_address_cas_ps1;
wire [ P_DATA_WIDTH - 1 : 0 ] wrt_data_cas_ps1;


RAS_arbiter #(
    .P_BA_N_PS(P_BA_N_PS),
    .P_BA_N_G(P_BA_N_G), 
    .P_ROW_ADDR_WIDTH(P_ROW_ADDR_WIDTH),
    .P_BA_ADDR_WIDTH(P_BA_ADDR_WIDTH)
) RAS_arbiter_ps0 (
    .clk(dfi_clk),
    .rst_n (dfi_rst_n),

    .cmd_ras_bank_picked(cmd_picked_ras[0:P_BA_N_PS-1]),
    .cmd_ras_bank (cmd_bank[0:P_BA_N_PS-1]),
    .bank_address_bank(bank_address_bank[0:P_BA_N_PS-1]),
    .row_address_bank(row_address_bank[0:P_BA_N_PS-1]),

    .ready_to_cmd_ras(ready_to_cmd_ras_ps0),
    .cmd_ras(cmd_ras_ps0),
    .bank_address_ras(bank_address_ras_ps0),
    .row_address_ras(row_address_ras_ps0) 
);

RAS_arbiter #(
    .P_BA_N_PS(P_BA_N_PS),
    .P_BA_N_G(P_BA_N_G), 
    .P_ROW_ADDR_WIDTH(P_ROW_ADDR_WIDTH),
    .P_BA_ADDR_WIDTH(P_BA_ADDR_WIDTH)

) RAS_arbiter_ps1 (
    .clk(dfi_clk),
    .rst_n (dfi_rst_n),
    
    .cmd_ras_bank_picked(cmd_picked_ras[P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .cmd_ras_bank (cmd_bank[P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .bank_address_bank(bank_address_bank[P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .row_address_bank(row_address_bank[P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    
    .ready_to_cmd_ras(ready_to_cmd_ras_ps1),
    .cmd_ras(cmd_ras_ps1),
    .bank_address_ras(bank_address_ras_ps1),
    .row_address_ras(row_address_ras_ps1) 
);


CAS_arbiter #(
    .P_BA_N_PS(P_BA_N_PS),
    .P_BA_N_G(P_BA_N_G), 
    .P_COL_ADDR_WIDTH(P_COL_ADDR_WIDTH),
    .P_BA_ADDR_WIDTH(P_BA_ADDR_WIDTH),
    .P_DATA_WIDTH(P_DATA_WIDTH)

) CAS_arbiter_ps0 (
    .clk(dfi_clk),
    .rst_n (dfi_rst_n),
    
    .cmd_cas_bank_picked(cmd_picked_cas[0:P_BA_N_PS-1]),
    .cmd_cas_bank (cmd_bank[0:P_BA_N_PS-1]),
    .bank_address_bank(bank_address_bank[0:P_BA_N_PS-1]),
    .column_address_bank(column_address_bank[0:P_BA_N_PS-1]),
    .wrt_data_bank(wrt_data_bank[0:P_BA_N_PS-1]),

    .ready_to_cmd_cas(ready_to_cmd_cas_ps0),
    .cmd_cas(cmd_cas_ps0),
    .bank_address_cas(bank_address_cas_ps0),
    .column_address_cas(column_address_cas_ps0),
    .wrt_data_cas(wrt_data_cas_ps0)
);

CAS_arbiter #(
    .P_BA_N_PS(P_BA_N_PS),
    .P_BA_N_G(P_BA_N_G), 
    .P_COL_ADDR_WIDTH(P_COL_ADDR_WIDTH),
    .P_BA_ADDR_WIDTH(P_BA_ADDR_WIDTH),
    .P_DATA_WIDTH(P_DATA_WIDTH)

) CAS_arbiter_ps1 (
    .clk(dfi_clk),
    .rst_n (dfi_rst_n),

    .cmd_cas_bank_picked(cmd_picked_cas[P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .cmd_cas_bank (cmd_bank[P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .bank_address_bank(bank_address_bank[P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .column_address_bank(column_address_bank[P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),
    .wrt_data_bank(wrt_data_bank[P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1]),

    .ready_to_cmd_cas(ready_to_cmd_cas_ps1),
    .cmd_cas(cmd_cas_ps1),
    .bank_address_cas(bank_address_cas_ps1),
    .column_address_cas(column_address_cas_ps1),
    .wrt_data_cas(wrt_data_cas_ps1)
);


ll_command_forwarder_RAS_CAS_PS0_PS1_queue #(
    .P_ROW_ADDR_WIDTH(P_ROW_ADDR_WIDTH),
    .P_COL_ADDR_WIDTH(P_COL_ADDR_WIDTH),
    .P_BA_ADDR_WIDTH(P_BA_ADDR_WIDTH)

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
    .dfi_lp_pwr_x_e_req                    (dfi_lp_pwr_x_e_req     ),
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
    
    /* My Interface */
    
    /* RAS cmd PS0 */
    .ready_to_cmd_ras_ps0(ready_to_cmd_ras_ps0),
    .cmd_ras_ps0(cmd_ras_ps0),
    .bank_address_ras_ps0(bank_address_ras_ps0),
    .row_address_ras_ps0(row_address_ras_ps0),
    
    /* CAS cmd PS0 */
    .ready_to_cmd_cas_ps0(ready_to_cmd_cas_ps0),
    .cmd_cas_ps0(cmd_cas_ps0),
    .bank_address_cas_ps0(bank_address_cas_ps0),
    .column_address_cas_ps0(column_address_cas_ps0),
    .wrt_data_cas_ps0(wrt_data_cas_ps0),
    
    /* RAS cmd PS1 */
    .ready_to_cmd_ras_ps1(ready_to_cmd_ras_ps1),
    .cmd_ras_ps1(cmd_ras_ps1),
    .bank_address_ras_ps1(bank_address_ras_ps1),
    .row_address_ras_ps1(row_address_ras_ps1),
    
    /* CAS cmd PS1 */
    .ready_to_cmd_cas_ps1(ready_to_cmd_cas_ps1),
    .cmd_cas_ps1(cmd_cas_ps1),
    .bank_address_cas_ps1(bank_address_cas_ps1),
    .column_address_cas_ps1(column_address_cas_ps1),
    .wrt_data_cas_ps1(wrt_data_cas_ps1),
    
    .served_ras(served_ras),
    .served_cas(served_cas)
);


endmodule
