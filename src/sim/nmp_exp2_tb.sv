`timescale 1ps/1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"
`include "nmp_exp2_lut.svh"

/******************************************************************************/
/* STANDALONE TESTBENCH FOR nmp_exp2                                          */
/*                                                                            */
/* Two checks at once, on the same stream of vectors:                         */
/*                                                                            */
/*   1. bit exactness   - a golden model written here reproduces the intended  */
/*                        arithmetic (floor, table, interpolation, shift).     */
/*                        Every output must match it exactly.                  */
/*   2. accuracy        - the same output is compared against 2^x computed in  */
/*                        real arithmetic, and the worst error is reported.    */
/*                                                                            */
/* Coverage: every one of the 2^16 fractional parts, for every shift amount    */
/* from 0 to 33 (i.e. every x from 0 down to -34), which is the whole input    */
/* space that produces a non zero result plus the two rows past it. Then a     */
/* random sweep with m != 0 to exercise the subtraction, and the x > 0 clamp.  */
/******************************************************************************/

module nmp_exp2_tb;

localparam int LP_SCORE_W    = 32;
localparam int LP_SCORE_FRAC = 16;
localparam int LP_TAG_W      = P_NMP_SEQ_WIDTH;

localparam int LP_MAX_INT    = 34;                              /* how far down we sweep x               */
localparam real LP_TAB_ERR    = 1.2e-6;

logic clock;
logic reset_n;

logic                             valid_i;
logic signed [LP_SCORE_W-1:0]     s_i;
logic signed [LP_SCORE_W-1:0]     m_i;
logic [LP_TAG_W-1:0]              tag_i;

logic                             valid_o;
logic [LP_TAG_W-1:0]              tag_o;
logic [P_NMP_P_FIXED_W-1:0]       p_o;

nmp_exp2 #(
    .P_SCORE_W    ( LP_SCORE_W    ),
    .P_SCORE_FRAC ( LP_SCORE_FRAC ),
    .P_TAG_W      ( LP_TAG_W      )
) u_dut (
    .clock_i  ( clock   ),
    .reset_ni ( reset_n ),
    .valid_i  ( valid_i ),
    .s_i      ( s_i     ),
    .m_i      ( m_i     ),
    .tag_i    ( tag_i   ),
    .valid_o  ( valid_o ),
    .tag_o    ( tag_o   ),
    .p_o      ( p_o     )
);

always #500 clock = ~clock;

/******************************************************************************/
/* GOLDEN MODEL                                                               */
/******************************************************************************/
function automatic logic [P_NMP_P_FIXED_W-1:0] golden ( input logic signed [LP_SCORE_W:0] x_in );
    logic signed [LP_SCORE_W:0]        x;
    logic signed [LP_SCORE_W-LP_SCORE_FRAC:0] xi;
    logic [LP_SCORE_FRAC-1:0]          xf;
    logic [P_NMP_EXP2_IDX_W-1:0]       idx;
    logic [P_NMP_EXP2_REM_W-1:0]       rem;
    logic [P_NMP_EXP2_VAL_W-1:0]       val;
    logic [P_NMP_EXP2_DLT_W-1:0]       dlt;
    logic [31:0]                       prod;
    logic [P_NMP_P_FIXED_W-1:0]        y;
    int                                nsh;

    x   = ( x_in > 0 ) ? '0 : x_in;
    xi  = x[LP_SCORE_W -: (LP_SCORE_W-LP_SCORE_FRAC+1)];
    xf  = x[LP_SCORE_FRAC-1:0];
    nsh = -xi;
    if ( nsh >= P_NMP_P_FIXED_FRAC + 1 ) return '0;

    idx  = xf[LP_SCORE_FRAC-1 -: P_NMP_EXP2_IDX_W];
    rem  = xf[P_NMP_EXP2_REM_W-1:0];
    val  = P_NMP_EXP2_VAL[idx*P_NMP_EXP2_VAL_W +: P_NMP_EXP2_VAL_W];
    dlt  = P_NMP_EXP2_DLT[idx*P_NMP_EXP2_DLT_W +: P_NMP_EXP2_DLT_W];
    prod = dlt * rem;
    y    = val + ( prod >> P_NMP_EXP2_REM_W );
    return y >> nsh;
endfunction

/******************************************************************************/
/* SCOREBOARD                                                                 */
/******************************************************************************/
logic [P_NMP_P_FIXED_W-1:0] exp_q [$];
real                        ref_q [$];
logic [LP_TAG_W-1:0]        tag_q [$];
longint                     n_check;
longint                     n_bad;
longint                     n_tag_bad;
longint                     n_acc_bad;
real                        worst_abs;                          /* worst |p - 2^x| in LSB of Q1.31       */
real                        worst_rel;
real                        worst_rel_at;

task automatic drive ( input logic signed [LP_SCORE_W-1:0] s,
                       input logic signed [LP_SCORE_W-1:0] m,
                       input logic [LP_TAG_W-1:0]          tg );
    logic signed [LP_SCORE_W:0] x;
    real                        xr;
    x  = $signed( { s[LP_SCORE_W-1], s } ) - $signed( { m[LP_SCORE_W-1], m } );
    xr = ( x > 0 ) ? 0.0 : real'(x) / real'(1 << LP_SCORE_FRAC);

    exp_q.push_back( golden(x) );
    ref_q.push_back( ( -xr > 40.0 ) ? 0.0 : (2.0 ** xr) * real'(64'd1 << P_NMP_P_FIXED_FRAC) );
    tag_q.push_back( tg );

    @ ( posedge clock );
    #100;                                                       /* well after the edge, never racing it  */
    valid_i = 1'b1;
    s_i     = s;
    m_i     = m;
    tag_i   = tg;
endtask

always @ ( posedge clock ) begin
    if ( reset_n && valid_o ) begin
        automatic logic [P_NMP_P_FIXED_W-1:0] e;
        automatic real                        r;
        automatic logic [LP_TAG_W-1:0]        t;
        automatic real                        d;

        e = exp_q.pop_front();
        r = ref_q.pop_front();
        t = tag_q.pop_front();
        n_check++;

        if ( p_o !== e ) begin
            n_bad++;
            if ( n_bad <= 10 ) begin
                $display("[ TB ]: MISMATCH tag %0d  rtl %0d  golden %0d", tag_o, p_o, e);
            end
        end
        if ( tag_o !== t ) begin
            n_tag_bad++;
            if ( n_tag_bad <= 10 ) $display("[ TB ]: TAG MISMATCH got %0d expected %0d", tag_o, t);
        end

        /* Accuracy. Two sources of error, and they add:
             - the interpolated table, LP_TAB_ERR relative;
             - the truncation of the final right shift, up to 1 LSB absolute.
           So the result must stay inside r*LP_TAB_ERR + 1 LSB, with a little
           slack for the rounding of the reference itself.                     */
        d = real'(p_o) - r;
        if ( d < 0.0 ) d = -d;
        if ( d > r * LP_TAB_ERR + 1.5 ) begin
            n_acc_bad++;
            if ( n_acc_bad <= 10 ) begin
                $display("[ TB ]: ACCURACY tag %0d  rtl %0d  reference %0.2f  error %0.2f LSB",
                         tag_o, p_o, r, d);
            end
        end
        if ( d > worst_abs ) worst_abs = d;
        /* the relative figure only means something while the value is large */
        if ( r >= 16777216.0 && d / r > worst_rel ) begin
            worst_rel    = d / r;
            worst_rel_at = r;
        end
    end
end

/******************************************************************************/
/* STIMULUS                                                                   */
/******************************************************************************/
integer      n;
integer      f;
integer      k;
logic signed [LP_SCORE_W-1:0] s_val;
logic signed [LP_SCORE_W-1:0] m_val;
int unsigned seed;

initial begin
    clock     = 1'b0;
    reset_n   = 1'b0;
    valid_i   = 1'b0;
    s_i       = '0;
    m_i       = '0;
    tag_i     = '0;
    n_check   = 0;
    n_bad     = 0;
    n_tag_bad = 0;
    n_acc_bad = 0;
    worst_abs = 0.0;
    worst_rel = 0.0;
    seed      = 32'd1;

    repeat (8) @ ( posedge clock );
    reset_n = 1'b1;
    repeat (4) @ ( posedge clock );

    /* ---- 1. exhaustive: every fraction, every integer part ---- */
    $display("[ TB ]: exhaustive sweep, %0d integer parts x 65536 fractions", LP_MAX_INT + 1);
    for ( n = 0; n <= LP_MAX_INT; n = n + 1 ) begin
        for ( f = 0; f < 65536; f = f + 1 ) begin
            s_val = -( n * 32'sd65536 ) - f;
            drive( s_val, 32'sd0, LP_TAG_W'(f) );
        end
    end

    /* ---- 2. random, with a non zero maximum ---- */
    $display("[ TB ]: random sweep with m != 0");
    for ( k = 0; k < 200000; k = k + 1 ) begin
        m_val = $signed($urandom) % 32'sd8388608;                /* +/- 128.0 in Q15.16                   */
        s_val = m_val - ( $urandom % 32'd3000000 );              /* up to about 45 below                  */
        drive( s_val, m_val, LP_TAG_W'(k) );
    end

    /* ---- 3. corner cases ---- */
    $display("[ TB ]: corners");
    drive( 32'sd0,        32'sd0, 12'd0 );                       /* x = 0     -> 1.0                      */
    drive( -32'sd65536,   32'sd0, 12'd1 );                       /* x = -1    -> 0.5                      */
    drive( -32'sd32768,   32'sd0, 12'd2 );                       /* x = -0.5  -> 0.7071                   */
    drive( -32'sd1,       32'sd0, 12'd3 );                       /* one LSB below 0                       */
    drive( -32'sd2031616, 32'sd0, 12'd4 );                       /* x = -31                               */
    drive( -32'sd2097152, 32'sd0, 12'd5 );                       /* x = -32   -> 0                        */
    drive( -32'sd2162688, 32'sd0, 12'd6 );                       /* x = -33   -> 0                        */
    drive( 32'sd65536,    32'sd0, 12'd7 );                       /* x = +1, illegal, must clamp to 1.0    */
    drive( 32'sh7fffffff, 32'sh80000000, 12'd8 );                /* the widest possible positive x        */
    drive( 32'sh80000000, 32'sh7fffffff, 12'd9 );                /* the widest possible negative x        */

    @ ( posedge clock );
    #100;
    valid_i = 1'b0;
    repeat (16) @ ( posedge clock );

    $display("--------------------------------------------------------------");
    $display("[ TB ]: checked        %0d", n_check);
    $display("[ TB ]: bit mismatches %0d", n_bad);
    $display("[ TB ]: tag mismatches %0d", n_tag_bad);
    $display("[ TB ]: out of bound   %0d", n_acc_bad);
    $display("[ TB ]: queue left     %0d", exp_q.size());
    $display("[ TB ]: worst absolute error %0.2f LSB of Q1.31", worst_abs);
    $display("[ TB ]: worst relative error %0.3e  (at value %0.0f)", worst_rel, worst_rel_at);
    if ( n_bad == 0 && n_tag_bad == 0 && n_acc_bad == 0 && exp_q.size() == 0 && n_check > 0 ) begin
        $display("[ TB ]: ******** PASS ********");
    end
    else begin
        $display("[ TB ]: ******** FAIL ********");
    end
    $display("--------------------------------------------------------------");
    $finish;
end

endmodule
