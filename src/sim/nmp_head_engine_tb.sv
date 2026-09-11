`timescale 1ps/1ps

`include "hbm_controller.svh"
`include "nmp_accelerator.svh"

// ---------------------------------------------------------------------------
// nmp_head_engine testbench - one MHA head on channel 0 of HBM_controller_top.
//
// Flow:
//   1. wait for reset_hbm_controller[0]
//   2. preload K_h and V_h into the HBM through the request port of channel 0
//      (WR requests, same 2-cycle protocol as HBM_controller_top_tb)
//   2b. read everything back through the same port and check it against the
//       stimulus (scoreboard by request id -> address -> expected block): tells
//       memory content apart from engine behaviour
//   3. hand the port to the engine, load q_h, start the job; every beat the
//      engine receives is checked by the same scoreboard, and every score it
//      produces is compared with nmp_scores.hex
//   4. collect o_h, compare with the reference, print the cycle statistics
//
// Stimulus / reference files (written by utils/nmp_gen_vectors.py, read from
// the simulation directory):
//   nmp_seq_len.hex  nmp_q.hex  nmp_k.hex  nmp_v.hex  nmp_scores.hex  nmp_ref.hex
//
// Channels 1..15 are instantiated (the PHY/MMCM/HBM stacks are built for 16
// lanes) but idle. Channel 0 is clocked by dfi_clk_buf[0].
//
// Console format (grep-able):
//   [TB] ...                      testbench progress
//   [TB STAT] ...                 cycle counters of the engine
//   [TB RET] ...                  read returns that do not match the stimulus (first ones)
//   [TB SCORE] ...                scores that do not match nmp_scores.hex (first ones)
//   [TB CHECK] ...                per-element comparison (only errors) and summary
//   [TB SUMMARY] RESULT: PASS|FAIL
// VCD dump only with +dump_vcd.
// ---------------------------------------------------------------------------

module nmp_head_engine_tb(

    );

    localparam int    N_CHANNELS    = 16;
    localparam int    REQ_ID_W      = P_REQ_ID_WIDTH;
    localparam int    MAX_S         = P_NMP_MAX_SEQ_LEN;
    localparam int    MAX_BLK       = MAX_S * P_NMP_BLK_PER_ROW;
    // Block index of the two regions (even, 8-aligned): K at row 0, V 2 MiB later
    localparam logic [P_NMP_BLK_ADDR_WIDTH-1:0] BASE_K_BLK = 24'h000000;
    localparam logic [P_NMP_BLK_ADDR_WIDTH-1:0] BASE_V_BLK = 24'h010000;
    // Idle cycles between the preload and the start of the engine
    localparam int    SETTLE_CYCLES = 500;
    // Relative tolerance on o_h. Everything up to the accumulators is integer and bit exact
    // (the scores are compared bit for bit separately); the tolerance only guards the one
    // floating point operation left, the final division by l.
    localparam real   REL_TOL       = 1.0e-3;
    localparam real   ABS_TOL       = 1.0e-4;
    // Give up if the engine does not finish within this many channel cycles
    localparam int    RUN_TIMEOUT   = 4_000_000;

reg HBM_REF_CLK_0;
reg ARESET_N_0;
reg APB_PCLK;
reg APB_PRESET_N;

////////////////////////////////////////////////////////////////////////////////
// Generating 100MHz REF clock
////////////////////////////////////////////////////////////////////////////////
initial HBM_REF_CLK_0 = 1'b0;
always HBM_REF_CLK_0 = #5000.00 ~HBM_REF_CLK_0;

////////////////////////////////////////////////////////////////////////////////
// Generating 100MHz APB clock and Reset
////////////////////////////////////////////////////////////////////////////////
initial APB_PCLK = 1'b0;
always APB_PCLK = #(10000/2.0) ~APB_PCLK;

initial begin
    APB_PRESET_N = 1'b0;
    #200ns;
    APB_PRESET_N = 1'b0;
    #4500ns;
    APB_PRESET_N = 1'b1;
end

initial begin
    ARESET_N_0 = 1'b0;
    #200ns;
    ARESET_N_0 = 1'b0;
    #4500ns;
    ARESET_N_0 = 1'b1;
end

////////////////////////////////////////////////////////////////////////////////
// DUT interface (all channels; only channel 0 is driven)
////////////////////////////////////////////////////////////////////////////////
logic clk_450 [0:N_CHANNELS-1];

logic [31:0]         input_address        [0:N_CHANNELS-1];
logic [255:0]        input_data           [0:N_CHANNELS-1];
logic [1:0]          input_request        [0:N_CHANNELS-1];
logic                request_valid        [0:N_CHANNELS-1];
logic [REQ_ID_W-1:0] request_id           [0:N_CHANNELS-1];
wire                 request_picked       [0:N_CHANNELS-1];
wire                 reset_hbm_controller [0:N_CHANNELS-1];
wire                 hbm_cattrip_output;

wire                 rd_data_valid_ps0    [0:N_CHANNELS-1];
wire                 rd_data_valid_ps1    [0:N_CHANNELS-1];
wire [REQ_ID_W-1:0]  rd_data_req_id_ps0   [0:N_CHANNELS-1];
wire [255:0]         rd_data_ps0          [0:N_CHANNELS-1];
wire [REQ_ID_W-1:0]  rd_data_req_id_ps1   [0:N_CHANNELS-1];
wire [255:0]         rd_data_ps1          [0:N_CHANNELS-1];

wire ch0_clk = clk_450[0];

////////////////////////////////////////////////////////////////////////////////
// Channel 0 port: testbench driver (preload) or engine
////////////////////////////////////////////////////////////////////////////////
logic                tb_owns_port;

logic [31:0]         tb_address;
logic [255:0]        tb_data;
logic [1:0]          tb_request;
logic                tb_request_valid;
logic [REQ_ID_W-1:0] tb_request_id;

logic [31:0]         eng_address;
logic [1:0]          eng_request;
logic [255:0]        eng_write_data;
logic [REQ_ID_W-1:0] eng_request_id;
logic                eng_request_valid;

always_comb begin
    for (int i = 0; i < N_CHANNELS; i++) begin
        input_address[i] = '0;
        input_data[i]    = '0;
        input_request[i] = '0;
        request_valid[i] = 1'b0;
        request_id[i]    = '0;
    end
    if (tb_owns_port) begin
        input_address[0] = tb_address;
        input_data[0]    = tb_data;
        input_request[0] = tb_request;
        request_valid[0] = tb_request_valid;
        request_id[0]    = tb_request_id;
    end else begin
        input_address[0] = eng_address;
        input_data[0]    = eng_write_data;
        input_request[0] = eng_request;
        request_valid[0] = eng_request_valid;
        request_id[0]    = eng_request_id;
    end
end

////////////////////////////////////////////////////////////////////////////////
// Engine interface
////////////////////////////////////////////////////////////////////////////////
logic                              q_wr_en;
logic [P_NMP_BLK_IDX_WIDTH-1:0]    q_wr_idx;
logic [255:0]                      q_wr_data;
logic                              eng_start;
logic [P_NMP_SEQ_WIDTH-1:0]        eng_seq_len;
wire                               eng_busy;
wire                               eng_done;
wire                               o_valid;
wire [P_NMP_OUT_IDX_WIDTH-1:0]     o_idx;
wire [31:0]                        o_data;
wire [31:0]                        cyc_pass_k, cyc_softmax, cyc_pass_v, cyc_total;
wire [31:0]                        stall_credit_cnt, wait_picked_cnt, starve_cnt, n_beats, n_dropped;
wire                               arith_overflow;

nmp_head_engine u_engine (
    .clock_i              (ch0_clk),
    .reset_ni             (reset_hbm_controller[0]),
    .q_wr_en_i            (q_wr_en),
    .q_wr_idx_i           (q_wr_idx),
    .q_wr_data_i          (q_wr_data),
    .start_i              (eng_start),
    .base_k_blk_i         (BASE_K_BLK),
    .base_v_blk_i         (BASE_V_BLK),
    .seq_len_i            (eng_seq_len),
    .busy_o               (eng_busy),
    .done_o               (eng_done),
    .o_valid_o            (o_valid),
    .o_idx_o              (o_idx),
    .o_o                  (o_data),
    .address_o            (eng_address),
    .request_o            (eng_request),
    .write_data_o         (eng_write_data),
    .request_id_o         (eng_request_id),
    .request_valid_o      (eng_request_valid),
    .request_picked_i     (request_picked[0] & ~tb_owns_port),
    .rd_data_valid_ps0_i  (rd_data_valid_ps0[0] & ~tb_owns_port),
    .rd_data_req_id_ps0_i (rd_data_req_id_ps0[0]),
    .rd_data_ps0_i        (rd_data_ps0[0]),
    .rd_data_valid_ps1_i  (rd_data_valid_ps1[0] & ~tb_owns_port),
    .rd_data_req_id_ps1_i (rd_data_req_id_ps1[0]),
    .rd_data_ps1_i        (rd_data_ps1[0]),
    .cyc_pass_k_o         (cyc_pass_k),
    .cyc_softmax_o        (cyc_softmax),
    .cyc_pass_v_o         (cyc_pass_v),
    .cyc_total_o          (cyc_total),
    .stall_credit_cnt_o   (stall_credit_cnt),
    .wait_picked_cnt_o    (wait_picked_cnt),
    .starve_cnt_o         (starve_cnt),
    .n_beats_o            (n_beats),
    .n_dropped_o          (n_dropped),
    .arith_overflow_o     (arith_overflow)
);

////////////////////////////////////////////////////////////////////////////////
// Stimulus and reference
////////////////////////////////////////////////////////////////////////////////
logic [31:0]  seq_len_mem [0:0];
logic [255:0] q_mem       [0:P_NMP_BLK_PER_ROW-1];
logic [255:0] k_mem       [0:MAX_BLK-1];
logic [255:0] v_mem       [0:MAX_BLK-1];
logic [31:0]  score_mem   [0:MAX_S-1];
logic [31:0]  ref_mem     [0:P_NMP_D_HEAD-1];
logic [31:0]  o_mem       [0:P_NMP_D_HEAD-1];
logic         o_seen      [0:P_NMP_D_HEAD-1];

int unsigned  S;
int unsigned  n_wr_issued = 0;
int unsigned  n_rb_issued = 0;        // readback reads issued by the testbench
// Scoreboard on channel 0 (both phases): id -> address for reads in flight,
// address -> block written at preload
logic [31:0]  pending_addr [int];
logic [255:0] mem_model    [int];
int unsigned  n_ret_rb = 0,  n_ret_rb_mism = 0,  n_ret_rb_swap = 0,  n_ret_rb_orph = 0;
int unsigned  n_ret_eng = 0, n_ret_eng_mism = 0, n_ret_eng_swap = 0, n_ret_eng_orph = 0;
int unsigned  n_ret_prints = 0;
int unsigned  n_score = 0, n_score_mism = 0, n_score_prints = 0;
localparam int MAX_RET_PRINTS   = 16;
localparam int MAX_SCORE_PRINTS = 8;
int unsigned  n_o_received = 0;
int unsigned  n_o_errors = 0;
real          max_rel_err = 0.0;
bit           engine_finished = 1'b0;
bit           engine_running  = 1'b0;
bit           run_timed_out   = 1'b0;
int unsigned  run_cycles      = 0;

// Watchdog on the engine run
always @(posedge ch0_clk) begin
    if (engine_running && !engine_finished) begin
        run_cycles++;
        if (run_cycles >= RUN_TIMEOUT) run_timed_out = 1'b1;
    end
end

initial begin
    tb_owns_port     = 1'b1;
    tb_address       = '0;
    tb_data          = '0;
    tb_request       = '0;
    tb_request_valid = 1'b0;
    tb_request_id    = '0;
    q_wr_en          = 1'b0;
    q_wr_idx         = '0;
    q_wr_data        = '0;
    eng_start        = 1'b0;
    eng_seq_len      = '0;
    for (int i = 0; i < P_NMP_D_HEAD; i++) begin
        o_mem[i]  = '0;
        o_seen[i] = 1'b0;
    end
    $readmemh("nmp_seq_len.hex", seq_len_mem);
    $readmemh("nmp_q.hex",       q_mem);
    $readmemh("nmp_k.hex",       k_mem);
    $readmemh("nmp_v.hex",       v_mem);
    $readmemh("nmp_scores.hex",  score_mem);
    $readmemh("nmp_ref.hex",     ref_mem);
    S = seq_len_mem[0];
    if (S < 1 || S > MAX_S)
        $fatal(1, "nmp_head_engine_tb: bad seq_len %0d in nmp_seq_len.hex", S);
    $display("[TB] S=%0d tokens, %0d blocks per region, K at blk %0d, V at blk %0d", S, S*P_NMP_BLK_PER_ROW, BASE_K_BLK, BASE_V_BLK);
end

// Testbench request driver on channel 0: phase 1 writes K then V (preload),
// phase 2 reads every block back (readback). Clocked process with the same
// protocol as the stimulus of HBM_controller_top_tb: the bus changes only on
// the edge where request_valid && request_picked is seen, so it is stable in
// the picked cycle.
logic        preload_go    = 1'b0;
logic        preload_done  = 1'b0;
logic        readback_go   = 1'b0;
logic        readback_done = 1'b0;
int unsigned pre_idx       = 0;         // next block to present, 0 .. 2*S*8-1

function automatic logic [P_NMP_BLK_ADDR_WIDTH-1:0] f_pre_blk(input int unsigned idx);
    if (idx < S*P_NMP_BLK_PER_ROW) return BASE_K_BLK + idx[P_NMP_BLK_ADDR_WIDTH-1:0];
    else                           return BASE_V_BLK + (idx - S*P_NMP_BLK_PER_ROW);
endfunction

function automatic logic [255:0] f_pre_data(input int unsigned idx);
    if (idx < S*P_NMP_BLK_PER_ROW) return k_mem[idx];
    else                           return v_mem[idx - S*P_NMP_BLK_PER_ROW];
endfunction

always @(posedge ch0_clk) begin
    if ((preload_go && !preload_done) || (readback_go && !readback_done)) begin
        if (tb_request_valid && request_picked[0]) begin
            if (tb_request == P_WRT_REQ) n_wr_issued++;
            else                         n_rb_issued++;
            tb_request_id <= tb_request_id + 1'b1;
        end
        if (~tb_request_valid || (tb_request_valid && request_picked[0])) begin
            if (pre_idx < 2*S*P_NMP_BLK_PER_ROW) begin
                tb_address       <= f_nmp_blk_to_addr(f_pre_blk(pre_idx));
                tb_data          <= f_pre_data(pre_idx);
                tb_request       <= (preload_go && !preload_done) ? P_WRT_REQ : P_RD_REQ;
                tb_request_valid <= 1'b1;
                pre_idx++;
            end else begin
                tb_request_valid <= 1'b0;
                if (preload_go && !preload_done) preload_done <= 1'b1;
                else                             readback_done <= 1'b1;
            end
        end
    end
end

// Scoreboard: log every accepted request on channel 0 (whoever owns the port)
always @(posedge ch0_clk) begin
    if (request_valid[0] === 1'b1 && request_picked[0] === 1'b1) begin
        if (input_request[0] == P_RD_REQ)
            pending_addr[int'(request_id[0])] = input_address[0];
        else
            mem_model[int'(input_address[0])] = input_data[0];
    end
end

// Scoreboard: check every read return on channel 0 against the block written
task automatic tb_check_return(input int ps, input logic [REQ_ID_W-1:0] rid, input logic [255:0] rdata);
    logic [31:0]  addr;
    logic [255:0] expct, swapped;
    string        fp;
    bit           eng = ~tb_owns_port;
    if (eng) n_ret_eng++; else n_ret_rb++;
    if (pending_addr.exists(int'(rid)) == 0) begin
        if (eng) n_ret_eng_orph++; else n_ret_rb_orph++;
        if (n_ret_prints < MAX_RET_PRINTS) begin
            n_ret_prints++;
            $display("[TB RET] %s id=%0d ps%0d ORPHAN (id not pending) at %0t", eng ? "engine" : "readback", rid, ps, $time);
        end
        return;
    end
    addr = pending_addr[int'(rid)];
    pending_addr.delete(int'(rid));
    expct   = mem_model.exists(int'(addr)) ? mem_model[int'(addr)] : 256'hx;
    swapped = {expct[127:0], expct[255:128]};
    if (rdata === expct) return;
    if (rdata === swapped) begin
        if (eng) n_ret_eng_swap++; else n_ret_rb_swap++;
    end else begin
        if (eng) n_ret_eng_mism++; else n_ret_rb_mism++;
    end
    if (n_ret_prints < MAX_RET_PRINTS) begin
        n_ret_prints++;
        fp = "";
        for (int l = 3; l >= 0; l--) begin
            logic [63:0] g = rdata[l*64 +: 64];
            logic [63:0] e = expct[l*64 +: 64];
            if (g === e)                        fp = {fp, "m"};
            else if (^g === 1'bx)               fp = {fp, "x"};
            else if (g == 64'hFFFFFFFFFFFFFFFF) fp = {fp, "F"};
            else if (g == 64'h0)                fp = {fp, "0"};
            else                                fp = {fp, "o"};
        end
        $display("[TB RET] %s id=%0d ps%0d addr=%08x blk=%0d %s lanes=%s at %0t\n         got %064x\n         exp %064x",
                 eng ? "engine" : "readback", rid, ps, addr,
                 {addr[28:15], addr[14:10], addr[6:3], addr[2]}, (rdata === swapped) ? "match-swapped" : "MISMATCH", fp, $time, rdata, expct);
    end
endtask

always @(posedge ch0_clk) begin
    if (rd_data_valid_ps0[0] === 1'b1) tb_check_return(0, rd_data_req_id_ps0[0], rd_data_ps0[0]);
    if (rd_data_valid_ps1[0] === 1'b1) tb_check_return(1, rd_data_req_id_ps1[0], rd_data_ps1[0]);
end

// Score monitor: every score the engine writes into its buffer vs nmp_scores.hex
always @(posedge ch0_clk) begin
    if (u_engine.dp_score_valid === 1'b1) begin
        n_score++;
        if (u_engine.dp_score !== score_mem[u_engine.dp_score_tok]) begin
            n_score_mism++;
            if (n_score_prints < MAX_SCORE_PRINTS) begin
                n_score_prints++;
                /* s' is Q15.16 now, not fp32: print it as such */
                $display("[TB SCORE] tok=%0d got %08x (%f) expected %08x (%f) at %0t", u_engine.dp_score_tok,
                         u_engine.dp_score, real'($signed(u_engine.dp_score)) / 65536.0,
                         score_mem[u_engine.dp_score_tok], real'($signed(score_mem[u_engine.dp_score_tok])) / 65536.0, $time);
            end
        end
    end
end

initial begin
    // 1. controller out of reset
    wait (reset_hbm_controller[0] === 1'b1);
    repeat (20) @(posedge ch0_clk);
    $display("[TB] channel 0 controller out of reset at %0t", $time);

    // 2. preload K_h then V_h
    $display("[TB] preload: %0d blocks (K from blk %0d, V from blk %0d) at %0t", 2*S*P_NMP_BLK_PER_ROW, BASE_K_BLK, BASE_V_BLK, $time);
    preload_go = 1'b1;
    wait (preload_done === 1'b1);
    $display("[TB] preload done: %0d writes accepted at %0t", n_wr_issued, $time);
    repeat (SETTLE_CYCLES) @(posedge ch0_clk);

    // 2b. read everything back and check it (memory content, independent of the engine)
    pre_idx = 0;
    readback_go = 1'b1;
    wait (readback_done === 1'b1);
    wait (n_ret_rb >= n_rb_issued);
    $display("[TB] readback done: %0d reads, %0d returned, %0d mismatch, %0d swapped, %0d orphan at %0t",
             n_rb_issued, n_ret_rb, n_ret_rb_mism, n_ret_rb_swap, n_ret_rb_orph, $time);
    repeat (SETTLE_CYCLES) @(posedge ch0_clk);

    // 3. port to the engine, load q, start
    tb_owns_port <= 1'b0;
    @(posedge ch0_clk);
    for (int j = 0; j < P_NMP_BLK_PER_ROW; j++) begin
        q_wr_en   <= 1'b1;
        q_wr_idx  <= j[P_NMP_BLK_IDX_WIDTH-1:0];
        q_wr_data <= q_mem[j];
        @(posedge ch0_clk);
    end
    q_wr_en <= 1'b0;
    @(posedge ch0_clk);
    eng_seq_len <= S[P_NMP_SEQ_WIDTH-1:0];
    eng_start   <= 1'b1;
    @(posedge ch0_clk);
    eng_start   <= 1'b0;
    $display("[TB] engine started at %0t", $time);

    // 4. wait for done (or the timeout watchdog below)
    engine_running = 1'b1;
    wait (eng_done === 1'b1 || run_timed_out);
    @(posedge ch0_clk);
    engine_finished = 1'b1;
    if (run_timed_out) begin
        $display("[TB] TIMEOUT: engine not done after %0d cycles (busy=%0b, beats=%0d)", RUN_TIMEOUT, eng_busy, n_beats);
        tb_summary(1'b1);
        $finish;
    end
    tb_summary(1'b0);
    $finish;
end

////////////////////////////////////////////////////////////////////////////////
// Output collection
////////////////////////////////////////////////////////////////////////////////
always @(posedge ch0_clk) begin
    if (o_valid === 1'b1) begin
        o_mem[o_idx]  = o_data;
        o_seen[o_idx] = 1'b1;
        n_o_received++;
    end
end

////////////////////////////////////////////////////////////////////////////////
// Check and summary
////////////////////////////////////////////////////////////////////////////////
task automatic tb_summary(input logic timed_out);
    real got, exp_, err, rel;
    real eff_k, eff_v;
    n_o_errors  = 0;
    max_rel_err = 0.0;
    for (int i = 0; i < P_NMP_D_HEAD; i++) begin
        if (!o_seen[i]) begin
            n_o_errors++;
            $display("[TB CHECK] o[%0d] never produced", i);
            continue;
        end
        got  = f_nmp_fp32_to_real(o_mem[i]);
        exp_ = f_nmp_fp32_to_real(ref_mem[i]);
        err  = (got > exp_) ? got - exp_ : exp_ - got;
        rel  = err / (((exp_ < 0.0) ? -exp_ : exp_) + ABS_TOL);
        if (rel > max_rel_err) max_rel_err = rel;
        if (rel > REL_TOL) begin
            n_o_errors++;
            $display("[TB CHECK] o[%0d] got %f (%08x) expected %f (%08x) rel err %e", i, got, o_mem[i], exp_, ref_mem[i], rel);
        end
    end

    eff_k = (cyc_pass_k > 0) ? real'(2*S*P_NMP_BLK_PER_ROW) / real'(cyc_pass_k) : 0.0;
    eff_v = (cyc_pass_v > 0) ? real'(2*S*P_NMP_BLK_PER_ROW) / real'(cyc_pass_v) : 0.0;

    $display("");
    $display("[TB STAT] S=%0d  blocks per pass=%0d  preload writes=%0d", S, S*P_NMP_BLK_PER_ROW, n_wr_issued);
    $display("[TB STAT] cycles: pass K %0d, softmax %0d, pass V %0d, total %0d", cyc_pass_k, cyc_softmax, cyc_pass_v, cyc_total);
    $display("[TB STAT] lower bound per pass at 1 request / 2 cycles: %0d cycles -> efficiency K %.3f, V %.3f", 2*S*P_NMP_BLK_PER_ROW, eff_k, eff_v);
    $display("[TB STAT] beats consumed %0d, dropped %0d, credit stalls %0d, extra picked waits %0d, starved pass cycles %0d, arithmetic overflow %0b", n_beats, n_dropped, stall_credit_cnt, wait_picked_cnt, starve_cnt, arith_overflow);
    $display("[TB STAT] cycles per token: pass K %.2f, pass V %.2f (16 = ideal)", real'(cyc_pass_k)/real'(S), real'(cyc_pass_v)/real'(S));
    $display("[TB CHECK] readback: %0d reads, %0d returned, %0d mismatch, %0d swapped, %0d orphan", n_rb_issued, n_ret_rb, n_ret_rb_mism, n_ret_rb_swap, n_ret_rb_orph);
    $display("[TB CHECK] engine beats: %0d returned, %0d mismatch, %0d swapped, %0d orphan", n_ret_eng, n_ret_eng_mism, n_ret_eng_swap, n_ret_eng_orph);
    $display("[TB CHECK] scores: %0d produced, %0d differ from nmp_scores.hex", n_score, n_score_mism);
    $display("[TB CHECK] %0d/%0d outputs received, %0d errors, max rel err %e (tol %e)", n_o_received, P_NMP_D_HEAD, n_o_errors, max_rel_err, REL_TOL);
    $display("[TB SUMMARY] %s", (!timed_out && n_o_errors == 0 && n_o_received == P_NMP_D_HEAD &&
                                  n_ret_rb_mism == 0 && n_ret_eng_mism == 0 && n_score_mism == 0 &&
                                  n_dropped == 0 && !arith_overflow) ? "RESULT: PASS" : "RESULT: FAIL");
    $display("");
endtask

////////////////////////////////////////////////////////////////////////////////
// DUT
////////////////////////////////////////////////////////////////////////////////
HBM_controller_top #(.N_CHANNELS(N_CHANNELS))
u_hbm_core (
    .HBM_REF_CLK_0(HBM_REF_CLK_0),
     .ARESET_N_0(ARESET_N_0),
     .APB_PCLK_0(APB_PCLK),
     .APB_PRESET_N_0(APB_PRESET_N),
     .ARESET_N_1(ARESET_N_0),
     .APB_PCLK_1(APB_PCLK),
     .APB_PRESET_N_1(APB_PRESET_N),

    .address(input_address),
    .request(input_request),
    .write_data(input_data),
    .request_valid(request_valid),
    .request_picked(request_picked),
    .request_id(request_id),
    .reset_hbm_controller(reset_hbm_controller),
    .rd_data_valid_ps0(rd_data_valid_ps0),
    .rd_data_valid_ps1(rd_data_valid_ps1),
    .rd_data_req_id_ps0(rd_data_req_id_ps0),
    .rd_data_ps0(rd_data_ps0),
    .rd_data_req_id_ps1(rd_data_req_id_ps1),
    .rd_data_ps1(rd_data_ps1),
    .hbm_cattrip_output(hbm_cattrip_output),

    .dfi_clk_buf(clk_450)
);

// VCD only on request: vsim ... +dump_vcd
initial begin
    if ($test$plusargs("dump_vcd")) begin
        $dumpfile("nmp_head_engine.vcd");
        $dumpvars(0, u_engine);
    end
end

endmodule
