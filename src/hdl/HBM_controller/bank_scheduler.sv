module bank_scheduler # 
(
    parameter		P_ROW_ADDR_WIDTH = 16,
    parameter		P_COL_ADDR_WIDTH = 12,
    parameter		P_BA_ADDR_WIDTH	 = 5, 
    parameter       P_DATA_WIDTH     = 256,
    parameter       P_QUEUE_LEN      = 2,
    parameter       P_BANK_INDEX     = 0,


    /* COMMANDS */
    parameter P_GENERAL_NOP  =  4'b1111,

    /* ROW COMMANDS */
    parameter P_ROW_NOP      = 3'b111,
    parameter P_ROW_ACT      = 3'b010,
    parameter P_ROW_PRE      = 3'b011,  /* WITH R[10] -> L */
    parameter P_ROW_PREA     = 3'b011,  /* WITH R[10] -> H */
    parameter P_ROW_REFPB    = 4'b1001, /* 1 at MSB to distinguish it from WRT */  

    /* COL COMMANDS */
    parameter P_COL_WRT      = 4'b0001,
    parameter P_COL_RD       = 4'b0101,

    /* HBM CONSTRAINTS */
    /* INTRA BANK CONSTRAINTS */
    parameter  tRCD          =      32'd14,       /* ACT to RD/WR delay   */
    parameter  tRP           =      32'd14,       /* PRE to ACT/REF delay */
    parameter  tRC           =      32'd1,        /* ACT to ACT/REF delay */
    parameter  tRAS          =      32'd34,       /* ACT to PRE delay     */            
    parameter  tWL           =      32'd4,        /* WR to data bus transfer delay */      
    parameter  tRL           =      32'd14,
    parameter  tRTPl         =      32'd6,        /* RD to PRE delay */
    parameter  tWR           =      32'd16,       /* End of a WR operation to PRE delay */
    parameter  tBURST        =      32'd2,        /* Data bus transfer */
    parameter  tRFCpb        =      32'd20,       /* Per Bank REF to Per Bank REF/ACT (Any Banks) */
    parameter  tREFP         =      32'd1215      /* Refresh Period*/  /* Maybe it is too conservative ? */
)
(
    input   clk,
    input   rst_n,

    /* Interface to command_dispatcher */
    input [63:0]                      req_id_dispatcher,
    input [63:0]                      cmd_id_dispatcher,
    input [3:0]                       cmd_dispatcher,
    input [P_BA_ADDR_WIDTH-1  : 0]    bank_addr_dispatcher,
    input [P_ROW_ADDR_WIDTH-1 : 0]    row_addr_dispatcher,
    input [P_COL_ADDR_WIDTH-1 : 0]    col_addr_dispatcher,
    input [P_DATA_WIDTH-1     : 0]    wrt_data_dispatcher,

    output                            cmd_picked_dispatcher,


    /* Interface to channel_scheduler */
    input                                         cmd_picked_bank,
    output  [3:0]                                 cmd_bank,
    output  [P_BA_ADDR_WIDTH-1 : 0]               bank_address_bank,
    output  [P_ROW_ADDR_WIDTH-1 : 0]              row_address_bank,
    output  [P_COL_ADDR_WIDTH-1 : 0]              column_address_bank,
    output  [P_DATA_WIDTH-1 : 0]                  wrt_data_bank,
    output  [63:0]                                req_id_bank,
    output  [63:0]                                cmd_id_bank,           
    
    input   served_ras,
    input   served_cas

);


/**********************************/
/* BANK SCHEDULER HIGH LEVEL VIEW */ 
/**********************************/

/*************************************************************************/
/*    ____________                                        ___________    */
/*   |            |      _________       __________      |           |   */
/*   |    CMD     |     |         |     |          |     |  CHANNEL  |   */
/*   | DISPATCHER |---->|cmd_inter|---->|r_cmd_bank|---->| SCHEDULER |   */
/*   |____________|     |_________|     |__________|     |___________|   */
/*                            |               |                          */
/*            ___________     |               |                          */
/*           |           |    |               |                          */
/*           |  REFRESH  |    |               |                          */
/*           | PROCEDURE |--->/       can_serve_actual_cmd               */
/*           |    FSM    |                                               */
/*           |___________|                                               */
/*                                                                       */
/*************************************************************************/

/* Channel Scheduler interface */
reg  [63:0]                      r_req_id_bank;
reg  [63:0]                      r_cmd_id_bank;
reg  [3:0]                       r_cmd_bank;
reg  [P_BA_ADDR_WIDTH-1 : 0]     r_bank_address_bank;
reg  [P_ROW_ADDR_WIDTH-1 : 0]    r_row_address_bank;
reg  [P_COL_ADDR_WIDTH-1 : 0]    r_column_address_bank;
reg  [P_DATA_WIDTH-1 : 0]        r_wrt_data_bank;

assign req_id_bank            = r_req_id_bank;
assign cmd_id_bank            = r_cmd_id_bank;
assign cmd_bank               = r_cmd_bank;
assign bank_address_bank      = r_bank_address_bank;
assign row_address_bank       = r_row_address_bank;
assign column_address_bank    = r_column_address_bank;
assign wrt_data_bank          = r_wrt_data_bank;


/* These registers serves to store the command data coming from Command Dispatcher */
reg  [3:0] cmd_inter;
reg  [P_BA_ADDR_WIDTH-1 : 0]         bank_address_inter;
reg  [P_ROW_ADDR_WIDTH-1 : 0]        row_address_inter;
reg  [P_COL_ADDR_WIDTH-1 : 0]        column_address_inter;
reg  [P_DATA_WIDTH-1 : 0]            wrt_data_inter;
reg  [63:0]                          req_id_inter;
reg  [63:0]                          cmd_id_inter; 

/* Command Dispatcher interface */
reg r_cmd_picked_dispatcher;
assign cmd_picked_dispatcher = r_cmd_picked_dispatcher;

/* Counters registers */
reg [15:0] last_ref_cnt;
reg [7:0]  last_act_cnt;
reg [7:0]  last_pre_cnt;
reg [7:0]  last_wrt_cnt;
reg [7:0]  last_rd_cnt;

/* Waiting registers, need to wait that a CMD is served by LLCF */
reg [1:0]  waiting_for_rd_serve;
reg [1:0]  waiting_for_wrt_serve;
reg [1:0]  waiting_for_act_serve;
reg [1:0]  waiting_for_pre_serve;
reg [1:0]  waiting_for_ref_serve;

reg [3:0]  previous_cmd;  /* Previous executed command */

/* These signals tell us if the command in cmd_inter_dispatcher stisfy timing constraints */
wire can_serve_actual_cmd;
wire can_serve_actual_act;
wire can_serve_actual_pre;
wire can_serve_actual_ref;
wire can_serve_actual_rd;
wire can_serve_actual_wrt;

reg [P_ROW_ADDR_WIDTH:0] active_row; /* Actual row open */

/* Refresh finite state machine signals, registers and states */
localparam LP_REF_IDLE     = 2'd0;
localparam LP_REF_PRE_WAIT = 2'd1;
localparam LP_REF_REF      = 2'd2;
localparam LP_REF_ACT      = 2'd3;

reg [1:0] refresh_present_state;
reg [1:0] refresh_next_state;

reg need_refresh;
reg [31:0] ref_occurrences_cnt; /* Counter just to give some id to refresh generated commands */

reg need_activate_after_refresh;

reg busy;

/* Can serve actual command combinatorial logic */
assign can_serve_actual_act = (cmd_inter == P_ROW_ACT) && (last_pre_cnt >= tRP) && (last_act_cnt >= tRC) && (last_ref_cnt >= tRFCpb) && ( (previous_cmd == P_ROW_PRE && waiting_for_pre_serve == 2'b00) || (previous_cmd == P_ROW_REFPB && waiting_for_ref_serve == 2'b00) );  
assign can_serve_actual_pre = (cmd_inter == P_ROW_PRE) && (last_act_cnt >= tRAS) && (last_rd_cnt  >= tRTPl) && (last_wrt_cnt >= (tWL + tWR + tBURST)) && ( (previous_cmd == P_COL_RD && waiting_for_rd_serve == 2'b00) || ( previous_cmd == P_COL_WRT && waiting_for_wrt_serve == 2'b00 ) || (previous_cmd == P_ROW_ACT && waiting_for_act_serve == 2'b00));
assign can_serve_actual_ref = (cmd_inter == P_ROW_REFPB) && (last_pre_cnt >= tRP) && (last_act_cnt >= tRC) && (last_ref_cnt >= tRFCpb) && (( previous_cmd == P_ROW_PRE && waiting_for_pre_serve == 2'b00 ) || (previous_cmd != P_ROW_PRE) );
assign can_serve_actual_rd  = (cmd_inter == P_COL_RD) && (last_act_cnt >= tRCD) && ((previous_cmd == P_ROW_ACT && waiting_for_act_serve == 2'b00 ) || ( previous_cmd == P_COL_WRT && waiting_for_wrt_serve == 2'b00 ) || (previous_cmd == P_COL_RD && waiting_for_rd_serve == 2'b00 ));
assign can_serve_actual_wrt = (cmd_inter == P_COL_WRT) && (last_act_cnt >= tRCD ) && ((previous_cmd == P_ROW_ACT && waiting_for_act_serve == 2'b00 ) || ( previous_cmd == P_COL_WRT && waiting_for_wrt_serve == 2'b00 ) || (previous_cmd == P_COL_RD && waiting_for_rd_serve == 2'b00 ));
assign can_serve_actual_cmd = can_serve_actual_act | can_serve_actual_pre | can_serve_actual_ref | can_serve_actual_rd | can_serve_actual_wrt;

/***********************/
/* PREVIOUS CMD UPDATE */
/***********************/
always @(posedge clk or negedge rst_n) begin
    if ( rst_n == 1'b0 ) begin
        // previous_cmd <= P_GENERAL_NOP;
        previous_cmd <= P_COL_RD;
    end
    else begin
        if ( r_cmd_bank != P_GENERAL_NOP /*&& cmd_picked_bank*/ ) begin
            previous_cmd <= r_cmd_bank;
        end
        else begin
            previous_cmd <= previous_cmd;
        end
    end
end

/***********************/
/* REG BUSY MANAGEMENT */
/***********************/
/* Every time cmd_inter is filled busy is set and every time cmd_inter is empty busy is reset */
always @(posedge clk or negedge rst_n) begin
    if ( rst_n == 1'b0 ) begin
        busy <= 1'b0;
    end
    else begin

        /*************************/
        /* FILLING THE CMD_INTER */
        /*************************/

        /* cmd_dispatcher give us a cmd, cmd_inter is empty, we can fill the cmd_inter */
        if ( cmd_dispatcher != P_GENERAL_NOP && cmd_inter == P_GENERAL_NOP && ~need_refresh && busy == 1'b0 ) begin
            busy <= 1'b1;
        end
        /* Same case of before, maybe we can delete this... */
        else if (~need_refresh && busy == 1'b0 && cmd_dispatcher != P_GENERAL_NOP ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty, we are going to fill it with a REF cmd */
        else if ( busy == 1'b0 && need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter == P_GENERAL_NOP && active_row != {P_ROW_ADDR_WIDTH+1{1'b1}} ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty, but the last cmd_inter was a no PRE cmd, we are going to fill it with a PRE cmd or a REF */
        else if ( busy == 1'b0 && need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter != P_ROW_PRE ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty, but the last cmd_inter was a no PRE cmd, we are going to fill it with a PRE cmd, now we are in wait state, see at FSM */
        else if ( need_refresh && refresh_present_state == LP_REF_PRE_WAIT && busy == 1'b0 && cmd_inter != P_ROW_PRE  ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty and the last cmd_inter was a PRE cmd, we are going to fill it with a REF cmd */
        else if ( need_refresh && refresh_present_state == LP_REF_PRE_WAIT && busy == 1'b0 && cmd_inter == P_ROW_PRE ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty and the cmd_dispatcher is a non ACT cmd, we are going to fill it with a ACT cmd */
        else if ( need_refresh && refresh_present_state == LP_REF_REF && busy == 1'b0 && cmd_dispatcher != P_ROW_ACT && need_activate_after_refresh ) begin
            busy <= 1'b1;
        end
        /* We are in refresh procedure, here the cmd_inter is empty and the cmd_dispatcher is a ACT cmd, we are going to fill it with the ACT coming from dispatcher */
        else if ( need_refresh && refresh_present_state == LP_REF_REF && busy == 1'b0 && cmd_dispatcher == P_ROW_ACT ) begin
            busy <= 1'b1;
        end

        /*************************/
        /* EMPTING THE CMD_INTER */
        /*************************/

        /* The cmd_inter is full and ready and r_cmd_bank is empty */
        else if ( r_cmd_bank == P_GENERAL_NOP && can_serve_actual_cmd && busy == 1'b1 ) begin
            busy <= 1'b0;
        end
        /* The cmd_inter is full and ready and r_cmd_bank is going to be picked by channel scheduler */
        else if ( can_serve_actual_cmd && r_cmd_bank != P_GENERAL_NOP && cmd_picked_bank && busy == 1'b1  ) begin
            busy <= 1'b0;
        end
    end
end



/*************************************/
/* ASSIGN CMD DISPATCHER TO CMD BANK */
/*************************************/
/* Here we get the cmd_inter e put it into r_cmd_bank if we can */
always @(posedge clk or negedge rst_n) begin
    if ( rst_n == 1'b0 ) begin
        r_cmd_bank <= P_GENERAL_NOP;
        r_bank_address_bank <= {P_BA_ADDR_WIDTH{1'b0}};
        r_row_address_bank <= {P_ROW_ADDR_WIDTH{1'b0}};
        r_column_address_bank <= {P_COL_ADDR_WIDTH{1'b0}};
        r_wrt_data_bank <= {P_DATA_WIDTH{1'b0}};
        r_req_id_bank <= {64{1'b1}};
        r_cmd_id_bank <= {64{1'b1}};
    end 
    else begin
        /* The case when r_cmd_bank is empty and we have a cmd_inter ready */
        if ( r_cmd_bank == P_GENERAL_NOP && can_serve_actual_cmd && busy == 1'b1 ) begin
            r_cmd_bank <= cmd_inter;
            r_bank_address_bank <= bank_address_inter; 
            r_row_address_bank <= row_address_inter;
            r_column_address_bank <= column_address_inter;
            r_wrt_data_bank <= wrt_data_inter;
            r_req_id_bank <= req_id_inter;
            r_cmd_id_bank <= cmd_id_inter;

            $display("[ BS %d ]: REQ: %d - CMD: %d (%d) sent at %d", bank_address_inter, req_id_inter, cmd_id_inter, cmd_inter, $time);

        end
        /* The case when channel scheduler get the cmd and we have another cmd_inter ready */
        else if ( can_serve_actual_cmd && r_cmd_bank != P_GENERAL_NOP && cmd_picked_bank && busy == 1'b1 ) begin
            r_cmd_bank <= cmd_inter;
            r_bank_address_bank <= bank_address_inter;
            r_row_address_bank <= row_address_inter;
            r_column_address_bank <= column_address_inter;
            r_wrt_data_bank <= wrt_data_inter;
            r_req_id_bank <= req_id_inter;
            r_cmd_id_bank <= cmd_id_inter;

            $display("[ BS %d ]: REQ: %d - CMD: %d (%d) sent at %d", bank_address_inter, req_id_inter, cmd_id_inter, cmd_inter, $time);

        end
        /* The case when channel scheduler get the cmd but we don't have another cmd_inter ready so just empty the r_cmd_bank */
        else if ( ~can_serve_actual_cmd && cmd_picked_bank && r_cmd_bank != P_GENERAL_NOP ) begin
            r_cmd_bank <= P_GENERAL_NOP;
        end
    end
end

/****************************************/
/* COMUNICATION WITH COMMAND DISPATCHER */
/****************************************/
/* Telling that we want other data (we get the previous) */
always @(posedge clk or negedge rst_n) begin
    if ( rst_n == 1'b0 ) begin
        r_cmd_picked_dispatcher <= 1'b0;
    end
    else begin
        /* Just to inform that we are ready to get data */
        if ( cmd_dispatcher == P_GENERAL_NOP && cmd_inter == P_GENERAL_NOP && ~need_refresh && busy == 1'b0 ) begin     
            r_cmd_picked_dispatcher <= 1'b1;
        end
        /* The cmd_inter is empty and the cmd_dispatcher is not NOP, we can get it */
        else if ( busy == 1'b0 && cmd_dispatcher != P_GENERAL_NOP && ~need_refresh && r_cmd_picked_dispatcher == 1'b0 ) begin
            r_cmd_picked_dispatcher <= 1'b1;
        end
        /* The refresh procedure is going on, we are in REF state and the cmd_dispatcher provide us a beautiful ACT, let's get it!!! :) */
        else if  ( need_refresh && refresh_present_state == LP_REF_REF && cmd_dispatcher == P_ROW_ACT && busy == 1'b0 && r_cmd_picked_dispatcher == 1'b0 ) begin
            r_cmd_picked_dispatcher <= 1'b1;
        end
        else begin
            r_cmd_picked_dispatcher <= 1'b0;
        end
    end
end

/************************/
/* CMD_INTER MANAGEMENT */
/************************/
/* Save the data and put the right data in case of refresh */
always @(posedge clk or negedge rst_n) begin
    if ( rst_n == 1'b0 ) begin
        cmd_inter <= P_GENERAL_NOP;
        bank_address_inter <= {P_BA_ADDR_WIDTH{1'b0}};
        row_address_inter <= {P_ROW_ADDR_WIDTH{1'b0}};
        column_address_inter <= {P_COL_ADDR_WIDTH{1'b0}};
        wrt_data_inter <= {P_DATA_WIDTH{1'b0}};
        req_id_inter <= {64{1'b1}};
        cmd_id_inter <= {64{1'b1}};
        ref_occurrences_cnt <= 32'd0;
    end
    else begin
        /* Tehse cases follow the cases of BUSY MANAGEMENT when fill the cmd_inter */
        if ( cmd_dispatcher != P_GENERAL_NOP && cmd_inter == P_GENERAL_NOP && ~need_refresh && busy == 1'b0 ) begin
            cmd_inter <= cmd_dispatcher;
            bank_address_inter <= bank_addr_dispatcher;
            row_address_inter <= row_addr_dispatcher;
            column_address_inter <= col_addr_dispatcher;
            wrt_data_inter <= wrt_data_dispatcher;
            req_id_inter <= req_id_dispatcher;
            cmd_id_inter <= cmd_id_dispatcher;
        end 
        else if ( ~need_refresh && busy == 1'b0 ) begin
            cmd_inter <= cmd_dispatcher;        /* Get the next command if the actual one can be served */
            bank_address_inter <= bank_addr_dispatcher;
            row_address_inter <= row_addr_dispatcher;
            column_address_inter <= col_addr_dispatcher;
            wrt_data_inter <= wrt_data_dispatcher;
            req_id_inter <= req_id_dispatcher;
            cmd_id_inter <= cmd_id_dispatcher;
        end
        else if ( busy == 1'b0 && need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter == P_GENERAL_NOP && active_row != {P_ROW_ADDR_WIDTH+1{1'b1}} ) begin
            cmd_inter <= P_ROW_PRE;
            cmd_id_inter <= 64'd0;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            bank_address_inter <= P_BANK_INDEX;
            column_address_inter <= column_address_inter;
            row_address_inter <= active_row;
        end
        else if ( busy == 1'b0 &&  need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter != P_ROW_PRE && cmd_inter != P_GENERAL_NOP ) begin
            cmd_inter <= P_ROW_PRE;
            cmd_id_inter <= 64'd0;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            bank_address_inter <= P_BANK_INDEX;
            column_address_inter <= column_address_inter;
            row_address_inter <= active_row;
        end

        else if ( busy == 1'b0 &&  need_refresh && refresh_present_state == LP_REF_IDLE && cmd_inter == P_GENERAL_NOP && active_row == {P_ROW_ADDR_WIDTH+1{1'b1}} ) begin
            cmd_inter <= P_ROW_REFPB;
            cmd_id_inter <= 64'd1;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            bank_address_inter <= P_BANK_INDEX;
            column_address_inter <= column_address_inter;
            row_address_inter <= active_row;

            ref_occurrences_cnt <= ref_occurrences_cnt + 1'b1;
        end

        else if ( need_refresh && refresh_present_state == LP_REF_PRE_WAIT && busy == 1'b0 && cmd_inter != P_ROW_PRE ) begin
            cmd_inter <= P_ROW_PRE;
            cmd_id_inter <= 64'd0;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            bank_address_inter <= P_BANK_INDEX;
            column_address_inter <= column_address_inter;
            row_address_inter <= active_row;
        end

        else if ( need_refresh && refresh_present_state == LP_REF_PRE_WAIT && busy == 1'b0 && cmd_inter == P_ROW_PRE ) begin
            cmd_inter <= P_ROW_REFPB;
            cmd_id_inter <= 64'd1;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            bank_address_inter <= P_BANK_INDEX;
            column_address_inter <= column_address_inter;
            row_address_inter <= active_row;

            ref_occurrences_cnt <= ref_occurrences_cnt + 1'b1;
        end

        else if ( need_refresh && refresh_present_state == LP_REF_REF && busy == 1'b0 && cmd_dispatcher != P_ROW_ACT && need_activate_after_refresh ) begin
            cmd_inter <= P_ROW_ACT;
            cmd_id_inter <= 64'd2;
            req_id_inter <= {P_BANK_INDEX, ref_occurrences_cnt, {27 {1'b1}}};
            bank_address_inter <= P_BANK_INDEX;
            column_address_inter <= column_address_inter;
            row_address_inter <= active_row;
        end

        else if ( need_refresh && refresh_present_state == LP_REF_REF && busy == 1'b0 && cmd_dispatcher == P_ROW_ACT ) begin
            cmd_inter <= cmd_dispatcher;
            bank_address_inter <= bank_addr_dispatcher;
            row_address_inter <= row_addr_dispatcher;
            column_address_inter <= col_addr_dispatcher;
            wrt_data_inter <= wrt_data_dispatcher;
            req_id_inter <= req_id_dispatcher;
            cmd_id_inter <= cmd_id_dispatcher;
        end
    end
end

/*************************/
/* ACTIVE ROW MANAGEMENT */
/*************************/
always @(posedge clk or negedge rst_n) begin
    if ( rst_n == 1'b0 ) begin
        active_row <= {P_ROW_ADDR_WIDTH+1{1'b1}};
    end
    else begin
        if ( r_cmd_bank == P_ROW_ACT && cmd_picked_bank ) begin
            active_row <= r_row_address_bank;
        end 
        else if ( r_cmd_bank == P_ROW_PRE && cmd_picked_bank ) begin
            active_row <= {P_ROW_ADDR_WIDTH+1{1'b1}};
        end
        else begin
            active_row <= active_row;
        end 
    end
end

/*******************************************/
/* ACT IS NEEDED AFTER REFRESH PROCEDURE ? */
/*******************************************/
always @(posedge clk or negedge rst_n) begin
    if ( rst_n == 1'b0 ) begin
        need_activate_after_refresh <= 1'b0;
    end
    else begin
        if ( refresh_present_state == LP_REF_IDLE && need_refresh && cmd_inter == P_ROW_PRE ) begin
            need_activate_after_refresh <= 1'b0;
        end
        else if ( refresh_present_state == LP_REF_IDLE && need_refresh && cmd_inter != P_ROW_PRE && cmd_inter != P_GENERAL_NOP) begin
            need_activate_after_refresh <= 1'b1;
        end
        else if ( refresh_present_state == LP_REF_IDLE && need_refresh && cmd_inter == P_GENERAL_NOP && active_row != {P_ROW_ADDR_WIDTH+1{1'b1}} ) begin
            need_activate_after_refresh <= 1'b1;
        end
    end
end


/***************************/
/* NEED REFRESH MANAGEMENT */
/***************************/
wire need_refresh_reset;
assign need_refresh_reset = (need_refresh == 1'b1) && (( refresh_present_state == LP_REF_REF && busy == 1'b0 && cmd_inter == P_ROW_REFPB && cmd_dispatcher == P_ROW_ACT) || (refresh_present_state == LP_REF_ACT && busy == 1'b0 && cmd_inter == P_ROW_ACT) || ( busy == 1'b0 && cmd_inter == P_ROW_REFPB && cmd_dispatcher != P_ROW_ACT && ~need_activate_after_refresh ) );
always @(posedge clk or negedge rst_n) begin
    if ( rst_n == 1'b0 ) begin
        need_refresh <= 1'b0;
    end
    else begin
        /* need_refresh is set when time is up, we are in normal execution and the last refresh is obviously served... */
        if ( last_ref_cnt >= tREFP && need_refresh == 1'b0 && waiting_for_ref_serve == 2'b00 ) begin
            need_refresh <= 1'b1;
        end
        else if (need_refresh_reset) begin
            need_refresh <= 1'b0;
        end
        else begin
            need_refresh <= need_refresh;
        end
    end
end


/********************************/
/* REFRESH FINITE STATE MACHINE */
/********************************/
always @(posedge clk or negedge rst_n) begin
    if ( rst_n == 1'b0 ) begin
        refresh_present_state <= LP_REF_IDLE;
    end
    else begin
        refresh_present_state <= refresh_next_state;
    end
end

always @( * ) begin
    case( refresh_present_state )
        LP_REF_IDLE:
        begin
            if( need_refresh ) begin
                if ( active_row != {P_ROW_ADDR_WIDTH+1{1'b1}} || cmd_inter != P_GENERAL_NOP ) begin
                    refresh_next_state <= LP_REF_PRE_WAIT;
                end
                else begin
                    refresh_next_state <= LP_REF_REF;
                end 
            end
            else begin
                refresh_next_state <= refresh_present_state;
            end
        end
        LP_REF_PRE_WAIT:
        begin
            if ( busy == 1'b0 && cmd_inter == P_ROW_PRE ) begin
                refresh_next_state <= LP_REF_REF;
            end
            else begin
                refresh_next_state <= refresh_present_state;
            end           
        end
        LP_REF_REF:
        begin
            if ( busy == 1'b0 && cmd_inter == P_ROW_REFPB && cmd_dispatcher != P_ROW_ACT && need_activate_after_refresh ) begin
                refresh_next_state <= LP_REF_ACT;
            end

            else if ( busy == 1'b0 && cmd_inter == P_ROW_REFPB && cmd_dispatcher != P_ROW_ACT && ~need_activate_after_refresh) begin
                refresh_next_state <= LP_REF_IDLE;
            end
            
            else if ( busy == 1'b0 && cmd_inter == P_ROW_REFPB && cmd_dispatcher == P_ROW_ACT) begin
                refresh_next_state <= LP_REF_IDLE;
            end

            else begin
                refresh_next_state <= refresh_present_state;
            end
        end
        LP_REF_ACT:
        begin
            if ( busy == 1'b0 && cmd_inter == P_ROW_ACT ) begin
                refresh_next_state <= LP_REF_IDLE;
            end
            else begin
                refresh_next_state <= refresh_present_state;
            end
        end
    endcase
end

/***********************/
/* COUNTERS MANAGEMENT */
/***********************/

/*******************/
/* REFRESH COUNTER */
/*******************/
/* Last REFRESH counter driver */
always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_ref_cnt <= { 16 { 1'b0 } };
    end
    else begin
        if ( waiting_for_ref_serve == 2'b10 && served_ras ) begin
            last_ref_cnt <= { 16 { 1'b0 } };
        end
        else if (last_ref_cnt == {16{1'b1}}) begin
            last_ref_cnt <= last_ref_cnt;
        end
        else begin
            last_ref_cnt <= last_ref_cnt + 1'b1;
        end
    end
end
/* Waiting for REF serve management */
always @ ( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        waiting_for_ref_serve <=  2'b00;
    end
    else begin
        if (r_cmd_bank == P_ROW_REFPB && waiting_for_ref_serve == 2'b00 && ~cmd_picked_bank) begin
            waiting_for_ref_serve <= 2'b01;
        end
        else if (r_cmd_bank == P_ROW_REFPB && waiting_for_ref_serve == 2'b00 && cmd_picked_bank) begin
            waiting_for_ref_serve <= 2'b10;
        end
        else if ( cmd_picked_bank && (r_cmd_bank == P_ROW_REFPB) && waiting_for_ref_serve == 2'b01 ) begin
            waiting_for_ref_serve <= 2'b10;
        end
        else if (waiting_for_ref_serve == 2'b10 && served_ras) begin
            waiting_for_ref_serve <=  2'b00;
        end
        else begin
            waiting_for_ref_serve <= waiting_for_ref_serve;
        end
    end
end

/********************/
/* ACTIVATE COUNTER */
/********************/
/* Last ACTIVATE counter driver */
always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_act_cnt <= { 8 { 1'b0 } };
    end
    else begin
        if ( waiting_for_act_serve == 2'b10 && served_ras ) begin
            last_act_cnt <= { 8 { 1'b0 } };
        end
        else if (last_act_cnt == {8{1'b1}}) begin
            last_act_cnt <= last_act_cnt;
        end
        else begin
            last_act_cnt <= last_act_cnt + 1'b1;
        end
    end
end
/* Waiting for ACT serve management */
always @ ( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        waiting_for_act_serve <=  2'b00;
    end
    else begin
        if (r_cmd_bank == P_ROW_ACT && waiting_for_act_serve == 2'b00 && ~cmd_picked_bank) begin
            waiting_for_act_serve <= 2'b01;
        end
        else if (r_cmd_bank == P_ROW_ACT && waiting_for_act_serve == 2'b00 && cmd_picked_bank) begin
            waiting_for_act_serve <= 2'b10;
        end
        else if ( cmd_picked_bank && (r_cmd_bank == P_ROW_ACT) && waiting_for_act_serve == 2'b01 ) begin
            waiting_for_act_serve <= 2'b10;
        end
        else if (waiting_for_act_serve == 2'b10 && served_ras) begin
            waiting_for_act_serve <=  2'b00;
        end
        else begin
            waiting_for_act_serve <= waiting_for_act_serve;
        end
    end
end

/*********************/
/* PRECHARGE COUNTER */
/*********************/
/* Last PRECHARGE counter driver */
always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_pre_cnt <= { 8 { 1'b0 } };
    end
    else begin
        if ( waiting_for_pre_serve == 2'b10 && served_ras ) begin
            last_pre_cnt <= { 8 { 1'b0 } };
        end
        else if (last_pre_cnt == {8{1'b1}}) begin
            last_pre_cnt <= last_pre_cnt;
        end
        else begin
            last_pre_cnt <= last_pre_cnt + 1'b1;
        end
    end
end
/* Waiting for PRE serve management */
always @ ( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        waiting_for_pre_serve <=  2'b00;
    end
    else begin
        if (r_cmd_bank == P_ROW_PRE && waiting_for_pre_serve == 2'b00 && ~cmd_picked_bank) begin
            waiting_for_pre_serve <= 2'b01;
        end
        else if (r_cmd_bank == P_ROW_PRE && waiting_for_pre_serve == 2'b00 && cmd_picked_bank) begin
            waiting_for_pre_serve <= 2'b10;
        end
        else if ( cmd_picked_bank && (r_cmd_bank == P_ROW_PRE) && waiting_for_pre_serve == 2'b01 ) begin
            waiting_for_pre_serve <= 2'b10;
        end
        else if (waiting_for_pre_serve == 2'b10 && served_ras) begin
            waiting_for_pre_serve <=  2'b00;
        end
        else begin
            waiting_for_pre_serve <= waiting_for_pre_serve;
        end
    end
end

/****************/
/* READ COUNTER */
/****************/
/* Last READ counter driver */
always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_rd_cnt <= { 8 { 1'b0 } };
    end
    else begin
        if ( waiting_for_rd_serve == 2'b10 && served_cas ) begin
            last_rd_cnt <= { 8 { 1'b0 } };
        end
        else if (last_rd_cnt == {8{1'b1}}) begin
            last_rd_cnt <= last_rd_cnt;
        end
        else begin
            last_rd_cnt <= last_rd_cnt + 1'b1;
        end
    end
end
/* Waiting for RD serve management */
always @ ( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        waiting_for_rd_serve <=  2'b00;
    end
    else begin
        if (r_cmd_bank == P_COL_RD && waiting_for_rd_serve == 2'b00 && ~cmd_picked_bank) begin
            waiting_for_rd_serve <= 2'b01;
        end
        else if (r_cmd_bank == P_COL_RD && waiting_for_rd_serve == 2'b00 && cmd_picked_bank) begin
            waiting_for_rd_serve <= 2'b10;
        end
        else if ( cmd_picked_bank && (r_cmd_bank == P_COL_RD) && waiting_for_rd_serve == 2'b01 ) begin
            waiting_for_rd_serve <= 2'b10;
        end
        else if (waiting_for_rd_serve == 2'b10 && served_cas) begin
            waiting_for_rd_serve <=  2'b00;
        end
        else begin
            waiting_for_rd_serve <= waiting_for_rd_serve;
        end
    end
end

/*****************/
/* WRITE COUNTER */
/*****************/
/* Last WRITE counter driver */
always @ ( negedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        last_wrt_cnt <= { 8 { 1'b0 } };
    end
    else begin
        if ( waiting_for_wrt_serve == 2'b10 && served_cas ) begin
            last_wrt_cnt <= { 8 { 1'b0 } };
        end
        else if (last_wrt_cnt == {8{1'b1}}) begin
            last_wrt_cnt <= last_wrt_cnt;
        end
        else begin
            last_wrt_cnt <= last_wrt_cnt + 1'b1;
        end
    end
end
/* Waiting for WRT serve management */
always @ ( posedge clk or negedge rst_n ) begin
    if (rst_n == 1'b0) begin
        waiting_for_wrt_serve <=  2'b00;
    end
    else begin
        if (r_cmd_bank == P_COL_WRT && waiting_for_wrt_serve == 2'b00 && ~cmd_picked_bank) begin
            waiting_for_wrt_serve <= 2'b01;
        end
        else if (r_cmd_bank == P_COL_WRT && waiting_for_wrt_serve == 2'b00 && cmd_picked_bank) begin
            waiting_for_wrt_serve <= 2'b10;
        end
        else if ( cmd_picked_bank && (r_cmd_bank == P_COL_WRT) && waiting_for_wrt_serve == 2'b01 ) begin
            waiting_for_wrt_serve <= 2'b10;
        end
        else if (waiting_for_wrt_serve == 2'b10 && served_cas) begin
            waiting_for_wrt_serve <=  2'b00;
        end
        else begin
            waiting_for_wrt_serve <= waiting_for_wrt_serve;
        end
    end
end


endmodule