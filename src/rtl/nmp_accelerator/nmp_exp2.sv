`timescale 1ps/1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"
`include "nmp_exp2_lut.svh"

/*************************************************************************/
/* This module executes the base 2 exponentiation as:                    */
/* 2^n * 2^f                                                             */
/* where f = x - n                                                       */
/* x is our number,                                                      */
/* n is the integer part, n = floor(x)                                   */
/* f is the decimal part of the number                                   */
/* since x is negative, 2^n is a right shift                             */
/* f belongs to [0, 1) so 2^f belongs to [1, 2),                         */
/* we can do a table for that                                            */
/* x is negative because it is always something - max                    */
/* so at most it is the max itself, and then x = 0                       */
/*                                                                       */
/* The module takes s and m separately and subtracts them itself, so the */
/* engine only has to wire the score buffer output and the running max.  */
/*                                                                       */
/*   x = s - m                        signed, P_SCORE_W + 1 bits, x <= 0 */
/*   n = x >>> P_SCORE_FRAC           floor(x): just the top bits of x   */
/*   f = x[P_SCORE_FRAC-1:0]          always in [0, 1), no sign          */
/*                                                                       */
/* floor() must round toward -infinity, not toward zero, so that f stays */
/* positive and one single table over [0, 1) is enough. In two's         */
/* complement that is exactly what taking the upper bits does, for free. */
/*                                                                       */
/* f is then split once more: the top P_NMP_EXP2_IDX_W bits index the    */
/* table, the remaining ones interpolate linearly toward the next entry. */
/*                                                                       */
/* Three pipeline stages, one result per cycle:                          */
/*   0 : subtract, floor, split into shift amount / index / remainder    */
/*   1 : read the two tables, multiply the delta by the remainder        */
/*   2 : add the interpolation, then shift right by the integer part     */
/*                                                                       */
/* The tag input travels with the data and comes back out with it, so    */
/* the caller can use it as the write address of the score buffer        */
/* without having to build a delay line of its own.                      */
/*                                                                       */
/* Boundary cases:                                                       */
/*   x = 0        -> n = 0, f = 0, y = VAL[0] = 2^31, p = 1.0 exactly    */
/*   x <= -32     -> the result is below the resolution of Q1.31, p = 0  */
/*   x > 0        -> cannot happen (m is the maximum): clamped to 0 and  */
/*                   reported in simulation                              */
/*************************************************************************/

module nmp_exp2 #(
    parameter int P_SCORE_W    = 32,                            /* width of s and m                       */
    parameter int P_SCORE_FRAC = 16,                            /* their fractional bits                  */
    parameter int P_OUT_W      = P_NMP_P_FIXED_W,               /* width of p                       (32)  */
    parameter int P_OUT_FRAC   = P_NMP_P_FIXED_FRAC,            /* its fractional bits              (31)  */
    parameter int P_TAG_W      = P_NMP_SEQ_WIDTH                /* token index carried through      (12)  */
) (
    input  logic                             clock_i,
    input  logic                             reset_ni,

    /* One score per cycle */
    input  logic                             valid_i,
    input  logic signed [P_SCORE_W-1:0]      s_i,               /* s'_t, from the score buffer            */
    input  logic signed [P_SCORE_W-1:0]      m_i,               /* m', the maximum of the pass            */
    input  logic [P_TAG_W-1:0]               tag_i,             /* travels with the data                  */

    /* Same, three cycles later */
    output logic                             valid_o,
    output logic [P_TAG_W-1:0]               tag_o,
    output logic [P_OUT_W-1:0]               p_o                /* 2^(s-m) in Q1.P_OUT_FRAC, unsigned     */
);

/* x needs one bit more than s and m, being their difference */
localparam int LP_X_W    = P_SCORE_W + 1;
/* bits of the integer part of x, i.e. floor(x) */
localparam int LP_INT_W  = LP_X_W - P_SCORE_FRAC;
/* bits of f left to the interpolation once the table index is taken */
localparam int LP_REM_W  = P_SCORE_FRAC - P_NMP_EXP2_IDX_W;
/* a shift of this much or more flushes p to zero */
localparam int LP_ZERO_N = P_OUT_FRAC + 1;
/* enough to hold LP_ZERO_N */
localparam int LP_NSH_W  = $clog2(LP_ZERO_N + 1);

/* The table is built for Q1.P_NMP_EXP2_FRAC, so the caller must ask for it */
// synthesis translate_off
initial begin
    if ( P_OUT_FRAC != P_NMP_EXP2_FRAC ) begin
        $fatal(1, "nmp_exp2: P_OUT_FRAC (%0d) does not match the table (%0d)",
               P_OUT_FRAC, P_NMP_EXP2_FRAC);
    end
    if ( LP_REM_W < 0 ) begin
        $fatal(1, "nmp_exp2: P_SCORE_FRAC (%0d) is narrower than the table index (%0d)",
               P_SCORE_FRAC, P_NMP_EXP2_IDX_W);
    end
end
// synthesis translate_on

/**************************************/
/* STAGE 0: subtract, floor, split    */
/**************************************/
logic signed [LP_X_W-1:0]            x;
logic signed [LP_X_W-1:0]            x_clamped;
logic signed [LP_INT_W-1:0]          x_int;                     /* floor(x), always <= 0                  */
logic [LP_INT_W-1:0]                 x_mag;                     /* -floor(x), the shift amount            */
logic [P_SCORE_FRAC-1:0]             x_frac;                    /* f, always >= 0                         */
logic                                s0_zero;                   /* the shift flushes everything out       */
logic [LP_NSH_W-1:0]                 s0_nsh;

logic                                r0_valid;
logic [P_TAG_W-1:0]                  r0_tag;
logic [P_NMP_EXP2_IDX_W-1:0]         r0_idx;
logic [LP_REM_W-1:0]                 r0_rem;
logic [LP_NSH_W-1:0]                 r0_nsh;
logic                                r0_zero;

always_comb begin
    x         = LP_X_W'(s_i) - LP_X_W'(m_i);
    /* m is the maximum, so x <= 0; clamping keeps the table in range if it is not.
       The test is on the sign bit on purpose: comparing against a constant would
       make the whole expression unsigned and every negative x would look huge.   */
    x_clamped = x[LP_X_W-1] ? x : { LP_X_W { 1'b0 } };

    x_int     = x_clamped[LP_X_W-1:P_SCORE_FRAC];               /* floor: the upper bits, signed          */
    x_frac    = x_clamped[P_SCORE_FRAC-1:0];                    /* f: the lower bits, unsigned            */

    /* x_int <= 0, so its negation always fits unsigned in the same width  */
    x_mag     = LP_INT_W'( -x_int );

    /* x_mag is the number of positions to shift right; past LP_ZERO_N it is all gone */
    s0_zero   = ( x_mag >= LP_INT_W'(LP_ZERO_N) );
    s0_nsh    = s0_zero ? LP_NSH_W'(LP_ZERO_N) : x_mag[LP_NSH_W-1:0];
end

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r0_valid <= 1'b0;
        r0_tag   <= { P_TAG_W { 1'b0 } };
        r0_idx   <= { P_NMP_EXP2_IDX_W { 1'b0 } };
        r0_rem   <= { LP_REM_W { 1'b0 } };
        r0_nsh   <= { LP_NSH_W { 1'b0 } };
        r0_zero  <= 1'b0;
    end
    else begin
        r0_valid <= valid_i;
        r0_tag   <= tag_i;
        r0_idx   <= x_frac[P_SCORE_FRAC-1 -: P_NMP_EXP2_IDX_W];
        r0_rem   <= x_frac[LP_REM_W-1:0];
        r0_nsh   <= s0_nsh;
        r0_zero  <= s0_zero;
    end
end

/**************************************/
/* STAGE 1: tables and interpolation  */
/**************************************/
logic [P_NMP_EXP2_VAL_W-1:0]         lut_val;
logic [P_NMP_EXP2_DLT_W-1:0]         lut_dlt;

logic                                 r1_valid;
logic [P_TAG_W-1:0]                   r1_tag;
logic [P_NMP_EXP2_VAL_W-1:0]          r1_val;
logic [P_NMP_EXP2_DLT_W+LP_REM_W-1:0] r1_prod;                  /* delta * remainder, not yet scaled      */
logic [LP_NSH_W-1:0]                  r1_nsh;
logic                                 r1_zero;

assign lut_val = P_NMP_EXP2_VAL[r0_idx * P_NMP_EXP2_VAL_W +: P_NMP_EXP2_VAL_W];
assign lut_dlt = P_NMP_EXP2_DLT[r0_idx * P_NMP_EXP2_DLT_W +: P_NMP_EXP2_DLT_W];

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r1_valid <= 1'b0;
        r1_tag   <= { P_TAG_W { 1'b0 } };
        r1_val   <= { P_NMP_EXP2_VAL_W { 1'b0 } };
        r1_prod  <= { (P_NMP_EXP2_DLT_W+LP_REM_W) { 1'b0 } };
        r1_nsh   <= { LP_NSH_W { 1'b0 } };
        r1_zero  <= 1'b0;
    end
    else begin
        r1_valid <= r0_valid;
        r1_tag   <= r0_tag;
        r1_val   <= lut_val;
        r1_prod  <= lut_dlt * r0_rem;                           /* unsigned, both operands are magnitudes */
        r1_nsh   <= r0_nsh;
        r1_zero  <= r0_zero;
    end
end

/***************************************/
/* STAGE 2: add, then shift by floor(x)*/
/***************************************/
/* y is 2^f in Q1.P_OUT_FRAC. It stays below 2.0 because the remainder never
   reaches a full step, so P_OUT_W bits are enough to hold it.               */
logic [P_OUT_W-1:0]                  y;

always_comb begin
    y = r1_val + P_OUT_W'( r1_prod >> LP_REM_W );
end

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        valid_o <= 1'b0;
        tag_o   <= { P_TAG_W { 1'b0 } };
        p_o     <= { P_OUT_W { 1'b0 } };
    end
    else begin
        valid_o <= r1_valid;
        tag_o   <= r1_tag;
        p_o     <= r1_zero ? { P_OUT_W { 1'b0 } } : ( y >> r1_nsh );
    end
end

`ifdef DEBUG
always @ ( posedge clock_i ) begin
    if ( reset_ni == 1'b1 && valid_i && ( $signed(s_i) > $signed(m_i) ) ) begin
        $display("[ NMP EXP2 ]: ERROR s (%0d) above the maximum m (%0d) at %0t",
                 $signed(s_i), $signed(m_i), $time);
    end
end
`endif

endmodule
