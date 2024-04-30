/** Last Level Command Fowarder **/
`timescale 1ps/1ps


module new_ll_command_forwarder # (
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
    parameter       P_DATA_WIDTH     = 256
)(
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
    
    
    /* My Interface */
    output                              ready_to_cmd_m_ps0,
    input [3:0]                         cmd_m_ps0,
    input [P_BA_ADDR_WIDTH-1:0]         bank_address_m_ps0,
    input [P_ROW_ADDR_WIDTH-1:0]        row_address_m_ps0,
    input [P_COL_ADDR_WIDTH-1:0]        column_address_m_ps0,
    input [P_DATA_WIDTH-1:0]            wrt_data_m_ps0,
    
    output                              ready_to_cmd_m_ps1,
    input [3:0]                         cmd_m_ps1,
    input [P_BA_ADDR_WIDTH-1:0]         bank_address_m_ps1,
    input [P_ROW_ADDR_WIDTH-1:0]        row_address_m_ps1,
    input [P_COL_ADDR_WIDTH-1:0]        column_address_m_ps1,
    input [P_DATA_WIDTH-1:0]            wrt_data_m_ps1
    
    
);

localparam WRT_DATA_BUFFER_LEN  = 16; 


/* STATES */
localparam LP_IDLE			    = 4'd0;
localparam LP_MRS			    = 4'd1;
localparam LP_FETCH			    = 4'd2;
localparam LP_CMD_WAIT          = 4'd3;
localparam LP_CMD_WAIT_1        = 4'd4;


/* COL COMMANDS */
localparam LP_COL_NOP		= 4'b1111;
localparam LP_COL_RD		= 4'b0101;
localparam LP_COL_RD_AP		= 4'b1101;
localparam LP_COL_WRT		= 4'b0001;
localparam LP_COL_WRT_AP	= 4'b1001;
localparam LP_COL_MRS		= 4'b0000;


/* ROW COMMANDS */
localparam LP_ROW_NOP		= 3'b111;
localparam LP_ROW_ACT		= 3'b010;
localparam LP_ROW_PRE		= 3'b011;  //WITH R[10] -> L
localparam LP_ROW_PREA		= 3'b011;  // WITH R[10] -> H

localparam LP_GENERAL_NOP   = 4'b1111;

localparam LP_MRS_CMD = 3'b000;
localparam LP_MRS0_A = 4'b0001;
localparam LP_MRS1_A = 4'b0001;
localparam LP_MRS2_A = 4'b0010;
localparam LP_MRS3_A = 4'b0011;
localparam LP_MRS4_A = 4'b0100;
localparam LP_MRS5_A = 4'b0101;
localparam LP_MRS6_A = 4'b0110;
localparam LP_MRS7_A = 4'b0111;

localparam LP_T_WL		= 1;
localparam LP_PAR       = 1'b1;

localparam LP_BA4_0     = 1'b0;      /* Pseudo Channel 0 */
localparam LP_BA4_1     = 1'b1;      /* Pseudo Channel 1 */


/* HBM LATENCIES */

/* SAME BANK  */
localparam  tRCD    =      32'd11;     /* Sicuro */
localparam  tRP     =      32'd0;
localparam  tRC     =      32'd0;
localparam  tRAS    =      32'd0;
localparam  tWL     =      32'd2;      /* Sicuro */      
localparam  tRL     =      32'd0;
localparam  tRTPl   =      32'd0;
localparam  tWR     =      32'd0;
localparam  tCCDl   =      32'd1;      /* Sicuro */ 
localparam  tRTW    =      32'd0;
localparam  tWTRl   =      32'd8;      /* Sicuro */


/* DIFFERENT BANKS */
localparam  tRTPs   =      32'd0;
localparam  tRRD    =      32'd0;
localparam  tFAW    =      32'd0;
localparam  tWTRs   =      32'd5;
localparam  tCCDs   =      32'd0;



wire w_mrs_lat_cnt_done;
wire w_precharge_lat_done;
wire [2:0]				w_T_WL_MRS2;
wire [4:0]				w_T_RL_MRS2;
wire w_fsm_rst_b;

reg r_dfi_init_start;

reg  [1:0]		r_dfi_aw_ck_p0;
reg  [1:0]      r_dfi_aw_cke_p0;
reg  [1:0]      r_dfi_aw_ck_p1;
reg  [1:0]      r_dfi_aw_cke_p1;
reg  [3:0]   	cke_cnt; 

reg  [11:0]		r_precharge_lat_cnt;
reg				r_precharge_lat_done; 
reg  [3:0]   	r_phy_tg_ps;
reg	 [3:0]	    r_phy_tg_ns;


reg				r_fsm_rst_b;
reg				r_mrs_lat_cnt_done;
reg				r_state_counter_done;
reg	 [7:0]	    r_state_counter;
reg				r_state_chg;
reg	 [11:0]		r_activate_lat_cnt;
reg  [7:0]		r_mrs_reg_cnt;


reg		[11:0]	r_row_cmd_p0;
reg		[11:0]	r_row_cmd_p1;
reg		[15:0]	r_col_cmd_p0;
reg		[15:0]	r_col_cmd_p1;


/* My Registers */
reg              r_ready_to_cmd_m_ps0;
reg              r_ready_to_cmd_m_ps1;


reg     [63:0]   previous_to_actual_cnt_ps0;    /* Contatore per tenere traccia di quanto tempo è passato dal comando precedente, così da vedere se è possibile lanciare il nuovo comando */
reg     [63:0]   previous_to_actual_cnt_ps1; 


reg              can_serve_actual_cmd_ps0;
reg              can_serve_actual_cmd_ps1;



assign ready_to_cmd_m_ps0 = r_ready_to_cmd_m_ps0;
assign ready_to_cmd_m_ps1 = r_ready_to_cmd_m_ps1;


assign dfi_aw_ck_p0  = r_dfi_aw_ck_p0;
assign dfi_aw_cke_p0 = r_dfi_aw_cke_p0;
assign dfi_aw_ck_p1  = r_dfi_aw_ck_p1;
assign dfi_aw_cke_p1 = r_dfi_aw_cke_p1;

assign dfi_init_start = r_dfi_init_start;
assign w_precharge_lat_done = (r_precharge_lat_cnt >= P_DRIVE_PRECHARGE_CMD) ? 1'b1 : 1'b0;

assign dfi_aw_col_p0    =  r_col_cmd_p0;
assign dfi_aw_col_p1	=  r_col_cmd_p1;
assign dfi_aw_row_p0    =  r_row_cmd_p0;
assign dfi_aw_row_p1    =  r_row_cmd_p1;


reg [P_DATA_WIDTH-1 : 0] wrt_data_ps0;
reg [P_DATA_WIDTH-1 : 0] wrt_data_ps1;

/* Il pattern dei dati va visto con più attenzione */
assign dfi_dw_wrdata_p0[63:0]      =  wrt_data_ps0[63:0];
assign dfi_dw_wrdata_p0[127:64]    =  wrt_data_ps1[63:0];
assign dfi_dw_wrdata_p0[191:128]   =  wrt_data_ps0[127:64];
assign dfi_dw_wrdata_p0[255:192]   =  wrt_data_ps1[127:64];

assign dfi_dw_wrdata_p1[63:0]      =  wrt_data_ps0[191:128];
assign dfi_dw_wrdata_p1[127:64]    =  wrt_data_ps1[191:128];
assign dfi_dw_wrdata_p1[191:128]   =  wrt_data_ps0[255:192];
assign dfi_dw_wrdata_p1[255:192]   =  wrt_data_ps1[255:192];

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

////////////////////////////////////////////////////////////////////////////////
// Counter to count activate latency before issuing activate command
////////////////////////////////////////////////////////////////////////////////
always @ (posedge dfi_clk or negedge dfi_rst_n) begin
  if (~dfi_rst_n) begin
    r_activate_lat_cnt <= 12'h000;
	r_mrs_lat_cnt_done	<= 1'b0; 
  end else
  begin
	r_mrs_lat_cnt_done	<= w_mrs_lat_cnt_done; 
  if (r_phy_tg_ps == LP_MRS && ( r_mrs_reg_cnt == P_MRS_CNT) && r_activate_lat_cnt != P_DRIVE_ACT_CMD) begin
    r_activate_lat_cnt <= r_activate_lat_cnt + 1'b1;
  end
  end
end

assign w_mrs_lat_cnt_done = (r_activate_lat_cnt >= P_DRIVE_ACT_CMD) ? 1'b1 : 0;
///////////////////////////////////////////////////////////////////////////////
// Counter to count the MR commands sent
////////////////////////////////////////////////////////////////////////////////
always @ (posedge dfi_clk or negedge dfi_rst_n) begin
  if (~dfi_rst_n) begin
    r_mrs_reg_cnt <= 8'h00;
  end else if ((r_phy_tg_ps == LP_MRS) && (r_mrs_reg_cnt != P_MRS_CNT)) begin
    r_mrs_reg_cnt <= r_mrs_reg_cnt + 1'b1;
  end
end


assign w_fsm_rst_b = r_precharge_lat_done && dfi_init_complete;

//rst_b pulse generation for PRBS SEED LOAD
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 )
    begin
        r_fsm_rst_b	 <= 1'b0;
    end
    else
    begin
        r_fsm_rst_b	 <= w_fsm_rst_b;
    end
end



// STATE COUNTER
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 )
    begin
        r_state_counter	<= 8'd0;
        r_state_chg		<= 1'b1;
        r_state_counter_done <= 1'b0;
    end
    else
    begin
        if( r_phy_tg_ps != r_phy_tg_ns )
        begin
            r_state_counter		 <= 8'd0;
            r_state_chg			 <= 1'b1;
            r_state_counter_done <= 1'b0;
        end
        else
        begin
            r_state_chg		<= 1'b0;
            case( r_phy_tg_ps )
                LP_IDLE:
                begin
                    r_state_counter	<= 8'd0;
                    r_state_counter_done <= 1'b0;
                end
                LP_MRS:
                begin
                    r_state_counter	<= 8'd0;
                    r_state_counter_done <= 1'b0;
                end
                LP_FETCH:
                begin
                    if( r_state_counter <= 8'd200)
                    begin
                        r_state_counter	<= r_state_counter + 8'd1;
                        r_state_counter_done <= 1'b0;
                    end
                    else
                    begin
                        r_state_counter_done <= 1'b1;
                        r_state_counter	<= r_state_counter;
                    end
                end
                
                default:
                begin
                    r_state_counter_done	<= 1'b0;
                    r_state_counter			<= 8'd0;
                end
            endcase
        end
    end
end

////////////////////////////////////////////////////////////////////////////////
// STATE ASSIGN
////////////////////////////////////////////////////////////////////////////////
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 )
    begin
        r_phy_tg_ps	<= LP_IDLE;
    end
    else
    begin
        r_phy_tg_ps	<= r_phy_tg_ns;
    end
end


// STATE TRAN
always @ ( * )
begin
    case( r_phy_tg_ps )
        LP_IDLE:
        begin
            if( r_fsm_rst_b == 1'b0  )
            begin
                r_phy_tg_ns	= LP_IDLE;
            end
            else
            begin
                    r_phy_tg_ns = LP_MRS;
            end
        end
        LP_MRS: 
        begin
            if( r_fsm_rst_b == 1'b0 )
            begin
                r_phy_tg_ns = LP_IDLE;
            end
            else
            begin
                if( r_mrs_lat_cnt_done == 1'b1 )
                begin
                    r_phy_tg_ns = LP_FETCH;
                end
                else
                begin
                    r_phy_tg_ns = LP_MRS;
                end
            end
        end
        
        LP_FETCH:
        begin
            if( r_fsm_rst_b == 1'b0 )
            begin
                r_phy_tg_ns = LP_IDLE;
            end
            else
            begin
                if( r_state_counter_done )
                begin
                    r_phy_tg_ns = LP_CMD_WAIT;
                end
                else
                begin
                    r_phy_tg_ns = LP_FETCH;
                end
            end
        end
       
        /* Fase di inizializzazione completata, qua siamo in attesa di un comando dall'esterno */
        LP_CMD_WAIT:
        begin
            if( r_fsm_rst_b == 1'b0 ) begin
                r_phy_tg_ns = LP_IDLE;
            end
            else if ( cmd_m_ps0 != LP_GENERAL_NOP )  begin  /* c'è un comando in arrivo */
                r_phy_tg_ns <= LP_CMD_WAIT_1;
                
            end
            else begin
                r_phy_tg_ns <= LP_CMD_WAIT;
            end
        end  
        
        LP_CMD_WAIT_1:
        if( r_fsm_rst_b == 1'b0 )begin
                r_phy_tg_ns = LP_IDLE;
        end
        else begin
            r_phy_tg_ns <= LP_CMD_WAIT_1;
        end  
                   
                
        default:
        begin
            r_phy_tg_ns = LP_IDLE;
        end
    endcase
end

// MRS
assign w_T_WL_MRS2 = LP_T_WL + 5;
assign w_T_RL_MRS2 = 5'b1_0010;


/* CODICE EFFETTIVO PER LA GESTIONE DEI COMANDI IN INGRESSO */
/* Da estendere sviluppando comandi sui due PS indipendenti */


/* Driver per gestire il previous to actual (cmd) counter per PS0 */
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        previous_to_actual_cnt_ps0 <= { 64 { 1'b0 } };
    end
    else begin
        if ( can_serve_actual_cmd_ps0 == 1'b1 ) begin
            previous_to_actual_cnt_ps0 <= { 64 { 1'b0 } };
        end
        else begin
            previous_to_actual_cnt_ps0 <= previous_to_actual_cnt_ps0 + 1'b1;
        end
    end
end



/* Driver per gestire il previous to actual (cmd) counter per PS1*/
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        previous_to_actual_cnt_ps1 <= { 64 { 1'b0 } };
    end
    else begin
        if ( can_serve_actual_cmd_ps1 == 1'b1 ) begin
            previous_to_actual_cnt_ps1 <= { 64 { 1'b0 } };
        end
        else begin
            previous_to_actual_cnt_ps1 <= previous_to_actual_cnt_ps1 + 1'b1;
        end
    end
end



/* Driver per gestire il ready to cmd ps0 */
always_comb
begin
    if( dfi_rst_n == 1'b0 ) begin
        r_ready_to_cmd_m_ps0 <= 1'b0;
    end

    else begin
        if ( r_phy_tg_ps == LP_CMD_WAIT  ) begin
            r_ready_to_cmd_m_ps0 <= 1'b1;
        end
        else if ( can_serve_actual_cmd_ps0 && r_phy_tg_ps == LP_CMD_WAIT_1  ) begin
            r_ready_to_cmd_m_ps0 <= 1'b1;
        end
        else begin
            r_ready_to_cmd_m_ps0 <= 1'b0;
        end        
    end
end


/* Driver per gestire il ready to cmd ps1 */
always_comb
begin
    if( dfi_rst_n == 1'b0 ) begin
        r_ready_to_cmd_m_ps1 <= 1'b0;
    end

    else begin
        if ( r_phy_tg_ps == LP_CMD_WAIT  ) begin
            r_ready_to_cmd_m_ps1 <= 1'b1;
        end
        else if ( can_serve_actual_cmd_ps1 && r_phy_tg_ps == LP_CMD_WAIT_1  ) begin
            r_ready_to_cmd_m_ps1 <= 1'b1;
        end
        else begin
            r_ready_to_cmd_m_ps1 <= 1'b0;
        end        
    end
end



reg [3:0]  previous_cmd_ps0;
reg [P_BA_ADDR_WIDTH-1 : 0]  previous_bank_addr_ps0;

reg [3:0]  previous_cmd_ps1;
reg [P_BA_ADDR_WIDTH-1 : 0]  previous_bank_addr_ps1;


/* Driver per salvare il cmd attuale in previous ps0 */
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        previous_cmd_ps0         <=  LP_GENERAL_NOP;
        previous_bank_addr_ps0   <=  { P_BA_ADDR_WIDTH { 1'b0 } };
    end

    else begin
        if ( can_serve_actual_cmd_ps0 && cmd_m_ps0 != LP_GENERAL_NOP ) begin
            previous_cmd_ps0 <= cmd_m_ps0;
            previous_bank_addr_ps0 <= bank_address_m_ps0;
        end
        else begin
            previous_cmd_ps0 <= previous_cmd_ps0;
            previous_bank_addr_ps0 <= previous_bank_addr_ps0;
        end        
    end
end

/* Driver per salvare il cmd attuale in previous ps1 */
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        previous_cmd_ps1         <=  LP_GENERAL_NOP;
        previous_bank_addr_ps1   <=  { P_BA_ADDR_WIDTH { 1'b0 } };
    end

    else begin
        if ( can_serve_actual_cmd_ps1 && cmd_m_ps1 != LP_GENERAL_NOP ) begin
            previous_cmd_ps1 <= cmd_m_ps1;
            previous_bank_addr_ps1 <= bank_address_m_ps1;
        end
        else begin
            previous_cmd_ps1 <= previous_cmd_ps1;
            previous_bank_addr_ps1 <= previous_bank_addr_ps1;
        end        
    end
end



/*******************************/
//                             //
//      WRDATA QUEUE PS0       //
//                             //
/*******************************/

/* Coda buffer per i write data PS0 */
reg [P_DATA_WIDTH - 1 : 0 ]       wrt_data_buffer_ps0         [ 0 : WRT_DATA_BUFFER_LEN-1 ];                               
reg [3:0]                         wrt_data_buffer_head_ps0;
reg [3:0]                         wrt_data_buffer_tail_ps0; 
reg [4:0]                         wrt_data_buffer_cnt_ps0; 

reg [3:0] wrt_to_data_cnt_ps0 [ 0 : WRT_DATA_BUFFER_LEN-1 ];


wire                              incr_wrt_data_buffer_cnt_ps0;
wire                              deincr_wrt_data_buffer_cnt_ps0;

wire                              rst_wrt_to_data_cnt_ps0;


assign     incr_wrt_data_buffer_cnt_ps0 = can_serve_actual_cmd_ps0 && (cmd_m_ps0 == LP_COL_WRT);
assign     deincr_wrt_data_buffer_cnt_ps0 = (wrt_data_buffer_cnt_ps0 > 0) && (wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] >= tWL);



/* Driver per gestire  write data buffer counter */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        wrt_data_buffer_cnt_ps0  <= 5'b00000;
    end 
    else begin
        if ( incr_wrt_data_buffer_cnt_ps0 && ~deincr_wrt_data_buffer_cnt_ps0 ) begin
            wrt_data_buffer_cnt_ps0 <= wrt_data_buffer_cnt_ps0 + 1'b1;
        
        end 
        else if ( ~incr_wrt_data_buffer_cnt_ps0 && deincr_wrt_data_buffer_cnt_ps0 ) begin
            wrt_data_buffer_cnt_ps0 <= wrt_data_buffer_cnt_ps0 - 1'b1;
        end
        else if ( incr_wrt_data_buffer_cnt_ps0 && deincr_wrt_data_buffer_cnt_ps0 ) begin
            wrt_data_buffer_cnt_ps0 <= wrt_data_buffer_cnt_ps0;
        end
    end 
end

assign rst_wrt_to_data_cnt_ps0 = can_serve_actual_cmd_ps0 && (cmd_m_ps0 == LP_COL_WRT) &&  (wrt_data_buffer_cnt_ps0 < WRT_DATA_BUFFER_LEN);

always @ ( posedge dfi_clk or negedge dfi_rst_n ) 
begin
    if( dfi_rst_n == 1'b0 ) begin
        wrt_to_data_cnt_ps0[0]  <= 4'b0000;
        wrt_to_data_cnt_ps0[1]  <= 4'b0000;
        wrt_to_data_cnt_ps0[2]  <= 4'b0000;
        wrt_to_data_cnt_ps0[3]  <= 4'b0000;
        wrt_to_data_cnt_ps0[4]  <= 4'b0000;
        wrt_to_data_cnt_ps0[5]  <= 4'b0000;
        wrt_to_data_cnt_ps0[6]  <= 4'b0000;
        wrt_to_data_cnt_ps0[7]  <= 4'b0000;
        wrt_to_data_cnt_ps0[8]  <= 4'b0000;
        wrt_to_data_cnt_ps0[9]  <= 4'b0000;
        wrt_to_data_cnt_ps0[10] <= 4'b0000;
        wrt_to_data_cnt_ps0[11] <= 4'b0000;
        wrt_to_data_cnt_ps0[12] <= 4'b0000;
        wrt_to_data_cnt_ps0[13] <= 4'b0000;
        wrt_to_data_cnt_ps0[14] <= 4'b0000;
        wrt_to_data_cnt_ps0[15] <= 4'b0000;
    end
    else begin
        if (rst_wrt_to_data_cnt_ps0)  begin
            wrt_to_data_cnt_ps0[0]  <= wrt_to_data_cnt_ps0[0]  + 1'b1;
            wrt_to_data_cnt_ps0[1]  <= wrt_to_data_cnt_ps0[1]  + 1'b1;
            wrt_to_data_cnt_ps0[2]  <= wrt_to_data_cnt_ps0[2]  + 1'b1;
            wrt_to_data_cnt_ps0[3]  <= wrt_to_data_cnt_ps0[3]  + 1'b1;
            wrt_to_data_cnt_ps0[4]  <= wrt_to_data_cnt_ps0[4]  + 1'b1;
            wrt_to_data_cnt_ps0[5]  <= wrt_to_data_cnt_ps0[5]  + 1'b1;
            wrt_to_data_cnt_ps0[6]  <= wrt_to_data_cnt_ps0[6]  + 1'b1;
            wrt_to_data_cnt_ps0[7]  <= wrt_to_data_cnt_ps0[7]  + 1'b1;
            wrt_to_data_cnt_ps0[8]  <= wrt_to_data_cnt_ps0[8]  + 1'b1;
            wrt_to_data_cnt_ps0[9]  <= wrt_to_data_cnt_ps0[9]  + 1'b1;
            wrt_to_data_cnt_ps0[10] <= wrt_to_data_cnt_ps0[10] + 1'b1;
            wrt_to_data_cnt_ps0[11] <= wrt_to_data_cnt_ps0[11] + 1'b1;
            wrt_to_data_cnt_ps0[12] <= wrt_to_data_cnt_ps0[12] + 1'b1;
            wrt_to_data_cnt_ps0[13] <= wrt_to_data_cnt_ps0[13] + 1'b1;
            wrt_to_data_cnt_ps0[14] <= wrt_to_data_cnt_ps0[14] + 1'b1;
            wrt_to_data_cnt_ps0[15] <= wrt_to_data_cnt_ps0[15] + 1'b1;
            wrt_to_data_cnt_ps0[wrt_data_buffer_head_ps0] <= 4'b0000;
        end
        else begin
            wrt_to_data_cnt_ps0[0]  <= wrt_to_data_cnt_ps0[0]  + 1'b1;
            wrt_to_data_cnt_ps0[1]  <= wrt_to_data_cnt_ps0[1]  + 1'b1;
            wrt_to_data_cnt_ps0[2]  <= wrt_to_data_cnt_ps0[2]  + 1'b1;
            wrt_to_data_cnt_ps0[3]  <= wrt_to_data_cnt_ps0[3]  + 1'b1;
            wrt_to_data_cnt_ps0[4]  <= wrt_to_data_cnt_ps0[4]  + 1'b1;
            wrt_to_data_cnt_ps0[5]  <= wrt_to_data_cnt_ps0[5]  + 1'b1;
            wrt_to_data_cnt_ps0[6]  <= wrt_to_data_cnt_ps0[6]  + 1'b1;
            wrt_to_data_cnt_ps0[7]  <= wrt_to_data_cnt_ps0[7]  + 1'b1;
            wrt_to_data_cnt_ps0[8]  <= wrt_to_data_cnt_ps0[8]  + 1'b1;
            wrt_to_data_cnt_ps0[9]  <= wrt_to_data_cnt_ps0[9]  + 1'b1;
            wrt_to_data_cnt_ps0[10] <= wrt_to_data_cnt_ps0[10] + 1'b1;
            wrt_to_data_cnt_ps0[11] <= wrt_to_data_cnt_ps0[11] + 1'b1;
            wrt_to_data_cnt_ps0[12] <= wrt_to_data_cnt_ps0[12] + 1'b1;
            wrt_to_data_cnt_ps0[13] <= wrt_to_data_cnt_ps0[13] + 1'b1;
            wrt_to_data_cnt_ps0[14] <= wrt_to_data_cnt_ps0[14] + 1'b1;
            wrt_to_data_cnt_ps0[15] <= wrt_to_data_cnt_ps0[15] + 1'b1;
        end
    end
end



/* Driver per salvare i dati da scrivere nel buffer */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) 
begin
    if( dfi_rst_n == 1'b0 ) begin        
        wrt_data_buffer_head_ps0 <= 4'b0000;
    end
    
    else begin
        if ( can_serve_actual_cmd_ps0 && cmd_m_ps0 == LP_COL_WRT ) begin      
           if ( wrt_data_buffer_cnt_ps0 < WRT_DATA_BUFFER_LEN ) begin      /* Se non ho spazio in coda perdo i dati, non capita se le code fuori e dentro sono della stessa dimensione */
           
                wrt_data_buffer_ps0[wrt_data_buffer_head_ps0] <= wrt_data_m_ps0;   
                wrt_data_buffer_head_ps0 <= wrt_data_buffer_head_ps0 + 1'b1;
                
                                
                
            end 
            
        end
    end
end

/* Driver per salvare i dati da scrivere nel buffer PS0 */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) 
begin
    if( dfi_rst_n == 1'b0 ) begin
        
        wrt_data_ps0         <=  { P_DATA_WIDTH { 1'b0 } };
        
        wrt_data_buffer_tail_ps0 <= 4'b0000;
          
    end
    
    else begin
        if ( wrt_data_buffer_cnt_ps0 > 0 ) begin
            if ( wrt_to_data_cnt_ps0[wrt_data_buffer_tail_ps0] >= tWL ) begin
                wrt_data_ps0   <=  wrt_data_buffer_ps0 [wrt_data_buffer_tail_ps0];
              
                wrt_data_buffer_tail_ps0 <= wrt_data_buffer_tail_ps0 + 1'b1;
            end
        end
    end
end



/*******************************/
//                             //
//      WRDATA QUEUE PS1       //
//                             //
/*******************************/

/* Coda buffer per i write data PS1 */
reg [P_DATA_WIDTH - 1 : 0 ]       wrt_data_buffer_ps1         [ 0 : WRT_DATA_BUFFER_LEN-1 ];                               
reg [3:0]                         wrt_data_buffer_head_ps1;
reg [3:0]                         wrt_data_buffer_tail_ps1; 
reg [4:0]                         wrt_data_buffer_cnt_ps1; 

reg [3:0] wrt_to_data_cnt_ps1 [ 0 : WRT_DATA_BUFFER_LEN-1 ];


wire                              incr_wrt_data_buffer_cnt_ps1;
wire                              deincr_wrt_data_buffer_cnt_ps1;

wire                              rst_wrt_to_data_cnt_ps1;


assign     incr_wrt_data_buffer_cnt_ps1 = can_serve_actual_cmd_ps1 && (cmd_m_ps1 == LP_COL_WRT);
assign     deincr_wrt_data_buffer_cnt_ps1 = (wrt_data_buffer_cnt_ps1 > 0) && (wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] >= tWL);



/* Driver per gestire  write data buffer counter */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) begin
    if ( dfi_rst_n == 1'b0 ) begin
        wrt_data_buffer_cnt_ps1  <= 5'b00000;
    end 
    else begin
        if ( incr_wrt_data_buffer_cnt_ps1 && ~deincr_wrt_data_buffer_cnt_ps1 ) begin
            wrt_data_buffer_cnt_ps1 <= wrt_data_buffer_cnt_ps1 + 1'b1;
        
        end 
        else if ( ~incr_wrt_data_buffer_cnt_ps1 && deincr_wrt_data_buffer_cnt_ps1 ) begin
            wrt_data_buffer_cnt_ps1 <= wrt_data_buffer_cnt_ps1 - 1'b1;
        end
        else if ( incr_wrt_data_buffer_cnt_ps1 && deincr_wrt_data_buffer_cnt_ps1 ) begin
            wrt_data_buffer_cnt_ps1 <= wrt_data_buffer_cnt_ps1;
        end
    end 
end

assign rst_wrt_to_data_cnt_ps1 = can_serve_actual_cmd_ps1 && (cmd_m_ps1 == LP_COL_WRT) &&  (wrt_data_buffer_cnt_ps1 < WRT_DATA_BUFFER_LEN);

always @ ( posedge dfi_clk or negedge dfi_rst_n ) 
begin
    if( dfi_rst_n == 1'b0 ) begin
        wrt_to_data_cnt_ps1[0]  <= 4'b0000;
        wrt_to_data_cnt_ps1[1]  <= 4'b0000;
        wrt_to_data_cnt_ps1[2]  <= 4'b0000;
        wrt_to_data_cnt_ps1[3]  <= 4'b0000;
        wrt_to_data_cnt_ps1[4]  <= 4'b0000;
        wrt_to_data_cnt_ps1[5]  <= 4'b0000;
        wrt_to_data_cnt_ps1[6]  <= 4'b0000;
        wrt_to_data_cnt_ps1[7]  <= 4'b0000;
        wrt_to_data_cnt_ps1[8]  <= 4'b0000;
        wrt_to_data_cnt_ps1[9]  <= 4'b0000;
        wrt_to_data_cnt_ps1[10] <= 4'b0000;
        wrt_to_data_cnt_ps1[11] <= 4'b0000;
        wrt_to_data_cnt_ps1[12] <= 4'b0000;
        wrt_to_data_cnt_ps1[13] <= 4'b0000;
        wrt_to_data_cnt_ps1[14] <= 4'b0000;
        wrt_to_data_cnt_ps1[15] <= 4'b0000;
    end
    else begin
        if (rst_wrt_to_data_cnt_ps1)  begin
            wrt_to_data_cnt_ps1[0]  <= wrt_to_data_cnt_ps1[0]  + 1'b1;
            wrt_to_data_cnt_ps1[1]  <= wrt_to_data_cnt_ps1[1]  + 1'b1;
            wrt_to_data_cnt_ps1[2]  <= wrt_to_data_cnt_ps1[2]  + 1'b1;
            wrt_to_data_cnt_ps1[3]  <= wrt_to_data_cnt_ps1[3]  + 1'b1;
            wrt_to_data_cnt_ps1[4]  <= wrt_to_data_cnt_ps1[4]  + 1'b1;
            wrt_to_data_cnt_ps1[5]  <= wrt_to_data_cnt_ps1[5]  + 1'b1;
            wrt_to_data_cnt_ps1[6]  <= wrt_to_data_cnt_ps1[6]  + 1'b1;
            wrt_to_data_cnt_ps1[7]  <= wrt_to_data_cnt_ps1[7]  + 1'b1;
            wrt_to_data_cnt_ps1[8]  <= wrt_to_data_cnt_ps1[8]  + 1'b1;
            wrt_to_data_cnt_ps1[9]  <= wrt_to_data_cnt_ps1[9]  + 1'b1;
            wrt_to_data_cnt_ps1[10] <= wrt_to_data_cnt_ps1[10] + 1'b1;
            wrt_to_data_cnt_ps1[11] <= wrt_to_data_cnt_ps1[11] + 1'b1;
            wrt_to_data_cnt_ps1[12] <= wrt_to_data_cnt_ps1[12] + 1'b1;
            wrt_to_data_cnt_ps1[13] <= wrt_to_data_cnt_ps1[13] + 1'b1;
            wrt_to_data_cnt_ps1[14] <= wrt_to_data_cnt_ps1[14] + 1'b1;
            wrt_to_data_cnt_ps1[15] <= wrt_to_data_cnt_ps1[15] + 1'b1;
            wrt_to_data_cnt_ps1[wrt_data_buffer_head_ps1] <= 4'b0000;
        end
        else begin
            wrt_to_data_cnt_ps1[0]  <= wrt_to_data_cnt_ps1[0]  + 1'b1;
            wrt_to_data_cnt_ps1[1]  <= wrt_to_data_cnt_ps1[1]  + 1'b1;
            wrt_to_data_cnt_ps1[2]  <= wrt_to_data_cnt_ps1[2]  + 1'b1;
            wrt_to_data_cnt_ps1[3]  <= wrt_to_data_cnt_ps1[3]  + 1'b1;
            wrt_to_data_cnt_ps1[4]  <= wrt_to_data_cnt_ps1[4]  + 1'b1;
            wrt_to_data_cnt_ps1[5]  <= wrt_to_data_cnt_ps1[5]  + 1'b1;
            wrt_to_data_cnt_ps1[6]  <= wrt_to_data_cnt_ps1[6]  + 1'b1;
            wrt_to_data_cnt_ps1[7]  <= wrt_to_data_cnt_ps1[7]  + 1'b1;
            wrt_to_data_cnt_ps1[8]  <= wrt_to_data_cnt_ps1[8]  + 1'b1;
            wrt_to_data_cnt_ps1[9]  <= wrt_to_data_cnt_ps1[9]  + 1'b1;
            wrt_to_data_cnt_ps1[10] <= wrt_to_data_cnt_ps1[10] + 1'b1;
            wrt_to_data_cnt_ps1[11] <= wrt_to_data_cnt_ps1[11] + 1'b1;
            wrt_to_data_cnt_ps1[12] <= wrt_to_data_cnt_ps1[12] + 1'b1;
            wrt_to_data_cnt_ps1[13] <= wrt_to_data_cnt_ps1[13] + 1'b1;
            wrt_to_data_cnt_ps1[14] <= wrt_to_data_cnt_ps1[14] + 1'b1;
            wrt_to_data_cnt_ps1[15] <= wrt_to_data_cnt_ps1[15] + 1'b1;
        end
    end
end



/* Driver per salvare i dati da scrivere nel buffer */
always @ ( posedge dfi_clk or negedge dfi_rst_n ) 
begin
    if( dfi_rst_n == 1'b0 ) begin        
        wrt_data_buffer_head_ps1 <= 4'b0000;
    end
    
    else begin
        if ( can_serve_actual_cmd_ps1 && cmd_m_ps1 == LP_COL_WRT ) begin      
           if ( wrt_data_buffer_cnt_ps1 < WRT_DATA_BUFFER_LEN ) begin      /* Se non ho spazio in coda perdo i dati, non capita se le code fuori e dentro sono della stessa dimensione */
                wrt_data_buffer_ps1[wrt_data_buffer_head_ps1] <= wrt_data_m_ps1;   
                wrt_data_buffer_head_ps1 <= wrt_data_buffer_head_ps1 + 1'b1;    
            end 
        end
    end
end

always @ ( posedge dfi_clk or negedge dfi_rst_n ) 
begin
    if( dfi_rst_n == 1'b0 ) begin
        wrt_data_ps1         <=  { P_DATA_WIDTH { 1'b0 } };
        wrt_data_buffer_tail_ps1 <= 4'b0000;      
    end
    else begin
        if ( wrt_data_buffer_cnt_ps1 > 0 ) begin
            if ( wrt_to_data_cnt_ps1[wrt_data_buffer_tail_ps1] >= tWL ) begin
                wrt_data_ps1   <=  wrt_data_buffer_ps1 [wrt_data_buffer_tail_ps1];
                wrt_data_buffer_tail_ps1 <= wrt_data_buffer_tail_ps1 + 1'b1;
            end
        end
    end
end






/******************************/
//                            //
//          COMMANDS          //
//                            //
/******************************/


/* Driver per eseguire effettivamente il comando attuale */
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        r_row_cmd_p0    <= 12'hfff;
        r_row_cmd_p1    <= 12'hfff;
        r_col_cmd_p0    <= 16'hffff;
        r_col_cmd_p1    <= 16'hffff;
        
    end
    
    else if( r_phy_tg_ps == LP_MRS )
        begin
          case (r_mrs_reg_cnt)
            8'h00: begin
              r_col_cmd_p0 <= 16'h0000; //MR-0
              r_col_cmd_p1 <= 16'hffff;
            end
         8'h10: begin
              r_col_cmd_p0 <= 16'hffff;
              //r_col_cmd_p1 <= 16'hea10; //MR-1
              r_col_cmd_p1 <= 16'ha010; //MR-1
            end
         8'h20: begin
              //r_col_cmd_p0 <= 16'h2e28; //w_T_WL_MRS2 MR-2
              r_col_cmd_p0 <= {w_T_RL_MRS2[3:0], w_T_WL_MRS2[2], LP_PAR, w_T_WL_MRS2[1:0], LP_MRS2_A, w_T_RL_MRS2[4],LP_MRS_CMD}; //MR-2
              r_col_cmd_p1 <= 16'hffff;
            end
         8'h30: begin
              r_col_cmd_p0 <= 16'hffff;
              //r_col_cmd_p1 <= 16'h4138; //MR-3
              r_col_cmd_p1 <= 16'hc138; //MR-3
            end
         8'h40: begin
              //r_col_cmd_p0 <= 16'h1c40; //MR-4
              r_col_cmd_p0 <= 16'h0440; //MR-4
              r_col_cmd_p1 <= 16'hffff;
            end
         8'h50: begin
              r_col_cmd_p0 <= 16'hffff;
              r_col_cmd_p1 <= 16'h0050; //MR-5
            end
         8'h60: begin
              r_col_cmd_p0 <= 16'hc060; //MR-6
              r_col_cmd_p1 <= 16'hffff;
            end
         8'h70: begin
              r_col_cmd_p0 <= 16'hffff;
              r_col_cmd_p1 <= 16'h0270; //MR-7
            end
         8'h80: begin
              r_col_cmd_p0 <= 16'h00f0;
              r_col_cmd_p1 <= 16'hffff; //MR-7
            end
            default : begin
              r_col_cmd_p0 <= 16'hffff;
              r_col_cmd_p1 <= 16'hffff;
            end
       endcase
    end

    else begin
        if ( (can_serve_actual_cmd_ps0 && cmd_m_ps0 != LP_GENERAL_NOP) || (can_serve_actual_cmd_ps1 && cmd_m_ps1 != LP_GENERAL_NOP) ) begin    /* Sono pronto a ricevere un comando e questo che ricevo è valido */
            if ( (cmd_m_ps0 == LP_ROW_PRE && can_serve_actual_cmd_ps0) && (cmd_m_ps1 == LP_GENERAL_NOP || ~can_serve_actual_cmd_ps1 )) begin
                r_row_cmd_p0		<= { bank_address_m_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_m_ps0[2:0], LP_ROW_PRE};
                r_row_cmd_p1		<= 12'hfff;
                r_col_cmd_p0        <= 16'hffff;
                r_col_cmd_p1        <= 16'hffff;
            end 
                        
            else if ( (cmd_m_ps0 == LP_GENERAL_NOP || ~can_serve_actual_cmd_ps0)&& (cmd_m_ps1 == LP_ROW_PRE && can_serve_actual_cmd_ps1) ) begin                
                r_row_cmd_p0        <= 12'hfff;
                r_row_cmd_p1		<= { bank_address_m_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, bank_address_m_ps1[2:0], LP_ROW_PRE};
                r_col_cmd_p0        <= 16'hffff;
                r_col_cmd_p1        <= 16'hffff;
            end
            
            else if ( cmd_m_ps0 == LP_ROW_PRE && cmd_m_ps1 == LP_ROW_PRE && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1) begin
                r_row_cmd_p0		<= { bank_address_m_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_m_ps0[2:0], LP_ROW_PRE};
                r_row_cmd_p1		<= { bank_address_m_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, bank_address_m_ps1[2:0], LP_ROW_PRE};
                r_col_cmd_p0        <= 16'hffff;
                r_col_cmd_p1        <= 16'hffff;
            end
            
            else if ( cmd_m_ps0 == LP_ROW_PRE && cmd_m_ps1 == LP_COL_WRT && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1) begin
                r_row_cmd_p0		<= { bank_address_m_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_m_ps0[2:0], LP_ROW_PRE};
                r_row_cmd_p1		<= 12'hfff;
                r_col_cmd_p0        <= { LP_BA4_1, column_address_m_ps1[5:2], LP_PAR, column_address_m_ps1[1], 1'b0, bank_address_m_ps1[3:0], LP_COL_WRT[3:0]}; 
                r_col_cmd_p1        <= 16'hffff;
            end
            
            else if ( cmd_m_ps0 == LP_ROW_PRE && cmd_m_ps1 == LP_COL_RD && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1) begin
                r_row_cmd_p0		<= { bank_address_m_ps0[3] , 1'b0, LP_BA4_0, LP_PAR, 2'b00, bank_address_m_ps0[2:0], LP_ROW_PRE};
                r_row_cmd_p1		<= 12'hfff;
                r_col_cmd_p0        <= { LP_BA4_1, column_address_m_ps1[5:2], LP_PAR, column_address_m_ps1[1], 1'b0, bank_address_m_ps1[3:0], LP_COL_RD};
                r_col_cmd_p1        <= 16'hffff;    
                
            end
            
            else if ( (cmd_m_ps0 == LP_COL_WRT && can_serve_actual_cmd_ps0) && (cmd_m_ps1 == LP_GENERAL_NOP || ~can_serve_actual_cmd_ps1)) begin
                r_row_cmd_p0     <= 12'hfff;
                r_row_cmd_p1     <= 12'hfff;
                r_col_cmd_p0	 <= { LP_BA4_0, column_address_m_ps0[5:2], LP_PAR, column_address_m_ps0[1], 1'b0, bank_address_m_ps0[3:0], LP_COL_WRT[3:0]};                
                r_col_cmd_p1	 <= 16'hffff;
				
            end
            
            else if ( cmd_m_ps0 == LP_COL_WRT && cmd_m_ps1 == LP_ROW_PRE && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1) begin
                r_row_cmd_p0     <= { bank_address_m_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, bank_address_m_ps1[2:0], LP_ROW_PRE};
                r_row_cmd_p1     <= 12'hfff;
                r_col_cmd_p0	 <= { LP_BA4_0, column_address_m_ps0[5:2], LP_PAR, column_address_m_ps0[1], 1'b0, bank_address_m_ps0[3:0], LP_COL_WRT[3:0]};                
                r_col_cmd_p1	 <= 16'hffff;
            end
            
            else if ( cmd_m_ps0 == LP_COL_WRT && cmd_m_ps1 == LP_COL_WRT && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1) begin
                r_row_cmd_p0     <= 12'hfff;
                r_row_cmd_p1     <= 12'hfff;
                r_col_cmd_p0	 <= { LP_BA4_0, column_address_m_ps0[5:2], LP_PAR, column_address_m_ps0[1], 1'b0, bank_address_m_ps0[3:0], LP_COL_WRT[3:0]};                
                r_col_cmd_p1	 <= { LP_BA4_1, column_address_m_ps1[5:2], LP_PAR, column_address_m_ps1[1], 1'b0, bank_address_m_ps1[3:0], LP_COL_WRT[3:0]};
            end
            
            else if ( cmd_m_ps0 == LP_COL_WRT && cmd_m_ps1 == LP_COL_RD && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1) begin
                r_row_cmd_p0     <= 12'hfff;
                r_row_cmd_p1     <= 12'hfff;
                r_col_cmd_p0	 <= { LP_BA4_0, column_address_m_ps0[5:2], LP_PAR, column_address_m_ps0[1], 1'b0, bank_address_m_ps0[3:0], LP_COL_WRT[3:0]};                
                r_col_cmd_p1	 <= { LP_BA4_1, column_address_m_ps1[5:2], LP_PAR, column_address_m_ps1[1], 1'b0, bank_address_m_ps1[3:0], LP_COL_RD};
            end
            
            else if ( (cmd_m_ps0 == LP_COL_RD && can_serve_actual_cmd_ps0)  && (cmd_m_ps1 == LP_GENERAL_NOP && ~can_serve_actual_cmd_ps1 ))  begin 
                r_row_cmd_p0     <= 12'hfff;
                r_row_cmd_p1     <= 12'hfff;               
                r_col_cmd_p0	 <= { LP_BA4_0, column_address_m_ps0[5:2], LP_PAR, column_address_m_ps0[1], 1'b0, bank_address_m_ps0[3:0], LP_COL_RD};
                r_col_cmd_p1	 <= 16'hffff;          
            end
            
            else if ( cmd_m_ps0 == LP_COL_RD && cmd_m_ps1 == LP_ROW_PRE && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1 )  begin 
                r_row_cmd_p0     <= { bank_address_m_ps1[3] , 1'b0, LP_BA4_1, LP_PAR, 2'b00, bank_address_m_ps1[2:0], LP_ROW_PRE};
                r_row_cmd_p1     <= 12'hfff;               
                r_col_cmd_p0	 <= { LP_BA4_0, column_address_m_ps0[5:2], LP_PAR, column_address_m_ps0[1], 1'b0, bank_address_m_ps0[3:0], LP_COL_RD};
                r_col_cmd_p1	 <= 16'hffff;          
            end
            
            else if ( cmd_m_ps0 == LP_COL_RD && cmd_m_ps1 == LP_COL_WRT && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1 )  begin 
                r_row_cmd_p0     <= 12'hfff; 
                r_row_cmd_p1     <= 12'hfff;               
                r_col_cmd_p0	 <= { LP_BA4_0, column_address_m_ps0[5:2], LP_PAR, column_address_m_ps0[1], 1'b0, bank_address_m_ps0[3:0], LP_COL_RD};
                r_col_cmd_p1	 <= { LP_BA4_1, column_address_m_ps1[5:2], LP_PAR, column_address_m_ps1[1], 1'b0, bank_address_m_ps1[3:0], LP_COL_WRT[3:0]};       
            end
            
            
            else if ( cmd_m_ps0 == LP_COL_RD && cmd_m_ps1 == LP_COL_RD && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1)  begin 
                r_row_cmd_p0     <= 12'hfff; 
                r_row_cmd_p1     <= 12'hfff;               
                r_col_cmd_p0	 <= { LP_BA4_0, column_address_m_ps0[5:2], LP_PAR, column_address_m_ps0[1], 1'b0, bank_address_m_ps0[3:0], LP_COL_RD};
                r_col_cmd_p1	 <= { LP_BA4_1, column_address_m_ps1[5:2], LP_PAR, column_address_m_ps1[1], 1'b0, bank_address_m_ps1[3:0], LP_COL_RD};
            end
            
            else if ( (cmd_m_ps0 == LP_GENERAL_NOP || ~can_serve_actual_cmd_ps0) && ( cmd_m_ps1 == LP_COL_WRT && can_serve_actual_cmd_ps1 )) begin
                r_row_cmd_p0     <= 12'hfff; 
                r_row_cmd_p1     <= 12'hfff;               
                r_col_cmd_p0	 <= 16'hffff;
                r_col_cmd_p1	 <= {LP_BA4_1, column_address_m_ps1[5:2], LP_PAR, column_address_m_ps1[1], 1'b0, bank_address_m_ps1[3:0], LP_COL_WRT[3:0]};       
            end
            
            else if ( (cmd_m_ps0 == LP_GENERAL_NOP || ~can_serve_actual_cmd_ps0) && (cmd_m_ps1 == LP_COL_RD && can_serve_actual_cmd_ps1))  begin 
                r_row_cmd_p0     <= 12'hfff; 
                r_row_cmd_p1     <= 12'hfff;               
                r_col_cmd_p0	 <= 16'hffff;
                r_col_cmd_p1	 <= { LP_BA4_1, column_address_m_ps1[5:2], LP_PAR, column_address_m_ps1[1], 1'b0, bank_address_m_ps1[3:0], LP_COL_RD};
            end
            
            else if ( (cmd_m_ps0 == LP_ROW_ACT && can_serve_actual_cmd_ps0) && (cmd_m_ps1 == LP_GENERAL_NOP || ~can_serve_actual_cmd_ps1) ) begin
                r_row_cmd_p0	 <= {bank_address_m_ps0[3], row_address_m_ps0[13], LP_BA4_0, LP_PAR, row_address_m_ps0[12:11], bank_address_m_ps0[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_m_ps0[4:2], LP_PAR, row_address_m_ps0[1:0], row_address_m_ps0[10:5]};
                r_col_cmd_p0     <= 16'hffff;
                r_col_cmd_p1     <= 16'hffff;
            end
            
            else if ( cmd_m_ps0 == LP_ROW_ACT && cmd_m_ps1 == LP_ROW_ACT && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1 ) begin
                r_row_cmd_p0	 <= {bank_address_m_ps0[3], row_address_m_ps0[13], LP_BA4_0, LP_PAR, row_address_m_ps0[12:11], bank_address_m_ps0[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_m_ps0[4:2], LP_PAR, row_address_m_ps0[1:0], row_address_m_ps0[10:5]};
                r_col_cmd_p0     <= 16'hffff;
                r_col_cmd_p1     <= 16'hffff;
            end
            
            else if ( cmd_m_ps0 == LP_ROW_ACT && cmd_m_ps1 == LP_ROW_PRE && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1 ) begin
                r_row_cmd_p0	 <= {bank_address_m_ps0[3], row_address_m_ps0[13], LP_BA4_0, LP_PAR, row_address_m_ps0[12:11], bank_address_m_ps0[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_m_ps0[4:2], LP_PAR, row_address_m_ps0[1:0], row_address_m_ps0[10:5]};
                r_col_cmd_p0     <= 16'hffff;
                r_col_cmd_p1     <= 16'hffff;
            end
            
            else if ( cmd_m_ps0 == LP_ROW_ACT && cmd_m_ps1 == LP_COL_RD && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1 ) begin
                r_row_cmd_p0	 <= {bank_address_m_ps0[3], row_address_m_ps0[13], LP_BA4_0, LP_PAR, row_address_m_ps0[12:11], bank_address_m_ps0[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_m_ps0[4:2], LP_PAR, row_address_m_ps0[1:0], row_address_m_ps0[10:5]};
                r_col_cmd_p0	 <= { LP_BA4_1, column_address_m_ps1[5:2], LP_PAR, column_address_m_ps1[1], 1'b0, bank_address_m_ps1[3:0], LP_COL_RD};
                r_col_cmd_p1     <= 16'hffff;
            end
            
            else if ( cmd_m_ps0 == LP_ROW_ACT && cmd_m_ps1 == LP_COL_WRT && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1 ) begin
                r_row_cmd_p0	 <= {bank_address_m_ps0[3], row_address_m_ps0[13], LP_BA4_0, LP_PAR, row_address_m_ps0[12:11], bank_address_m_ps0[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_m_ps0[4:2], LP_PAR, row_address_m_ps0[1:0], row_address_m_ps0[10:5]};
                r_col_cmd_p0     <= { LP_BA4_1, column_address_m_ps1[5:2], LP_PAR, column_address_m_ps1[1], 1'b0, bank_address_m_ps1[3:0], LP_COL_WRT[3:0]};
                r_col_cmd_p1     <= 16'hffff;
            end
            
            
            else if ( (cmd_m_ps0 == LP_GENERAL_NOP || ~can_serve_actual_cmd_ps0) && (cmd_m_ps1 == LP_ROW_ACT && can_serve_actual_cmd_ps1) ) begin
                r_row_cmd_p0	 <= {bank_address_m_ps1[3], row_address_m_ps1[13], LP_BA4_1, LP_PAR, row_address_m_ps1[12:11], bank_address_m_ps1[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_m_ps1[4:2], LP_PAR, row_address_m_ps1[1:0], row_address_m_ps1[10:5]};
                r_col_cmd_p0     <= 16'hffff;
                r_col_cmd_p1     <= 16'hffff;
            end
            
            else if ( cmd_m_ps0 == LP_ROW_PRE && cmd_m_ps1 == LP_ROW_ACT && can_serve_actual_cmd_ps1 ) begin
                r_row_cmd_p0	 <= {bank_address_m_ps1[3], row_address_m_ps1[13], LP_BA4_1, LP_PAR, row_address_m_ps1[12:11], bank_address_m_ps1[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_m_ps1[4:2], LP_PAR, row_address_m_ps1[1:0], row_address_m_ps1[10:5]};
                r_col_cmd_p0     <= 16'hffff;
                r_col_cmd_p1     <= 16'hffff;
            end
            
            
            else if ( cmd_m_ps0 == LP_COL_RD && cmd_m_ps1 == LP_ROW_ACT && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1 ) begin
                r_row_cmd_p0	 <= {bank_address_m_ps1[3], row_address_m_ps1[13], LP_BA4_1, LP_PAR, row_address_m_ps1[12:11], bank_address_m_ps1[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_m_ps1[4:2], LP_PAR, row_address_m_ps1[1:0], row_address_m_ps1[10:5]};
                r_col_cmd_p0     <= { LP_BA4_0, column_address_m_ps0[5:2], LP_PAR, column_address_m_ps0[1], 1'b0, bank_address_m_ps0[3:0], LP_COL_RD};
                r_col_cmd_p1     <= 16'hffff;
            end
            
            
            else if ( cmd_m_ps0 == LP_COL_WRT && cmd_m_ps1 == LP_ROW_ACT && can_serve_actual_cmd_ps0 && can_serve_actual_cmd_ps1 ) begin
                r_row_cmd_p0	 <= {bank_address_m_ps1[3], row_address_m_ps1[13], LP_BA4_1, LP_PAR, row_address_m_ps1[12:11], bank_address_m_ps1[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                r_row_cmd_p1	 <= {row_address_m_ps1[4:2], LP_PAR, row_address_m_ps1[1:0], row_address_m_ps1[10:5]};
                r_col_cmd_p0     <= { LP_BA4_0, column_address_m_ps0[5:2], LP_PAR, column_address_m_ps0[1], 1'b0, bank_address_m_ps0[3:0], LP_COL_WRT[3:0]};
                r_col_cmd_p1     <= 16'hffff;
            end
            
            
            
            else begin
                r_row_cmd_p0    <= 12'hfff;
                r_row_cmd_p1    <= 12'hfff;
                r_col_cmd_p0    <= 16'hffff;
                r_col_cmd_p1    <= 16'hffff;
            end
            
        end
        else begin
            r_row_cmd_p0    <= 12'hfff;
            r_row_cmd_p1    <= 12'hfff;
            r_col_cmd_p0    <= 16'hffff;
            r_col_cmd_p1    <= 16'hffff;
        end   
    end
end


/* Circuito combinatorio per controllare se il tempo trascorso tra il comando precedente e quello attuale rispetta le latenze necessarie per quanto riguarda il PS0 */
always_comb
begin
    if( dfi_rst_n == 1'b0 ) begin
        can_serve_actual_cmd_ps0 <= 1'b0;
    end
    else begin
        if ( (r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1 ) && cmd_m_ps0 != LP_GENERAL_NOP ) begin             /* Sono pronto a ricevere un comando e questo che ricevo è valido */
            if ( cmd_m_ps1 == LP_ROW_ACT && cmd_m_ps0 == LP_ROW_PRE ) begin                       /* Se su PS1 c'è un ACT e su PS0 c'è un PRE, in generale un comando di riga tranne ACT, mi fermo su PS0, aspetto che PS1 completi ACT */
                can_serve_actual_cmd_ps0 <= 1'b0;
            end
            
            else begin 
            
            
                if ( previous_cmd_ps0 != LP_GENERAL_NOP ) begin
                    if ( previous_cmd_ps0 == LP_ROW_PRE ) begin                       /* Il comando precendente era un PRE */
                        
                        if ( cmd_m_ps0 == LP_ROW_PRE ) begin                   /* Dopo un PRE non ci può essere un altro PRE sullo stesso bank */
                            if ( previous_bank_addr_ps0 != bank_address_m_ps0 ) begin
                                can_serve_actual_cmd_ps0 <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd_ps0 <= 1'b0;
                            end
                        end
                        
                        if ( cmd_m_ps0 == LP_ROW_ACT ) begin                   /* tRP = PRE to ACT delay, che vale solo se stiamo accedendo allo stesso bank*/
                            if ( previous_bank_addr_ps0 == bank_address_m_ps0 ) begin
                                if ( previous_to_actual_cnt_ps0 >= tRP ) begin
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end
                            else begin
                                can_serve_actual_cmd_ps0 <= 1'b1;
                            end 
                        
                        end
                        
                        else if ( cmd_m_ps0 == LP_COL_WRT ) begin          /* PRE to WRT e PRE to RD è impossibile, perhè dopo un PRE ci deve essere per forza un ACT per poter eseguire altri comandi */        
                            can_serve_actual_cmd_ps0 <= 1'b1;
                        end
                        else if ( cmd_m_ps0 == LP_COL_RD  ) begin
                            can_serve_actual_cmd_ps0 <= 1'b1;
                        end
                        
                        else begin
                            can_serve_actual_cmd_ps0 <= 1'b0;
                        end
                                        
                    end
                    
                    else if ( previous_cmd_ps0 == LP_ROW_ACT ) begin                /* Il comando precendente era un ACT */
                        
                        if ( cmd_m_ps0 == LP_ROW_PRE ) begin
                            if ( previous_bank_addr_ps0 == bank_address_m_ps0 ) begin
                                if ( previous_to_actual_cnt_ps0 >= tRAS ) begin     /* tRAS = ACT to PRE delay, stesso bank */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end
                            else begin
                                can_serve_actual_cmd_ps0 <= 1'b1;
                            end 
                        end
                        
                        else if ( cmd_m_ps0 == LP_ROW_ACT ) begin
                            if ( previous_bank_addr_ps0 == bank_address_m_ps0 ) begin
                                if ( previous_to_actual_cnt_ps0 >= tRC ) begin     /* tRC = ACT to ACT delay, stesso bank */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end
                            else begin
                                if ( previous_to_actual_cnt_ps0 >= tRRD ) begin   /* tRRD = ACT to ACT delay, diversi bank */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end 
                        end
                        
                        else if ( cmd_m_ps0 == LP_COL_WRT || cmd_m_ps0 == LP_COL_RD ) begin
                            if ( previous_bank_addr_ps0 == bank_address_m_ps0 ) begin
                                if ( previous_to_actual_cnt_ps0 >= tRCD ) begin     /* tRCD = ACT to WRT/RD delay, stesso bank */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end
                            else begin
                                can_serve_actual_cmd_ps0 <= 1'b1;
                            end 
                        end
                    end
                    
                    else if ( previous_cmd_ps0 == LP_COL_WRT ) begin                /* Il comando precendente era un WRT */ 
                        if ( cmd_m_ps0 == LP_ROW_PRE ) begin
                            if ( previous_bank_addr_ps0 == bank_address_m_ps0 ) begin
                                if ( previous_to_actual_cnt_ps0 >=  tWR ) begin    /* tWR = data end of WRT to PRE, qua c'è da aggiustare la situazione */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end
                            else begin
                                can_serve_actual_cmd_ps0 <= 1'b1;
                            end 
                        end
                        
                        else if ( cmd_m_ps0 == LP_ROW_ACT ) begin
                            if ( previous_bank_addr_ps0 == bank_address_m_ps0 ) begin      /* WRT to ACT allo stesso bank non si può mai verificare, dato che prima di fare ACT dovrei fare un PRE */
                                can_serve_actual_cmd_ps0 <= 1'b0;
                            end
                            else begin
                                can_serve_actual_cmd_ps0 <= 1'b1;
                            end 
                        
                        end
                        
                        else if ( cmd_m_ps0 == LP_COL_WRT ) begin
                            if ( previous_bank_addr_ps0 == bank_address_m_ps0 ) begin
                                if ( previous_to_actual_cnt_ps0 >=  tCCDl ) begin    /* tCCDl = CAS to CAS delay, same bank */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end
                            else begin
                                if ( previous_to_actual_cnt_ps0 >=  tCCDs ) begin    /* tCCDs = CAS to CAS delay, different banks */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end 
                        
                        end
                        
                        else if ( cmd_m_ps0 == LP_COL_RD  ) begin
                            if ( previous_bank_addr_ps0 == bank_address_m_ps0 ) begin
                                if ( previous_to_actual_cnt_ps0 >=  tWTRl ) begin    /* tWTRl = WRT to RD delay, same bank */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end
                            else begin
                                if ( previous_to_actual_cnt_ps0 >=  tWTRs ) begin    /* tWTRs = WRT to RD delay, different banks */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end 
                        end
                    end
                    
                    else if ( previous_cmd_ps0 == LP_COL_RD  ) begin                /* Il comando precendente era un RD */
                        if ( cmd_m_ps0 == LP_ROW_PRE ) begin
                            if ( previous_bank_addr_ps0 == bank_address_m_ps0 ) begin
                                if ( previous_to_actual_cnt_ps0 >=  tRTPl ) begin    /* tRTPl = RD to PRE delay, same bank */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end
                            
                            else begin                        
                                if ( previous_to_actual_cnt_ps0 >=  tRTPl ) begin    /* tRTPs = RD to PRE delay, different banks */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end 
                                    
                        end
                        
                        else if ( cmd_m_ps0 == LP_ROW_ACT ) begin
                            if ( previous_bank_addr_ps0 != bank_address_m_ps0 ) begin   /* RD to ACT allo stesso bank non si può mai verificare, dato che prima di fare ACT dovrei fare un PRE */
                                can_serve_actual_cmd_ps0 <= 1'b1;
                            end                
                        end
                        
                        else if ( cmd_m_ps0 == LP_COL_WRT ) begin
                            if ( previous_to_actual_cnt_ps0 >= tRTW  ) begin
                                can_serve_actual_cmd_ps0 <= 1'b1;
                            end 
                            else begin
                                can_serve_actual_cmd_ps0 <= 1'b0;
                            end
                        
                        end
                        
                        else if ( cmd_m_ps0 == LP_COL_RD  ) begin
                            if ( previous_bank_addr_ps0 == bank_address_m_ps0 ) begin
                                if ( previous_to_actual_cnt_ps0 >=  tCCDl ) begin    /* tCCDl = CAS to CAS delay, same bank */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end
                            else begin
                                if ( previous_to_actual_cnt_ps0 >=  tCCDs ) begin    /* tCCDs = CAS to CAS delay, different banks */
                                    can_serve_actual_cmd_ps0 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps0 <= 1'b0;
                                end
                            end 
                        end
                    end
                                
                end
                
                else begin
                    can_serve_actual_cmd_ps0 <= 1'b1;
                end
            end
        end
        else begin
            can_serve_actual_cmd_ps0 <= 1'b0;
        end
    end
end


/* Circuito combinatorio per controllare se il tempo trascorso tra il comando precedente e quello attuale rispetta le latenze necessarie per quanto riguarda il PS1 */
always_comb
begin
    if( dfi_rst_n == 1'b0 ) begin
        can_serve_actual_cmd_ps1 <= 1'b0;
    end
    else begin
        if ( (r_phy_tg_ps == LP_CMD_WAIT || r_phy_tg_ps == LP_CMD_WAIT_1 ) && cmd_m_ps1 != LP_GENERAL_NOP ) begin             /* Sono pronto a ricevere un comando e questo che ricevo è valido */
            if ( cmd_m_ps0 == LP_ROW_ACT && (cmd_m_ps1 == LP_ROW_ACT || cmd_m_ps1 == LP_ROW_PRE) ) begin                       /* Se su PS0 c'è un ACT e su PS1 c'è un ACT o un PRE, in generale un comando di riga, mi fermo su PS1, aspetto che PS0 completi ACT */
                can_serve_actual_cmd_ps1 <= 1'b0;
            end
            
            else begin
            
                if ( previous_cmd_ps1 != LP_GENERAL_NOP ) begin
                    if ( previous_cmd_ps1 == LP_ROW_PRE ) begin                       /* Il comando precendente era un PRE */
                        
                        if ( cmd_m_ps1 == LP_ROW_PRE ) begin                   /* Dopo un PRE non ci può essere un altro PRE sullo stesso bank */
                            if ( previous_bank_addr_ps1 != bank_address_m_ps1 ) begin
                                can_serve_actual_cmd_ps1 <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd_ps1 <= 1'b0;
                            end
                        end
                        
                        if ( cmd_m_ps1 == LP_ROW_ACT ) begin                   /* tRP = PRE to ACT delay, che vale solo se stiamo accedendo allo stesso bank*/
                            if ( previous_bank_addr_ps1 == bank_address_m_ps1 ) begin
                                if ( previous_to_actual_cnt_ps1 >= tRP ) begin
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end
                            else begin
                                can_serve_actual_cmd_ps1 <= 1'b1;
                            end 
                        
                        end
                        
                        else if ( cmd_m_ps1 == LP_COL_WRT ) begin          /* PRE to WRT e PRE to RD è impossibile, perhè dopo un PRE ci deve essere per forza un ACT per poter eseguire altri comandi */
                            can_serve_actual_cmd_ps1 <= 1'b1;
                        end
                        else if ( cmd_m_ps1 == LP_COL_RD  ) begin
                            can_serve_actual_cmd_ps1 <= 1'b1;
                        end
                        
                        else begin
                            can_serve_actual_cmd_ps1 <= 1'b0;
                        end
                                        
                    end
                    
                    else if ( previous_cmd_ps1 == LP_ROW_ACT ) begin                /* Il comando precendente era un ACT */
                        
                        if ( cmd_m_ps1 == LP_ROW_PRE ) begin
                            if ( previous_bank_addr_ps1 == bank_address_m_ps1 ) begin
                                if ( previous_to_actual_cnt_ps1 >= tRAS ) begin     /* tRAS = ACT to PRE delay, stesso bank */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end
                            else begin
                                can_serve_actual_cmd_ps1 <= 1'b1;
                            end 
                        end
                        
                        else if ( cmd_m_ps1 == LP_ROW_ACT ) begin
                            if ( previous_bank_addr_ps1 == bank_address_m_ps1 ) begin
                                if ( previous_to_actual_cnt_ps1 >= tRC ) begin     /* tRC = ACT to ACT delay, stesso bank */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end
                            else begin
                                if ( previous_to_actual_cnt_ps1 >= tRRD ) begin   /* tRRD = ACT to ACT delay, diversi bank */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end 
                        end
                        
                        else if ( cmd_m_ps1 == LP_COL_WRT || cmd_m_ps1 == LP_COL_RD ) begin
                            if ( previous_bank_addr_ps1 == bank_address_m_ps1 ) begin
                                if ( previous_to_actual_cnt_ps1 >= tRCD ) begin     /* tRCD = ACT to WRT/RD delay, stesso bank */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end
                            else begin
                                can_serve_actual_cmd_ps1 <= 1'b1;
                            end 
                        end
                    end
                    
                    else if ( previous_cmd_ps1 == LP_COL_WRT ) begin                /* Il comando precendente era un WRT */ 
                        if ( cmd_m_ps1 == LP_ROW_PRE ) begin
                            if ( previous_bank_addr_ps1 == bank_address_m_ps1 ) begin
                                if ( previous_to_actual_cnt_ps1 >=  tWR ) begin    /* tWR = data end of WRT to PRE, qua c'è da aggiustare la situazione */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end
                            else begin
                                can_serve_actual_cmd_ps1 <= 1'b1;
                            end 
                        end
                        
                        else if ( cmd_m_ps1 == LP_ROW_ACT ) begin
                            if ( previous_bank_addr_ps1 == bank_address_m_ps1 ) begin      /* WRT to ACT allo stesso bank non si può mai verificare, dato che prima di fare ACT dovrei fare un PRE */
                                can_serve_actual_cmd_ps1 <= 1'b0;
                            end
                            else begin
                                can_serve_actual_cmd_ps1 <= 1'b1;
                            end 
                        
                        end
                        
                        else if ( cmd_m_ps1 == LP_COL_WRT ) begin
                            if ( previous_bank_addr_ps1 == bank_address_m_ps1 ) begin
                                if ( previous_to_actual_cnt_ps1 >=  tCCDl ) begin    /* tCCDl = CAS to CAS delay, same bank */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end
                            else begin
                                if ( previous_to_actual_cnt_ps1 >=  tCCDs ) begin    /* tCCDs = CAS to CAS delay, different banks */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end 
                        
                        end
                        
                        else if ( cmd_m_ps1 == LP_COL_RD  ) begin
                            if ( previous_bank_addr_ps1 == bank_address_m_ps1 ) begin
                                if ( previous_to_actual_cnt_ps1 >=  tWTRl ) begin    /* tWTRl = WRT to RD delay, same bank */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end
                            else begin
                                if ( previous_to_actual_cnt_ps1 >=  tWTRs ) begin    /* tWTRs = WRT to RD delay, different banks */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end 
                        end
                    end
                    
                    else if ( previous_cmd_ps1 == LP_COL_RD  ) begin                /* Il comando precendente era un RD */
                        if ( cmd_m_ps1 == LP_ROW_PRE ) begin
                            if ( previous_bank_addr_ps1 == bank_address_m_ps1 ) begin
                                if ( previous_to_actual_cnt_ps1 >=  tRTPl ) begin    /* tRTPl = RD to PRE delay, same bank */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end
                            
                            else begin                        
                                if ( previous_to_actual_cnt_ps1 >=  tRTPl ) begin    /* tRTPs = RD to PRE delay, different banks */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end 
                                    
                        end
                        
                        else if ( cmd_m_ps1 == LP_ROW_ACT ) begin
                            if ( previous_bank_addr_ps1 != bank_address_m_ps1 ) begin   /* RD to ACT allo stesso bank non si può mai verificare, dato che prima di fare ACT dovrei fare un PRE */
                                can_serve_actual_cmd_ps1 <= 1'b1;
                            end                
                        end
                        
                        else if ( cmd_m_ps1 == LP_COL_WRT ) begin
                            if ( previous_to_actual_cnt_ps1 >= tRTW  ) begin
                                can_serve_actual_cmd_ps1 <= 1'b1;
                            end 
                            else begin
                                can_serve_actual_cmd_ps1 <= 1'b0;
                            end
                        
                        end
                        
                        else if ( cmd_m_ps1 == LP_COL_RD  ) begin
                            if ( previous_bank_addr_ps1 == bank_address_m_ps1 ) begin
                                if ( previous_to_actual_cnt_ps1 >=  tCCDl ) begin    /* tCCDl = CAS to CAS delay, same bank */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end
                            else begin
                                if ( previous_to_actual_cnt_ps1 >=  tCCDs ) begin    /* tCCDs = CAS to CAS delay, different banks */
                                    can_serve_actual_cmd_ps1 <= 1'b1;
                                end
                                else begin
                                    can_serve_actual_cmd_ps1 <= 1'b0;
                                end
                            end 
                        end
                    end
                                
                end
                
                else begin
                    can_serve_actual_cmd_ps1 <= 1'b1;
                end
            end
        end
        else begin
            can_serve_actual_cmd_ps1 <= 1'b0;
        end
    end
end

endmodule