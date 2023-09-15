/** Last Level Command Fowarder **/
`timescale 1ps/1ps


module ll_command_forwarder # (
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
    input            dfi_phyupd_ack,
    
    
    /* My Interface */
    output                              ready_to_cmd_m,
    input                               cmd_arrive_m,
    input [3:0]                         cmd_m,
    input [P_BA_ADDR_WIDTH-1:0]         bank_address_m,
    input [P_ROW_ADDR_WIDTH-1:0]        row_address_m,
    input [P_COL_ADDR_WIDTH-1:0]        column_address_m,
    input [(P_DATA_WIDTH*2)-1:0]        data_m
    
    
);

/* STATES */
localparam LP_IDLE			    = 4'd0;
localparam LP_MRS			    = 4'd1;
localparam LP_FETCH			    = 4'd2;
localparam LP_CMD_WAIT          = 4'd3;
localparam LP_PRECHG		    = 4'd4;
localparam LP_ACT               = 4'd5;
localparam LP_WRT               = 4'd6;
localparam LP_RD                = 4'd7;
localparam LP_CMD_CHECK_SERVE   = 4'd8;
localparam LP_CMD_SERVING       = 4'd9;


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
localparam LP_ROW_PRE		= 3'b011; //WITH R[10] -> L
localparam LP_ROW_PREA		= 3'b011; // WITH R[10] -> H

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
localparam LP_PAR       = 1;


/* HBM LATENCIES */

/* SAME BANK  */
localparam  tRCD    =      32'd30;
localparam  tRP     =      32'd0;
localparam  tRC     =      32'd30;
localparam  tRAS    =      32'd30;
localparam  tWL     =      32'd30;
localparam  tRL     =      32'd30;
localparam  tRTPl   =      32'd30;
localparam  tWR     =      32'd30;
localparam  tCCDl   =      32'd0;
localparam  tRTW    =      32'd30;
localparam  tWTRs   =      32'd30;


/* DIFFERENT BANKS */
localparam  tRTPs   =      32'd30;
localparam  tRRD    =      32'd30;
localparam  tFAW    =      32'd30;
localparam  tWTRl   =      32'd30;
localparam  tCCDs   =      32'd30;





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


reg      r_phy_only_ps_prechg;
reg      r_phy_only_ps_prechg_sync_0;
reg      r_phy_only_ps_prechg_sync_1;

reg		 r_phy_only_ps_act;
reg		 r_phy_only_ps_act_sync_0;
reg		 r_phy_only_ps_act_sync_1;
reg		 r_phy_only_ps_act_sync_2;

reg		 r_wrt_en;
reg      r_rd_en;

reg      r_wrt_cmdnaddr_en ;
reg      r_wrt_cmdnaddr_en_sync_0;

reg      r_rd_cmdnaddr_en;
reg      r_rd_cmdnaddr_en_sync_0;

reg     [255:0]  r_dw_wrdata_p0;
reg     [255:0]  r_dw_wrdata_p1;

/* My Registers */
reg              r_ready_to_cmd_m;

reg     [2:0]    rd_counter;
reg     [2:0]    wrt_counter;

reg     [15:0]   data_wrt_cnt;
reg     [15:0]   data_rd_cnt;

reg     [63:0]   previous_to_actual_cnt;    /* Contatore per tenere traccia di quanto tempo è passato dal comando precedente, così da vedere se è possibile lanciare il nuovo comando */

reg              can_serve_actual_cmd;
reg              actual_cmd_done;

/* Comando attuale che deve essere servito */
reg  [3:0]    actual_cmd;

/* Dati attuali che devono essere scritti in caso di write */
reg  [P_DATA_WIDTH-1 : 0]       actual_wrt_data_p0;
reg  [P_DATA_WIDTH-1 : 0]       actual_wrt_data_p1; 

/* Indirizzi del comando attuale */
reg  [P_ROW_ADDR_WIDTH-1  : 0]   actual_row_addr;
reg  [P_COL_ADDR_WIDTH-1  : 0]   actual_col_addr;
reg  [P_BA_ADDR_WIDTH-1   : 0]   actual_bank_addr;


assign ready_to_cmd_m = r_ready_to_cmd_m;

assign dfi_aw_ck_p0  = r_dfi_aw_ck_p0;
assign dfi_aw_cke_p0 = r_dfi_aw_cke_p0;
assign dfi_aw_ck_p1  = r_dfi_aw_ck_p1;
assign dfi_aw_cke_p1 = r_dfi_aw_cke_p1;

assign dfi_init_start =r_dfi_init_start;
assign w_precharge_lat_done = (r_precharge_lat_cnt >= P_DRIVE_PRECHARGE_CMD) ? 1'b1 : 1'b0;

assign dfi_aw_col_p0    =  r_col_cmd_p0;
assign dfi_aw_col_p1	=  r_col_cmd_p1;
assign dfi_aw_row_p0    =  r_row_cmd_p0;
assign dfi_aw_row_p1    =  r_row_cmd_p1;

assign dfi_dw_wrdata_p0 = actual_wrt_data_p0;                /* r_dw_wrdata_p0; */
assign dfi_dw_wrdata_p1 = actual_wrt_data_p0;                /* r_dw_wrdata_p1; */


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
            if ( cmd_m != LP_GENERAL_NOP )  begin  /* c'è un comando in arrivo */
                r_phy_tg_ns <= LP_CMD_CHECK_SERVE;
                
            end
            else begin
                r_phy_tg_ns <= LP_CMD_WAIT;
            end
            
        end             
        
        LP_CMD_CHECK_SERVE:
        begin
            if ( can_serve_actual_cmd == 1'b1 ) begin
                r_phy_tg_ns <= LP_CMD_SERVING;
            end
            else begin
                r_phy_tg_ns <= LP_CMD_CHECK_SERVE;
            end
        end
        
        LP_CMD_SERVING:
        begin
            if ( actual_cmd_done == 1'b1 ) begin
                r_phy_tg_ns <= LP_CMD_WAIT;
            end
            else begin
                r_phy_tg_ns <= LP_CMD_SERVING;
            end
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


/* Driver per gestire il previous to actual (cmd) counter */
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        previous_to_actual_cnt <= { 64 { 1'b0 } };
    end
    else begin
        if ( can_serve_actual_cmd == 1'b1 ) begin
            previous_to_actual_cnt <= { 64 { 1'b0 } };
        end
        else begin
            previous_to_actual_cnt <= previous_to_actual_cnt + 1'b1;
        end
    end
end

/* Driver per gestire il ready_to_cmd verso l'esterno */
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        r_ready_to_cmd_m <= 1'b0;     
    end
    else begin
        if ( r_phy_tg_ps == LP_CMD_WAIT  ) begin             /* In questo caso o sto aspettando un comando ho ho preso quello che ci stava, dunque chiedo all'esterno di mettermi un altro cmd */
            r_ready_to_cmd_m <= 1'b1;
        end
        else begin
            r_ready_to_cmd_m <= 1'b0;
        end
    end
end



/* Driver per salvare le informazioni necessarie del comando attuale */
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        actual_cmd          <=   LP_GENERAL_NOP;
    
        actual_bank_addr    <=  { P_BA_ADDR_WIDTH  { 1'b0 } };
        actual_col_addr     <=  { P_COL_ADDR_WIDTH { 1'b0 } };
        actual_row_addr     <=  { P_ROW_ADDR_WIDTH { 1'b0 } };
        
        actual_wrt_data_p0  <=  { P_DATA_WIDTH     { 1'b1 } };
        actual_wrt_data_p1  <=  { P_DATA_WIDTH     { 1'b1 } };
    end
    else begin
        if ( r_phy_tg_ps == LP_CMD_WAIT && cmd_m != LP_GENERAL_NOP ) begin
            actual_cmd <= cmd_m;                                                                /* Mi salvo il comando che deve essere servito */
            if ( cmd_m == LP_COL_WRT ) begin                                                    /* Mi salvo i dati che devono essere scritti in caso di write */
                actual_wrt_data_p0  <=  data_m[P_DATA_WIDTH-1:0];
                actual_wrt_data_p1  <=  data_m[(P_DATA_WIDTH*2)-1:P_DATA_WIDTH] ;
            end
            
            actual_bank_addr <=  bank_address_m;
            actual_col_addr  <=  column_address_m;
            actual_row_addr  <=  row_address_m;
            
        end

    end
end



reg [3:0]  previous_cmd;
reg [P_BA_ADDR_WIDTH-1 : 0]     previous_bank_addr;


/* Driver per salvare il cmd actual in previous */
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        previous_cmd         <=  LP_GENERAL_NOP;
        previous_bank_addr   <=  { P_BA_ADDR_WIDTH { 1'b0 } };
    end

    else begin
        if ( actual_cmd_done == 1'b1 ) begin
            previous_cmd <= actual_cmd;
            previous_bank_addr <= actual_bank_addr;
        end
        else begin
            previous_cmd <= previous_cmd;
            previous_bank_addr <= previous_bank_addr;
        end        
    end
end

/* Driver per eseguire effettivamente il comando attuale */
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        r_row_cmd_p0    <= LP_COL_NOP;
        r_row_cmd_p1    <= LP_COL_NOP;
        r_col_cmd_p0    <= LP_COL_NOP;
        r_col_cmd_p1    <= LP_COL_NOP;
        actual_cmd_done <= 1'b0;

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
        if ( r_phy_tg_ps == LP_CMD_SERVING ) begin
            if ( actual_cmd == LP_ROW_PRE ) begin
                r_col_cmd_p0 <= 16'hffff;
                r_col_cmd_p1 <= 16'hffff;
                
                if( r_phy_only_ps_prechg && ~r_phy_only_ps_prechg_sync_0 ) begin
					r_row_cmd_p0		<= { actual_bank_addr[3] , 1'b0, actual_bank_addr[4], 3'b000, actual_bank_addr[2:0], LP_ROW_PRE};
					r_row_cmd_p1		<= 12'hfff;
					actual_cmd_done     <= 1'b0;
				end
				else if( r_phy_only_ps_prechg_sync_0 && ~r_phy_only_ps_prechg_sync_1) begin
				    r_row_cmd_p0		<= 12'hfff;
                    r_row_cmd_p1		<= { actual_bank_addr[3],  1'b0, ~actual_bank_addr[4], 3'b000, actual_bank_addr[2:0], LP_ROW_PRE};
				    actual_cmd_done     <= 1'b1;
				end
				else
				begin
					r_row_cmd_p0		<= 12'hfff;
					r_row_cmd_p1		<= 12'hfff;
					actual_cmd_done     <= 1'b0;
				end                
                
            end 
            else if ( actual_cmd == LP_ROW_ACT ) begin
                r_col_cmd_p0 <= 16'hffff;
                r_col_cmd_p1 <= 16'hffff;
                
                if( ~r_phy_only_ps_act && ~r_phy_only_ps_act_sync_0 )
                begin
                    r_row_cmd_p0		<= {actual_bank_addr[3], actual_row_addr[13], actual_bank_addr[4], 1'b0, actual_row_addr[12:11], actual_bank_addr[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                    r_row_cmd_p1		<= {actual_row_addr[4:2],1'b0, actual_row_addr[1:0], actual_row_addr[10:5]};
                    actual_cmd_done     <= 1'b0;
                end
                else if( r_phy_only_ps_act && ~r_phy_only_ps_act_sync_0 )
                begin
                    r_row_cmd_p0		<= {actual_bank_addr[3], actual_row_addr[13], ~actual_bank_addr[4], 1'b0, actual_row_addr[12:11], actual_bank_addr[2:0],1'b0/*r_RA[14]*/,LP_ROW_ACT[1:0]};
                    r_row_cmd_p1		<= {actual_row_addr[4:2],1'b0, actual_row_addr[1:0], actual_row_addr[10:5]};
                    actual_cmd_done     <= 1'b1;
                end
                else 
                begin
                    r_row_cmd_p0		<= 12'hfff;
                    r_row_cmd_p1		<= 12'hfff;
                    actual_cmd_done     <= 1'b0;
                end
                                
            end
            else if ( actual_cmd == LP_COL_WRT ) begin
                r_row_cmd_p0 <= 12'hfff;
                r_row_cmd_p1 <= 12'hfff;
                
                if( r_wrt_cmdnaddr_en && ~r_wrt_cmdnaddr_en_sync_0 )
				begin
					r_col_cmd_p0	 <= {actual_bank_addr[4], actual_col_addr[5:2], 1'b0, actual_col_addr[1], 1'b0, actual_bank_addr[3:0], LP_COL_WRT[3:0]};
					r_col_cmd_p1	 <= 16'hffff;
					actual_cmd_done  <= 1'b1;
				end
				else if( r_wrt_cmdnaddr_en && r_wrt_cmdnaddr_en_sync_0 )
				begin
				    r_col_cmd_p0	 <= 16'hffff;
					r_col_cmd_p1	 <= {~actual_bank_addr[4], actual_col_addr[5:2], 1'b0, actual_col_addr[1], 1'b0, actual_bank_addr[3:0], LP_COL_WRT[3:0]};
					actual_cmd_done  <= 1'b0;
				end
				else if( r_wrt_cmdnaddr_en_sync_0 )
				begin
					r_col_cmd_p0	 <= 16'hffff;
					r_col_cmd_p1	 <= 16'hffff;
					actual_cmd_done  <= 1'b0;
				end
				else 
				begin
				    actual_cmd_done  <= 1'b0;
					r_col_cmd_p0	 <= 16'hffff;
					r_col_cmd_p1	 <= 16'hffff;
				end
                
            end
            
            else if ( actual_cmd == LP_COL_RD )  begin
                r_row_cmd_p0 <= 12'hfff;
                r_row_cmd_p1 <= 12'hfff;
                
                if( r_rd_cmdnaddr_en && ~r_rd_cmdnaddr_en_sync_0 )
				begin
                    r_col_cmd_p0	 <= {actual_bank_addr[4], actual_col_addr[5:2], 1'b0, actual_col_addr[1], 1'b0, actual_bank_addr[3:0], LP_COL_RD};
					r_col_cmd_p1	 <= 16'hffff;
					actual_cmd_done  <= 1'b1;
				end
				else if( r_rd_cmdnaddr_en && r_rd_cmdnaddr_en_sync_0)
				begin
					r_col_cmd_p1	 <= {~actual_bank_addr[4], actual_col_addr[5:2], 1'b0, actual_col_addr[1], 1'b0, actual_bank_addr[3:0], LP_COL_RD};
                    r_col_cmd_p0	 <= 16'hffff;
                    actual_cmd_done  <= 1'b0;
				end				
				else if( r_rd_cmdnaddr_en_sync_0 )
				begin
                    r_col_cmd_p0	 <= 16'hffff;
                    r_col_cmd_p1	 <= 16'hffff;
                    actual_cmd_done  <= 1'b0;
				end
				else 
				begin
					r_col_cmd_p0	 <= 16'hffff;
					r_col_cmd_p1	 <= 16'hffff;
					actual_cmd_done  <= 1'b0;
				end
            end
        
        end
        else begin
            r_row_cmd_p0    <= 12'hfff;
            r_row_cmd_p1    <= 12'hfff;
            r_col_cmd_p0    <= 16'hffff;;
            r_col_cmd_p1    <= 16'hffff;;
            actual_cmd_done <= 1'b0;
        end   
    end
end

// PRECHARGE STATE INDICATOR
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 )
    begin
        r_phy_only_ps_prechg			<= 1'b0;
        r_phy_only_ps_prechg_sync_0	<= 1'b0;
        r_phy_only_ps_prechg_sync_1	<= 1'b0;
    end
    else
    begin
        r_phy_only_ps_prechg_sync_0	<= r_phy_only_ps_prechg;
        r_phy_only_ps_prechg_sync_1	<= r_phy_only_ps_prechg_sync_0;
        if( actual_cmd == LP_ROW_PRE && r_phy_tg_ps == LP_CMD_SERVING ) 
        begin
            r_phy_only_ps_prechg	<= 1'b1;
        end
        else
        begin
            r_phy_only_ps_prechg	<= 1'b0;
        end
    end
end

// ACT STATE INDICATOR
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 )
    begin
        r_phy_only_ps_act			<= 1'b0;
        r_phy_only_ps_act_sync_0	<= 1'b0;

    end
    else
    begin
        r_phy_only_ps_act_sync_0	<= r_phy_only_ps_act;
        if( actual_cmd == LP_ROW_ACT && r_phy_tg_ps == LP_CMD_SERVING ) 
        begin
            r_phy_only_ps_act	<= 1'b1;
        end
        else
        begin
            r_phy_only_ps_act	<= 1'b0;
        end
    end
end

// READ STATE INDICATOR
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 )
    begin
        r_rd_cmdnaddr_en			    <= 1'b0;
        r_rd_cmdnaddr_en_sync_0	        <= 1'b0;
    end
    else
    begin
        r_rd_cmdnaddr_en_sync_0	<= r_rd_cmdnaddr_en;
        if( actual_cmd == LP_COL_RD && r_phy_tg_ps == LP_CMD_SERVING ) 
        begin
            r_rd_cmdnaddr_en	<= 1'b1;
        end
        else
        begin
            r_rd_cmdnaddr_en	<= 1'b0;
        end
    end
end

// WRT STATE INDICATOR
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 )
    begin
        r_wrt_cmdnaddr_en			    <= 1'b0;
        r_wrt_cmdnaddr_en_sync_0	    <= 1'b0;
    end
    else
    begin
        r_wrt_cmdnaddr_en_sync_0	<= r_wrt_cmdnaddr_en;
        if( actual_cmd == LP_COL_WRT && r_phy_tg_ps == LP_CMD_SERVING ) 
        begin
            r_wrt_cmdnaddr_en	<= 1'b1;
        end
        else
        begin
            r_wrt_cmdnaddr_en	<= 1'b0;
        end
    end
end



/* Driver per controllare se il tempo trascorso tra il comando precedente e quello attuale rispetta le latenze necessarie */
always @ ( posedge dfi_clk or negedge dfi_rst_n )
begin
    if( dfi_rst_n == 1'b0 ) begin
        can_serve_actual_cmd <= 1'b0;
    end
    else begin
        if ( r_phy_tg_ps == LP_CMD_CHECK_SERVE ) begin
            if ( previous_cmd != LP_GENERAL_NOP ) begin
                if ( previous_cmd == LP_ROW_PRE ) begin                       /* Il comando precendente era un PRE */
                    
                    if ( actual_cmd == LP_ROW_PRE ) begin                   /* Dopo un PRE non ci può essere un altro PRE sullo stesso bank */
                        if ( previous_bank_addr != actual_bank_addr ) begin
                            can_serve_actual_cmd <= 1'b1;
                        end
                        else begin
                            can_serve_actual_cmd <= 1'b0;
                        end
                    end
                    
                    if ( actual_cmd == LP_ROW_ACT ) begin                   /* tRP = PRE to ACT delay, che vale solo se stiamo accedendo allo stesso bank*/
                        if ( previous_bank_addr == actual_bank_addr ) begin
                            if ( previous_to_actual_cnt >= tRP ) begin
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end
                        else begin
                            can_serve_actual_cmd <= 1'b1;
                        end 
                    
                    end
                    
//                    else if ( actual_cmd == LP_COL_WRT ) begin          /* PRE to WRT e PRE to RD è impossibile, perhè dopo un PRE ci deve essere per forza un ACT per poter eseguire altri comandi */        
//                    end
//                    else if ( actual_cmd == LP_COL_RD  ) begin
//                    end
                    
                    else begin
                        can_serve_actual_cmd <= 1'b0;
                    end
                                    
                end
                
                else if ( previous_cmd == LP_ROW_ACT ) begin                /* Il comando precendente era un ACT */
                    
                    if ( actual_cmd == LP_ROW_PRE ) begin
                        if ( previous_bank_addr == actual_bank_addr ) begin
                            if ( previous_to_actual_cnt >= tRAS ) begin     /* tRAS = ACT to PRE delay, stesso bank */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end
                        else begin
                            can_serve_actual_cmd <= 1'b1;
                        end 
                    end
                    
                    else if ( actual_cmd == LP_ROW_ACT ) begin
                        if ( previous_bank_addr == actual_bank_addr ) begin
                            if ( previous_to_actual_cnt >= tRC ) begin     /* tRC = ACT to ACT delay, stesso bank */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end
                        else begin
                            if ( previous_to_actual_cnt >= tRRD ) begin   /* tRRD = ACT to ACT delay, diversi bank */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end 
                    end
                    
                    else if ( actual_cmd == LP_COL_WRT || actual_cmd == LP_COL_RD ) begin
                        if ( previous_bank_addr == actual_bank_addr ) begin
                            if ( previous_to_actual_cnt >= tRCD ) begin     /* tRCD = ACT to WRT/RD delay, stesso bank */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end
                        else begin
                            can_serve_actual_cmd <= 1'b1;
                        end 
                    end
                end
                
                else if ( previous_cmd == LP_COL_WRT ) begin                /* Il comando precendente era un WRT */ 
                    if ( actual_cmd == LP_ROW_PRE ) begin
                        if ( previous_bank_addr == actual_bank_addr ) begin
                            if ( previous_to_actual_cnt >=  tWR ) begin    /* tWR = data end of WRT to PRE, qua c'è da aggiustare la situazione */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end
                        else begin
                            can_serve_actual_cmd <= 1'b1;
                        end 
                    end
                    
                    else if ( actual_cmd == LP_ROW_ACT ) begin
                        if ( previous_bank_addr == actual_bank_addr ) begin      /* WRT to ACT allo stesso bank non si può mai verificare, dato che prima di fare ACT dovrei fare un PRE */
                            can_serve_actual_cmd <= 1'b0;
                        end
                        else begin
                            can_serve_actual_cmd <= 1'b1;
                        end 
                    
                    end
                    
                    else if ( actual_cmd == LP_COL_WRT ) begin
                        if ( previous_bank_addr == actual_bank_addr ) begin
                            if ( previous_to_actual_cnt >=  tCCDl ) begin    /* tCCDl = CAS to CAS delay, same bank */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end
                        else begin
                            if ( previous_to_actual_cnt >=  tCCDs ) begin    /* tCCDs = CAS to CAS delay, different banks */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end 
                    
                    end
                    
                    else if ( actual_cmd == LP_COL_RD  ) begin
                        if ( previous_bank_addr == actual_bank_addr ) begin
                            if ( previous_to_actual_cnt >=  tWTRl ) begin    /* tWTRl = WRT to RD delay, same bank */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end
                        else begin
                            if ( previous_to_actual_cnt >=  tWTRs ) begin    /* tWTRs = WRT to RD delay, different banks */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end 
                    end
                end
                
                else if ( previous_cmd == LP_COL_RD  ) begin                /* Il comando precendente era un RD */
                    if ( actual_cmd == LP_ROW_PRE ) begin
                        if ( previous_bank_addr == actual_bank_addr ) begin
                            if ( previous_to_actual_cnt >=  tRTPl ) begin    /* tRTPl = RD to PRE delay, same bank */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end
                        
                        else begin                        
                            if ( previous_to_actual_cnt >=  tRTPl ) begin    /* tRTPs = RD to PRE delay, different banks */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end 
                                
                    end
                    
                    else if ( actual_cmd == LP_ROW_ACT ) begin
                        if ( previous_bank_addr != actual_bank_addr ) begin   /* RD to ACT allo stesso bank non si può mai verificare, dato che prima di fare ACT dovrei fare un PRE */
                            can_serve_actual_cmd <= 1'b1;
                        end                
                    end
                    
                    else if ( actual_cmd == LP_COL_WRT ) begin
                        if ( previous_to_actual_cnt >= tRTW  ) begin
                            can_serve_actual_cmd <= 1'b1;
                        end 
                        else begin
                            can_serve_actual_cmd <= 1'b0;
                        end
                    
                    end
                    
                    else if ( actual_cmd == LP_COL_RD  ) begin
                        if ( previous_bank_addr == actual_bank_addr ) begin
                            if ( previous_to_actual_cnt >=  tCCDl ) begin    /* tCCDl = CAS to CAS delay, same bank */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end
                        else begin
                            if ( previous_to_actual_cnt >=  tCCDs ) begin    /* tCCDs = CAS to CAS delay, different banks */
                                can_serve_actual_cmd <= 1'b1;
                            end
                            else begin
                                can_serve_actual_cmd <= 1'b0;
                            end
                        end 
                    end
                end
                            
            end
            
            else begin
                can_serve_actual_cmd <= 1'b1;
            end
        end
        else begin
            can_serve_actual_cmd <= 1'b0;
        end
    end
end

endmodule