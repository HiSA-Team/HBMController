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
    parameter       P_DATA_WIDTH     = 256
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
    input            dfi_phyupd_ack
    
    
    /* Interfaccia verso i command bank register RAS PS0 */
//    output cmd_ras_bank_picked_ps0 [0 : P_BA_N_PS - 1],
//    input  [3:0] cmd_ras_bank_ps0  [0 : P_BA_N_PS - 1],
//    input  [P_BA_ADDR_WIDTH-1 : 0] bank_address_bank_ps0 [0 : P_BA_N_PS - 1],
//    input  [P_ROW_ADDR_WIDTH-1 : 0] row_address_bank_ps0 [0 : P_BA_N_PS - 1],
    
//    /* Interfaccia verso i command bank register RAS PS1 */
//    output cmd_ras_bank_picked_ps1 [0 : P_BA_N_PS - 1],
//    input  [3:0] cmd_ras_bank_ps1  [0 : P_BA_N_PS - 1],
//    input  [P_BA_ADDR_WIDTH-1 : 0] bank_address_bank_ps1 [0 : P_BA_N_PS - 1],
//    input  [P_ROW_ADDR_WIDTH-1 : 0] row_address_bank_ps1 [0 : P_BA_N_PS - 1]
    
    
);

localparam LP_GENERAL_NOP = 4'b1111;

/* ROW COMMANDS */
localparam LP_ROW_NOP		= 3'b111;
localparam LP_ROW_ACT		= 3'b010;
localparam LP_ROW_PRE		= 3'b011;  //WITH R[10] -> L
localparam LP_ROW_PREA		= 3'b011;  // WITH R[10] -> H

/* PER SIMULARE !!!!  */
reg  [0 : P_BA_N_PS - 1] cmd_ras_bank_picked_ps0;
reg  [3:0] cmd_ras_bank_ps0  [0 : P_BA_N_PS - 1];
reg  [P_BA_ADDR_WIDTH-1 : 0] bank_address_bank_ps0 [0 : P_BA_N_PS - 1];
reg  [P_ROW_ADDR_WIDTH-1 : 0] row_address_bank_ps0 [0 : P_BA_N_PS - 1];

/* Interfaccia verso i command bank register RAS PS1 */
reg  [0 : P_BA_N_PS - 1] cmd_ras_bank_picked_ps1;
reg  [3:0] cmd_ras_bank_ps1  [0 : P_BA_N_PS - 1];
reg  [P_BA_ADDR_WIDTH-1 : 0] bank_address_bank_ps1 [0 : P_BA_N_PS - 1];
reg  [P_ROW_ADDR_WIDTH-1 : 0] row_address_bank_ps1 [0 : P_BA_N_PS - 1];

reg [31:0] dummy_cnt_ps0;
reg [31:0] dummy_cnt_ps1;

initial begin
    for (integer i = 1; i < 16; i = i + 1) begin
        cmd_ras_bank_ps0[i] <= LP_GENERAL_NOP;
        
        bank_address_bank_ps0[i] <= { P_BA_ADDR_WIDTH { 1'b0 } };
        row_address_bank_ps0[i] <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        
        cmd_ras_bank_ps1[i] <= LP_GENERAL_NOP;
        bank_address_bank_ps1[i] <= { P_BA_ADDR_WIDTH { 1'b0 } };
        row_address_bank_ps1[i] <= { P_ROW_ADDR_WIDTH { 1'b0 } };    
    end
    
    cmd_ras_bank_ps0[0] <= LP_ROW_PRE;
    cmd_ras_bank_ps1[0] <= LP_ROW_PRE;
    
    bank_address_bank_ps0[0] <= { P_BA_ADDR_WIDTH { 1'b0 } };
    row_address_bank_ps0[0] <= { P_ROW_ADDR_WIDTH { 1'b0 } };
    bank_address_bank_ps1[0] <= { P_BA_ADDR_WIDTH { 1'b0 } };
    row_address_bank_ps1[0] <= { P_ROW_ADDR_WIDTH { 1'b0 } };
    
    dummy_cnt_ps0 <= {32 { 1'b0 }};
    dummy_cnt_ps1 <= {32 { 1'b0 }};
end

reg [31:0] index_ps0;
reg [31:0] index_ps1;

always_comb begin
    if ( dfi_rst_n == 1'b0 ) begin
        index_ps0 <= {32 { 1'b0 }};
        index_ps1 <= {32 { 1'b0 }};
    end 
    
    else begin
       for (integer i = 0; i < 16 ; i = i + 1) begin
            if ( cmd_ras_bank_picked_ps0[i] == 1'b1 ) begin
                index_ps0 <= i;
            end 
            
            if ( cmd_ras_bank_picked_ps1[i] == 1'b1 ) begin
                index_ps1 <= i;
            end
            
       end
       
    end
end

always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
     if ( |cmd_ras_bank_picked_ps0 ) begin
        dummy_cnt_ps0 <= dummy_cnt_ps0 + 1'b1;
        if ( dummy_cnt_ps0 % 2 == 0 ) begin
            cmd_ras_bank_ps0[index_ps0] <= LP_ROW_ACT;
            bank_address_bank_ps0[index_ps0] <= { P_BA_ADDR_WIDTH { 1'b0 } };
            row_address_bank_ps0[index_ps0] <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        end
        else begin
            cmd_ras_bank_ps0[index_ps0] <= LP_ROW_PRE;
            bank_address_bank_ps0[index_ps0] <= { P_BA_ADDR_WIDTH { 1'b0 } };
            row_address_bank_ps0[index_ps0] <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        end
        
     end
     if ( |cmd_ras_bank_picked_ps1 ) begin
        dummy_cnt_ps1 <= dummy_cnt_ps1 + 1'b1;
        if ( dummy_cnt_ps1 % 2 == 0 ) begin
            cmd_ras_bank_ps1[index_ps1] <= LP_ROW_ACT;
            bank_address_bank_ps1[index_ps1] <= { P_BA_ADDR_WIDTH { 1'b0 } };
            row_address_bank_ps1[index_ps1] <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        end
        else begin
            cmd_ras_bank_ps1[index_ps1] <= LP_ROW_PRE;
            bank_address_bank_ps1[index_ps1] <= { P_BA_ADDR_WIDTH { 1'b0 } };
            row_address_bank_ps1[index_ps1] <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        end
     end     
end

always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
     if ( dummy_cnt_ps0 >= 32'd50 && dummy_cnt_ps1 >= 32'd50) begin
        $finish;
     end
end

/* FINE SIMULAZIONE */

localparam LP_QUEUE_LEN = 16;

/* RAS cmd PS0 */
wire ready_to_cmd_ras_ps0;
wire [3:0] cmd_ras_ps0;
wire [ P_BA_ADDR_WIDTH - 1 : 0 ]  bank_address_ras_ps0;
wire [ P_ROW_ADDR_WIDTH - 1 : 0 ]  row_address_ras_ps0;
    
/* CAS cmd PS0 */
wire ready_to_cmd_cas_ps0;
wire [3:0] cmd_cas_ps0;
wire [ P_BA_ADDR_WIDTH - 1 : 0 ] bank_address_cas_ps0;
wire [ P_COL_ADDR_WIDTH - 1 : 0 ] column_address_cas_ps0;
wire [ P_DATA_WIDTH - 1 : 0 ] wrt_data_cas_ps0;
    
/* RAS cmd PS1 */
wire ready_to_cmd_ras_ps1;
wire [3:0] cmd_ras_ps1;
wire [ P_BA_ADDR_WIDTH - 1 : 0 ]  bank_address_ras_ps1;
wire [ P_ROW_ADDR_WIDTH - 1 : 0 ]  row_address_ras_ps1;

/* CAS cmd PS1 */
wire ready_to_cmd_cas_ps1;
wire [3:0] cmd_cas_ps1;
wire [ P_BA_ADDR_WIDTH - 1 : 0 ] bank_address_cas_ps1;
wire [ P_COL_ADDR_WIDTH - 1 : 0 ] column_address_cas_ps1;
wire [ P_DATA_WIDTH - 1 : 0 ] wrt_data_cas_ps1;


RAS_arbiter #(
    .P_BA_N_PS(P_BA_N_PS),
    .P_BA_N_G(P_BA_N_G), 
    .P_ROW_ADDR_WIDTH(P_ROW_ADDR_WIDTH),
    .P_BA_ADDR_WIDTH(P_BA_ADDR_WIDTH),
    .P_QUEUE_LEN(LP_QUEUE_LEN)
) RAS_arbiter_ps0 (
    .clk(dfi_clk),
    .rst_n (dfi_rst_n),

    .cmd_ras_bank_picked(cmd_ras_bank_picked_ps0),
    .cmd_ras_bank (cmd_ras_bank_ps0),
    .bank_address_bank(bank_address_bank_ps0),
    .row_address_bank(row_address_bank_ps0),

    .ready_to_cmd_ras(ready_to_cmd_ras_ps0),
    .cmd_ras(cmd_ras_ps0),
    .bank_address_ras(bank_address_ras_ps0),
    .row_address_ras(row_address_ras_ps0) 
);

RAS_arbiter #(
    .P_BA_N_PS(P_BA_N_PS),
    .P_BA_N_G(P_BA_N_G), 
    .P_ROW_ADDR_WIDTH(P_ROW_ADDR_WIDTH),
    .P_BA_ADDR_WIDTH(P_BA_ADDR_WIDTH),
    .P_QUEUE_LEN(LP_QUEUE_LEN)

) RAS_arbiter_ps1 (
    .clk(dfi_clk),
    .rst_n (dfi_rst_n),
    
    
    .cmd_ras_bank_picked(cmd_ras_bank_picked_ps1),
    .cmd_ras_bank (cmd_ras_bank_ps1),
    .bank_address_bank(bank_address_bank_ps1),
    .row_address_bank(row_address_bank_ps1),
    
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
    .P_DATA_WIDTH(P_DATA_WIDTH),
    .P_QUEUE_LEN(LP_QUEUE_LEN)

) CAS_arbiter_ps0 (
    .clk(dfi_clk),
    .rst_n (dfi_rst_n),

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
    .P_DATA_WIDTH(P_DATA_WIDTH),
    .P_QUEUE_LEN(LP_QUEUE_LEN)

) CAS_arbiter_ps1 (
    .clk(dfi_clk),
    .rst_n (dfi_rst_n),

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
    .wrt_data_cas_ps1(wrt_data_cas_ps1)
);


endmodule
