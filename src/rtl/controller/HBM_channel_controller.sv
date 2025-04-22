`timescale 1ps / 1ps

`include "dfi_interface.svh"
`include "commands.svh"
`include "hbm_controller.svh"
`include "hbm_timing_constraints.svh"

module HBM_channel_controller ( 
    input logic             dfi_clk_buf,
    input logic           	dfi_rst_n,
    input logic            	dfi_rst_buf_n,

    `DEFINE_DFI_MASTER_PORTS, 

    /* Extern interface to the top switch */
    input logic [31:0]                 input_address,
    input logic [1:0]                  input_request,
    input logic [P_DATA_WIDTH-1:0]     input_write_data,
    input logic [P_REQ_ID_WIDTH-1:0]   request_id,
    input logic                        input_request_valid,
    output logic                       output_request_picked,
    output logic                       reset_hbm_controller,
    
    output logic                       rd_data_valid_ps0,
    output logic                       rd_data_valid_ps1,
    output logic [P_REQ_ID_WIDTH-1:0]  rd_data_req_id_ps0,
    output logic [P_DATA_WIDTH-1:0]    rd_data_ps0,
    output logic [P_REQ_ID_WIDTH-1:0]  rd_data_req_id_ps1,
    output logic [P_DATA_WIDTH-1:0]    rd_data_ps1
    
);

logic [P_ROW_ADDR_WIDTH-1 : 0]               row_address;
logic [P_COL_ADDR_WIDTH-1 : 0]               column_address;
logic [P_BA_ADDR_WIDTH-1  : 0]               bank_address;

logic  [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1]  cmd_picked_bank;
logic  [3:0]                                 cmd_bank                 [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
logic  [P_ROW_ADDR_WIDTH-1 : 0]              row_address_bank         [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];

logic [3:0]                                  cmd_dispatcher           [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
logic [P_ROW_ADDR_WIDTH-1 : 0]               row_addr_dispatcher      [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];
logic                                        cmd_picked_dispatcher    [0 : P_TOTAL_PER_CHANNEL_BANK_N - 1];

logic [(P_BA_N_PS*2)-1:0]                    served_ras;
logic [(P_BA_N_PS*2)-1:0]                    served_cas;


/* Request ID and command ID - for tracking and debugging */
/* From extern to dispatcher */
logic [P_REQ_ID_WIDTH-1:0] input_req_id    [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];

/* From dispatcher to bank scheduler */
logic [P_REQ_ID_WIDTH-1:0] req_id          [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];
logic [P_CMD_ID_WIDTH-1:0] cmd_id          [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];

/* From bank scheduler to channel scheduler */
logic [P_REQ_ID_WIDTH-1:0] req_id_bank     [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];
logic [P_CMD_ID_WIDTH-1:0] cmd_id_bank     [0 : P_TOTAL_PER_CHANNEL_BANK_N-1];


logic [P_TOTAL_PER_CHANNEL_BANK_N-1:0] request_picked;
logic [P_TOTAL_PER_CHANNEL_BANK_N-1:0] request_valid;

assign request_valid = input_request_valid << bank_address; 
 
logic [P_REQ_ID_WIDTH-1:0] counter_requests;

assign output_request_picked = |(request_picked);



logic rd_blk_ram_write_en_ps0;
assign rd_blk_ram_write_en_ps0 = input_request_valid & ~bank_address[4] &  input_request[0] & |(request_picked);

logic rd_blk_ram_write_en_ps1;
assign rd_blk_ram_write_en_ps1 = input_request_valid & bank_address[4]  &  input_request[0] & |(request_picked);

logic wr_blk_ram_write_en_ps0;
assign wr_blk_ram_write_en_ps0 = input_request_valid & ~bank_address[4] & ~input_request[0] & |(request_picked);

logic wr_blk_ram_write_en_ps1;
assign wr_blk_ram_write_en_ps1 = input_request_valid & bank_address[4]  & ~input_request[0] & |(request_picked);



logic [(P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH)-2:0] blk_ram_wrt_addr;
assign blk_ram_wrt_addr = {request_id, bank_address[3:0]} /*counter_requests*/;

logic  [P_DATA_WIDTH-1 : 0] ram_cas_out_ps0;
logic  [P_DATA_WIDTH-1 : 0] ram_cas_out_ps1;


logic  [P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-2:0] wr_ram_cas_address_req_id_ps0;
logic  [P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-2:0] wr_ram_cas_address_req_id_ps1;

logic  [P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-2:0] rd_ram_cas_address_req_id_ps0;
logic  [P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-2:0] rd_ram_cas_address_req_id_ps1;

logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] wr_ram_cas_address_out_ps0;
logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] wr_ram_cas_address_out_ps1;

logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] rd_ram_cas_address_out_ps0;
logic  [P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH-1 : 0] rd_ram_cas_address_out_ps1;

/* ADDRESS MAPPING POLICY */

generate
/* 14R-5C-2BG-2B-PC */
//`ifdef ADDRESS_MAPPING_1
// if (P_MAPPING_POLICY == 1) begin
//     assign row_address    =  input_address[28:15];
//     assign column_address =  {input_address[14:10], 1'b1};
//     assign bank_address   =  {input_address[5], input_address[9:6]};
// //`endif
// end
if (P_MAPPING_POLICY == 1) begin
    assign row_address    =  input_address[28:15];
    assign column_address =  {input_address[14:10], 1'b1};
    assign bank_address   =  {input_address[2], input_address[6:3]};
//`endif
end
/* WARNINGGGGGGGGGGGGGGGGGGGGGGGGGGGG */
/* TO BE ADJUSTED */
else if (P_MAPPING_POLICY == 2) begin
/* 14R-5C-2B-2BG-PC */
//`ifdef ADDRESS_MAPPING_2
    assign row_address    =  input_address[26:13];
    assign column_address =  {input_address[12:8], 1'b1};
    assign bank_address   =  {input_address[2], input_address[4:3],input_address[6:5]};
//`endif
end 
else if (P_MAPPING_POLICY == 3) begin
/* PC-2BG-2B-14R-5C */
//`ifdef ADDRESS_MAPPING_3
    assign row_address    =  {input_address[21:8]};
    assign column_address =  {input_address[7:3], 1'b1};
    assign bank_address   =  {input_address[26:22]};
//`endif
end
else if (P_MAPPING_POLICY == 4) begin 
/* 14R-PC-2BG-2B-5C */ 
//`ifdef ADDRESS_MAPPING_4
    assign row_address    =  {input_address[26:13]};
    assign column_address =  {input_address[7:3], 1'b1};
    assign bank_address   =  {input_address[12:8]};
//`endif
end
else if (P_MAPPING_POLICY == 5) begin 
/* 14R-2BG-2B-5C-PC */
//`ifdef ADDRESS_MAPPING_5
    assign row_address    =  input_address[26:13];
    assign column_address =  {input_address[8:4], 1'b1};
    assign bank_address   =  {input_address[2], input_address[12:9]};
//`endif
end
endgenerate
/* END ADDRESS MAPPING POLICY */

/* TRACK THE NUMBER OF REQUESTS */
always @(posedge dfi_clk_buf or negedge reset_hbm_controller ) begin 
    if ( reset_hbm_controller == 1'b0 ) begin
        counter_requests <= { P_REQ_ID_WIDTH { 1'b0 } };
    end
    else begin
        if ( |(request_picked) == 1'b1 ) begin
            counter_requests <= counter_requests + 1'b1;
            `ifdef DEBUG
                $display("[ CONTROLLER %d ]: REQ: %d - CMD: %d (%d) sent at %d", 1'b0, counter_requests, 1'b0, 1'b0, $time);
            `endif
        end
    end
end


always_comb begin
    foreach (input_req_id[i]) input_req_id[i] <= request_id /* counter_requests */;
end



/* CAS BUFFERS */
/* | WRT DATA | BANK ADDRESS | COL ADDRESS | */
block_ram #
(
    .ADDR_WIDTH(P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-1),
    .DATA_WIDTH(P_DATA_WIDTH)
)
cas_data_ps0
(
    .data_in(input_write_data),
    .read_addr(wr_ram_cas_address_req_id_ps0),
     
    .write_addr(blk_ram_wrt_addr),
    .wr_en(wr_blk_ram_write_en_ps0), 
    .clk(dfi_clk_buf),
    .data_out(ram_cas_out_ps0)
);

block_ram #
(
    .ADDR_WIDTH(P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-1),
    .DATA_WIDTH(P_DATA_WIDTH)
)
cas_data_ps1
(
    .data_in(input_write_data),
    .read_addr(wr_ram_cas_address_req_id_ps1), 
    .write_addr(blk_ram_wrt_addr),
    .wr_en(wr_blk_ram_write_en_ps1), 
    .clk(dfi_clk_buf),
    .data_out(ram_cas_out_ps1)
);


block_ram #
(
    .ADDR_WIDTH(P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-1),
    .DATA_WIDTH(P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH)
)
wr_cas_address_ps0
(
    .data_in({bank_address, column_address}), 
    .read_addr(wr_ram_cas_address_req_id_ps0), 
    .write_addr(blk_ram_wrt_addr),
    .wr_en(wr_blk_ram_write_en_ps0), 
    .clk(dfi_clk_buf),
    .data_out(wr_ram_cas_address_out_ps0)
);

block_ram #
(
    .ADDR_WIDTH(P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-1),
    .DATA_WIDTH(P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH)
)
wr_cas_address_ps1
(
    .data_in({bank_address, column_address}),
    .read_addr(wr_ram_cas_address_req_id_ps1), 
    .write_addr(blk_ram_wrt_addr),
    .wr_en(wr_blk_ram_write_en_ps1), 
    .clk(dfi_clk_buf),
    .data_out(wr_ram_cas_address_out_ps1)
);


// READ ADDRESS BRAM - NOT REALLY NEEDED
block_ram #
(
    .ADDR_WIDTH(P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-1),
    .DATA_WIDTH(P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH)
)
rd_cas_address_ps0
(
    .data_in({bank_address, column_address}), 
    .read_addr(rd_ram_cas_address_req_id_ps0), 
    .write_addr(blk_ram_wrt_addr),
    .wr_en(rd_blk_ram_write_en_ps0), 
    .clk(dfi_clk_buf),
    .data_out(rd_ram_cas_address_out_ps0)
);

block_ram #
(
    .ADDR_WIDTH(P_REQ_ID_WIDTH+P_BA_ADDR_WIDTH-1),
    .DATA_WIDTH(P_BA_ADDR_WIDTH+P_COL_ADDR_WIDTH)
)
rd_cas_address_ps1
(
    .data_in({bank_address, column_address}),
    .read_addr(rd_ram_cas_address_req_id_ps1), 
    .write_addr(blk_ram_wrt_addr),
    .wr_en(rd_blk_ram_write_en_ps1), 
    .clk(dfi_clk_buf),
    .data_out(rd_ram_cas_address_out_ps1)
);

genvar i;
generate 
    for ( i = 0; i < P_TOTAL_PER_CHANNEL_BANK_N; i = i + 1 ) begin : translator_bank_scheduler
            REQ_to_CMD_translator #(
//                .P_REQ_WIDTH       (2),
//                .P_ADDR_WIDTH      (32),
//                .P_DATA_WIDTH      (P_DATA_WIDTH),
//                .P_ROW_ADDR_WIDTH  (P_ROW_ADDR_WIDTH),
//                .P_COL_ADDR_WIDTH  (P_COL_ADDR_WIDTH),
//                .P_BA_ADDR_WIDTH   (P_BA_ADDR_WIDTH),
//                .P_REQ_ID_WIDTH    (P_REQ_ID_WIDTH),
//                .P_CMD_ID_WIDTH    (P_CMD_ID_WIDTH),                


//                .P_QUEUE_LEN       (P_QUEUE_LEN  ),
//                .P_WRT_REQ         (P_WRT_REQ    ),
//                .P_RD_REQ          (P_RD_REQ     ),
//                .P_GENERAL_NOP     (P_GENERAL_NOP),
//                .P_ROW_NOP		   (P_ROW_NOP    ),
//                .P_ROW_ACT		   (P_ROW_ACT    ),
//                .P_ROW_PRE		   (P_ROW_PRE    ),
//                .P_ROW_PREA	       (P_ROW_PREA   ),
//                .P_COL_WRT		   (P_COL_WRT    ),
//                .P_COL_RD          (P_COL_RD     )
            ) REQ_to_CMD_translator_i (
                .clk               (dfi_clk_buf              ),
                .rst_n             (reset_hbm_controller     ),
                .input_req_id      (input_req_id[i]          ), 
                .input_request     (input_request            ),
                .row_address       (row_address              ),
                .request_valid     (request_valid[i]         ),
                .request_picked    (request_picked[i]        ),
                .req_id            (req_id[i]                ),
                .cmd_id            (cmd_id[i]                ),
                .cmd_picked        (cmd_picked_dispatcher[i] ),
                .cmd               (cmd_dispatcher[i]        ),
                .row_addr          (row_addr_dispatcher[i]   )
            );
    
    
            bank_scheduler #(
//                .P_ROW_ADDR_WIDTH          (P_ROW_ADDR_WIDTH ),
//                .P_COL_ADDR_WIDTH          (P_COL_ADDR_WIDTH ),
//                .P_BA_ADDR_WIDTH           (P_BA_ADDR_WIDTH  ), 
//                .P_DATA_WIDTH              (P_DATA_WIDTH     ),
                .P_BANK_INDEX              (i                )
//                .P_GENERAL_NOP             (P_GENERAL_NOP    ),
//                .P_ROW_NOP                 (P_ROW_NOP        ),
//                .P_ROW_ACT                 (P_ROW_ACT        ),
//                .P_ROW_PRE                 (P_ROW_PRE        ),  
//                .P_ROW_PREA                (P_ROW_PREA       ),  
//                .P_ROW_REFPB               (P_ROW_REFPB      ), 
//                .P_COL_WRT                 (P_COL_WRT        ),
//                .P_COL_RD                  (P_COL_RD         ),
//                .P_REQ_ID_WIDTH            (P_REQ_ID_WIDTH   ),
//                .P_CMD_ID_WIDTH            (P_CMD_ID_WIDTH   ),

//                .tRCD                      (tRCD   ),
//                .tRP                       (tRP    ),
//                .tRC                       (tRC    ),
//                .tRAS                      (tRAS   ),
//                .tWL                       (tWL    ),
//                .tRL                       (tRL    ),
//                .tRTPl                     (tRTPl  ),
//                .tWR                       (tWR    ),
//                .tBURST                    (tBURST ),
//                .tRFCpb                    (tRFCpb ),
//                .tREFP                     (tREFP  )  
            ) bank_scheduler_i (
                .clock_i                       (dfi_clk_buf ),
                .reset_ni                     (reset_hbm_controller   ),
                
                .req_id_req_to_cmd_translator         (req_id[i]                ),
                .cmd_id_req_to_cmd_translator         (cmd_id[i]                ),
                .cmd_req_to_cmd_translator            (cmd_dispatcher[i]        ),
                .row_addr_req_to_cmd_translator       (row_addr_dispatcher[i]   ),
                .cmd_picked_req_to_cmd_translator     (cmd_picked_dispatcher[i] ),
            
                .cmd_picked_bank           (cmd_picked_bank[i]     ),
                .req_id_bank               (req_id_bank[i]         ),
                .cmd_id_bank               (cmd_id_bank[i]         ),
                .cmd_bank                  (cmd_bank[i]            ),
                .row_address_bank          (row_address_bank[i]    ),
                .served_ras                (served_ras[i]          ),
                .served_cas                (served_cas[i]          )
            );
    end
endgenerate


channel_scheduler  channel_scheduler_u (
    .clock_i                         ( dfi_clk_buf                   ),
    .reset_ni                        ( dfi_rst_n                     ),
    
    .dfi_rst_buf_n                   ( dfi_rst_buf_n                 ),
    .dfi_init_start                  ( dfi_init_start                ),
    .dfi_aw_ck_p0                    ( dfi_aw_ck_p0                  ),
    .dfi_aw_cke_p0                   ( dfi_aw_cke_p0                 ),
    .dfi_aw_row_p0                   ( dfi_aw_row_p0                 ),
    .dfi_aw_col_p0                   ( dfi_aw_col_p0                 ),
    .dfi_dw_wrdata_p0                ( dfi_dw_wrdata_p0              ),
    .dfi_dw_wrdata_mask_p0           ( dfi_dw_wrdata_mask_p0         ),
    .dfi_dw_wrdata_dbi_p0            ( dfi_dw_wrdata_dbi_p0          ),
    .dfi_dw_wrdata_par_p0            ( dfi_dw_wrdata_par_p0          ),
    .dfi_dw_wrdata_dq_en_p0          ( dfi_dw_wrdata_dq_en_p0        ),
    .dfi_dw_wrdata_par_en_p0         ( dfi_dw_wrdata_par_en_p0       ),
    .dfi_aw_ck_p1                    ( dfi_aw_ck_p1                  ),
    .dfi_aw_cke_p1                   ( dfi_aw_cke_p1                 ),
    .dfi_aw_row_p1                   ( dfi_aw_row_p1                 ),
    .dfi_aw_col_p1                   ( dfi_aw_col_p1                 ),
    .dfi_dw_wrdata_p1                ( dfi_dw_wrdata_p1              ),
    .dfi_dw_wrdata_mask_p1           ( dfi_dw_wrdata_mask_p1         ),
    .dfi_dw_wrdata_dbi_p1            ( dfi_dw_wrdata_dbi_p1          ),
    .dfi_dw_wrdata_par_p1            ( dfi_dw_wrdata_par_p1          ),
    .dfi_dw_wrdata_dq_en_p1          ( dfi_dw_wrdata_dq_en_p1        ),
    .dfi_dw_wrdata_par_en_p1         ( dfi_dw_wrdata_par_en_p1       ),
    .dfi_aw_ck_dis                   ( dfi_aw_ck_dis                 ),
    .dfi_lp_pwr_e_req                ( dfi_lp_pwr_e_req              ),
    .dfi_lp_sr_e_req                 ( dfi_lp_sr_e_req               ),
    .dfi_lp_pwr_x_req                ( dfi_lp_pwr_x_req              ),
    .dfi_aw_tx_indx_ld               ( dfi_aw_tx_indx_ld             ),
    .dfi_dw_tx_indx_ld               ( dfi_dw_tx_indx_ld             ),
    .dfi_dw_rx_indx_ld               ( dfi_dw_rx_indx_ld             ),
    .dfi_ctrlupd_ack                 ( dfi_ctrlupd_ack               ),
    .dfi_phyupd_req                  ( dfi_phyupd_req                ),
    .dfi_lp_pwr_x_e_req              ( dfi_lp_pwr_x_e_req            ),
    .dfi_init_complete               ( dfi_init_complete             ),
    .dfi_dw_rddata_valid             ( dfi_dw_rddata_valid           ),
    .dfi_dw_rddata_p0                ( dfi_dw_rddata_p0              ),
    .dfi_dw_rddata_dm_p0             ( dfi_dw_rddata_dm_p0           ),
    .dfi_dw_rddata_dbi_p0            ( dfi_dw_rddata_dbi_p0          ),
    .dfi_dw_rddata_par_p0            ( dfi_dw_rddata_par_p0          ),
    .dfi_dw_rddata_p1                ( dfi_dw_rddata_p1              ),
    .dfi_dw_rddata_dm_p1             ( dfi_dw_rddata_dm_p1           ),
    .dfi_dw_rddata_dbi_p1            ( dfi_dw_rddata_dbi_p1          ),
    .dfi_dw_rddata_par_p1            ( dfi_dw_rddata_par_p1          ),
    .dfi_ctrlupd_req                 ( dfi_ctrlupd_req               ),
    .dfi_phyupd_ack                  ( dfi_phyupd_ack                ),
    
    .cmd_picked_bank                 ( cmd_picked_bank               ),
    .req_id_bank                     ( req_id_bank                   ),
    .cmd_id_bank                     ( cmd_id_bank                   ),
    .cmd_bank                        ( cmd_bank                      ),
    
    .served_ras                      ( served_ras                    ),
    .served_cas                      ( served_cas                    ),

    .reset_hbm_controller            ( reset_hbm_controller          ),

    .ram_cas_out_ps0                 ( ram_cas_out_ps0               ),
    .ram_cas_out_ps1                 ( ram_cas_out_ps1               ),

    .row_address_bank                ( row_address_bank              ),

  
    .wr_ram_cas_address_req_id_ps0   ( wr_ram_cas_address_req_id_ps0 ),
    .wr_ram_cas_address_req_id_ps1   ( wr_ram_cas_address_req_id_ps1 ),

    .rd_ram_cas_address_req_id_ps0   ( rd_ram_cas_address_req_id_ps0 ),
    .rd_ram_cas_address_req_id_ps1   ( rd_ram_cas_address_req_id_ps1 ),

    .wr_ram_cas_address_out_ps0      ( wr_ram_cas_address_out_ps0    ),
    .wr_ram_cas_address_out_ps1      ( wr_ram_cas_address_out_ps1    ),

    .rd_ram_cas_address_out_ps0      ( rd_ram_cas_address_out_ps0    ),
    .rd_ram_cas_address_out_ps1      ( rd_ram_cas_address_out_ps1    ),

    .rd_data_valid_ps0               ( rd_data_valid_ps0             ),
    .rd_data_valid_ps1               ( rd_data_valid_ps1             ),
    .rd_data_req_id_ps0              ( rd_data_req_id_ps0            ),
    .rd_data_ps0                     ( rd_data_ps0                   ),
    .rd_data_req_id_ps1              ( rd_data_req_id_ps1            ),
    .rd_data_ps1                     ( rd_data_ps1                   )
);

endmodule