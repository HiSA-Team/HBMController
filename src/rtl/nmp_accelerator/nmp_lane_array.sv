`timescale 1ps/1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"

/******************************************************************************/
/* NMP LANE ARRAY (16 lanes, one pseudo-channel)                              */
/*                                                                            */
/* Consumes one beat per cycle from one PS, in any order, in one of two modes:*/
/*   K mode : lane i multiplies q[16j+i] (fp16) by k_t[16j+i] (fp16); the 16  */
/*            exact products are aligned to the fixed-point grid and summed   */
/*            by an integer tree into one partial (the contribution of this   */
/*            beat to q . k_t)                                                */
/*   V mode : lane i multiplies p_t (Q1.31) by v_t[16j+i] (fp16); the 16      */
/*            aligned products are output one per lane, to be added to the    */
/*            output accumulators o[16j .. 16j+15]                            */
/*                                                                            */
/* Arithmetic (all integer, synthesisable):                                   */
/*   fp16 value = sig * 2^(exp - 10), sig 11 bits, exp in [-14, 15]           */
/*   product    = sigA * sigB * 2^(expA + expB - 20)  (exact, 22 or 43 bits)  */
/*   aligned    = product * 2^P_NMP_ACC_FRAC as a 64-bit two's complement     */
/*                integer: shift left by expA + expB - 20 + FRAC, or right    */
/*                (truncation toward zero) when that is negative              */
/*   In V mode p_t = p_fixed * 2^-31 is treated as sig = p_fixed, exp = -21   */
/*   (so that sig * 2^(exp - 10) = p_fixed * 2^-31).                          */
/*                                                                            */
/* Pipeline: stage 0 registers the inputs, stage 1 decodes and multiplies,    */
/* stage 2 aligns, stage 3 reduces (K) - 4 cycles from input to output.       */
/******************************************************************************/

module nmp_lane_array (
    input  logic                              clock_i,
    input  logic                              reset_ni,

    /* Beat input */
    input  logic                              beat_valid_i,
    input  logic [P_DATA_WIDTH-1:0]           beat_data_i,      /* 16 fp16, element i at [16i+15:16i]    */
    input  logic [P_NMP_SEQ_WIDTH-1:0]        beat_tok_i,       /* token t                               */
    input  logic [P_NMP_BLK_IDX_WIDTH-1:0]    beat_blk_i,       /* block j inside k_t / v_t              */
    input  logic                              mode_v_i,         /* 0: K pass - 1: V pass                 */
    input  logic [P_DATA_WIDTH-1:0]           q_chunk_i,        /* q[16j .. 16j+15] (K mode)             */
    input  logic [P_NMP_P_FIXED_W-1:0]        p_fixed_i,        /* p_t as Q1.31 (V mode)                 */

    /* Output, 4 cycles later */
    output logic                                       out_valid_o,
    output logic [P_NMP_SEQ_WIDTH-1:0]                 out_tok_o,
    output logic [P_NMP_BLK_IDX_WIDTH-1:0]             out_blk_o,
    output logic                                       out_mode_v_o,
    output logic signed [P_NMP_ACC_W-1:0]              partial_o,        /* K: sum of the 16 aligned products            */
    output logic [P_NMP_ELEM_PER_BEAT*P_NMP_ACC_W-1:0] prod_o,           /* V: aligned product of lane i at [64i +: 64]  */
    output logic                                       overflow_o        /* sticky: an aligned product did not fit       */
);

localparam LP_SHIFT_W = 8;                                                            /* shift amount, signed: [-23, 42] */
localparam logic signed [LP_SHIFT_W-1:0] LP_FRAC_S    = LP_SHIFT_W'(P_NMP_ACC_FRAC);
localparam logic signed [LP_SHIFT_W-1:0] LP_P_EXP     = -8'sd21;                      /* p_fixed * 2^-31 = sig * 2^(exp-10) */
localparam logic signed [LP_SHIFT_W-1:0] LP_SIG_SHIFT = -8'sd20;                      /* two significands: 2^-10 each */

/**************************************/
/* STAGE 0: input registers            */
/**************************************/
logic                              r0_valid;
logic [P_DATA_WIDTH-1:0]           r0_beat;
logic [P_NMP_SEQ_WIDTH-1:0]        r0_tok;
logic [P_NMP_BLK_IDX_WIDTH-1:0]    r0_blk;
logic                              r0_mode_v;
logic [P_DATA_WIDTH-1:0]           r0_q;
logic [P_NMP_P_FIXED_W-1:0]        r0_p;

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r0_valid  <= 1'b0;
        r0_beat   <= { P_DATA_WIDTH { 1'b0 } };
        r0_tok    <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r0_blk    <= { P_NMP_BLK_IDX_WIDTH { 1'b0 } };
        r0_mode_v <= 1'b0;
        r0_q      <= { P_DATA_WIDTH { 1'b0 } };
        r0_p      <= { P_NMP_P_FIXED_W { 1'b0 } };
    end
    else begin
        r0_valid  <= beat_valid_i;
        r0_beat   <= beat_data_i;
        r0_tok    <= beat_tok_i;
        r0_blk    <= beat_blk_i;
        r0_mode_v <= mode_v_i;
        r0_q      <= q_chunk_i;
        r0_p      <= p_fixed_i;
    end
end

/**************************************/
/* STAGE 1: decode and multiply        */
/**************************************/
logic                                          r1_valid;
logic [P_NMP_SEQ_WIDTH-1:0]                    r1_tok;
logic [P_NMP_BLK_IDX_WIDTH-1:0]                r1_blk;
logic                                          r1_mode_v;
logic [P_NMP_ELEM_PER_BEAT*P_NMP_PROD_W-1:0]   r1_prod;        /* |sigA * sigB| of lane i at [43i +: 43]      */
logic [P_NMP_ELEM_PER_BEAT-1:0]                r1_sign;
logic [P_NMP_ELEM_PER_BEAT*LP_SHIFT_W-1:0]     r1_shift;       /* expA + expB - 20 + FRAC, signed 8 bits      */

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r1_valid  <= 1'b0;
        r1_tok    <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r1_blk    <= { P_NMP_BLK_IDX_WIDTH { 1'b0 } };
        r1_mode_v <= 1'b0;
        r1_prod   <= { P_NMP_ELEM_PER_BEAT*P_NMP_PROD_W { 1'b0 } };
        r1_sign   <= { P_NMP_ELEM_PER_BEAT { 1'b0 } };
        r1_shift  <= { P_NMP_ELEM_PER_BEAT*LP_SHIFT_W { 1'b0 } };
    end
    else begin
        logic [15:0]                    a16;
        logic [15:0]                    b16;
        logic [P_NMP_P_FIXED_W-1:0]     sig_a;
        logic [P_NMP_SIG_W-1:0]         sig_b;
        logic signed [P_NMP_EXP_W-1:0]  e6_a;
        logic signed [P_NMP_EXP_W-1:0]  e6_b;
        logic signed [LP_SHIFT_W-1:0]   exp_a;
        logic signed [LP_SHIFT_W-1:0]   exp_b;
        logic [P_NMP_PROD_W-1:0]        prod;
        r1_valid  <= r0_valid;
        r1_tok    <= r0_tok;
        r1_blk    <= r0_blk;
        r1_mode_v <= r0_mode_v;
        for ( integer i = 0; i < P_NMP_ELEM_PER_BEAT; i = i + 1 ) begin
            a16   = r0_q   [i*P_NMP_ELEM_WIDTH +: P_NMP_ELEM_WIDTH];
            b16   = r0_beat[i*P_NMP_ELEM_WIDTH +: P_NMP_ELEM_WIDTH];
            sig_b = f_nmp_fp16_sig(b16);
            e6_b  = f_nmp_fp16_exp(b16);
            exp_b = { { (LP_SHIFT_W-P_NMP_EXP_W) { e6_b[P_NMP_EXP_W-1] } }, e6_b };   /* sign extension */
            if ( r0_mode_v ) begin
                sig_a = r0_p;                                             /* p_fixed = p * 2^31 */
                exp_a = LP_P_EXP;
                r1_sign[i] <= b16[15];                                    /* sign of p_t is always positive due to softmax */
            end
            else begin
                sig_a = { { (P_NMP_P_FIXED_W-P_NMP_SIG_W) { 1'b0 } }, f_nmp_fp16_sig(a16) };
                e6_a  = f_nmp_fp16_exp(a16);
                exp_a = { { (LP_SHIFT_W-P_NMP_EXP_W) { e6_a[P_NMP_EXP_W-1] } }, e6_a };
                r1_sign[i] <= a16[15] ^ b16[15];
            end
            prod = sig_a * sig_b;
            r1_prod [i*P_NMP_PROD_W +: P_NMP_PROD_W] <= prod;
            r1_shift[i*LP_SHIFT_W   +: LP_SHIFT_W]   <= exp_a + exp_b + LP_SIG_SHIFT + LP_FRAC_S;
        end
    end
end

/******************************************/
/* STAGE 2: align to the accumulator grid */
/******************************************/
logic                                          r2_valid;
logic [P_NMP_SEQ_WIDTH-1:0]                    r2_tok;
logic [P_NMP_BLK_IDX_WIDTH-1:0]                r2_blk;
logic                                          r2_mode_v;
logic [P_NMP_ELEM_PER_BEAT*P_NMP_ACC_W-1:0]    r2_aligned;     /* signed 64-bit aligned product of lane i     */
logic                                          r2_overflow;

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r2_valid    <= 1'b0;
        r2_tok      <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        r2_blk      <= { P_NMP_BLK_IDX_WIDTH { 1'b0 } };
        r2_mode_v   <= 1'b0;
        r2_overflow <= 1'b0;
        r2_aligned  <= { P_NMP_ELEM_PER_BEAT*P_NMP_ACC_W { 1'b0 } };
    end
    else begin
        logic [P_NMP_PROD_W-1:0]             prod;
        logic signed [LP_SHIFT_W-1:0]        sh;
        logic [LP_SHIFT_W-1:0]               sh_mag;
        logic [P_NMP_ACC_W+P_NMP_PROD_W-1:0] wide;                      /* room for the left shift */
        logic [P_NMP_ACC_W-1:0]              mag;
        logic signed [P_NMP_ACC_W-1:0]       val;
        logic                                ovf;
        r2_valid    <= r1_valid;
        r2_tok      <= r1_tok;
        r2_blk      <= r1_blk;
        r2_mode_v   <= r1_mode_v;
        r2_overflow <= 1'b0;
        for ( integer i = 0; i < P_NMP_ELEM_PER_BEAT; i = i + 1 ) begin
            prod = r1_prod [i*P_NMP_PROD_W +: P_NMP_PROD_W];
            sh   = r1_shift[i*LP_SHIFT_W   +: LP_SHIFT_W];
            if ( sh >= 0 ) begin
                sh_mag = sh;
                wide   = { { P_NMP_ACC_W { 1'b0 } }, prod } << sh_mag;
                mag    = wide[P_NMP_ACC_W-1:0];
                ovf    = ( wide[P_NMP_ACC_W+P_NMP_PROD_W-1:P_NMP_ACC_W-1] != { (P_NMP_PROD_W+1) { 1'b0 } } );  /* must fit in 63 bits */
            end
            else begin
                sh_mag = -sh;
                mag    = { { (P_NMP_ACC_W-P_NMP_PROD_W) { 1'b0 } }, prod } >> sh_mag;   /* truncation toward zero */
                ovf    = 1'b0;
            end
            if ( r1_valid && ovf ) begin
                r2_overflow <= 1'b1;
            end
            val = r1_sign[i] ? -$signed(mag) : $signed(mag);
            r2_aligned[i*P_NMP_ACC_W +: P_NMP_ACC_W] <= val;
        end
    end
end

/*********************************************/
/* STAGE 3: reduction (K) / pass-through (V) */
/*********************************************/
always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        out_valid_o  <= 1'b0;
        out_tok_o    <= { P_NMP_SEQ_WIDTH { 1'b0 } };
        out_blk_o    <= { P_NMP_BLK_IDX_WIDTH { 1'b0 } };
        out_mode_v_o <= 1'b0;
        partial_o    <= { P_NMP_ACC_W { 1'b0 } };
        prod_o       <= { P_NMP_ELEM_PER_BEAT*P_NMP_ACC_W { 1'b0 } };
        overflow_o   <= 1'b0;
    end
    else begin
        logic signed [P_NMP_ACC_W-1:0] sum;
        logic signed [P_NMP_ACC_W-1:0] term;
        out_valid_o  <= r2_valid;
        out_tok_o    <= r2_tok;
        out_blk_o    <= r2_blk;
        out_mode_v_o <= r2_mode_v;
        if ( r2_overflow ) begin
            overflow_o <= 1'b1;                                          /* sticky */
        end
        sum = { P_NMP_ACC_W { 1'b0 } };
        for ( integer i = 0; i < P_NMP_ELEM_PER_BEAT; i = i + 1 ) begin
            term = r2_aligned[i*P_NMP_ACC_W +: P_NMP_ACC_W];
            sum  = sum + term;                                            /* integer tree, written as a chain: same result */
        end
        partial_o <= sum;
        prod_o    <= r2_aligned;
    end
end

endmodule
