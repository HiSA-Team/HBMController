`timescale 1ps / 1ps

`include "dfi_interface.svh"
`include "commands.svh"
`include "hbm_controller.svh"

module last_level_command_forwarder (

    // Clock and reset
    input logic             clock_i,
    input logic           	reset_ni,
    input logic            	dfi_rst_buf_n,

    // DFI interface ports - to the HBM PHY
    `DEFINE_DFI_MASTER_PORTS,
    
    /* RAS cmd PS0 */
    output logic                        ready_to_cmd_ras_ps0,
    input logic [3:0]                   cmd_ras_ps0,
    input logic [P_REQ_ID_WIDTH-1:0]    req_ras_id_ps0,
    input logic [P_CMD_ID_WIDTH-1:0]    cmd_ras_id_ps0,
    input logic [1:0]                   bank_group_ras_ps0,
    input logic [P_ROW_ADDR_WIDTH-1:0]  row_address_ras_ps0,
    
    /* CAS cmd PS0 */
    output logic                        ready_to_cmd_cas_ps0,
    input logic [3:0]                   cmd_cas_ps0,
    input logic [P_REQ_ID_WIDTH-1:0]    req_cas_id_ps0,
    input logic [P_CMD_ID_WIDTH-1:0]    cmd_cas_id_ps0,
    input logic [1:0]                   bank_group_cas_ps0,
    
    /* RAS cmd PS1 */
    output logic                        ready_to_cmd_ras_ps1,
    input logic [3:0]                   cmd_ras_ps1,
    input logic [P_REQ_ID_WIDTH-1:0]    req_ras_id_ps1,
    input logic [P_CMD_ID_WIDTH-1:0]    cmd_ras_id_ps1,
    input logic [1:0]                   bank_group_ras_ps1,
    input logic [P_ROW_ADDR_WIDTH-1:0]  row_address_ras_ps1,
    
    /* CAS cmd PS1 */
    output logic                        ready_to_cmd_cas_ps1,
    input logic [3:0]                   cmd_cas_ps1,
    input logic [P_REQ_ID_WIDTH-1:0]    req_cas_id_ps1,
    input logic [P_CMD_ID_WIDTH-1:0]    cmd_cas_id_ps1,
    input logic [1:0]                   bank_group_cas_ps1,

    
    input logic [P_BA_ADDR_WIDTH-1:0]       bank_address_ras_ps0,
    input logic [P_BA_ADDR_WIDTH-1:0]       bank_address_ras_ps1,
    
    /* To inform bank schedulers that the command is served */
    output logic [(P_BA_N_PS*2)-1:0]          served_ras,
    output logic [(P_BA_N_PS*2)-1:0]          served_cas,

    /* Data Read out with the associate request id */
    output logic                              rd_data_valid_ps0,
    output logic                              rd_data_valid_ps1,
    output logic [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps0,
    output logic [P_DATA_WIDTH-1:0]           rd_data_ps0,
    output logic [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps1,
    output logic [P_DATA_WIDTH-1:0]           rd_data_ps1,

    input logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] wr_ram_cas_address_out_ps0,
    input logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] wr_ram_cas_address_out_ps1,

    input logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] rd_ram_cas_address_out_ps0,
    input logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] rd_ram_cas_address_out_ps1,

    input logic  [P_DATA_WIDTH-1 : 0] wrt_data_cas_ps0,
    input logic  [P_DATA_WIDTH-1 : 0] wrt_data_cas_ps1,

    output logic reset_hbm_controller
    
);


// TODO refactor this, it is not necessary to have wr and rd bram, we need just a bram per pseudo
logic [P_BA_ADDR_WIDTH-1:0]         bank_address_cas_ps0;
logic [P_COL_ADDR_WIDTH-1:0]        column_address_cas_ps0;
logic [P_BA_ADDR_WIDTH-1:0]         bank_address_cas_ps1;
logic [P_COL_ADDR_WIDTH-1:0]        column_address_cas_ps1;
assign bank_address_cas_ps0    =   ( cmd_cas_ps0 == P_COL_WRT ) ? wr_ram_cas_address_out_ps0  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:P_COL_ADDR_WIDTH] : rd_ram_cas_address_out_ps0  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:P_COL_ADDR_WIDTH];
assign column_address_cas_ps0  =   ( cmd_cas_ps0 == P_COL_WRT ) ? wr_ram_cas_address_out_ps0  [P_COL_ADDR_WIDTH-1:0] : rd_ram_cas_address_out_ps0  [P_COL_ADDR_WIDTH-1:0];
assign bank_address_cas_ps1    =   ( cmd_cas_ps1 == P_COL_WRT ) ? wr_ram_cas_address_out_ps1  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:P_COL_ADDR_WIDTH] : rd_ram_cas_address_out_ps1  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1:P_COL_ADDR_WIDTH];
assign column_address_cas_ps1  =   ( cmd_cas_ps1 == P_COL_WRT ) ? wr_ram_cas_address_out_ps1  [P_COL_ADDR_WIDTH-1:0] : rd_ram_cas_address_out_ps1  [P_COL_ADDR_WIDTH-1:0];


assign dfi_dw_wrdata_mask_p0   = 32'h0000_0000;
assign dfi_dw_wrdata_dbi_p0    = 32'h0000_0000;
assign dfi_dw_wrdata_par_p0    = 8'h00;
assign dfi_dw_wrdata_par_en_p0 = 8'h00;
assign dfi_dw_wrdata_mask_p1   = 32'h0000_0000;
assign dfi_dw_wrdata_dbi_p1    = 32'h0000_0000;
assign dfi_dw_wrdata_par_p1    = 8'h00;
assign dfi_dw_wrdata_par_en_p1 = 8'h00;
assign dfi_lp_pwr_x_e_req      = 1'b0;

assign dfi_dw_wrdata_dq_en_p0  = 8'h00; //{{(4){r_dfi_dw_wrdata_dq_en_p0}}, {(4){r_dfi_dw_wrdata_dq_en_p1}}; 
assign dfi_dw_wrdata_dq_en_p1  = 8'h00; //{{(4){r_dfi_dw_wrdata_dq_en_p0}}, {(4){r_dfi_dw_wrdata_dq_en_p1}}; 

assign dfi_aw_ck_dis           = 1'b0;
assign dfi_lp_pwr_e_req        = 1'b0;
assign dfi_lp_sr_e_req         = 1'b0;
assign dfi_lp_pwr_x_req        = 1'b0;
assign dfi_aw_tx_indx_ld       = 1'b0;
assign dfi_dw_tx_indx_ld       = 1'b0;
assign dfi_dw_rx_indx_ld       = 1'b0;
assign dfi_ctrlupd_ack         = 1'b0;
assign dfi_phyupd_req          = 1'b0;

/* STATES TODO refactor */
localparam LP_IDLE			    = 4'd0;
localparam LP_MRS			    = 4'd1;
localparam LP_FETCH			    = 4'd2;
localparam LP_CMD_WAIT          = 4'd3;
localparam LP_CMD_WAIT_1        = 4'd4;

logic [3:0]   r_phy_tg_ps; // Present state TODO refactor
logic [7:0]   r_mrs_reg_cnt; // TODO refactor

logic         can_serve_actual_ras_ps0;
logic         can_serve_actual_ras_ps1;
logic         can_serve_actual_cas_ps0;
logic         can_serve_actual_cas_ps1;

logic         can_serve_actual_act_ps0;
logic         can_serve_actual_act_ps1;
logic         can_serve_actual_pre_ps0;
logic         can_serve_actual_pre_ps1;
logic         can_serve_actual_ref_ps0;
logic         can_serve_actual_ref_ps1;;

logic         can_serve_actual_wrt_ps0;
logic         can_serve_actual_wrt_ps1;
logic         can_serve_actual_rd_ps0;
logic         can_serve_actual_rd_ps1;

logic         double_act_ras_sync;

assign ready_to_cmd_ras_ps0 = (r_phy_tg_ps == LP_CMD_WAIT) || ( (can_serve_actual_ras_ps0 || cmd_ras_ps0 == P_GENERAL_NOP) && r_phy_tg_ps == LP_CMD_WAIT_1 ) ? 1'b1 : 1'b0;
assign ready_to_cmd_cas_ps0 = (r_phy_tg_ps == LP_CMD_WAIT) || ( (can_serve_actual_cas_ps0 || cmd_cas_ps0 == P_GENERAL_NOP) && r_phy_tg_ps == LP_CMD_WAIT_1 ) ? 1'b1 : 1'b0;
assign ready_to_cmd_ras_ps1 = (r_phy_tg_ps == LP_CMD_WAIT) || ( (can_serve_actual_ras_ps1 || cmd_ras_ps1 == P_GENERAL_NOP) && r_phy_tg_ps == LP_CMD_WAIT_1 ) ? 1'b1 : 1'b0;
assign ready_to_cmd_cas_ps1 = (r_phy_tg_ps == LP_CMD_WAIT) || ( (can_serve_actual_cas_ps1 || cmd_cas_ps1 == P_GENERAL_NOP) && r_phy_tg_ps == LP_CMD_WAIT_1 ) ? 1'b1 : 1'b0;



llcf_init_sequence_driver llcf_init_sequence_driver_u (

    // Input
    .clock_i                ( clock_i              ),     
    .reset_ni               ( reset_ni             ),
    .dfi_rst_buf_n          ( dfi_rst_buf_n        ), 
    .dfi_init_complete      ( dfi_init_complete    ),

    .cmd_ras_ps0            ( cmd_ras_ps0          ), 
    .cmd_ras_ps1            ( cmd_ras_ps1          ), 
    .cmd_cas_ps0            ( cmd_cas_ps0          ), 
    .cmd_cas_ps1            ( cmd_cas_ps1          ), 

    // Output
    .dfi_init_start         ( dfi_init_start       ), 
    .dfi_aw_cke_p0          ( dfi_aw_cke_p0        ),
    .dfi_aw_cke_p1          ( dfi_aw_cke_p1        ),
    .dfi_aw_ck_p0           ( dfi_aw_ck_p0         ),  
    .dfi_aw_ck_p1           ( dfi_aw_ck_p1         ), 

    .r_phy_tg_ps            ( r_phy_tg_ps          ),  // Present state TODO refactor
    .r_mrs_reg_cnt          ( r_mrs_reg_cnt        ),  // TODO maybe refactor
    .reset_hbm_controller   ( reset_hbm_controller )

);

// Write data driver
llcf_write_data_driver llcf_write_data_driver_u (
    .clock_i              ( clock_i                  ),
    .reset_ni             ( reset_ni                 ),
    // Input data
    .wrt_data_ps0_i       ( wrt_data_cas_ps0         ),
    .wrt_data_ps1_i       ( wrt_data_cas_ps1         ),
    .wrt_data_ps0_valid_i ( can_serve_actual_wrt_ps0 ),
    .wrt_data_ps1_valid_i ( can_serve_actual_wrt_ps1 ),
    // Output data
    .wrt_data_p0_o        ( dfi_dw_wrdata_p0         ),
    .wrt_data_p1_o        ( dfi_dw_wrdata_p1         )
);

// Read data driver
llcf_read_data_driver llcf_read_data_driver_u (
    .clock_i               ( clock_i                 ),
    .reset_ni              ( reset_ni                ),
    // Input id
    .rd_req_id_ps0_i       ( req_cas_id_ps0          ),
    .rd_req_id_ps1_i       ( req_cas_id_ps1          ),
    .rd_req_id_ps0_valid_i ( can_serve_actual_rd_ps0 ),
    .rd_req_id_ps1_valid_i ( can_serve_actual_rd_ps1 ),
    // Input data directly from the HBM
    .rd_data_p0_i          ( dfi_dw_rddata_p0        ),
    .rd_data_p1_i          ( dfi_dw_rddata_p1        ),
    .rd_data_valid_i       ( dfi_dw_rddata_valid     ),
    // Output data and id
    .rd_data_ps0_o         ( rd_data_ps0             ),
    .rd_data_ps1_o         ( rd_data_ps1             ),
    .rd_data_req_id_ps0_o  ( rd_data_req_id_ps0      ),
    .rd_data_req_id_ps1_o  ( rd_data_req_id_ps1      ),
    .rd_data_valid_ps0_o   ( rd_data_valid_ps0       ),
    .rd_data_valid_ps1_o   ( rd_data_valid_ps1       )
);


llcf_ras_cmd_driver llcf_ras_cmd_driver_u (
    
    // Input
    .clock_i                     ( clock_i                  ),
    .reset_ni                    ( reset_ni                 ),

    .can_serve_actual_ras_ps0    ( can_serve_actual_ras_ps0 ),
    .can_serve_actual_ras_ps1    ( can_serve_actual_ras_ps1 ), 
    .can_serve_actual_act_ps0    ( can_serve_actual_act_ps0 ),
    .can_serve_actual_act_ps1    ( can_serve_actual_act_ps1 ),
    .can_serve_actual_pre_ps0    ( can_serve_actual_pre_ps0 ),
    .can_serve_actual_pre_ps1    ( can_serve_actual_pre_ps1 ),
    .can_serve_actual_ref_ps0    ( can_serve_actual_ref_ps0 ),
    .can_serve_actual_ref_ps1    ( can_serve_actual_ref_ps1 ),

    .cmd_ras_ps0                 ( cmd_ras_ps0              ), 
    .bank_address_ras_ps0        ( bank_address_ras_ps0     ), 
    .row_address_ras_ps0         ( row_address_ras_ps0      ), 

    .cmd_ras_ps1                 ( cmd_ras_ps1              ), 
    .bank_address_ras_ps1        ( bank_address_ras_ps1     ), 
    .row_address_ras_ps1         ( row_address_ras_ps1      ), 
    
    .r_phy_tg_ps                 (  r_phy_tg_ps             ),    // Present state TODO refactor

    `ifdef DEBUG
        .req_ras_id_ps0          ( req_ras_id_ps0           ), 
        .cmd_ras_id_ps0          ( cmd_ras_id_ps0           ),
        .req_ras_id_ps1          ( req_ras_id_ps1           ), 
        .cmd_ras_id_ps1          ( cmd_ras_id_ps1           ), 
    `endif

    
    // Output
    .double_act_ras_sync         ( double_act_ras_sync      ),
    
    .served_ras                  ( served_ras               ),
    .dfi_aw_row_p0               ( dfi_aw_row_p0            ),
    .dfi_aw_row_p1               ( dfi_aw_row_p1            )
);

llcf_cas_cmd_driver llcf_cas_cmd_driver_u (

    // Input
    .clock_i                     ( clock_i                  ),
    .reset_ni                    ( reset_ni                 ),

    .r_phy_tg_ps                 ( r_phy_tg_ps              ), 
    .r_mrs_reg_cnt               ( r_mrs_reg_cnt            ), 

    .can_serve_actual_cas_ps0    ( can_serve_actual_cas_ps0 ), 
    .can_serve_actual_cas_ps1    ( can_serve_actual_cas_ps1 ),
    .can_serve_actual_wrt_ps0    ( can_serve_actual_wrt_ps0 ), 
    .can_serve_actual_wrt_ps1    ( can_serve_actual_wrt_ps1 ),
    .can_serve_actual_rd_ps0     ( can_serve_actual_rd_ps0  ), 
    .can_serve_actual_rd_ps1     ( can_serve_actual_rd_ps1  ),

    .cmd_cas_ps0                 ( cmd_cas_ps0              ),
    .bank_address_cas_ps0        ( bank_address_cas_ps0     ), 
    .column_address_cas_ps0      ( column_address_cas_ps0   ),

    .cmd_cas_ps1                 ( cmd_cas_ps1              ),
    .bank_address_cas_ps1        ( bank_address_cas_ps1     ), 
    .column_address_cas_ps1      ( column_address_cas_ps1   ),

    `ifdef DEBUG
        .req_cas_id_ps0          ( req_cas_id_ps0           ), 
        .cmd_cas_id_ps0          ( cmd_cas_id_ps0           ),
        .req_cas_id_ps1          ( req_cas_id_ps1           ), 
        .cmd_cas_id_ps1          ( cmd_cas_id_ps1           ),
    `endif

    // Output
    .served_cas                  ( served_cas               ), 
    .dfi_aw_col_p0               ( dfi_aw_col_p0            ),
    .dfi_aw_col_p1               ( dfi_aw_col_p1            )
);


llcf_ras_constraints_checker llcf_ras_constraints_checker_u (
    
    // Input
    .clock_i                     ( clock_i                  ),
    .reset_ni                    ( reset_ni                 ),
    .cmd_ras_ps0                 ( cmd_ras_ps0              ),
    .cmd_ras_ps1                 ( cmd_ras_ps1              ),
    
    .bank_group_ras_ps0          ( bank_group_ras_ps0       ),
    .bank_group_ras_ps1          ( bank_group_ras_ps1       ),
    .double_act_ras_sync         ( double_act_ras_sync      ),

    // Output
    .can_serve_actual_ras_ps0    ( can_serve_actual_ras_ps0 ),
    .can_serve_actual_ras_ps1    ( can_serve_actual_ras_ps1 ), 
    .can_serve_actual_act_ps0    ( can_serve_actual_act_ps0 ),
    .can_serve_actual_act_ps1    ( can_serve_actual_act_ps1 ),
    .can_serve_actual_pre_ps0    ( can_serve_actual_pre_ps0 ),
    .can_serve_actual_pre_ps1    ( can_serve_actual_pre_ps1 ),
    .can_serve_actual_ref_ps0    ( can_serve_actual_ref_ps0 ),
    .can_serve_actual_ref_ps1    ( can_serve_actual_ref_ps1 )

);

llcf_cas_constraints_checker llcf_cas_constraints_checker_u (
    
    // Input
    .clock_i                     ( clock_i                  ),
    .reset_ni                    ( reset_ni                 ),
    .cmd_cas_ps0                 ( cmd_cas_ps0              ),
    .cmd_cas_ps1                 ( cmd_cas_ps1              ),
    
    .bank_group_cas_ps0          ( bank_group_cas_ps0       ),
    .bank_group_cas_ps1          ( bank_group_cas_ps1       ),
    
    // Output
    .can_serve_actual_cas_ps0    ( can_serve_actual_cas_ps0 ),
    .can_serve_actual_cas_ps1    ( can_serve_actual_cas_ps1 ), 
    .can_serve_actual_wrt_ps0    ( can_serve_actual_wrt_ps0 ),
    .can_serve_actual_wrt_ps1    ( can_serve_actual_wrt_ps1 ),
    .can_serve_actual_rd_ps0     ( can_serve_actual_rd_ps0  ),
    .can_serve_actual_rd_ps1     ( can_serve_actual_rd_ps1  )

);


endmodule