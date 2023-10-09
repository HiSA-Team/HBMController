`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/26/2023 02:23:55 PM
// Design Name: 
// Module Name: ll_command_forwarder_RAS_CAS_PS0_PS1_queue_top
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


genvar i;
generate 
    for ( i = 0; i < P_TOTAL_PER_CHANNEL_BANK_N; i = i + 1 ) begin : bank
        if (i < P_BA_N_PS) begin
            bank_scheduler#(
                .P_ROW_ADDR_WIDTH          (P_ROW_ADDR_WIDTH),
                .P_COL_ADDR_WIDTH          (P_COL_ADDR_WIDTH),
                .P_BA_ADDR_WIDTH           (P_BA_ADDR_WIDTH), 
                .P_DATA_WIDTH              (P_DATA_WIDTH),
                .P_BANK_INDEX              (i)
            ) bank_scheduler(
                .clk                       (dfi_0_clk_buf),
                .rst_n                     (dfi_0_rst_n),
                .cmd_picked_bank           (cmd_picked_bank[i]),
                .cmd_bank                  (cmd_bank[i]),
                .bank_address_bank         (bank_address_bank[i]),
                .row_address_bank          (row_address_bank[i]),
                .column_address_bank       (column_address_bank[i]),
                .wrt_data_bank             (wrt_data_bank[i]),
                .ready_to_cmd_ras          (ready_to_cmd_ras_ps0),
                .ready_to_cmd_cas          (ready_to_cmd_cas_ps0)
            );
        end
        else begin
            bank_scheduler#(
                .P_ROW_ADDR_WIDTH          (P_ROW_ADDR_WIDTH),
                .P_COL_ADDR_WIDTH          (P_COL_ADDR_WIDTH),
                .P_BA_ADDR_WIDTH           (P_BA_ADDR_WIDTH), 
                .P_DATA_WIDTH              (P_DATA_WIDTH),
                .P_BANK_INDEX              (i)
            ) bank_scheduler(
                .clk                       (dfi_0_clk_buf),
                .rst_n                     (dfi_0_rst_n),
                .cmd_picked_bank           (cmd_picked_bank[i]),
                .cmd_bank                  (cmd_bank[i]),
                .bank_address_bank         (bank_address_bank[i]),
                .row_address_bank          (row_address_bank[i]),
                .column_address_bank       (column_address_bank[i]),
                .wrt_data_bank             (wrt_data_bank[i]),
                .ready_to_cmd_ras          (ready_to_cmd_ras_ps1),
                .ready_to_cmd_cas          (ready_to_cmd_cas_ps1)
            );
        end
    end
endgenerate



channel_scheduler#(
    .P_TOTAL_PER_CHANNEL_BANK_N(P_TOTAL_PER_CHANNEL_BANK_N)
)
channel_0_scheduler
(
    //DFI INTERFACE SIGNALS
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
    
     /* Interfaccia verso i bank scheduler */
    .cmd_picked_bank             (cmd_picked_bank),
    .cmd_bank                    (cmd_bank),
    .bank_address_bank           (bank_address_bank),
    .row_address_bank            (row_address_bank),
    .column_address_bank         (column_address_bank),
    .wrt_data_bank               (wrt_data_bank),
    
    .ready_to_cmd_ras_ps0        (ready_to_cmd_ras_ps0),
    .ready_to_cmd_cas_ps0        (ready_to_cmd_cas_ps0),
    .ready_to_cmd_ras_ps1        (ready_to_cmd_ras_ps1),
    .ready_to_cmd_cas_ps1        (ready_to_cmd_cas_ps1)

    
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