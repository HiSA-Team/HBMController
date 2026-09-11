`timescale 1ps/1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"

/******************************************************************************/
/* NMP TOKEN TABLE (K pass)                                                   */
/*                                                                            */
/* Accumulators for the tokens that have at least one beat in flight. Beats   */
/* of a token arrive in any order and interleaved with other tokens; each one */
/* adds its partial (the sum of 16 aligned products) to the entry of its      */
/* token and sets the bit of its block. When all 8 bits are set the score is  */
/* complete: it goes out through a small queue and the entry is freed.        */
/*                                                                            */
/* The entry is t mod P_NMP_TOK_TABLE_LEN. The address generator keeps at     */
/* most P_NMP_INFLIGHT_MAX beats issued-and-not-consumed, i.e. the tokens in  */
/* flight span at most 18 consecutive values, so 32 entries never collide.    */
/*                                                                            */
/* Two input ports (one per PS). Both may hit the same entry in the same      */
/* cycle: the entry then takes both partials. Two different tokens may also   */
/* complete in the same cycle: the queue absorbs it and drains one per cycle. */
/******************************************************************************/

module nmp_token_table (
    input  logic                              clock_i,
    input  logic                              reset_ni,

    input  logic                              clear_i,          /* start of the pass: free all entries   */

    /* Port 0 (PS0) */
    input  logic                              in0_valid_i,
    input  logic [P_NMP_SEQ_WIDTH-1:0]        in0_tok_i,
    input  logic [P_NMP_BLK_IDX_WIDTH-1:0]    in0_blk_i,
    input  logic signed [P_NMP_ACC_W-1:0]     in0_partial_i,

    /* Port 1 (PS1) */
    input  logic                              in1_valid_i,
    input  logic [P_NMP_SEQ_WIDTH-1:0]        in1_tok_i,
    input  logic [P_NMP_BLK_IDX_WIDTH-1:0]    in1_blk_i,
    input  logic signed [P_NMP_ACC_W-1:0]     in1_partial_i,

    /* Completed scores, one per cycle */
    output logic                              score_valid_o,
    output logic [P_NMP_SEQ_WIDTH-1:0]        score_tok_o,
    output logic signed [P_NMP_ACC_W-1:0]     score_acc_o,

    output logic                              queue_overflow_o  /* sticky: a completed score was lost   */
);

localparam LP_QUEUE_LEN   = 4;
localparam LP_QUEUE_WIDTH = $clog2(LP_QUEUE_LEN);

/* Table (packed: entry e at [e*W +: W]) */
logic [P_NMP_TOK_TABLE_LEN*P_NMP_ACC_W-1:0]        r_acc;
logic [P_NMP_TOK_TABLE_LEN*P_NMP_BLK_PER_ROW-1:0]  r_mask;
logic signed [P_NMP_ACC_W-1:0]        acc0;
logic signed [P_NMP_ACC_W-1:0]        acc1;
logic [P_NMP_BLK_PER_ROW-1:0]         mask0;
logic [P_NMP_BLK_PER_ROW-1:0]         mask1;

/* Entry selection */
logic [P_NMP_TOK_TABLE_WIDTH-1:0]     e0;
logic [P_NMP_TOK_TABLE_WIDTH-1:0]     e1;
logic                                 same;
logic signed [P_NMP_ACC_W-1:0]        base0;
logic signed [P_NMP_ACC_W-1:0]        base1;
logic signed [P_NMP_ACC_W-1:0]        next0;
logic signed [P_NMP_ACC_W-1:0]        next1;
logic [P_NMP_BLK_PER_ROW-1:0]         bit0;
logic [P_NMP_BLK_PER_ROW-1:0]         bit1;
logic [P_NMP_BLK_PER_ROW-1:0]         mask0_next;
logic [P_NMP_BLK_PER_ROW-1:0]         mask1_next;
logic                                 done0;
logic                                 done1;

assign e0    = in0_tok_i[P_NMP_TOK_TABLE_WIDTH-1:0];
assign e1    = in1_tok_i[P_NMP_TOK_TABLE_WIDTH-1:0];
assign acc0  = r_acc [e0*P_NMP_ACC_W       +: P_NMP_ACC_W];
assign acc1  = r_acc [e1*P_NMP_ACC_W       +: P_NMP_ACC_W];
assign mask0 = r_mask[e0*P_NMP_BLK_PER_ROW +: P_NMP_BLK_PER_ROW];
assign mask1 = r_mask[e1*P_NMP_BLK_PER_ROW +: P_NMP_BLK_PER_ROW];
assign same  = in0_valid_i & in1_valid_i & ( e0 == e1 );
assign bit0  = P_NMP_BLK_PER_ROW'(1) << in0_blk_i;
assign bit1  = P_NMP_BLK_PER_ROW'(1) << in1_blk_i;

/* A free entry (mask = 0) starts from zero, whatever its old accumulator holds */
assign base0 = ( mask0 == { P_NMP_BLK_PER_ROW { 1'b0 } } ) ? { P_NMP_ACC_W { 1'b0 } } : acc0;
assign base1 = ( mask1 == { P_NMP_BLK_PER_ROW { 1'b0 } } ) ? { P_NMP_ACC_W { 1'b0 } } : acc1;

assign next0      = base0 + in0_partial_i + ( same ? in1_partial_i : { P_NMP_ACC_W { 1'b0 } } );
assign next1      = base1 + in1_partial_i;
assign mask0_next = mask0 | bit0 | ( same ? bit1 : { P_NMP_BLK_PER_ROW { 1'b0 } } );
assign mask1_next = mask1 | bit1;

assign done0 = in0_valid_i & ( mask0_next == { P_NMP_BLK_PER_ROW { 1'b1 } } );
assign done1 = in1_valid_i & ~same & ( mask1_next == { P_NMP_BLK_PER_ROW { 1'b1 } } );

/*******************************/
/* TABLE UPDATE                */
/*******************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_acc  <= { P_NMP_TOK_TABLE_LEN*P_NMP_ACC_W { 1'b0 } };
        r_mask <= { P_NMP_TOK_TABLE_LEN*P_NMP_BLK_PER_ROW { 1'b0 } };
    end
    else begin
        if ( clear_i ) begin
            r_mask <= { P_NMP_TOK_TABLE_LEN*P_NMP_BLK_PER_ROW { 1'b0 } };
        end
        else begin
            if ( in0_valid_i ) begin
                r_acc [e0*P_NMP_ACC_W       +: P_NMP_ACC_W]       <= next0;
                r_mask[e0*P_NMP_BLK_PER_ROW +: P_NMP_BLK_PER_ROW] <= done0 ? { P_NMP_BLK_PER_ROW { 1'b0 } } : mask0_next;   /* complete: free the entry */
            end
            if ( in1_valid_i && ~same ) begin
                r_acc [e1*P_NMP_ACC_W       +: P_NMP_ACC_W]       <= next1;
                r_mask[e1*P_NMP_BLK_PER_ROW +: P_NMP_BLK_PER_ROW] <= done1 ? { P_NMP_BLK_PER_ROW { 1'b0 } } : mask1_next;
            end
        end
    end
end

/*******************************/
/* COMPLETED SCORE QUEUE       */
/*******************************/
logic [LP_QUEUE_LEN*P_NMP_SEQ_WIDTH-1:0]  q_tok;                       /* packed: slot k at [k*W +: W] */
logic [LP_QUEUE_LEN*P_NMP_ACC_W-1:0]      q_acc;
logic [LP_QUEUE_WIDTH-1:0]            q_head_p1;
logic [LP_QUEUE_WIDTH-1:0]            q_head;                             /* next slot to write */
logic [LP_QUEUE_WIDTH-1:0]            q_tail;                             /* next slot to read  */
logic [LP_QUEUE_WIDTH:0]              q_cnt;
logic [1:0]                           n_push;
logic                                 pop;

assign n_push    = { 1'b0, done0 } + { 1'b0, done1 };
assign pop       = ( q_cnt != { (LP_QUEUE_WIDTH+1) { 1'b0 } } );
assign q_head_p1 = q_head + 1'b1;

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        q_head           <= { LP_QUEUE_WIDTH { 1'b0 } };
        q_tail           <= { LP_QUEUE_WIDTH { 1'b0 } };
        q_cnt            <= { (LP_QUEUE_WIDTH+1) { 1'b0 } };
        score_valid_o    <= 1'b0;
        score_tok_o      <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        score_acc_o      <= { P_NMP_ACC_W { 1'b0 } };
        queue_overflow_o <= 1'b0;
        q_tok            <= { LP_QUEUE_LEN*P_NMP_SEQ_WIDTH { 1'b0 } };
        q_acc            <= { LP_QUEUE_LEN*P_NMP_ACC_W { 1'b0 } };
    end
    else begin
        score_valid_o <= 1'b0;
        if ( clear_i ) begin
            q_head <= { LP_QUEUE_WIDTH { 1'b0 } };
            q_tail <= { LP_QUEUE_WIDTH { 1'b0 } };
            q_cnt  <= { (LP_QUEUE_WIDTH+1) { 1'b0 } };
        end
        else begin
            /* push up to two completed scores */
            if ( done0 && done1 ) begin
                q_tok[q_head    * P_NMP_SEQ_WIDTH +: P_NMP_SEQ_WIDTH] <= in0_tok_i;
                q_acc[q_head    * P_NMP_ACC_W     +: P_NMP_ACC_W]     <= next0;
                q_tok[q_head_p1 * P_NMP_SEQ_WIDTH +: P_NMP_SEQ_WIDTH] <= in1_tok_i;
                q_acc[q_head_p1 * P_NMP_ACC_W     +: P_NMP_ACC_W]     <= next1;
                q_head <= q_head + 2'd2;
            end
            else if ( done0 ) begin
                q_tok[q_head * P_NMP_SEQ_WIDTH +: P_NMP_SEQ_WIDTH] <= in0_tok_i;
                q_acc[q_head * P_NMP_ACC_W     +: P_NMP_ACC_W]     <= next0;
                q_head <= q_head + 1'b1;
            end
            else if ( done1 ) begin
                q_tok[q_head * P_NMP_SEQ_WIDTH +: P_NMP_SEQ_WIDTH] <= in1_tok_i;
                q_acc[q_head * P_NMP_ACC_W     +: P_NMP_ACC_W]     <= next1;
                q_head <= q_head + 1'b1;
            end
            /* pop one per cycle */
            if ( pop ) begin
                score_valid_o <= 1'b1;
                score_tok_o   <= q_tok[q_tail * P_NMP_SEQ_WIDTH +: P_NMP_SEQ_WIDTH];
                score_acc_o   <= q_acc[q_tail * P_NMP_ACC_W     +: P_NMP_ACC_W];
                q_tail        <= q_tail + 1'b1;
            end
            q_cnt <= q_cnt + { { (LP_QUEUE_WIDTH-1) { 1'b0 } }, n_push } - { { LP_QUEUE_WIDTH { 1'b0 } }, pop };
            if ( q_cnt + { { (LP_QUEUE_WIDTH-1) { 1'b0 } }, n_push } - { { LP_QUEUE_WIDTH { 1'b0 } }, pop } > LP_QUEUE_LEN ) begin
                queue_overflow_o <= 1'b1;
            end
        end
    end
end

`ifdef DEBUG
always @ ( posedge clock_i ) begin
    if ( reset_ni == 1'b1 && ~clear_i ) begin
        if ( in0_valid_i && mask0[in0_blk_i] ) begin
            $display("[ NMP TABLE ]: ERROR PS0 block %0d of token %0d received twice at %0t", in0_blk_i, in0_tok_i, $time);
        end
        if ( in1_valid_i && mask1[in1_blk_i] ) begin
            $display("[ NMP TABLE ]: ERROR PS1 block %0d of token %0d received twice at %0t", in1_blk_i, in1_tok_i, $time);
        end
    end
end
`endif

endmodule
