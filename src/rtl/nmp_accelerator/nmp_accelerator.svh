`ifndef NMP_ACCELERATOR_SVH__
`define NMP_ACCELERATOR_SVH__

`include "hbm_controller.svh"

/******************************************************************************/
/* NEAR-MEMORY PROCESSING (NMP) ACCELERATOR - v1                              */
/*                                                                            */
/* Single attention head (MHA, decode step) served by one DFI channel:        */
/*   pass K : s_t = q . k_t / sqrt(d)      (one score per token)              */
/*   softmax: p_t = exp(s_t - max) , l = sum(p_t)                             */
/*   pass V : o   = sum(p_t . v_t) / l                                        */
/*                                                                            */
/* Everything is expressed in beats of the HBM channel (P_DATA_WIDTH = 256 b  */
/* = 16 fp16 elements) and in channel clock cycles.                           */
/*                                                                            */
/* v1 arithmetic: fp16 x fp16 products are exact integers (11 x 11 bits) and  */
/* are accumulated, after alignment, in wide two's complement fixed-point     */
/* accumulators (P_NMP_ACC_W bits, P_NMP_ACC_FRAC fractional bits). Integer   */
/* sums are exact and order independent, so beats are consumed in the order  */
/* in which the channel returns them. Floating point appears only at the      */
/* boundaries (fp16 in, fp32 out) and, until step 2, in the softmax scan.     */
/******************************************************************************/

/* Element format (fp16) and geometry of a head */
localparam       P_NMP_ELEM_WIDTH        = 16;                                     /* fp16                            */
localparam       P_NMP_ELEM_PER_BEAT     = P_DATA_WIDTH / P_NMP_ELEM_WIDTH;        /* 16 elements per 32 B block      */
localparam       P_NMP_D_HEAD            = 128;                                    /* head dimension (OPT-6.7B)       */
localparam       P_NMP_BLK_PER_ROW       = P_NMP_D_HEAD / P_NMP_ELEM_PER_BEAT;     /* 8 blocks per k_t (or v_t)       */
localparam       P_NMP_BLK_IDX_WIDTH     = $clog2(P_NMP_BLK_PER_ROW);              /* 3                               */

/* Context length supported by the score buffer */
localparam       P_NMP_MAX_SEQ_LEN       = 2048;
localparam       P_NMP_SEQ_WIDTH         = $clog2(P_NMP_MAX_SEQ_LEN) + 1;          /* 12: holds 0 .. 2048             */
localparam       P_NMP_SCORE_ADDR_WIDTH  = $clog2(P_NMP_MAX_SEQ_LEN);              /* 11                              */

/* fp32 word (scores in the buffer, p_t, outputs) */
localparam       P_NMP_F32_WIDTH         = 32;

/* Fixed-point accumulator: two's complement, value = acc / 2^P_NMP_ACC_FRAC   */
localparam       P_NMP_ACC_W             = 64;
localparam       P_NMP_ACC_FRAC          = 32;

/* fp16 decode: 11-bit significand, exponent in [-14, 15] (6-bit signed)      */
localparam       P_NMP_SIG_W             = 11;
localparam       P_NMP_EXP_W             = 6;

/* p_t as unsigned fixed point Q1.31 in the V pass: value = p_fixed / 2^31    */
localparam       P_NMP_P_FIXED_W         = 32;
localparam       P_NMP_P_FIXED_FRAC      = 31;

/* Lane product: (up to 32-bit significand) x (11-bit significand)            */
localparam       P_NMP_PROD_W            = P_NMP_P_FIXED_W + P_NMP_SIG_W;          /* 43                              */

/* Block index space of one channel: 2^24 blocks of 32 B = 512 MiB */
localparam       P_NMP_BLK_ADDR_WIDTH    = 24;

/* Beats issued and not yet consumed: 2 x P_RD_ID_BUFFER_LEN (64 reads in flight per PS) */
localparam       P_NMP_INFLIGHT_MAX      = 2 * P_RD_ID_BUFFER_LEN;                 /* 128                             */
localparam       P_NMP_INFLIGHT_WIDTH    = $clog2(P_NMP_INFLIGHT_MAX);             /* 7                               */

/* Tokens with at least one beat in flight span at most 18 consecutive tokens  */
/* (128 beats / 8 + 2), so a 32-entry table indexed by t mod 32 never collides */
localparam       P_NMP_TOK_TABLE_LEN     = 32;
localparam       P_NMP_TOK_TABLE_WIDTH   = $clog2(P_NMP_TOK_TABLE_LEN);            /* 5                               */

/* Head output: P_NMP_D_HEAD values */
localparam       P_NMP_OUT_IDX_WIDTH     = $clog2(P_NMP_D_HEAD);                   /* 7                               */

/**********************************************************************************/
/* BLOCK INDEX -> CONTROLLER ADDRESS (mapping policy 1 of HBM_channel_controller) */
/*   PC     = address[2]                                                          */
/*   bank   = address[6:3]                                                        */
/*   column = address[14:10]                                                      */
/*   row    = address[28:15]                                                      */
/* address[1:0], address[9:7] and address[31:29] are not decoded.                 */
/* A sequential walk on the block index alternates the two PS at every block,     */
/* changes bank every 2 blocks and changes row every 1024 blocks (32 KiB).        */
/**********************************************************************************/
function automatic logic [31:0] f_nmp_blk_to_addr (input logic [P_NMP_BLK_ADDR_WIDTH-1:0] blk);
    logic [31:0] address;
    address        = 32'd0;
    address[2]     = blk[0];
    address[6:3]   = blk[4:1];
    address[14:10] = blk[9:5];
    address[28:15] = blk[23:10];
    return address;
endfunction

/******************************************************************************/
/* FP16 DECODE (synthesisable)                                                */
/* value = sig * 2^(exp - 10): sig = {1, m} for normals, {0, m} for zero and   */
/* subnormals (exp = -14). inf/nan are not expected and decode like a normal.  */
/******************************************************************************/
function automatic logic [P_NMP_SIG_W-1:0] f_nmp_fp16_sig (input logic [15:0] h);
    return { (h[14:10] != 5'd0), h[9:0] };
endfunction

function automatic logic signed [P_NMP_EXP_W-1:0] f_nmp_fp16_exp (input logic [15:0] h);
    if (h[14:10] == 5'd0) return -6'sd14;
    else                  return $signed({1'b0, h[14:10]}) - 6'sd15;
endfunction

/******************************************************************************/
/* FIXED-POINT ACCUMULATOR -> fp32, round to nearest even (synthesisable)     */
/* acc is two's complement, value = acc / 2^P_NMP_ACC_FRAC.                   */
/******************************************************************************/
function automatic logic [31:0] f_nmp_acc_to_fp32 (input logic signed [P_NMP_ACC_W-1:0] acc);
    logic                     s;
    logic [P_NMP_ACC_W-1:0]   mag;
    integer                   msb;                                       /* position of the leading one */
    integer                   e32;
    logic [P_NMP_ACC_W-1:0]   shifted;                                   /* leading one moved to bit 63 */
    logic [23:0]              m24;                                       /* 1 + 23 mantissa bits        */
    logic [24:0]              m25;
    logic [P_NMP_ACC_W-25:0]  rest;
    logic                     round_up;
    s   = acc[P_NMP_ACC_W-1];
    mag = s ? (~acc + 1'b1) : acc;
    if (mag == { P_NMP_ACC_W { 1'b0 } }) begin
        return 32'd0;
    end
    msb = 0;
    for (integer i = 0; i < P_NMP_ACC_W; i = i + 1) begin
        if (mag[i]) msb = i;
    end
    shifted  = mag << (P_NMP_ACC_W - 1 - msb);
    m24      = shifted[P_NMP_ACC_W-1 -: 24];
    rest     = shifted[P_NMP_ACC_W-25:0];
    round_up = rest[P_NMP_ACC_W-25] & ((rest[P_NMP_ACC_W-26:0] != { (P_NMP_ACC_W-25) { 1'b0 } }) | m24[0]);
    m25      = {1'b0, m24} + {24'd0, round_up};
    e32      = msb - P_NMP_ACC_FRAC + 127;
    if (m25[24]) begin                                                   /* mantissa overflow after rounding */
        m25 = 25'h800000;
        e32 = e32 + 1;
    end
    if (e32 >= 255) return {s, 8'hFF, 23'd0};
    if (e32 <= 0)   return {s, 31'd0};
    return {s, e32[7:0], m25[22:0]};
endfunction

/******************************************************************************/
/* fp32 in (0, 1] -> unsigned Q1.31 (truncation)                              */
/* p_fixed = floor(p * 2^31); p = 1.0 -> 2^31; bits below 2^-31 are dropped.  */
/******************************************************************************/
function automatic logic [P_NMP_P_FIXED_W-1:0] f_nmp_fp32_to_q31 (input logic [31:0] f);
    logic [23:0] sig;
    integer      sh;                                                     /* sig * 2^(e-127-23) * 2^31 = sig << (e-119) */
    if (f[30:23] == 8'd0) return { P_NMP_P_FIXED_W { 1'b0 } };
    sig = {1'b1, f[22:0]};
    sh  = integer'(f[30:23]) - 119;
    if (sh >= 0) return P_NMP_P_FIXED_W'(sig) << sh;
    else if (sh > -24) return P_NMP_P_FIXED_W'(sig) >> (-sh);
    else return { P_NMP_P_FIXED_W { 1'b0 } };
endfunction

/******************************************************************************/
/* BEHAVIOURAL FLOATING POINT HELPERS (softmax scan and scale, until step 2)  */
/******************************************************************************/
function automatic real f_nmp_fp32_to_real (input logic [31:0] f);
    logic        s;
    logic [7:0]  e;
    logic [22:0] m;
    logic [10:0] e64;
    real         r;
    s = f[31];
    e = f[30:23];
    m = f[22:0];
    if (e == 8'd0) begin
        r = 0.0;                                                         /* zero / subnormal (flushed) */
    end
    else if (e == 8'd255) begin
        r = 3.4028235e38;                                                /* inf / nan: clamp (not expected) */
    end
    else begin
        e64 = 11'd1023 - 11'd127 + {3'd0, e};                            /* rebias to double */
        r   = $bitstoreal({1'b0, e64, m, 29'd0});
    end
    return (s == 1'b1) ? -r : r;
endfunction

/* real (IEEE double) -> fp32 bit pattern, round to nearest even */
function automatic logic [31:0] f_nmp_real_to_fp32 (input real r);
    logic [63:0] d;
    logic        s;
    logic [10:0] e;
    logic [51:0] m;
    integer      e32;
    logic [23:0] m32;                                                    /* one guard bit for the carry */
    logic [28:0] rest;
    logic        round_up;
    d = $realtobits(r);
    s = d[63];
    e = d[62:52];
    m = d[51:0];
    if (e == 11'd0) begin
        return {s, 31'd0};                                               /* zero / double subnormal */
    end
    if (e == 11'h7FF) begin
        return {s, 8'hFF, 23'd0};                                        /* inf / nan */
    end
    e32      = integer'(e) - 1023 + 127;
    m32      = {1'b0, m[51:29]};
    rest     = m[28:0];
    round_up = rest[28] & ((rest[27:0] != 28'd0) | m[29]);
    m32      = m32 + {23'd0, round_up};
    if (m32[23] == 1'b1) begin                                           /* mantissa overflow after rounding */
        m32 = 24'd0;
        e32 = e32 + 1;
    end
    if (e32 >= 255) begin
        return {s, 8'hFF, 23'd0};                                        /* overflow -> inf */
    end
    if (e32 <= 0) begin
        return {s, 31'd0};                                               /* underflow -> 0 (flush) */
    end
    return {s, e32[7:0], m32[22:0]};
endfunction

`endif // NMP_ACCELERATOR_SVH__
