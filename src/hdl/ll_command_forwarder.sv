/** Last Level Command Fowarder **/

module ll_command_forwarder # (
    parameter P_DRIVE_PRECHARGE_CMD = 114
)(
    //DFI INTERFACE SIGNALS
    input            			dfi_clk,
    input           			dfi_rst_n,
    input            			dfi_rst_buf_n,

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
);


wire w_mrs_lat_cnt_done;
wire w_precharge_lat_done;


reg r_dfi_init_start;

reg  [1:0]		r_dfi_aw_ck_p0;
reg  [1:0]      r_dfi_aw_cke_p0;
reg  [1:0]      r_dfi_aw_ck_p1;
reg  [1:0]      r_dfi_aw_cke_p1;
reg  [3:0]   	cke_cnt; 

reg [11:0]		r_precharge_lat_cnt;




assign dfi_aw_ck_p0  = r_dfi_aw_ck_p0;
assign dfi_aw_cke_p0 = r_dfi_aw_cke_p0;
assign dfi_aw_ck_p1  = r_dfi_aw_ck_p1;
assign dfi_aw_cke_p1 = r_dfi_aw_cke_p1;

assign dfi_init_start =r_dfi_init_start;
assign w_precharge_lat_done = (r_precharge_lat_cnt >= P_DRIVE_PRECHARGE_CMD) ? 1'b1 : 1'b0;


////////////////////////////////////////////////////////////////////////////////
// Driving init_start signal after APB initialization sequence is complete
////////////////////////////////////////////////////////////////////////////////

always @ (posedge dfi_clk or negedge dfi_rst_n) begin
    if (~dfi_rst_n) begin
        r_dfi_init_start <= 1'b0;
    end else if (dfi_rst_buf_n == 1'b1) begin
        r_dfi_init_start <= 1'b1;
    end
end


////////////////////////////////////////////////////////////////////////////////
// Counter to wait for driving CKE signal
////////////////////////////////////////////////////////////////////////////////
always @ (posedge dfi_clk or negedge dfi_rst_n) begin
    if (~dfi_rst_n) begin
        cke_cnt <= 4'h0;
    end else if (dfi_init_complete == 1'b1 && cke_cnt != 4'hf) begin
        cke_cnt <= cke_cnt + 1'b1;
    end
end

always @ (posedge dfi_clk or negedge dfi_rst_n) begin
    if (~dfi_rst_n) begin
        r_dfi_aw_cke_p0 <= 2'b00;
        r_dfi_aw_cke_p1 <= 2'b00;
        r_dfi_aw_ck_p0  <= 2'b00;
        r_dfi_aw_ck_p1  <= 2'b00;
    end else if (cke_cnt == 4'he) begin
        r_dfi_aw_cke_p0 <= 2'b11;
        r_dfi_aw_cke_p1 <= 2'b11;
        r_dfi_aw_ck_p0  <= 2'b01;
        r_dfi_aw_ck_p1  <= 2'b01;
    end
end


////////////////////////////////////////////////////////////////////////////////
// Counter to count pre-charge latency before issuing MR commands
////////////////////////////////////////////////////////////////////////////////
always @ (posedge dfi_clk or negedge dfi_rst_n) begin
    if (~dfi_rst_n) begin
        r_precharge_lat_cnt <= 12'h000;
        r_precharge_lat_done <= 1'b0; 
    end else
    begin
        r_precharge_lat_done <= w_precharge_lat_done; 
        if (r_phy_tg_ps == LP_IDLE && dfi_init_complete == 1'b1 && r_precharge_lat_cnt != P_DRIVE_PRECHARGE_CMD) begin
            r_precharge_lat_cnt <= r_precharge_lat_cnt + 1'b1;
        end
    end
end


endmodule