`timescale 1ps/1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"

/******************************************************************************/
/* NMP SCORE DATAPATH (16 lanes)                                              */
/*                                                                            */
/* Consumes one beat per cycle, in block order (t, j), in one of two modes:   */
/*   K mode : partial = sum_i q[16j+i] * k_t[16j+i]  (16 products, one tree)  */
/*            acc     = acc + partial ; after j = 7 : s_t = acc / sqrt(d)     */
/*   V mode : o[16j+i] = o[16j+i] + p_t * v_t[16j+i]  (16 accumulators of the */
/*            128 that hold the head output)                                  */
/* After the V pass, normalize_i streams out o[i] / l for i = 0 .. d-1.       */
/*                                                                            */
/* ARITHMETIC IS BEHAVIOURAL IN v0: products and sums are done on simulator   */
/* reals and rounded to fp32 wherever a register would hold an fp32 value     */
/* (partial sum, score accumulator, output accumulators). The pipeline depth  */
/* (2 stages) is what a synthesisable version would also have at the least.   */
/******************************************************************************/

module nmp_score_datapath (
    input  logic                              clock_i,
    input  logic                              reset_ni,

    input  logic                              clear_i,          /* start of a job: clear accumulators    */

    /* Beat input (in order) */
    input  logic                              beat_valid_i,
    input  logic [P_DATA_WIDTH-1:0]           beat_data_i,      /* 16 fp16, element i at [16i+15:16i]    */
    input  logic [P_NMP_SEQ_WIDTH-1:0]        beat_tok_i,       /* token t                               */
    input  logic [P_NMP_BLK_IDX_WIDTH-1:0]    beat_blk_i,       /* block j inside k_t / v_t              */
    input  logic                              mode_v_i,         /* 0: K pass (scores) - 1: V pass        */
    input  logic [P_DATA_WIDTH-1:0]           q_chunk_i,        /* q[16j .. 16j+15] (K mode)             */
    input  logic [P_NMP_ACC_WIDTH-1:0]        p_i,              /* fp32 p_t aligned with the beat (V)    */

    /* Score output (K mode) */
    output logic                              score_valid_o,
    output logic [P_NMP_SEQ_WIDTH-1:0]        score_tok_o,
    output logic [P_NMP_ACC_WIDTH-1:0]        score_o,          /* fp32                                  */

    /* Normalisation and head output (after the V pass) */
    input  logic                              normalize_i,      /* one cycle pulse                       */
    input  logic [P_NMP_ACC_WIDTH-1:0]        l_i,              /* fp32 softmax denominator              */
    output logic                              o_valid_o,
    output logic [P_NMP_OUT_IDX_WIDTH-1:0]    o_idx_o,
    output logic [P_NMP_ACC_WIDTH-1:0]        o_o,              /* fp32 o[idx]                           */
    output logic                              normalize_done_o
);

localparam real LP_SCALE = 0.08838834764831845;                           /* 1 / sqrt(P_NMP_D_HEAD), d = 128 */

/**************************************/
/* STAGE 0: input registers            */
/**************************************/
logic                              r0_valid;
logic [P_DATA_WIDTH-1:0]           r0_beat;
logic [P_NMP_SEQ_WIDTH-1:0]        r0_tok;
logic [P_NMP_BLK_IDX_WIDTH-1:0]    r0_blk;
logic                              r0_mode_v;
logic [P_DATA_WIDTH-1:0]           r0_q;
logic [P_NMP_ACC_WIDTH-1:0]        r0_p;

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r0_valid  <= 1'b0;
        r0_beat   <= { P_DATA_WIDTH { 1'b0 } };
        r0_tok    <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r0_blk    <= { P_NMP_BLK_IDX_WIDTH { 1'b0 } };
        r0_mode_v <= 1'b0;
        r0_q      <= { P_DATA_WIDTH { 1'b0 } };
        r0_p      <= { P_NMP_ACC_WIDTH { 1'b0 } };
    end
    else begin
        r0_valid  <= beat_valid_i;
        r0_beat   <= beat_data_i;
        r0_tok    <= beat_tok_i;
        r0_blk    <= beat_blk_i;
        r0_mode_v <= mode_v_i;
        r0_q      <= q_chunk_i;
        r0_p      <= p_i;
    end
end

/**************************************/
/* STAGE 1: 16 products and the tree   */
/**************************************/
logic                              r1_valid;
logic [P_NMP_SEQ_WIDTH-1:0]        r1_tok;
logic [P_NMP_BLK_IDX_WIDTH-1:0]    r1_blk;
logic                              r1_mode_v;
real                               r1_partial;                  /* K: sum of the 16 products (fp32 rounded) */
real                               r1_pv [0:P_NMP_ELEM_PER_BEAT-1]; /* V: p * v[i] (fp32 rounded)          */

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r1_valid   <= 1'b0;
        r1_tok     <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r1_blk     <= { P_NMP_BLK_IDX_WIDTH { 1'b0 } };
        r1_mode_v  <= 1'b0;
        r1_partial <= 0.0;
        for ( integer i = 0; i < P_NMP_ELEM_PER_BEAT; i = i + 1 ) begin
            r1_pv[i] <= 0.0;
        end
    end
    else begin
        real sum;
        real p;
        r1_valid  <= r0_valid;
        r1_tok    <= r0_tok;
        r1_blk    <= r0_blk;
        r1_mode_v <= r0_mode_v;
        sum = 0.0;
        p   = f_nmp_fp32_to_real(r0_p);
        for ( integer i = 0; i < P_NMP_ELEM_PER_BEAT; i = i + 1 ) begin
            sum = sum + f_nmp_fp16_to_real(r0_q[i*P_NMP_ELEM_WIDTH +: P_NMP_ELEM_WIDTH]) *
                        f_nmp_fp16_to_real(r0_beat[i*P_NMP_ELEM_WIDTH +: P_NMP_ELEM_WIDTH]);
            r1_pv[i] <= f_nmp_fp32_to_real(f_nmp_real_to_fp32(p * f_nmp_fp16_to_real(r0_beat[i*P_NMP_ELEM_WIDTH +: P_NMP_ELEM_WIDTH])));
        end
        r1_partial <= f_nmp_fp32_to_real(f_nmp_real_to_fp32(sum));
    end
end

/**************************************/
/* STAGE 2: accumulation               */
/**************************************/
logic [P_NMP_ACC_WIDTH-1:0]        r_score_acc;                 /* fp32 running q.k_t */
logic [P_NMP_D_HEAD*P_NMP_ACC_WIDTH-1:0] r_o_acc;               /* fp32 output accumulators, o[i] at [32i+31:32i] */

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_score_acc   <= { P_NMP_ACC_WIDTH { 1'b0 } };
        score_valid_o <= 1'b0;
        score_tok_o   <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        score_o       <= { P_NMP_ACC_WIDTH { 1'b0 } };
        r_o_acc       <= { P_NMP_D_HEAD*P_NMP_ACC_WIDTH { 1'b0 } };
    end
    else begin
        real acc;
        score_valid_o <= 1'b0;
        if ( clear_i ) begin
            r_score_acc <= { P_NMP_ACC_WIDTH { 1'b0 } };
            r_o_acc     <= { P_NMP_D_HEAD*P_NMP_ACC_WIDTH { 1'b0 } };
        end
        else if ( r1_valid && ~r1_mode_v ) begin
            /* K pass: block 0 restarts the accumulation, block 7 closes the score */
            acc = ( r1_blk == { P_NMP_BLK_IDX_WIDTH { 1'b0 } } ) ? 0.0 : f_nmp_fp32_to_real(r_score_acc);
            acc = f_nmp_fp32_to_real(f_nmp_real_to_fp32(acc + r1_partial));
            r_score_acc <= f_nmp_real_to_fp32(acc);
            if ( r1_blk == { P_NMP_BLK_IDX_WIDTH { 1'b1 } } ) begin              /* last block of the token */
                score_valid_o <= 1'b1;
                score_tok_o   <= r1_tok;
                score_o       <= f_nmp_real_to_fp32(acc * LP_SCALE);
            end
        end
        else if ( r1_valid && r1_mode_v ) begin
            /* V pass: 16 of the 128 accumulators */
            for ( integer i = 0; i < P_NMP_ELEM_PER_BEAT; i = i + 1 ) begin
                r_o_acc[(r1_blk * P_NMP_ELEM_PER_BEAT + i) * P_NMP_ACC_WIDTH +: P_NMP_ACC_WIDTH] <=
                    f_nmp_real_to_fp32(f_nmp_fp32_to_real(r_o_acc[(r1_blk * P_NMP_ELEM_PER_BEAT + i) * P_NMP_ACC_WIDTH +: P_NMP_ACC_WIDTH]) + r1_pv[i]);
            end
        end
    end
end

/**************************************/
/* NORMALISATION: o[i] / l, one per cycle */
/**************************************/
logic                              r_norm_busy;
logic [P_NMP_OUT_IDX_WIDTH:0]      r_norm_idx;
real                               r_norm_l;

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_norm_busy      <= 1'b0;
        r_norm_idx       <= { P_NMP_OUT_IDX_WIDTH+1 { 1'b0 } };
        r_norm_l         <= 1.0;
        o_valid_o        <= 1'b0;
        o_idx_o          <= { P_NMP_OUT_IDX_WIDTH { 1'b0 } };
        o_o              <= { P_NMP_ACC_WIDTH { 1'b0 } };
        normalize_done_o <= 1'b0;
    end
    else begin
        o_valid_o        <= 1'b0;
        normalize_done_o <= 1'b0;
        if ( normalize_i && ~r_norm_busy ) begin
            r_norm_busy <= 1'b1;
            r_norm_idx  <= { P_NMP_OUT_IDX_WIDTH+1 { 1'b0 } };
            r_norm_l    <= f_nmp_fp32_to_real(l_i);
        end
        else if ( r_norm_busy ) begin
            if ( r_norm_idx == P_NMP_D_HEAD ) begin
                r_norm_busy      <= 1'b0;
                normalize_done_o <= 1'b1;
            end
            else begin
                o_valid_o  <= 1'b1;
                o_idx_o    <= r_norm_idx[P_NMP_OUT_IDX_WIDTH-1:0];
                o_o        <= f_nmp_real_to_fp32(f_nmp_fp32_to_real(r_o_acc[r_norm_idx[P_NMP_OUT_IDX_WIDTH-1:0] * P_NMP_ACC_WIDTH +: P_NMP_ACC_WIDTH]) / r_norm_l);
                r_norm_idx <= r_norm_idx + 1'b1;
            end
        end
    end
end

endmodule
