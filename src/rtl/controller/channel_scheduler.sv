`timescale 1ps / 1ps

`include "dfi_interface.svh"
`include "commands.svh"
`include "hbm_controller.svh"
`include "hbm_timing_constraints.svh"


module channel_scheduler (
    input logic             clock_i,
    input logic           	reset_ni,
    input logic            	dfi_rst_buf_n,

    `DEFINE_DFI_MASTER_PORTS, 
    
    /* Interface to bank scheduler */
    output logic [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1]     cmd_picked_bank,
    input logic  [P_REQ_ID_WIDTH-1:0]                     req_id_bank                 [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    input logic  [P_CMD_ID_WIDTH-1:0]                     cmd_id_bank                 [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    input logic  [3:0]                                    cmd_bank                    [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    input logic  [P_ROW_ADDR_WIDTH-1 : 0]                 row_address_bank            [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1],
    
    output logic [(P_BA_N_PS*2)-1:0]                      served_ras,
    output logic [(P_BA_N_PS*2)-1:0]                      served_cas,

    output logic                                          reset_hbm_controller,

    input logic  [P_DATA_WIDTH-1 : 0]                     ram_cas_out_ps0,
    input logic  [P_DATA_WIDTH-1 : 0]                     ram_cas_out_ps1,

    output logic [P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-2:0]     wr_ram_cas_address_req_id_ps0,
    output logic [P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-2:0]     wr_ram_cas_address_req_id_ps1,
    input logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] wr_ram_cas_address_out_ps0,
    input logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] wr_ram_cas_address_out_ps1,

    output logic [P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-2:0]     rd_ram_cas_address_req_id_ps0,
    output logic [P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-2:0]     rd_ram_cas_address_req_id_ps1,
    input logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] rd_ram_cas_address_out_ps0,
    input logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] rd_ram_cas_address_out_ps1,


    output logic                                          rd_data_valid_ps0,
    output logic                                          rd_data_valid_ps1,
    output logic [P_REQ_ID_WIDTH-1:0]                     rd_data_req_id_ps0,
    output logic [P_DATA_WIDTH-1:0]                       rd_data_ps0,
    output logic [P_REQ_ID_WIDTH-1:0]                     rd_data_req_id_ps1,
    output logic [P_DATA_WIDTH-1:0]                       rd_data_ps1
    
       
);


/* To ll_command_forwarder */
logic [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1] cmd_picked_ras;
logic [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1] cmd_picked_cas;
logic ready_to_cmd_ras_ps0;
logic ready_to_cmd_cas_ps0;
logic ready_to_cmd_ras_ps1;
logic ready_to_cmd_cas_ps1;

genvar i;
generate 
    for ( i = 0; i <  P_TOTAL_PER_CHANNEL_BANK_N; i = i + 1) begin
        assign cmd_picked_bank[i] = cmd_picked_ras[i] || cmd_picked_cas[i];
    end
endgenerate

/* From arbiters to LLCF */
/* RAS cmd PS0 */
logic [3:0]                         cmd_ras_ps0;
logic [P_REQ_ID_WIDTH-1:0]          req_ras_id_ps0;
logic [P_CMD_ID_WIDTH-1:0]          cmd_ras_id_ps0;
logic [1:0]                         bank_group_ras_ps0;
logic [ P_ROW_ADDR_WIDTH - 1 : 0 ]  row_address_ras_ps0;
    
/* CAS cmd PS0 */
logic [3:0]                         cmd_cas_ps0;
logic [P_REQ_ID_WIDTH-1:0]          req_cas_id_ps0;
logic [P_CMD_ID_WIDTH-1:0]          cmd_cas_id_ps0;
logic [1:0]                         bank_group_cas_ps0;
    
/* RAS cmd PS1 */
logic [3:0]                         cmd_ras_ps1;
logic [P_REQ_ID_WIDTH-1:0]          req_ras_id_ps1;
logic [P_CMD_ID_WIDTH-1:0]          cmd_ras_id_ps1;
logic [1:0]                         bank_group_ras_ps1;
logic [ P_ROW_ADDR_WIDTH - 1 : 0 ]  row_address_ras_ps1;

/* CAS cmd PS1 */
logic [3:0]                         cmd_cas_ps1;
logic [P_REQ_ID_WIDTH-1:0]          req_cas_id_ps1;
logic [P_CMD_ID_WIDTH-1:0]          cmd_cas_id_ps1;
logic [1:0]                         bank_group_cas_ps1;

logic [P_BA_ADDR_WIDTH-1  : 0]      bank_address_ras_ps0; 
logic [P_BA_ADDR_WIDTH-1  : 0]      bank_address_ras_ps1; 


RAS_arbiter RAS_arbiter_ps0 (
    .clock_i               ( clock_i                          ),
    .reset_ni              ( reset_hbm_controller             ),

    .cmd_ras_bank_picked   ( cmd_picked_ras   [0:P_BA_N_PS-1] ),
    .req_ras_id_bank       ( req_id_bank      [0:P_BA_N_PS-1] ),
    .cmd_ras_id_bank       ( cmd_id_bank      [0:P_BA_N_PS-1] ),
    .cmd_ras_bank          ( cmd_bank         [0:P_BA_N_PS-1] ),
    .row_address_bank      ( row_address_bank [0:P_BA_N_PS-1] ),

    .ready_to_cmd_ras      ( ready_to_cmd_ras_ps0             ),
    .cmd_ras               ( cmd_ras_ps0                      ),
    .req_id_ras            ( req_ras_id_ps0                   ),
    .cmd_id_ras            ( cmd_ras_id_ps0                   ),
    .bank_group_ras        ( bank_group_ras_ps0               ),
    .bank_address_ras      ( bank_address_ras_ps0             ),
    .row_address_ras       ( row_address_ras_ps0              )
);

RAS_arbiter RAS_arbiter_ps1 (
    .clock_i               ( clock_i                                                     ),
    .reset_ni              ( reset_hbm_controller                                        ),
    
    .cmd_ras_bank_picked   ( cmd_picked_ras   [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1] ),
    .req_ras_id_bank       ( req_id_bank      [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1] ),
    .cmd_ras_id_bank       ( cmd_id_bank      [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1] ),
    .cmd_ras_bank          ( cmd_bank         [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1] ),
    .row_address_bank      ( row_address_bank [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1] ),
    
    .ready_to_cmd_ras      ( ready_to_cmd_ras_ps1                                        ),
    .cmd_ras               ( cmd_ras_ps1                                                 ),
    .req_id_ras            ( req_ras_id_ps1                                              ),
    .cmd_id_ras            ( cmd_ras_id_ps1                                              ),
    .bank_group_ras        ( bank_group_ras_ps1                                          ),
    .bank_address_ras      ( bank_address_ras_ps1                                        ),
    .row_address_ras       ( row_address_ras_ps1                                         )
);


CAS_arbiter CAS_arbiter_ps0 (
    .clock_i               ( clock_i                        ),
    .reset_ni              ( reset_hbm_controller           ),
    
    .cmd_cas_bank_picked   ( cmd_picked_cas [0:P_BA_N_PS-1] ),
    .req_cas_id_bank       ( req_id_bank    [0:P_BA_N_PS-1] ),
    .cmd_cas_id_bank       ( cmd_id_bank    [0:P_BA_N_PS-1] ),
    .cmd_cas_bank          ( cmd_bank       [0:P_BA_N_PS-1] ),
    .ready_to_cmd_cas      ( ready_to_cmd_cas_ps0           ),
    .cmd_cas               ( cmd_cas_ps0                    ),
    .req_id_cas            ( req_cas_id_ps0                 ),
    .cmd_id_cas            ( cmd_cas_id_ps0                 ), 
    .bank_group_cas        ( bank_group_cas_ps0             ),

    .wr_ram_cas_req_id     ( wr_ram_cas_address_req_id_ps0  ),
    .rd_ram_cas_req_id     ( rd_ram_cas_address_req_id_ps0  )
);

CAS_arbiter CAS_arbiter_ps1 (
    .clock_i               ( clock_i                                                   ),
    .reset_ni              ( reset_hbm_controller                                      ),

    .cmd_cas_bank_picked   ( cmd_picked_cas [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1] ),
    .req_cas_id_bank       ( req_id_bank    [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1] ),
    .cmd_cas_id_bank       ( cmd_id_bank    [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1] ),
    .cmd_cas_bank          ( cmd_bank       [P_BA_N_PS:P_TOTAL_PER_CHANNEL_BANK_N - 1] ),
    .ready_to_cmd_cas      ( ready_to_cmd_cas_ps1                                      ),
    .cmd_cas               ( cmd_cas_ps1                                               ),
    .req_id_cas            ( req_cas_id_ps1                                            ),
    .cmd_id_cas            ( cmd_cas_id_ps1                                            ), 
    .bank_group_cas        ( bank_group_cas_ps1                                        ),

    .wr_ram_cas_req_id     ( wr_ram_cas_address_req_id_ps1                             ),
    .rd_ram_cas_req_id     ( rd_ram_cas_address_req_id_ps1                             )

);


last_level_command_forwarder last_level_command_forwarder_i (
    .clock_i                      ( clock_i                    ),
    .reset_ni                     ( reset_ni                   ),
    .dfi_rst_buf_n                ( dfi_rst_buf_n              ),
    
    .dfi_init_start               ( dfi_init_start             ),
    .dfi_aw_ck_p0                 ( dfi_aw_ck_p0               ),
    .dfi_aw_cke_p0                ( dfi_aw_cke_p0              ),
    .dfi_aw_row_p0                ( dfi_aw_row_p0              ),
    .dfi_aw_col_p0                ( dfi_aw_col_p0              ),
    .dfi_dw_wrdata_p0             ( dfi_dw_wrdata_p0           ),
    .dfi_dw_wrdata_mask_p0        ( dfi_dw_wrdata_mask_p0      ),
    .dfi_dw_wrdata_dbi_p0         ( dfi_dw_wrdata_dbi_p0       ),
    .dfi_dw_wrdata_par_p0         ( dfi_dw_wrdata_par_p0       ),
    .dfi_dw_wrdata_dq_en_p0       ( dfi_dw_wrdata_dq_en_p0     ),
    .dfi_dw_wrdata_par_en_p0      ( dfi_dw_wrdata_par_en_p0    ),
    .dfi_aw_ck_p1                 ( dfi_aw_ck_p1               ),
    .dfi_aw_cke_p1                ( dfi_aw_cke_p1              ),
    .dfi_aw_row_p1                ( dfi_aw_row_p1              ),
    .dfi_aw_col_p1                ( dfi_aw_col_p1              ),
    .dfi_dw_wrdata_p1             ( dfi_dw_wrdata_p1           ),
    .dfi_dw_wrdata_mask_p1        ( dfi_dw_wrdata_mask_p1      ),
    .dfi_dw_wrdata_dbi_p1         ( dfi_dw_wrdata_dbi_p1       ),
    .dfi_dw_wrdata_par_p1         ( dfi_dw_wrdata_par_p1       ),
    .dfi_dw_wrdata_dq_en_p1       ( dfi_dw_wrdata_dq_en_p1     ),
    .dfi_dw_wrdata_par_en_p1      ( dfi_dw_wrdata_par_en_p1    ),
    .dfi_aw_ck_dis                ( dfi_aw_ck_dis              ),
    .dfi_lp_pwr_e_req             ( dfi_lp_pwr_e_req           ),
    .dfi_lp_sr_e_req              ( dfi_lp_sr_e_req            ),
    .dfi_lp_pwr_x_req             ( dfi_lp_pwr_x_req           ),
    .dfi_lp_pwr_x_e_req           ( dfi_lp_pwr_x_e_req         ),
    .dfi_aw_tx_indx_ld            ( dfi_aw_tx_indx_ld          ),
    .dfi_dw_tx_indx_ld            ( dfi_dw_tx_indx_ld          ),
    .dfi_dw_rx_indx_ld            ( dfi_dw_rx_indx_ld          ),
    .dfi_ctrlupd_ack              ( dfi_ctrlupd_ack            ),
    .dfi_phyupd_req               ( dfi_phyupd_req             ),
    .dfi_init_complete            ( dfi_init_complete          ),
    .dfi_dw_rddata_valid          ( dfi_dw_rddata_valid        ),
    .dfi_dw_rddata_p0             ( dfi_dw_rddata_p0           ),
    .dfi_dw_rddata_dm_p0          ( dfi_dw_rddata_dm_p0        ),
    .dfi_dw_rddata_dbi_p0         ( dfi_dw_rddata_dbi_p0       ),
    .dfi_dw_rddata_par_p0         ( dfi_dw_rddata_par_p0       ),
    .dfi_dw_rddata_p1             ( dfi_dw_rddata_p1           ),
    .dfi_dw_rddata_dm_p1          ( dfi_dw_rddata_dm_p1        ),
    .dfi_dw_rddata_dbi_p1         ( dfi_dw_rddata_dbi_p1       ),
    .dfi_dw_rddata_par_p1         ( dfi_dw_rddata_par_p1       ),
    .dfi_ctrlupd_req              ( dfi_ctrlupd_req            ),
    .dfi_phyupd_ack               ( dfi_phyupd_ack             ),
        
    /* RAS cmd PS0 */
    .ready_to_cmd_ras_ps0         ( ready_to_cmd_ras_ps0       ),
    .cmd_ras_ps0                  ( cmd_ras_ps0                ),
    .req_ras_id_ps0               ( req_ras_id_ps0             ),
    .cmd_ras_id_ps0               ( cmd_ras_id_ps0             ),
    .bank_group_ras_ps0           ( bank_group_ras_ps0         ),
    .row_address_ras_ps0          ( row_address_ras_ps0        ),
    
    /* CAS cmd PS0 */
    .ready_to_cmd_cas_ps0         ( ready_to_cmd_cas_ps0       ),
    .cmd_cas_ps0                  ( cmd_cas_ps0                ),
    .req_cas_id_ps0               ( req_cas_id_ps0             ),
    .cmd_cas_id_ps0               ( cmd_cas_id_ps0             ),
    .bank_group_cas_ps0           ( bank_group_cas_ps0         ),
    
    /* RAS cmd PS1 */
    .ready_to_cmd_ras_ps1         ( ready_to_cmd_ras_ps1       ),
    .cmd_ras_ps1                  ( cmd_ras_ps1                ),
    .req_ras_id_ps1               ( req_ras_id_ps1             ),
    .cmd_ras_id_ps1               ( cmd_ras_id_ps1             ),
    .bank_group_ras_ps1           ( bank_group_ras_ps1         ),
    .row_address_ras_ps1          ( row_address_ras_ps1        ),
    
    /* CAS cmd PS1 */
    .ready_to_cmd_cas_ps1         ( ready_to_cmd_cas_ps1       ),
    .cmd_cas_ps1                  ( cmd_cas_ps1                ),
    .req_cas_id_ps1               ( req_cas_id_ps1             ),
    .cmd_cas_id_ps1               ( cmd_cas_id_ps1             ),
    .bank_group_cas_ps1           ( bank_group_cas_ps1         ),
    
    .bank_address_ras_ps0         ( bank_address_ras_ps0       ),
    .bank_address_ras_ps1         ( bank_address_ras_ps1       ),
    
    .served_ras                   ( served_ras                 ),
    .served_cas                   ( served_cas                 ),
    

    .reset_hbm_controller         ( reset_hbm_controller       ),

    .wrt_data_cas_ps0             ( ram_cas_out_ps0            ),
    .wrt_data_cas_ps1             ( ram_cas_out_ps1            ),

    .wr_ram_cas_address_out_ps0   ( wr_ram_cas_address_out_ps0 ),
    .wr_ram_cas_address_out_ps1   ( wr_ram_cas_address_out_ps1 ),

    .rd_ram_cas_address_out_ps0   ( rd_ram_cas_address_out_ps0 ),
    .rd_ram_cas_address_out_ps1   ( rd_ram_cas_address_out_ps1 ),


    .rd_data_valid_ps0            ( rd_data_valid_ps0          ),
    .rd_data_valid_ps1            ( rd_data_valid_ps1          ),
    .rd_data_req_id_ps0           ( rd_data_req_id_ps0         ),
    .rd_data_ps0                  ( rd_data_ps0                ),
    .rd_data_req_id_ps1           ( rd_data_req_id_ps1         ),
    .rd_data_ps1                  ( rd_data_ps1                )
);


endmodule
