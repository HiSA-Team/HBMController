`timescale 1ps/1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"

/******************************************************************************/
/* NMP ADDRESS GENERATOR                                                      */
/*                                                                            */
/* Walks a contiguous region of block indices [base, base + n_blk) and issues */
/* one read request per block on the request port of HBM_channel_controller.  */
/*                                                                            */
/* Port contract (as exercised by HBM_controller_top_tb):                     */
/*   - request_valid_o is held with a stable address/id until the controller  */
/*     answers request_picked_i (registered ack, one cycle after sampling);   */
/*   - the bus is still stable in the picked cycle (the CAS RAMs are written  */
/*     in that cycle with {request_id, bank[3:0]} taken from the bus);        */
/*   - the next request is presented on the edge where picked is seen, so at  */
/*     most one request every two cycles is accepted;                         */
/*   - request_id_o increments by one on every accepted request.              */
/*                                                                            */
/* Flow control: the unit may not have more than P_NMP_INFLIGHT_MAX blocks    */
/* issued-and-not-yet-consumed (credit_return_i = beats consumed per cycle).  */
/* Because consecutive blocks alternate PS0/PS1 this also bounds the reads in */
/* flight per PS to P_RD_ID_BUFFER_LEN, the controller's limit, and the       */
/* tokens in flight to a window of 18, the token table's assumption.          */
/******************************************************************************/

module nmp_address_generator (
    input  logic                              clock_i,
    input  logic                              reset_ni,

    /* Job */
    input  logic                              start_i,          /* one cycle pulse                       */
    input  logic [P_NMP_BLK_ADDR_WIDTH-1:0]   base_blk_i,       /* first block index of the region       */
    input  logic [P_NMP_BLK_ADDR_WIDTH-1:0]   n_blk_i,          /* number of blocks to read              */
    output logic                              busy_o,           /* requests still to be issued           */
    output logic                              done_o,           /* one cycle pulse: last request accepted*/

    /* Flow control from the consumer */
    input  logic [1:0]                        credit_return_i,  /* beats consumed downstream this cycle (0..2) */
    output logic [P_NMP_INFLIGHT_WIDTH:0]     outstanding_o,    /* issued - consumed                     */
    output logic [P_REQ_ID_WIDTH-1:0]         next_req_id_o,    /* id that the next request will carry   */

    /* HBM_channel_controller request port */
    output logic [31:0]                       address_o,
    output logic [P_REQ_WIDTH-1:0]            request_o,
    output logic [P_REQ_ID_WIDTH-1:0]         request_id_o,
    output logic                              request_valid_o,
    input  logic                              request_picked_i,

    /* Statistics (cycles) */
    output logic [31:0]                       stall_credit_cnt_o, /* cycles with a request ready but no credit */
    output logic [31:0]                       wait_picked_cnt_o   /* cycles with request_valid high and no picked */
);

/* Region walk */
logic [P_NMP_BLK_ADDR_WIDTH-1:0]   r_blk;            /* block index of the request on the bus / next one */
logic [P_NMP_BLK_ADDR_WIDTH-1:0]   r_remaining;      /* blocks still to be presented                    */
logic                              r_busy;
logic                              r_done;

/* Request bus */
logic                              r_request_valid;
logic [31:0]                       r_address;
logic [P_REQ_ID_WIDTH-1:0]         r_request_id;

/* Credits */
logic [P_NMP_INFLIGHT_WIDTH:0]     r_outstanding;
logic                              has_credit;
logic                              accepted;

logic [P_NMP_INFLIGHT_WIDTH:0]     outstanding_next;
logic [P_NMP_INFLIGHT_WIDTH:0]     credits_in;

assign accepted         = r_request_valid & request_picked_i;
assign credits_in       = ( { { (P_NMP_INFLIGHT_WIDTH-1) { 1'b0 } }, credit_return_i } > r_outstanding ) ? r_outstanding : { { (P_NMP_INFLIGHT_WIDTH-1) { 1'b0 } }, credit_return_i };
/* Value after this edge: the request accepted now is counted, the beats consumed now are not */
assign outstanding_next = r_outstanding + { { P_NMP_INFLIGHT_WIDTH { 1'b0 } }, accepted } - credits_in;
assign has_credit       = ( outstanding_next < P_NMP_INFLIGHT_MAX[P_NMP_INFLIGHT_WIDTH:0] );

assign address_o       = r_address;
assign request_o       = P_RD_REQ;                                            /* v0: read only */
assign request_id_o    = r_request_id;
assign request_valid_o = r_request_valid;
assign busy_o          = r_busy;
assign done_o          = r_done;
assign outstanding_o   = r_outstanding;
assign next_req_id_o   = r_request_id;

/********************************/
/* OUTSTANDING (CREDIT) COUNTER */
/********************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_outstanding <= { P_NMP_INFLIGHT_WIDTH+1 { 1'b0 } };
    end
    else begin
        r_outstanding <= outstanding_next;
    end
end

/*******************************/
/* REGION WALK AND REQUEST BUS */
/*******************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_blk           <= { P_NMP_BLK_ADDR_WIDTH { 1'b0 } };
        r_remaining     <= { P_NMP_BLK_ADDR_WIDTH { 1'b0 } };
        r_busy          <= 1'b0;
        r_done          <= 1'b0;
        r_request_valid <= 1'b0;
        r_address       <= 32'd0;
        r_request_id    <= { P_REQ_ID_WIDTH { 1'b0 } };
    end
    else begin
        r_done <= 1'b0;

        if ( start_i && ~r_busy ) begin
            /* Latch the job; the first request is presented on the next edge */
            r_blk           <= base_blk_i;
            r_remaining     <= n_blk_i;
            r_busy          <= (n_blk_i != { P_NMP_BLK_ADDR_WIDTH { 1'b0 } });
            r_request_valid <= 1'b0;
        end
        else if ( r_busy ) begin
            if ( accepted ) begin
                /* The request on the bus has just been accepted: advance the id
                   and present the next block, if any, on this same edge */
                r_request_id <= r_request_id + 1'b1;
                if ( r_remaining == { P_NMP_BLK_ADDR_WIDTH { 1'b0 } } ) begin
                    r_request_valid <= 1'b0;
                    r_busy          <= 1'b0;
                    r_done          <= 1'b1;
                end
                else if ( has_credit ) begin
                    r_address       <= f_nmp_blk_to_addr(r_blk);
                    r_blk           <= r_blk + 1'b1;
                    r_remaining     <= r_remaining - 1'b1;
                    r_request_valid <= 1'b1;
                end
                else begin
                    r_request_valid <= 1'b0;                              /* wait for credits */
                end
            end
            else if ( ~r_request_valid ) begin
                /* Nothing on the bus: present the next block when credits allow */
                if ( r_remaining == { P_NMP_BLK_ADDR_WIDTH { 1'b0 } } ) begin
                    r_busy <= 1'b0;
                    r_done <= 1'b1;
                end
                else if ( has_credit ) begin
                    r_address       <= f_nmp_blk_to_addr(r_blk);
                    r_blk           <= r_blk + 1'b1;
                    r_remaining     <= r_remaining - 1'b1;
                    r_request_valid <= 1'b1;
                end
            end
            /* else: request on the bus, waiting for request_picked_i */
        end
    end
end

/**************/
/* STATISTICS */
/**************/
/* Every request spends one structural cycle on the bus before the registered
   picked arrives: that cycle is not counted. wait_picked_cnt_o counts only the
   extra cycles (bank queue not empty, refresh, ...). */
logic r_valid_d;
logic r_accepted_d;

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_valid_d          <= 1'b0;
        r_accepted_d       <= 1'b0;
        stall_credit_cnt_o <= 32'd0;
        wait_picked_cnt_o  <= 32'd0;
    end
    else begin
        r_valid_d    <= r_request_valid;
        r_accepted_d <= accepted;
        if ( start_i && ~r_busy ) begin
            stall_credit_cnt_o <= 32'd0;
            wait_picked_cnt_o  <= 32'd0;
        end
        else begin
            if ( r_busy && ~r_request_valid && ~has_credit && r_remaining != { P_NMP_BLK_ADDR_WIDTH { 1'b0 } } ) begin
                stall_credit_cnt_o <= stall_credit_cnt_o + 1'b1;
            end
            if ( r_request_valid && ~request_picked_i && r_valid_d && ~r_accepted_d ) begin
                wait_picked_cnt_o <= wait_picked_cnt_o + 1'b1;
            end
        end
    end
end

endmodule
