`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/03/2023 02:50:47 PM
// Design Name: 
// Module Name: bank_scheduler
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


module bank_scheduler # 
(
    parameter		P_ROW_ADDR_WIDTH = 16,
    parameter		P_COL_ADDR_WIDTH = 12,
    parameter		P_BA_ADDR_WIDTH	 = 5, 
    parameter       P_DATA_WIDTH     = 256,
    parameter       P_QUEUE_LEN      = 16,
    parameter       P_BANK_INDEX     = 0
)
(
    input                                         clk,
    input                                         rst_n,

    /* Interfaccia verso il command_dispatcher */
//    output [P_ROW_ADDR_WIDTH-1 : 0]               actual_row_open, 
    input [3:0]                       cmd_dispatcher,
    input [P_BA_ADDR_WIDTH-1  : 0]    bank_addr_dispatcher,
    input [P_ROW_ADDR_WIDTH-1 : 0]    row_addr_dispatcher,
    input [P_COL_ADDR_WIDTH-1 : 0]    col_addr_dispatcher,
    input [P_DATA_WIDTH-1     : 0]    wrt_data_dispatcher,

    output                            cmd_picked_dispatcher,


    /* Interfaccia verso il channel scheduler */
    input                                         cmd_picked_bank,
    output  [3:0]                                 cmd_bank,
    output  [P_BA_ADDR_WIDTH-1 : 0]               bank_address_bank,
    output  [P_ROW_ADDR_WIDTH-1 : 0]              row_address_bank,
    output  [P_COL_ADDR_WIDTH-1 : 0]              column_address_bank,
    output  [P_DATA_WIDTH-1 : 0]                  wrt_data_bank,
    
    input   served_ras,
    input   served_cas

);

/* COMMANDS */
localparam LP_GENERAL_NOP   =  4'b1111;

/* ROW COMMANDS */
localparam LP_ROW_NOP		= 3'b111;
localparam LP_ROW_ACT		= 3'b010;
localparam LP_ROW_PRE		= 3'b011;  //WITH R[10] -> L
localparam LP_ROW_PREA		= 3'b011;  // WITH R[10] -> H
localparam LP_ROW_REFPB     = 4'b1001; // Metto un 1 al MSB per distinguerlo dalla Write 

/* COL COMMANDS */
localparam LP_COL_WRT		= 4'b0001;
localparam LP_COL_RD        = 4'b0101;

reg  [3:0]                       r_cmd_bank;
reg  [P_BA_ADDR_WIDTH-1 : 0]     r_bank_address_bank;
reg  [P_ROW_ADDR_WIDTH-1 : 0]    r_row_address_bank;
reg  [P_COL_ADDR_WIDTH-1 : 0]    r_column_address_bank;
reg  [P_DATA_WIDTH-1 : 0]        r_wrt_data_bank;

assign cmd_bank               = r_cmd_bank;
assign bank_address_bank      = r_bank_address_bank;
assign row_address_bank       = r_row_address_bank;
assign column_address_bank    = r_column_address_bank;
assign wrt_data_bank          = r_wrt_data_bank;



/* HBM LATENCIES */

/* INTRA BANK  */
localparam  tRCD    =      32'd14;     /* ACT to RD/WR delay */                 /* Verificato */
localparam  tRP     =      32'd14;     /* PRE to ACT/REF delay */
localparam  tRC     =      32'd1;      /* ACT to ACT/REF delay */
localparam  tRAS    =      32'd34;     /* ACT to PRE delay */                   /* Verificato */
localparam  tWL     =      32'd4;      /* WR to data bus transfer delay */      /* Verificato */      
localparam  tRL     =      32'd14;
localparam  tRTPl   =      32'd6;      /* RD to PRE delay */                    /* Forse Verificato, questo è simbolico, per non far scappare le RD prima delle PRE, il parametro è infatti verificato in ll_command_forwarder */
localparam  tWR     =      32'd16;     /* End of a WR operation to PRE delay */
localparam  tCCDl   =      32'd1;      /* WR/RD to WR/RD delay */               /* Verificato */ 
localparam  tRTW    =      32'd0;      /* RD to WR delay */
localparam  tWTRl   =      32'd8;      /* WR to RD delay */                     /* Verificato */
localparam  tBURST  =      32'd2;      /* Data bus transfer */
localparam  tRFCpb  =      32'd20;     /* Per Bank REF to Per Bank REF/ACT (Any Banks) */

localparam  tREFP   =      32'd1200;      /* Refresh Period, da verificare */


/* Registri per tenere traccia del tempo trascorso dall'ultimo comando specifico */
reg [63:0] last_act_cnt;
reg [63:0] last_act_for_cas_cnt;
reg [63:0] last_pre_cnt;
reg [63:0] last_wrt_cnt;
reg [63:0] last_rd_cnt;
reg [63:0] last_wrt_for_pre_cnt;
reg [63:0] last_rd_for_pre_cnt;

reg [63:0] last_ref_cnt;    /* Contatore del tempo trascorso dall'ultimo refresh */
reg need_refresh;

wire can_serve_actual_act;
wire can_serve_actual_pre;
wire can_serve_actual_wrt;
wire can_serve_actual_rd;

wire can_serve_actual_cmd;


reg [1:0] waiting_for_act_serve;
//reg waiting_for_pre_serve;
reg [1:0] waiting_for_wrt_serve;
reg [1:0] waiting_for_rd_serve;

reg [3:0] previous_cmd;

reg [P_ROW_ADDR_WIDTH : 0] actual_row_open; 

/* Coda dei comandi in ingresso */
reg [3:0]                     cmd_queue         [0 : P_QUEUE_LEN - 1];
reg [P_BA_ADDR_WIDTH-1:0]     bank_addr_queue   [0 : P_QUEUE_LEN - 1];
reg [P_ROW_ADDR_WIDTH-1:0]    row_addr_queue    [0 : P_QUEUE_LEN - 1];
reg [P_COL_ADDR_WIDTH-1:0]    col_addr_queue    [0 : P_QUEUE_LEN - 1];
reg [P_DATA_WIDTH-1 : 0]      wrt_data_queue    [0 : P_QUEUE_LEN - 1];
reg [3:0]                     tail;
reg [3:0]                     head;
reg [4:0]                     cmd_cnt;
wire                          incr_cmd_cnt;
wire                          deincr_cmd_cnt;


reg r_cmd_picked_dispatcher;
assign cmd_picked_dispatcher = r_cmd_picked_dispatcher;

/* Incremento e decremento il cnt della coda */ 
assign incr_cmd_cnt   = (cmd_cnt < P_QUEUE_LEN && cmd_dispatcher != LP_GENERAL_NOP);
assign deincr_cmd_cnt = ~need_refresh && ((can_serve_actual_cmd && cmd_picked_bank && r_cmd_bank != LP_GENERAL_NOP) || (can_serve_actual_cmd && r_cmd_bank == LP_GENERAL_NOP));

always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        cmd_cnt   <=  5'b00000;
    end 
    else begin
        if ( incr_cmd_cnt && ~deincr_cmd_cnt ) begin
            cmd_cnt <= cmd_cnt + 1'b1;
        end 
        else if ( ~incr_cmd_cnt && deincr_cmd_cnt ) begin
            cmd_cnt <= cmd_cnt - 1'b1;
        end
        else if ( incr_cmd_cnt && deincr_cmd_cnt ) begin
            cmd_cnt <= cmd_cnt;
        end
    end
end

assign can_serve_actual_act = /*cmd_picked_bank &&*/ ( cmd_cnt > 0 ) && (cmd_queue[tail] == LP_ROW_ACT) && (last_pre_cnt >= tRP)  && (last_act_cnt >= tRC) && (last_ref_cnt >= tRFCpb);  
assign can_serve_actual_pre = /*cmd_picked_bank &&*/ ( cmd_cnt > 0 ) && (cmd_queue[tail] == LP_ROW_PRE) && (last_act_cnt >= tRAS) && ((last_rd_cnt  >= tRTPl && previous_cmd != LP_COL_RD) || (last_rd_for_pre_cnt  >= tRTPl && previous_cmd == LP_COL_RD && waiting_for_rd_serve == 2'b00) ) && ( (last_wrt_cnt >= (tWL + tWR + tBURST) && previous_cmd != LP_COL_WRT) || (last_wrt_for_pre_cnt >= (tWL + tWR + tBURST) && previous_cmd == LP_COL_WRT && waiting_for_wrt_serve == 2'b00));                                     
assign can_serve_actual_wrt = /*cmd_picked_bank &&*/ ( cmd_cnt > 0 ) && (cmd_queue[tail] == LP_COL_WRT) && ((previous_cmd != LP_ROW_ACT && last_act_cnt >= tRCD ) || (previous_cmd == LP_ROW_ACT && last_act_for_cas_cnt >= tRCD && waiting_for_act_serve == 2'b00)) && (last_rd_cnt  >= tRTW)   && (last_wrt_cnt >= tCCDl);
assign can_serve_actual_rd  = /*cmd_picked_bank &&*/ ( cmd_cnt > 0 ) && (cmd_queue[tail] == LP_COL_RD)  && ((previous_cmd != LP_ROW_ACT && last_act_cnt >= tRCD ) || (previous_cmd == LP_ROW_ACT && last_act_for_cas_cnt >= tRCD && waiting_for_act_serve == 2'b00)) && (last_wrt_cnt >= tWTRl)  && (last_rd_cnt  >= tCCDl) ;


wire can_serve_pre_ref;
wire can_serve_act_ref;

assign can_serve_actual_ref =  (last_pre_cnt >= tRP) && (last_act_cnt >= tRC) && (last_ref_cnt >= tRFCpb);
assign can_serve_pre_ref    =  (last_act_cnt >= tRAS) && ((last_rd_cnt  >= tRTPl && previous_cmd != LP_COL_RD) || (last_rd_for_pre_cnt  >= tRTPl && previous_cmd == LP_COL_RD && waiting_for_rd_serve == 2'b00) ) && ( (last_wrt_cnt >= (tWL + tWR + tBURST) && previous_cmd != LP_COL_WRT) || (last_wrt_for_pre_cnt >= (tWL + tWR + tBURST) && previous_cmd == LP_COL_WRT && waiting_for_wrt_serve == 2'b00 ));
assign can_serve_act_ref    =  (last_pre_cnt >= tRP)  && (last_act_cnt >= tRC) && (last_ref_cnt >= tRFCpb);

assign can_serve_actual_cmd = can_serve_actual_act || can_serve_actual_pre || can_serve_actual_wrt || can_serve_actual_rd /*|| can_serve_actual_ref*/;


always @ ( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        waiting_for_act_serve <=  2'b00;
    end
    else begin
        if (r_cmd_bank == LP_ROW_ACT && waiting_for_act_serve == 2'b00 ) begin
            waiting_for_act_serve <= 2'b01;
        end
        else if ( cmd_picked_bank && (r_cmd_bank == LP_ROW_ACT) && waiting_for_act_serve == 2'b01 ) begin
            waiting_for_act_serve <= 2'b10;
//            waiting_for_act_serve <= 2'b00;
        end
        else if (waiting_for_act_serve == 2'b10 && served_ras) begin
            waiting_for_act_serve <=  2'b00;
        end
        else begin
            waiting_for_act_serve <= waiting_for_act_serve;
        end
    end
end

always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_act_for_cas_cnt <= { 64 { 1'b0 } };
    end
    else begin
        if ( waiting_for_act_serve == 2'b10 && served_ras ) begin
            last_act_for_cas_cnt <= { 64 { 1'b0 } };
        end
        else if (last_act_for_cas_cnt == {64{1'b1}}) begin
            last_act_for_cas_cnt <= last_act_for_cas_cnt;
        end
        else begin
            last_act_for_cas_cnt <= last_act_for_cas_cnt + 1'b1;
        end
    end
end



always @ ( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        waiting_for_wrt_serve <=  2'b00;
    end
    else begin
        if (r_cmd_bank == LP_COL_WRT && waiting_for_wrt_serve == 2'b00 ) begin
            waiting_for_wrt_serve <= 2'b01;
        end
        else if ( cmd_picked_bank && (r_cmd_bank == LP_COL_WRT) && waiting_for_wrt_serve == 2'b01 ) begin
            waiting_for_wrt_serve <= 2'b10;
//            waiting_for_wrt_serve <= 2'b00;
        end
        else if (waiting_for_wrt_serve == 2'b10 && served_cas) begin
            waiting_for_wrt_serve <=  2'b00;
        end
        else begin
            waiting_for_wrt_serve <= waiting_for_wrt_serve;
        end
    end
end

always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_wrt_for_pre_cnt <= { 64 { 1'b0 } };
    end
    else begin
        if ( waiting_for_wrt_serve == 2'b10 && served_cas ) begin
            last_wrt_for_pre_cnt <= { 64 { 1'b0 } };
        end
        else if (last_wrt_for_pre_cnt == {64{1'b1}}) begin
            last_wrt_for_pre_cnt <= last_wrt_for_pre_cnt;
        end
        else begin
            last_wrt_for_pre_cnt <= last_wrt_for_pre_cnt + 1'b1;
        end
    end
end


always @ ( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        waiting_for_rd_serve <=  2'b00;
    end
    else begin
        if (r_cmd_bank == LP_COL_RD && waiting_for_rd_serve == 2'b00) begin
            waiting_for_rd_serve <= 2'b01;
        end
        else if ( cmd_picked_bank && (r_cmd_bank == LP_COL_RD) && waiting_for_rd_serve == 2'b01 ) begin
            waiting_for_rd_serve <= 2'b10;
//            waiting_for_rd_serve <= 2'b00;
        end
        else if (waiting_for_rd_serve == 2'b10 && served_cas) begin
            waiting_for_rd_serve <=  2'b00;
        end
        else begin
            waiting_for_rd_serve <= waiting_for_rd_serve;
        end
    end
end

always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_rd_for_pre_cnt <= { 64 { 1'b0 } };
    end
    else begin
        if ( waiting_for_rd_serve == 2'b10 && served_cas ) begin
            last_rd_for_pre_cnt <= { 64 { 1'b0 } };
        end
        else if (last_rd_for_pre_cnt == {64{1'b1}}) begin
            last_rd_for_pre_cnt <= last_rd_for_pre_cnt;
        end
        else begin
            last_rd_for_pre_cnt <= last_rd_for_pre_cnt + 1'b1;
        end
    end
end


always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_act_cnt <= { 64 { 1'b0 } };
    end
    else begin
        if ( cmd_picked_bank && (r_cmd_bank == LP_ROW_ACT) ) begin
            last_act_cnt <= { 64 { 1'b0 } };
        end
        else if (last_act_cnt == {64{1'b1}}) begin
            last_act_cnt <= last_act_cnt;
        end
        else begin
            last_act_cnt <= last_act_cnt + 1'b1;
        end
    end
end

always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        actual_row_open <= { P_ROW_ADDR_WIDTH+1{ 1'b1 } };
    end
    else begin
        if ( cmd_picked_bank && (r_cmd_bank == LP_ROW_ACT ) ) begin
            actual_row_open <= r_row_address_bank;
        end
        else if (cmd_picked_bank && (r_cmd_bank == LP_ROW_PRE) && ~need_refresh) begin
            actual_row_open <= { P_ROW_ADDR_WIDTH+1{ 1'b1 } };
        end
        else begin
            actual_row_open <= actual_row_open;
        end
    end
end


always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_pre_cnt <= { 64 { 1'b0 } };
    end
    else begin
        if ( cmd_picked_bank && (r_cmd_bank == LP_ROW_PRE) ) begin
            last_pre_cnt <= { 64 { 1'b0 } };
        end
        else if (last_pre_cnt == {64{1'b1}}) begin
            last_pre_cnt <= last_pre_cnt;
        end
        else begin
            last_pre_cnt <= last_pre_cnt + 1'b1;
        end
    end
end


always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_wrt_cnt <= { 64 { 1'b0 } };
    end
    else begin
        if ( cmd_picked_bank && (r_cmd_bank == LP_COL_WRT) ) begin
            last_wrt_cnt <= { 64 { 1'b0 } };
        end
        else if (last_wrt_cnt == {64{1'b1}}) begin
            last_wrt_cnt <= last_wrt_cnt;
        end
        else begin
            last_wrt_cnt <= last_wrt_cnt + 1'b1;
        end
    end
end

always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_rd_cnt <= { 64 { 1'b0 } };
    end
    else begin
        if ( cmd_picked_bank && (r_cmd_bank == LP_COL_RD) ) begin
            last_rd_cnt <= { 64 { 1'b0 } };
        end
        else if (last_rd_cnt == {64{1'b1}}) begin
            last_rd_cnt <= last_rd_cnt;
        end
        else begin
            last_rd_cnt <= last_rd_cnt + 1'b1;
        end
    end
end



always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        previous_cmd <= LP_GENERAL_NOP;
    end
    else begin
        if ( cmd_picked_bank  && r_cmd_bank != LP_GENERAL_NOP ) begin
            previous_cmd <= r_cmd_bank;
        end
        else begin
            previous_cmd <= previous_cmd;
        end
    end
end

reg sync_refresh;

always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        last_ref_cnt <=  { 64 { 1'b0 } };
    end
    else begin
        if ( cmd_picked_bank && (r_cmd_bank == LP_ROW_REFPB) ) begin
            last_ref_cnt <=  { 64 { 1'b0 } };
        end
        else if ( last_ref_cnt == { 64 { 1'b1 } } )  begin 
            last_ref_cnt <= last_ref_cnt;
        end
        else begin
            last_ref_cnt <= last_ref_cnt + 1'b1;
        end
    end
end

always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        sync_refresh <= 1'b0;
    end
    else begin
        if ( last_ref_cnt >= tREFP && ~need_refresh && ~sync_refresh ) begin
            sync_refresh <= 1'b1;
        end
        else if (cmd_picked_bank && (r_cmd_bank == LP_ROW_REFPB) && sync_refresh) begin
            sync_refresh <= 1'b0;
        end
    end
end

always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        need_refresh <=  1'b0;
    end
    else begin
        if ( last_ref_cnt >= tREFP && ~need_refresh && ~sync_refresh ) begin
            need_refresh <= 1'b1;
//            need_refresh <= 1'b0;
            
        end
        else if ( actual_row_open == { P_ROW_ADDR_WIDTH+1 {1'b1} } &&( need_refresh  && can_serve_actual_ref &&  (previous_cmd != LP_ROW_REFPB || (previous_cmd == LP_ROW_REFPB && actual_row_open == { P_ROW_ADDR_WIDTH+1 {1'b1} } ) ) && ((cmd_picked_bank && r_cmd_bank == LP_ROW_PRE) || (r_cmd_bank == LP_GENERAL_NOP && (previous_cmd == LP_ROW_PRE || actual_row_open == { P_ROW_ADDR_WIDTH+1 {1'b1} } ))) ) )  begin 
            need_refresh <= 1'b0;
        end
        else if ( need_refresh && actual_row_open != { P_ROW_ADDR_WIDTH+1 {1'b1} } &&  can_serve_act_ref &&  previous_cmd != LP_ROW_ACT && ((cmd_picked_bank && r_cmd_bank == LP_ROW_REFPB) || (r_cmd_bank == LP_GENERAL_NOP && previous_cmd == LP_ROW_REFPB ))) begin
            need_refresh <= 1'b0;
        end
    end
end



/* Prendo il comando in coda e lo mando al channel scheduler */
always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        r_cmd_bank             <= LP_GENERAL_NOP;
        r_bank_address_bank    <= P_BANK_INDEX/*{ P_BA_ADDR_WIDTH { 1'b0 } }*/;
        r_row_address_bank     <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        r_column_address_bank  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        r_wrt_data_bank        <= { P_DATA_WIDTH { 1'b0 } };
                
        tail                   <= 4'b0000;
        
    end
    else begin
        if ( need_refresh  &&  can_serve_pre_ref && previous_cmd != LP_ROW_PRE && ((cmd_picked_bank && r_cmd_bank != LP_ROW_PRE) || r_cmd_bank == LP_GENERAL_NOP) && actual_row_open != { P_ROW_ADDR_WIDTH+1 {1'b1} }) begin
            r_cmd_bank              <= LP_ROW_PRE;
            r_bank_address_bank     <= P_BANK_INDEX /*bank_addr_queue[tail]*/;
            r_row_address_bank      <= { P_ROW_ADDR_WIDTH { 1'b0 } }; 
            r_column_address_bank   <= { P_COL_ADDR_WIDTH { 1'b0 } };
            r_wrt_data_bank         <= { P_DATA_WIDTH { 1'b0 } };          
        end
        
        else if ( need_refresh  && can_serve_actual_ref && (previous_cmd != LP_ROW_REFPB || (previous_cmd == LP_ROW_REFPB && actual_row_open == { P_ROW_ADDR_WIDTH+1 {1'b1} } ) ) && ((cmd_picked_bank && r_cmd_bank == LP_ROW_PRE) || (r_cmd_bank == LP_GENERAL_NOP && (previous_cmd == LP_ROW_PRE || actual_row_open == { P_ROW_ADDR_WIDTH+1 {1'b1} } ))) ) begin
            r_cmd_bank              <=  LP_ROW_REFPB;
            r_bank_address_bank     <= P_BANK_INDEX /*bank_addr_queue[tail]*/;
            r_row_address_bank      <= { P_ROW_ADDR_WIDTH { 1'b0 } }; 
            r_column_address_bank   <= { P_COL_ADDR_WIDTH { 1'b0 } };
            r_wrt_data_bank         <= { P_DATA_WIDTH { 1'b0 } }; 
                   
        end  
        
        else if ( need_refresh && actual_row_open != { P_ROW_ADDR_WIDTH+1 {1'b1} } &&  can_serve_act_ref &&  previous_cmd != LP_ROW_ACT && ((cmd_picked_bank && r_cmd_bank == LP_ROW_REFPB) || (r_cmd_bank == LP_GENERAL_NOP && previous_cmd == LP_ROW_REFPB ))) begin
            r_cmd_bank              <= LP_ROW_ACT;
            r_bank_address_bank     <= P_BANK_INDEX /*bank_addr_queue[tail]*/;
            r_row_address_bank      <= actual_row_open; 
            r_column_address_bank   <= { P_COL_ADDR_WIDTH { 1'b0 } };
            r_wrt_data_bank         <= { P_DATA_WIDTH { 1'b0 } };
            
        end

        else if ( need_refresh && cmd_picked_bank ) begin
            r_cmd_bank              <= LP_GENERAL_NOP;
        end
               
        /* BUONO */
        else if (~need_refresh && can_serve_actual_cmd && cmd_picked_bank && r_cmd_bank != LP_GENERAL_NOP ) begin            
            r_cmd_bank              <= cmd_queue[tail];
            r_bank_address_bank     <= P_BANK_INDEX /*bank_addr_queue[tail]*/;
            r_row_address_bank      <= row_addr_queue[tail];
            r_column_address_bank   <= col_addr_queue[tail];
            r_wrt_data_bank         <= wrt_data_queue[tail];
            
            tail                    <= tail + 1'b1;
        end
        else if ( ~need_refresh &&  ~can_serve_actual_cmd && cmd_picked_bank && r_cmd_bank != LP_GENERAL_NOP ) begin
            r_cmd_bank              <= LP_GENERAL_NOP;
        end
        else if (~need_refresh &&  can_serve_actual_cmd && r_cmd_bank == LP_GENERAL_NOP ) begin
            r_cmd_bank              <= cmd_queue[tail];
            r_bank_address_bank     <= P_BANK_INDEX /*bank_addr_queue[tail]*/;
            r_row_address_bank      <= row_addr_queue[tail];
            r_column_address_bank   <= col_addr_queue[tail];
            r_wrt_data_bank         <= wrt_data_queue[tail];
            
            tail                    <= tail + 1'b1;
        end
    end
end


/* Riempio la coda */
always @ ( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        for ( integer i = 0; i < P_QUEUE_LEN; i = i + 1 ) cmd_queue       [i]  <= 4'b0000;
        for ( integer i = 0; i < P_QUEUE_LEN; i = i + 1 ) bank_addr_queue [i]  <= { P_BA_ADDR_WIDTH  { 1'b0 } };
        for ( integer i = 0; i < P_QUEUE_LEN; i = i + 1 ) row_addr_queue  [i]  <= { P_ROW_ADDR_WIDTH { 1'b0 } };
        for ( integer i = 0; i < P_QUEUE_LEN; i = i + 1 ) col_addr_queue  [i]  <= { P_COL_ADDR_WIDTH { 1'b0 } };
        for ( integer i = 0; i < P_QUEUE_LEN; i = i + 1 ) wrt_data_queue  [i]  <= { P_DATA_WIDTH     { 1'b0 } };
        
        r_cmd_picked_dispatcher <= 1'b0;
        head <= 4'b0000; 
        
    end 
    else begin
        if ( cmd_cnt < P_QUEUE_LEN && cmd_dispatcher != LP_GENERAL_NOP ) begin
            cmd_queue       [head]    <= cmd_dispatcher;
            bank_addr_queue [head]    <= bank_addr_dispatcher;
            row_addr_queue  [head]    <= row_addr_dispatcher;   
            col_addr_queue  [head]    <= col_addr_dispatcher;
            wrt_data_queue  [head]    <= wrt_data_dispatcher;
             
            head <= head + 1'b1;
            r_cmd_picked_dispatcher  <= 1'b1;
        
        end 
        else if (/*cmd_cnt < P_QUEUE_LEN &&*/ cmd_dispatcher == LP_GENERAL_NOP) begin
            r_cmd_picked_dispatcher  <= 1'b1;
        end
        else begin
            head <= head;
            r_cmd_picked_dispatcher  <= 1'b0;
        end
    end
end


endmodule
