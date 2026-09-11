`timescale 1ps/1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"

/******************************************************************************/
/* NMP HEAD ENGINE (v1)                                                       */
/*                                                                            */
/* One attention head of one decode step, on one DFI channel:                 */
/*                                                                            */
/*   IDLE -> PASS_K -> SOFTMAX_EXP -> PASS_V -> NORMALIZE -> DONE              */
/*                                                                            */
/*   PASS_K      : stream K_h (8 blocks per token from base_k_blk); every     */
/*                 beat is consumed when it arrives, in any order; the token   */
/*                 table sums the 8 partials of a token, the result is scaled */
/*                 by C = log2(e)/sqrt(d) into s' (Q15.16); the running        */
/*                 maximum m' is kept while the scores go into the buffer     */
/*   SOFTMAX_EXP : scan the buffer, s'_t <- p_t = 2^(s'_t - m') in Q1.31,     */
/*                 l = sum_t p_t as a plain integer (nmp_exp2, 3 cycles)      */
/*   PASS_V      : stream V_h (from base_v_blk), o += p_t * v_t, any order    */
/*   NORMALIZE   : o[i] / l streamed out on o_valid_o / o_idx_o / o_o         */
/*                                                                            */
/* Each pseudo-channel has its own lane array: the two beats that may return  */
/* in the same cycle are processed in the same cycle. PS0 returns the even    */
/* blocks of a token and PS1 the odd ones.                                    */
/*                                                                            */
/* q_h is written beforehand through the q_wr_* port (8 beats of 16 fp16).    */
/* The engine owns the request port of its channel: reads only in v1, the     */
/* KV cache is written by the host / testbench.                               */
/******************************************************************************/

module nmp_head_engine (
    input  logic                              clock_i,
    input  logic                              reset_ni,

    /* q_h load: 8 x 256 bit, chunk j holds q[16j .. 16j+15] */
    input  logic                              q_wr_en_i,
    input  logic [P_NMP_BLK_IDX_WIDTH-1:0]    q_wr_idx_i,
    input  logic [P_DATA_WIDTH-1:0]           q_wr_data_i,

    /* Job */
    input  logic                              start_i,
    input  logic [P_NMP_BLK_ADDR_WIDTH-1:0]   base_k_blk_i,     /* first block of K_h (even)             */
    input  logic [P_NMP_BLK_ADDR_WIDTH-1:0]   base_v_blk_i,     /* first block of V_h (even)             */
    input  logic [P_NMP_SEQ_WIDTH-1:0]        seq_len_i,        /* S = tokens in the context (1 .. 2048) */
    output logic                              busy_o,
    output logic                              done_o,           /* one cycle pulse after the last o      */

    /* Head output o_h = softmax(q.K^T/sqrt(d)).V, fp32, one element per cycle */
    output logic                              o_valid_o,
    output logic [P_NMP_OUT_IDX_WIDTH-1:0]    o_idx_o,
    output logic [P_NMP_F32_WIDTH-1:0]        o_o,

    /* HBM_channel_controller request port */
    output logic [31:0]                       address_o,
    output logic [P_REQ_WIDTH-1:0]            request_o,
    output logic [P_DATA_WIDTH-1:0]           write_data_o,
    output logic [P_REQ_ID_WIDTH-1:0]         request_id_o,
    output logic                              request_valid_o,
    input  logic                              request_picked_i,

    /* HBM_channel_controller read data */
    input  logic                              rd_data_valid_ps0_i,
    input  logic [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps0_i,
    input  logic [P_DATA_WIDTH-1:0]           rd_data_ps0_i,
    input  logic                              rd_data_valid_ps1_i,
    input  logic [P_REQ_ID_WIDTH-1:0]         rd_data_req_id_ps1_i,
    input  logic [P_DATA_WIDTH-1:0]           rd_data_ps1_i,

    /* Statistics (channel cycles) */
    output logic [31:0]                       cyc_pass_k_o,
    output logic [31:0]                       cyc_softmax_o,
    output logic [31:0]                       cyc_pass_v_o,
    output logic [31:0]                       cyc_total_o,
    output logic [31:0]                       stall_credit_cnt_o,
    output logic [31:0]                       wait_picked_cnt_o,
    output logic [31:0]                       starve_cnt_o,     /* pass cycles with no beat arriving      */
    output logic [31:0]                       n_beats_o,
    output logic [31:0]                       n_dropped_o,      /* returns outside the pass window        */
    output logic                              arith_overflow_o  /* sticky: an aligned product did not fit */
);

/* States */
localparam [2:0] S_IDLE        = 3'd0;
localparam [2:0] S_PASS_K      = 3'd1;
localparam [2:0] S_SOFTMAX_EXP = 3'd2;
localparam [2:0] S_PASS_V      = 3'd3;
localparam [2:0] S_NORMALIZE   = 3'd4;
localparam [2:0] S_DONE        = 3'd5;

// localparam real  LP_SCALE      = 0.08838834764831845;                 /* 1 / sqrt(P_NMP_D_HEAD), d = 128 */
localparam logic signed [32:0] LP_SCALE = 33'sh0_20A4_FB7B;              /* This is log2(e)/sqrt(d) with d = 128, notation Q0.32 + the signed bit */
localparam [3:0] LP_DRAIN      = 4'd8;                                   /* register stage + 4 lane stages + accumulators */

logic [2:0]                        r_state;

/* Job registers */
logic [P_NMP_BLK_ADDR_WIDTH-1:0]   r_base_k_blk;
logic [P_NMP_BLK_ADDR_WIDTH-1:0]   r_base_v_blk;
logic [P_NMP_SEQ_WIDTH-1:0]        r_seq_len;
logic [P_NMP_BLK_ADDR_WIDTH-1:0]   n_blk_pass;                  /* 8 * S */

assign n_blk_pass = { { (P_NMP_BLK_ADDR_WIDTH-P_NMP_SEQ_WIDTH-P_NMP_BLK_IDX_WIDTH) { 1'b0 } }, r_seq_len, { P_NMP_BLK_IDX_WIDTH { 1'b0 } } };

logic in_pass;
logic in_pass_v;
assign in_pass   = ( r_state == S_PASS_K ) || ( r_state == S_PASS_V );
assign in_pass_v = ( r_state == S_PASS_V );

/* q_h store */
logic [P_DATA_WIDTH-1:0]           r_q [0:P_NMP_BLK_PER_ROW-1];

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        for ( integer i = 0; i < P_NMP_BLK_PER_ROW; i = i + 1 ) begin
            r_q[i] <= { P_DATA_WIDTH { 1'b0 } };
        end
    end
    else begin
        if ( q_wr_en_i ) begin
            r_q[q_wr_idx_i] <= q_wr_data_i;
        end
    end
end

/*******************************/
/* ADDRESS GENERATOR           */
/*******************************/
logic                              ag_start;
logic [P_NMP_BLK_ADDR_WIDTH-1:0]   ag_base_blk;
logic                              ag_busy;
logic                              ag_done;
logic [P_NMP_INFLIGHT_WIDTH:0]     ag_outstanding;
logic [P_REQ_ID_WIDTH-1:0]         ag_next_req_id;
logic [1:0]                        credit_return;

nmp_address_generator u_address_generator (
    .clock_i            (clock_i),
    .reset_ni           (reset_ni),
    .start_i            (ag_start),
    .base_blk_i         (ag_base_blk),
    .n_blk_i            (n_blk_pass),
    .busy_o             (ag_busy),
    .done_o             (ag_done),
    .credit_return_i    (credit_return),
    .outstanding_o      (ag_outstanding),
    .next_req_id_o      (ag_next_req_id),
    .address_o          (address_o),
    .request_o          (request_o),
    .request_id_o       (request_id_o),
    .request_valid_o    (request_valid_o),
    .request_picked_i   (request_picked_i),
    .stall_credit_cnt_o (stall_credit_cnt_o),
    .wait_picked_cnt_o  (wait_picked_cnt_o)
);

assign write_data_o = { P_DATA_WIDTH { 1'b0 } };                 /* v1: no writes */

/*******************************/
/* BEAT DECODE (per PS)        */
/*******************************/
/* A returned beat belongs to the open pass if its offset (id - base id) is
   inside [0, n_blk) and on the PS its parity says. Anything else is dropped. */
logic [P_REQ_ID_WIDTH-1:0]         r_base_req_id;
logic                              r_pass_open;                 /* accept returns                   */
logic [P_REQ_ID_WIDTH-1:0]         off0;                        /* beat offset PS0                  */
logic [P_REQ_ID_WIDTH-1:0]         off1;                        /* beat pffset PS1                  */
logic                              acc0;                        /* beat on PS0 accepted this cycle  */
logic                              acc1;                        /* beat on PS1 accepted this cycle  */

logic [P_NMP_SEQ_WIDTH-1:0]        tok0;                        /* What token on PS0 */
logic [P_NMP_SEQ_WIDTH-1:0]        tok1;                        /* What token on PS1 */
logic [P_NMP_BLK_IDX_WIDTH-1:0]    blk0;                        /* What block on PS0 */
logic [P_NMP_BLK_IDX_WIDTH-1:0]    blk1;                        /* What block on PS1 */
logic                              drop0;
logic                              drop1;

assign off0  = rd_data_req_id_ps0_i - r_base_req_id;
assign off1  = rd_data_req_id_ps1_i - r_base_req_id;

/* Check if the beat can be accepted */
assign acc0  = rd_data_valid_ps0_i & r_pass_open & ( off0[P_NMP_BLK_ADDR_WIDTH-1:0] < n_blk_pass ) & ( off0[0] == 1'b0 );
assign acc1  = rd_data_valid_ps1_i & r_pass_open & ( off1[P_NMP_BLK_ADDR_WIDTH-1:0] < n_blk_pass ) & ( off1[0] == 1'b1 );

/* Beat dropped */
assign drop0 = rd_data_valid_ps0_i & ~acc0;
assign drop1 = rd_data_valid_ps1_i & ~acc1;

/* Actual token */
assign tok0  = off0[P_NMP_BLK_IDX_WIDTH +: P_NMP_SEQ_WIDTH];
assign tok1  = off1[P_NMP_BLK_IDX_WIDTH +: P_NMP_SEQ_WIDTH];

/* Actual block */
assign blk0  = off0[P_NMP_BLK_IDX_WIDTH-1:0];
assign blk1  = off1[P_NMP_BLK_IDX_WIDTH-1:0];

/* Credit to the address generator */
assign credit_return = { 1'b0, acc0 } + { 1'b0, acc1 };

/*******************************/
/* SCORE BUFFER (S x 32 bit)   */
/*******************************/
/* Holds s'_t in Q15.16 during PASS_K, then the softmax scan overwrites each
   entry in place with p_t in Q1.31. Same 32-bit word, two different formats:
   nothing in the buffer is fp32 any more.
   Two read ports: port 0 serves the softmax scan and PS0, port 1 serves PS1 */
logic [P_NMP_SCORE_ADDR_WIDTH-1:0] sb_read_addr_0;
logic [P_NMP_SCORE_ADDR_WIDTH-1:0] sb_read_addr_1;
logic [P_NMP_SCORE_ADDR_WIDTH-1:0] sb_write_addr;
logic [P_NMP_F32_WIDTH-1:0]        sb_data_in;
logic                              sb_wr_en;
logic [P_NMP_F32_WIDTH-1:0]        sb_data_out_0;
logic [P_NMP_F32_WIDTH-1:0]        sb_data_out_1;

dual_port_ram #(
    .DATA_WIDTH(P_NMP_F32_WIDTH),
    .ADDR_WIDTH(P_NMP_SCORE_ADDR_WIDTH)
)
score_buffer (
    .data_in(sb_data_in),
    .read_addr_0(sb_read_addr_0),
    .read_addr_1(sb_read_addr_1),
    .write_addr(sb_write_addr),
    .wr_en(sb_wr_en),
    .clk(clock_i),
    .data_out_0(sb_data_out_0),
    .data_out_1(sb_data_out_1)
);

/*******************************/
/* REGISTER STAGE (per PS)     */
/*******************************/
/* One register between the channel and the lane arrays, so that p_t, read
   from the score buffer with one cycle of latency, travels with its beat */
logic                              r_b0_valid;
logic [P_DATA_WIDTH-1:0]           r_b0_data;
logic [P_NMP_SEQ_WIDTH-1:0]        r_b0_tok;
logic [P_NMP_BLK_IDX_WIDTH-1:0]    r_b0_blk;
logic [P_DATA_WIDTH-1:0]           r_b0_q;
logic                              r_b1_valid;
logic [P_DATA_WIDTH-1:0]           r_b1_data;
logic [P_NMP_SEQ_WIDTH-1:0]        r_b1_tok;
logic [P_NMP_BLK_IDX_WIDTH-1:0]    r_b1_blk;
logic [P_DATA_WIDTH-1:0]           r_b1_q;
logic [P_NMP_BLK_ADDR_WIDTH-1:0]   r_beats_accepted;

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_b0_valid       <= 1'b0;
        r_b0_data        <= { P_DATA_WIDTH { 1'b0 } };
        r_b0_tok         <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r_b0_blk         <= { P_NMP_BLK_IDX_WIDTH { 1'b0 } };
        r_b0_q           <= { P_DATA_WIDTH { 1'b0 } };
        r_b1_valid       <= 1'b0;
        r_b1_data        <= { P_DATA_WIDTH { 1'b0 } };
        r_b1_tok         <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r_b1_blk         <= { P_NMP_BLK_IDX_WIDTH { 1'b0 } };
        r_b1_q           <= { P_DATA_WIDTH { 1'b0 } };
        r_beats_accepted <= { P_NMP_BLK_ADDR_WIDTH { 1'b0 } };
    end
    else begin
        r_b0_valid <= acc0;
        r_b0_data  <= rd_data_ps0_i;
        r_b0_tok   <= tok0;
        r_b0_blk   <= blk0;
        r_b0_q     <= r_q[blk0];
        r_b1_valid <= acc1;
        r_b1_data  <= rd_data_ps1_i;
        r_b1_tok   <= tok1;
        r_b1_blk   <= blk1;
        r_b1_q     <= r_q[blk1];
        if ( ag_start ) begin
            r_beats_accepted <= { P_NMP_BLK_ADDR_WIDTH { 1'b0 } };
        end
        else begin
            r_beats_accepted <= r_beats_accepted + { { (P_NMP_BLK_ADDR_WIDTH-2) { 1'b0 } }, credit_return };
        end
    end
end

/*******************************/
/* LANE ARRAYS (one per PS)    */
/*******************************/
logic                              la0_valid;
logic [P_NMP_SEQ_WIDTH-1:0]        la0_tok;
logic [P_NMP_BLK_IDX_WIDTH-1:0]    la0_blk;
logic                              la0_mode_v;
logic signed [P_NMP_ACC_W-1:0]     la0_partial;
logic [P_NMP_ELEM_PER_BEAT*P_NMP_ACC_W-1:0] la0_prod;
logic                              la0_overflow;
logic                              la1_valid;
logic [P_NMP_SEQ_WIDTH-1:0]        la1_tok;
logic [P_NMP_BLK_IDX_WIDTH-1:0]    la1_blk;
logic                              la1_mode_v;
logic signed [P_NMP_ACC_W-1:0]     la1_partial;
logic [P_NMP_ELEM_PER_BEAT*P_NMP_ACC_W-1:0] la1_prod;
logic                              la1_overflow;

nmp_lane_array u_lanes_ps0 (
    .clock_i      (clock_i),
    .reset_ni     (reset_ni),
    .beat_valid_i (r_b0_valid),
    .beat_data_i  (r_b0_data),
    .beat_tok_i   (r_b0_tok),
    .beat_blk_i   (r_b0_blk),
    .mode_v_i     (in_pass_v),
    .q_chunk_i    (r_b0_q),
    .p_fixed_i    (sb_data_out_0),                              /* p[tok0] of the beat now in r_b0_*, already Q1.31 */
    .out_valid_o  (la0_valid),
    .out_tok_o    (la0_tok),
    .out_blk_o    (la0_blk),
    .out_mode_v_o (la0_mode_v),
    .partial_o    (la0_partial),
    .prod_o       (la0_prod),
    .overflow_o   (la0_overflow)
);

nmp_lane_array u_lanes_ps1 (
    .clock_i      (clock_i),
    .reset_ni     (reset_ni),
    .beat_valid_i (r_b1_valid),
    .beat_data_i  (r_b1_data),
    .beat_tok_i   (r_b1_tok),
    .beat_blk_i   (r_b1_blk),
    .mode_v_i     (in_pass_v),
    .q_chunk_i    (r_b1_q),
    .p_fixed_i    (sb_data_out_1),
    .out_valid_o  (la1_valid),
    .out_tok_o    (la1_tok),
    .out_blk_o    (la1_blk),
    .out_mode_v_o (la1_mode_v),
    .partial_o    (la1_partial),
    .prod_o       (la1_prod),
    .overflow_o   (la1_overflow)
);

/*******************************/
/* TOKEN TABLE (K pass)        */
/*******************************/
logic                              tt_clear;
logic                              tt_score_valid;
logic [P_NMP_SEQ_WIDTH-1:0]        tt_score_tok;
logic signed [P_NMP_ACC_W-1:0]     tt_score_acc;
logic                              tt_queue_overflow;

nmp_token_table u_token_table (
    .clock_i          (clock_i),
    .reset_ni         (reset_ni),
    .clear_i          (tt_clear),
    .in0_valid_i      (la0_valid & ~la0_mode_v),
    .in0_tok_i        (la0_tok),
    .in0_blk_i        (la0_blk),
    .in0_partial_i    (la0_partial),
    .in1_valid_i      (la1_valid & ~la1_mode_v),
    .in1_tok_i        (la1_tok),
    .in1_blk_i        (la1_blk),
    .in1_partial_i    (la1_partial),
    .score_valid_o    (tt_score_valid),
    .score_tok_o      (tt_score_tok),
    .score_acc_o      (tt_score_acc),
    .queue_overflow_o (tt_queue_overflow)
);

/*******************************/
/* OUTPUT ACCUMULATORS (V pass)*/
/*******************************/
logic                              oa_clear;
logic [P_NMP_OUT_IDX_WIDTH-1:0]    oa_rd_idx;
logic signed [P_NMP_ACC_W-1:0]     oa_rd_acc;

nmp_output_acc u_output_acc (
    .clock_i     (clock_i),
    .reset_ni    (reset_ni),
    .clear_i     (oa_clear),
    .in0_valid_i (la0_valid & la0_mode_v),
    .in0_blk_i   (la0_blk),
    .in0_prod_i  (la0_prod),
    .in1_valid_i (la1_valid & la1_mode_v),
    .in1_blk_i   (la1_blk),
    .in1_prod_i  (la1_prod),
    .rd_idx_i    (oa_rd_idx),
    .rd_acc_o    (oa_rd_acc)
);


/******************************************************************************/
/* SCORE SCALING (K pass): accumulator -> s', fixed point                     */
/*                                                                            */
/* The token table hands out the exact integer dot product of one token,      */
/* acc = q . k_t, on the accumulator grid (Q31.32: value = acc / 2^32).       */
/* The softmax needs                                                          */
/*                                                                            */
/*     p_t = e^(s_t - m)          with  s_t = (q . k_t) / sqrt(d)             */
/*                                                                            */
/* which we compute in base 2, because 2^x costs a shift plus a small table   */
/* while e^x does not exist in hardware:                                      */
/*                                                                            */
/*     p_t = 2^(s'_t - m')        with  s'_t = acc_t * C,  C = log2(e)/sqrt(d)*/
/*                                                                            */
/* One constant absorbs both the model scale (1/sqrt(d)) and the change of    */
/* base (log2 e), because they multiply the same number. Applying it here,    */
/* at the output of the token table, costs ONE multiplier for the whole       */
/* engine: at most one score leaves the table per cycle.                      */
/*                                                                            */
/* Formats (Qm.n = m integer bits, n fractional bits, value = X / 2^n):       */
/*     tt_score_acc  Q31.32  signed, 64 bit   (the accumulator grid)          */
/*     LP_SCALE      Q0.32   unsigned value, carried in a 33-bit signed word  */
/*     product       Q32.64  signed, 97 bit   (fractional bits add up)        */
/*     score_scaled  Q15.16  signed, 32 bit   (+-32768, step 2^-16)           */
/*                                                                            */
/* Hence the right shift of 32 + 32 - 16 = 48 bits. The 97-bit intermediate   */
/* is mandatory: the product of a 36-bit accumulator by a 30-bit constant     */
/* already needs 65 bits, and SystemVerilog would size the multiply from the  */
/* assignment context, silently wrapping it.                                  */
/*                                                                            */
/* Every operand is signed so that >>> propagates the sign on its own. The    */
/* shift truncates toward -infinity (floor), which is what the Python         */
/* reference does too, so the two stay bit exact.                             */
/*                                                                            */
/* s' saturates for |q . k_t| > ~2.6e5, far above anything an LLM produces    */
/* but reachable with synthetic stress vectors: the sticky flag reports it.   */
/******************************************************************************/

/* C = log2(e) / sqrt(128) in Q0.32, sign extended to 33 bits (MSB = 0)       */
localparam int                 LP_SCALE_FRAC  = 32;                                              /* fractional bits of C          */
localparam int                 LP_SCORE_FRAC  = 16;                                              /* fractional bits of s'         */
localparam int                 LP_SCORE_W     = 32;                                              /* total width of s'             */
localparam int                 LP_PROD_W      = P_NMP_ACC_W + 33;                                /* 97: no wrap possible          */
localparam int                 LP_SCORE_SHIFT = P_NMP_ACC_FRAC + LP_SCALE_FRAC - LP_SCORE_FRAC;  /* 32 + 32 - 16 = 48            */

logic signed [LP_PROD_W-1:0]   score_prod;                                                       /* Q32.64, exact                 */
logic signed [LP_PROD_W-1:0]   score_shifted;                                                    /* Q_.16, value in the low bits  */
logic signed [LP_SCORE_W-1:0]  score_scaled;                                                     /* Q15.16, goes to the buffer    */
logic                          score_sat;                                                        /* s' did not fit in 32 bits     */

always_comb begin : scaling_score

    /* Exact product: 64-bit signed accumulator by the 33-bit signed constant */
    score_prod    = tt_score_acc * LP_SCALE;

    /* Back to 16 fractional bits. Arithmetic shift: the sign extends itself  */
    score_shifted = score_prod >>> LP_SCORE_SHIFT;

    /* The value fits in a 32-bit signed word only when every bit above the
       sign position is a copy of it: all ones, or all zeros                  */
    score_sat     = ~( ( &score_shifted[LP_PROD_W-1:LP_SCORE_W-1] ) | ( ~|score_shifted[LP_PROD_W-1:LP_SCORE_W-1] ) );

    /* Clamp instead of wrapping: a wrapped score would silently reorder the
       softmax, a clamped one only flattens the tail and raises the flag      */
    if ( score_sat ) begin
        score_scaled = score_shifted[LP_PROD_W-1] ? 32'sh8000_0000 : 32'sh7FFF_FFFF;
    end
    else begin
        score_scaled = score_shifted[LP_SCORE_W-1:0];
    end

end

/**************************************************************************/
/* SCORE: one register stage, into the buffer, running maximum m'         */
/**************************************************************************/
logic                              dp_score_valid;
logic signed [P_NMP_SEQ_WIDTH-1:0] dp_score_tok;
logic signed [LP_SCORE_W-1:0]      dp_score;                    /* s'_t, Q15.16                      */
logic signed [LP_SCORE_W-1:0]      r_max;                       /* m', Q15.16                        */
logic                              r_max_init;
logic [P_NMP_SEQ_WIDTH-1:0]        r_scores_written;

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        dp_score_valid <= 1'b0;
        dp_score_tok   <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        dp_score       <= { LP_SCORE_W { 1'b0 } };
    end
    else begin
        dp_score_valid <= tt_score_valid;
        dp_score_tok   <= tt_score_tok;
        dp_score       <= score_scaled;
    end
end

/******************************************************************************/
/* SOFTMAX SCAN                                                               */
/*                                                                            */
/* One address per cycle: the read is issued at cycle c, the word is on       */
/* sb_data_out_0 at c+1 (flagged by r_scan_valid_d, with its index in         */
/* r_scan_idx_d), and nmp_exp2 gives p_t back at c+4 together with the index  */
/* it came in with. The write back therefore lags the read by four cycles and */
/* never touches an address the scan has still to read: no delay line is      */
/* needed here, the tag is the delay line.                                    */
/*                                                                            */
/* l is a plain integer sum of the p_t in Q1.31. S <= 2048 values below 2^32  */
/* cannot exceed 2^43, so LP_L_W bits are enough and nothing is ever rounded. */
/******************************************************************************/
localparam int LP_L_W = P_NMP_P_FIXED_W + P_NMP_SEQ_WIDTH;       /* 44: exact, no growth possible    */

logic [P_NMP_SEQ_WIDTH-1:0]        r_scan_idx;                  /* next address to read              */
logic                              r_scan_valid_d;              /* data for r_scan_idx_d is on sb_data_out_0 */
logic [P_NMP_SEQ_WIDTH-1:0]        r_scan_idx_d;
logic                              r_scan_active;
logic [LP_L_W-1:0]                 r_l;                         /* softmax denominator, Q13.31       */
logic [P_NMP_SEQ_WIDTH-1:0]        r_p_written;                 /* p_t written back so far           */

/* nmp_exp2: p_t = 2^(s'_t - m'), three cycles, one result per cycle */
logic                              ex_valid;
logic [P_NMP_SEQ_WIDTH-1:0]        ex_tag;
logic [P_NMP_P_FIXED_W-1:0]        ex_p;

assign r_scan_active = ( r_state == S_SOFTMAX_EXP );

nmp_exp2 #(
    .P_SCORE_W    (LP_SCORE_W),
    .P_SCORE_FRAC (LP_SCORE_FRAC)
) u_exp2 (
    .clock_i  (clock_i),
    .reset_ni (reset_ni),
    .valid_i  (r_scan_valid_d),
    .s_i      (sb_data_out_0),                                  /* s'_t straight out of the buffer   */
    .m_i      (r_max),                                          /* m', frozen since the end of K     */
    .tag_i    (r_scan_idx_d),
    .valid_o  (ex_valid),
    .tag_o    (ex_tag),
    .p_o      (ex_p)
);

/* Score buffer ports */
always_comb begin
    if ( r_scan_active ) begin
        sb_read_addr_0 = r_scan_idx[P_NMP_SCORE_ADDR_WIDTH-1:0];
    end
    else begin
        sb_read_addr_0 = tok0[P_NMP_SCORE_ADDR_WIDTH-1:0];      /* V pass: p_t of the PS0 beat */
    end
    sb_read_addr_1 = tok1[P_NMP_SCORE_ADDR_WIDTH-1:0];          /* V pass: p_t of the PS1 beat */

    if ( r_state == S_SOFTMAX_EXP ) begin
        sb_wr_en      = ex_valid;                               /* four cycles behind the read       */
        sb_write_addr = ex_tag[P_NMP_SCORE_ADDR_WIDTH-1:0];
        sb_data_in    = ex_p;
    end
    else begin
        sb_wr_en      = dp_score_valid;
        sb_write_addr = dp_score_tok[P_NMP_SCORE_ADDR_WIDTH-1:0];
        sb_data_in    = dp_score;
    end
end

/*******************************/
/* NORMALISATION               */
/*******************************/
logic                              r_norm_busy;
logic [P_NMP_OUT_IDX_WIDTH:0]      r_norm_idx;
logic                              r_norm_done;

assign oa_rd_idx = r_norm_idx[P_NMP_OUT_IDX_WIDTH-1:0];

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_norm_busy <= 1'b0;
        r_norm_idx  <= { P_NMP_OUT_IDX_WIDTH+1 { 1'b0 } };
        r_norm_done <= 1'b0;
        o_valid_o   <= 1'b0;
        o_idx_o     <= { P_NMP_OUT_IDX_WIDTH { 1'b0 } };
        o_o         <= { P_NMP_F32_WIDTH { 1'b0 } };
    end
    else begin
        o_valid_o   <= 1'b0;
        r_norm_done <= 1'b0;
        if ( r_state == S_NORMALIZE && ~r_norm_busy && ~r_norm_done ) begin
            r_norm_busy <= 1'b1;
            r_norm_idx  <= { P_NMP_OUT_IDX_WIDTH+1 { 1'b0 } };
        end
        else if ( r_norm_busy ) begin
            if ( r_norm_idx == P_NMP_D_HEAD ) begin
                r_norm_busy <= 1'b0;
                r_norm_done <= 1'b1;
            end
            else begin
                o_valid_o  <= 1'b1;
                o_idx_o    <= r_norm_idx[P_NMP_OUT_IDX_WIDTH-1:0];
                /* Still the behavioural division of step 2b: l is now an exact
                   integer in Q1.31, so it is turned into a real just here. This
                   is the LAST `real` left in the engine and the last thing in
                   the way of synthesis; step 2c removes it by emitting
                   (o_tilde, m, l) and letting the host do the division once.   */
                o_o        <= f_nmp_real_to_fp32(f_nmp_fp32_to_real(f_nmp_acc_to_fp32(oa_rd_acc))
                                                 / ( real'(r_l) / real'(64'd1 << P_NMP_P_FIXED_FRAC) ));
                r_norm_idx <= r_norm_idx + 1'b1;
            end
        end
    end
end

/*******************************/
/* MAIN SEQUENCER              */
/*******************************/
logic [3:0] r_drain;

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_state          <= S_IDLE;
        r_base_k_blk     <= { P_NMP_BLK_ADDR_WIDTH { 1'b0 } };
        r_base_v_blk     <= { P_NMP_BLK_ADDR_WIDTH { 1'b0 } };
        r_seq_len        <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r_base_req_id    <= { P_REQ_ID_WIDTH { 1'b0 } };
        r_pass_open      <= 1'b0;
        ag_start         <= 1'b0;
        ag_base_blk      <= { P_NMP_BLK_ADDR_WIDTH { 1'b0 } };
        tt_clear         <= 1'b0;
        oa_clear         <= 1'b0;
        r_l              <= { LP_L_W { 1'b0 } };
        r_scan_idx       <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r_scan_valid_d   <= 1'b0;
        r_scan_idx_d     <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r_p_written      <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r_max            <= 32'sh8000_0000;
        r_max_init       <= 1'b0;
        r_scores_written <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r_drain          <= 4'd0;
        busy_o           <= 1'b0;
        done_o           <= 1'b0;
    end
    else begin
        ag_start       <= 1'b0;
        tt_clear       <= 1'b0;
        oa_clear       <= 1'b0;
        done_o         <= 1'b0;
        r_scan_valid_d <= 1'b0;

        case ( r_state )

            S_IDLE: begin
                if ( start_i ) begin
                    r_base_k_blk     <= base_k_blk_i;
                    r_base_v_blk     <= base_v_blk_i;
                    r_seq_len        <= seq_len_i;
                    ag_base_blk      <= base_k_blk_i;
                    ag_start         <= 1'b1;                    /* generator latches base/n on the next edge */
                    r_base_req_id    <= ag_next_req_id;          /* id of the first request of the pass       */
                    r_pass_open      <= 1'b1;
                    tt_clear         <= 1'b1;
                    oa_clear         <= 1'b1;
                    r_scores_written <= { P_NMP_SEQ_WIDTH { 1'b0 } };
                    r_max_init       <= 1'b0;
                    busy_o           <= 1'b1;
                    r_state          <= S_PASS_K;
                end
            end

            S_PASS_K: begin
                /* scores arrive one per cycle at most; keep the running maximum */
                if ( dp_score_valid ) begin
                    r_scores_written <= r_scores_written + 1'b1;
                    if ( ~r_max_init || (dp_score > r_max) ) begin
                        r_max <= dp_score;
                    end
                    r_max_init <= 1'b1;
                end
                if ( r_scores_written == r_seq_len && ~dp_score_valid ) begin
                    r_pass_open <= 1'b0;
                    r_scan_idx  <= { P_NMP_SEQ_WIDTH { 1'b0 } };
                    r_l         <= { LP_L_W { 1'b0 } };
                    r_p_written <= { P_NMP_SEQ_WIDTH { 1'b0 } };
                    r_state     <= S_SOFTMAX_EXP;
                end
            end

            S_SOFTMAX_EXP: begin
                /* read s'_i, write back p_i = 2^(s'_i - m'), l += p_i */
                if ( r_scan_idx < r_seq_len ) begin
                    r_scan_idx     <= r_scan_idx + 1'b1;
                    r_scan_valid_d <= 1'b1;
                    r_scan_idx_d   <= r_scan_idx;
                end
                /* the sum follows the exp2 output, not the read: exact integer */
                if ( ex_valid ) begin
                    r_l         <= r_l + { { (LP_L_W-P_NMP_P_FIXED_W) { 1'b0 } }, ex_p };
                    r_p_written <= r_p_written + 1'b1;
                end
                /* leave only when every p_t is back in the buffer: the three
                   stages of nmp_exp2 are still full when the last read goes out */
                if ( r_p_written == r_seq_len ) begin
                    ag_base_blk   <= r_base_v_blk;
                    ag_start      <= 1'b1;
                    r_base_req_id <= ag_next_req_id;
                    r_pass_open   <= 1'b1;
                    r_drain       <= 4'd0;
                    r_state       <= S_PASS_V;
                end
            end

            S_PASS_V: begin
                /* all beats accepted, then let the pipeline finish */
                if ( r_beats_accepted == n_blk_pass && ~ag_start ) begin
                    r_drain <= r_drain + 1'b1;
                    if ( r_drain == LP_DRAIN ) begin
                        r_pass_open <= 1'b0;
                        r_state     <= S_NORMALIZE;
                    end
                end
                else begin
                    r_drain <= 4'd0;
                end
            end

            S_NORMALIZE: begin
                if ( r_norm_done ) begin
                    r_state <= S_DONE;
                end
            end

            S_DONE: begin
                done_o  <= 1'b1;
                busy_o  <= 1'b0;
                r_state <= S_IDLE;
            end

            default: begin
                r_state <= S_IDLE;
            end
        endcase
    end
end

/*******************************/
/* STATISTICS                  */
/*******************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        cyc_pass_k_o     <= 32'd0;
        cyc_softmax_o    <= 32'd0;
        cyc_pass_v_o     <= 32'd0;
        cyc_total_o      <= 32'd0;
        starve_cnt_o     <= 32'd0;
        n_beats_o        <= 32'd0;
        n_dropped_o      <= 32'd0;
        arith_overflow_o <= 1'b0;
    end
    else begin
        if ( r_state == S_IDLE && start_i ) begin
            cyc_pass_k_o     <= 32'd0;
            cyc_softmax_o    <= 32'd0;
            cyc_pass_v_o     <= 32'd0;
            cyc_total_o      <= 32'd0;
            starve_cnt_o     <= 32'd0;
            n_beats_o        <= 32'd0;
            n_dropped_o      <= 32'd0;
            arith_overflow_o <= 1'b0;
        end
        else if ( r_state != S_IDLE ) begin
            cyc_total_o <= cyc_total_o + 1'b1;
            if ( r_state == S_PASS_K ) begin
                cyc_pass_k_o <= cyc_pass_k_o + 1'b1;
            end
            if ( r_scan_active ) begin
                cyc_softmax_o <= cyc_softmax_o + 1'b1;
            end
            if ( r_state == S_PASS_V ) begin
                cyc_pass_v_o <= cyc_pass_v_o + 1'b1;
            end
            if ( in_pass && ~acc0 && ~acc1 ) begin
                starve_cnt_o <= starve_cnt_o + 1'b1;
            end
            n_beats_o   <= n_beats_o   + { 30'd0, credit_return };
            n_dropped_o <= n_dropped_o + { 31'd0, drop0 } + { 31'd0, drop1 };
            if ( la0_overflow || la1_overflow || tt_queue_overflow ) begin
                arith_overflow_o <= 1'b1;
            end
        end
    end
end

`ifdef DEBUG
always @ ( posedge clock_i ) begin
    if ( reset_ni == 1'b1 ) begin
        if ( r_state == S_IDLE && start_i ) begin
            $display("[ NMP ENGINE ]: start S=%0d base_k=%0d base_v=%0d at %0t", seq_len_i, base_k_blk_i, base_v_blk_i, $time);
        end
        if ( drop0 ) begin
            $display("[ NMP ENGINE ]: DROPPED PS0 id %0d (offset %0d, window %0d, base %0d) at %0t", rd_data_req_id_ps0_i, off0, n_blk_pass, r_base_req_id, $time);
        end
        if ( drop1 ) begin
            $display("[ NMP ENGINE ]: DROPPED PS1 id %0d (offset %0d, window %0d, base %0d) at %0t", rd_data_req_id_ps1_i, off1, n_blk_pass, r_base_req_id, $time);
        end
        if ( tt_score_valid && score_sat ) begin
            $display("[ NMP ENGINE ]: WARNING score of token %0d saturated (acc 0x%016x) at %0t",
                     tt_score_tok, tt_score_acc, $time);
        end
        if ( r_state == S_PASS_K && r_scores_written == r_seq_len && ~dp_score_valid ) begin
            $display("[ NMP ENGINE ]: pass K done after %0d cycles, max=%f (0x%08x, Q15.16) at %0t",
                     cyc_pass_k_o, real'(r_max) / real'(1 << LP_SCORE_FRAC), r_max, $time);
        end
        if ( r_state == S_SOFTMAX_EXP && r_p_written == r_seq_len ) begin
            $display("[ NMP ENGINE ]: softmax done, l=%f (0x%011x, Q13.31) at %0t",
                     real'(r_l) / real'(64'd1 << P_NMP_P_FIXED_FRAC), r_l, $time);
        end
        if ( r_state == S_PASS_V && r_beats_accepted == n_blk_pass && r_drain == LP_DRAIN ) begin
            $display("[ NMP ENGINE ]: pass V done after %0d cycles at %0t", cyc_pass_v_o, $time);
        end
        if ( r_state == S_DONE ) begin
            $display("[ NMP ENGINE ]: done, total %0d cycles (K %0d, softmax %0d, V %0d), %0d beats, %0d dropped, credit stalls %0d, extra picked waits %0d, starved %0d, overflow %0b at %0t",
                     cyc_total_o, cyc_pass_k_o, cyc_softmax_o, cyc_pass_v_o, n_beats_o, n_dropped_o, stall_credit_cnt_o, wait_picked_cnt_o, starve_cnt_o, arith_overflow_o, $time);
        end
    end
end
`endif

endmodule
