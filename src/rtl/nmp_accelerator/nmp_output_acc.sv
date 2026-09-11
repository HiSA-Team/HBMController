`timescale 1ps/1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"

/*******************************************************************************/
/* NMP OUTPUT ACCUMULATORS (V pass)                                            */
/*                                                                             */
/* 128 fixed-point accumulators, one per element of the head output:           */
/*   o_acc[16j + i] += p_t * v_t[16j + i]   for every beat (t, j) of the pass  */
/* A beat updates the 16 accumulators of its group j. Two input ports, one     */
/* per PS: PS0 delivers even blocks and PS1 odd blocks (the region base is     */
/* even), so the two ports never write the same group in the same cycle.       */
/* Integer sums: any order of arrival gives the same result.                   */
/*******************************************************************************/

module nmp_output_acc (
    input  logic                              clock_i,
    input  logic                              reset_ni,

    input  logic                              clear_i,          /* start of the job                      */

    /* Port 0 (PS0) */
    input  logic                              in0_valid_i,
    input  logic [P_NMP_BLK_IDX_WIDTH-1:0]    in0_blk_i,
    input  logic [P_NMP_ELEM_PER_BEAT*P_NMP_ACC_W-1:0] in0_prod_i,

    /* Port 1 (PS1) */
    input  logic                              in1_valid_i,
    input  logic [P_NMP_BLK_IDX_WIDTH-1:0]    in1_blk_i,
    input  logic [P_NMP_ELEM_PER_BEAT*P_NMP_ACC_W-1:0] in1_prod_i,

    /* Read port (normalisation) */
    input  logic [P_NMP_OUT_IDX_WIDTH-1:0]    rd_idx_i,
    output logic signed [P_NMP_ACC_W-1:0]     rd_acc_o
);

localparam LP_GROUP_W = P_NMP_ELEM_PER_BEAT * P_NMP_ACC_W;                /* 1024 bits per group of 16 */

/* Accumulators, packed: element k at [k*64 +: 64], group j at [j*1024 +: 1024] */
logic [P_NMP_D_HEAD*P_NMP_ACC_W-1:0]  r_acc;

logic [LP_GROUP_W-1:0]                group0;
logic [LP_GROUP_W-1:0]                group1;
logic [LP_GROUP_W-1:0]                group0_next;
logic [LP_GROUP_W-1:0]                group1_next;

assign group0 = r_acc[in0_blk_i*LP_GROUP_W +: LP_GROUP_W];
assign group1 = r_acc[in1_blk_i*LP_GROUP_W +: LP_GROUP_W];

always_comb begin
    for ( integer i = 0; i < P_NMP_ELEM_PER_BEAT; i = i + 1 ) begin
        group0_next[i*P_NMP_ACC_W +: P_NMP_ACC_W] = $signed(group0[i*P_NMP_ACC_W +: P_NMP_ACC_W]) + $signed(in0_prod_i[i*P_NMP_ACC_W +: P_NMP_ACC_W]);
        group1_next[i*P_NMP_ACC_W +: P_NMP_ACC_W] = $signed(group1[i*P_NMP_ACC_W +: P_NMP_ACC_W]) + $signed(in1_prod_i[i*P_NMP_ACC_W +: P_NMP_ACC_W]);
    end
end

always @ ( posedge clock_i or negedge reset_ni ) begin
    if ( reset_ni == 1'b0 ) begin
        r_acc <= { P_NMP_D_HEAD*P_NMP_ACC_W { 1'b0 } };
    end
    else begin
        if ( clear_i ) begin
            r_acc <= { P_NMP_D_HEAD*P_NMP_ACC_W { 1'b0 } };
        end
        else begin
            if ( in0_valid_i ) begin
                r_acc[in0_blk_i*LP_GROUP_W +: LP_GROUP_W] <= group0_next;
            end
            if ( in1_valid_i ) begin
                r_acc[in1_blk_i*LP_GROUP_W +: LP_GROUP_W] <= group1_next;
            end
        end
    end
end

assign rd_acc_o = r_acc[rd_idx_i*P_NMP_ACC_W +: P_NMP_ACC_W];

`ifdef DEBUG
always @ ( posedge clock_i ) begin
    if ( reset_ni == 1'b1 && in0_valid_i && in1_valid_i && in0_blk_i == in1_blk_i ) begin
        $display("[ NMP OACC ]: ERROR both ports write group %0d in the same cycle at %0t", in0_blk_i, $time);
    end
end
`endif

endmodule
