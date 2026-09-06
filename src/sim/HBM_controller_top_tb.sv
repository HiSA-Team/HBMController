`timescale 1ps/1ps

// ---------------------------------------------------------------------------
// HBM_controller_top testbench - trace driven, all N_CHANNELS in parallel.
//
// Every channel reads TRACE_FILE independently and drives its own request port.
// Changes w.r.t. the previous version (2026-09-05):
//   * request_id is a per-channel counter, +1 on every accepted request.
//     The RTL uses {request_id, bank[3:0]} as the CAS-RAM address, so a
//     constant id makes consecutive requests to the same bank overwrite
//     each other's write data / column.
//   * all stimulus arrays are initialised (no X into the DUT before reset).
//   * blank / short trace lines are skipped (the old loop issued a spurious
//     WR to address 0 on the trailing newline).
//   * scoreboard: every accepted request is logged; reads are matched on
//     return through rd_data_req_id_ps0/ps1 and compared with a simple
//     memory model written at acceptance time.
//   * the simulation ends when every channel has issued its trace AND all
//     issued reads have returned, or after DRAIN_TIMEOUT DFI cycles; the
//     summary lists, per channel, reads issued / returned / missing.
//   * channels 7 and 15 are clocked from clk_450[6]/[14] (their exported
//     dfi_clk_buf entries are undriven in HBM_controller_top).
//   * VCD dump is off by default; run with +dump_vcd to enable it
//     (16 channels of $dumpvars(0, ...) is tens of GB and slows Questa a lot).
//
// Console format (grep-able):
//   [TB ch N] REQ id=.. RD|WR addr=........ accepted at <t>
//   [TB ch N] RET id=.. psX addr=........ <match|match-swapped|MISMATCH lanes=....|unknown|ORPHAN> at <t>
//   [TB ch N] PENDING RD id=.. addr=........ never returned   (only on drain timeout)
//   [TB ch N] TRACE DONE ...
//   [TB DRAIN] ... (only refresh traffic is left in the RTL log from here on)
//   [TB SUMMARY] ...
// The RTL keeps its own "[ LLCF ]: REQ: .. served at .." prints (DEBUG).
// ---------------------------------------------------------------------------

module HBM_controller_top_tb(

    );

    // Must match HBM_controller_top; PHY/MMCM/HBM stacks in that module are built for 16 lanes.
    localparam int    N_CHANNELS    = 16;
    localparam string TRACE_FILE    = "./example_0.txt";
    // Must match P_REQ_ID_WIDTH in hbm_controller.svh when DEBUG is defined (sim_1 fileset).
    localparam int    REQ_ID_W      = 24;
    // DFI cycles to wait for outstanding reads after the last channel finished its trace.
    localparam int    DRAIN_TIMEOUT = 5000;
    // How many data mismatches to print in full before going quiet (per channel).
    localparam int    MAX_MISMATCH_PRINTS = 8;

    // HBM_controller_top drives dfi_clk_buf[7] and [15] from the same BUFG as
    // channels 6 and 14 (one MMCM has 7 outputs per stack) and leaves the
    // exported dfi_clk_buf[7]/[15] undriven. Clock the stimulus of those two
    // channels from their real clock source.
    // (see CLK_SRC inside g_ch_stim)

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
// DUT interface
////////////////////////////////////////////////////////////////////////////////
logic clk_450 [0:N_CHANNELS-1];

reg  [31:0]         input_address        [0:N_CHANNELS-1];
reg  [255:0]        input_data           [0:N_CHANNELS-1];
reg  [1:0]          input_request        [0:N_CHANNELS-1];
reg                 request_valid        [0:N_CHANNELS-1];
logic [REQ_ID_W-1:0] request_id          [0:N_CHANNELS-1];
wire                request_picked       [0:N_CHANNELS-1];
wire                reset_hbm_controller [0:N_CHANNELS-1];
wire                hbm_cattrip_output;

wire                rd_data_valid_ps0    [0:N_CHANNELS-1];
wire                rd_data_valid_ps1    [0:N_CHANNELS-1];
wire [REQ_ID_W-1:0] rd_data_req_id_ps0   [0:N_CHANNELS-1];
wire [255:0]        rd_data_ps0          [0:N_CHANNELS-1];
wire [REQ_ID_W-1:0] rd_data_req_id_ps1   [0:N_CHANNELS-1];
wire [255:0]        rd_data_ps1          [0:N_CHANNELS-1];

////////////////////////////////////////////////////////////////////////////////
// Per-channel bookkeeping (visible to the summary)
////////////////////////////////////////////////////////////////////////////////
integer      fd                 [0:N_CHANNELS-1];
logic        f_open             [0:N_CHANNELS-1];
logic        channel_trace_done [0:N_CHANNELS-1];

int unsigned n_req_accepted     [0:N_CHANNELS-1];
int unsigned n_wr_issued        [0:N_CHANNELS-1];
int unsigned n_rd_issued        [0:N_CHANNELS-1];
int unsigned n_rd_returned      [0:N_CHANNELS-1];
int unsigned n_rd_match         [0:N_CHANNELS-1];
int unsigned n_rd_match_swapped [0:N_CHANNELS-1];
int unsigned n_rd_mismatch      [0:N_CHANNELS-1];
int unsigned n_rd_unknown       [0:N_CHANNELS-1];   // address never written by this trace
int unsigned n_rd_orphan        [0:N_CHANNELS-1];   // returned id not pending (mislabelled / duplicated)
int unsigned n_mm_allff         [0:N_CHANNELS-1];   // mismatch, all four lanes all-ones (idle write bus captured)
int unsigned n_mm_halfff        [0:N_CHANNELS-1];   // mismatch, one 128-bit half all-ones
int unsigned n_mm_other         [0:N_CHANNELS-1];   // mismatch, other data (stale / wrong entry)

initial begin
    for (int i = 0; i < N_CHANNELS; i++) begin
        f_open[i]             = 1'b0;
        channel_trace_done[i] = 1'b0;
        input_address[i]      = '0;
        input_data[i]         = '0;
        input_request[i]      = '0;
        request_valid[i]      = 1'b0;
        request_id[i]         = '0;
        n_req_accepted[i]     = 0;
        n_wr_issued[i]        = 0;
        n_rd_issued[i]        = 0;
        n_rd_returned[i]      = 0;
        n_rd_match[i]         = 0;
        n_rd_match_swapped[i] = 0;
        n_rd_mismatch[i]      = 0;
        n_rd_unknown[i]       = 0;
        n_rd_orphan[i]        = 0;
        n_mm_allff[i]         = 0;
        n_mm_halfff[i]        = 0;
        n_mm_other[i]         = 0;
    end
end

////////////////////////////////////////////////////////////////////////////////
// Trace helpers
////////////////////////////////////////////////////////////////////////////////

// Parse one stimulus line (RD/WR + address + optional 256b write data).
task automatic tb_parse_trace_line(
    input  string       line,
    output string       req_kind,
    output reg [31:0]   addr,
    output reg [255:0]  wdata
);
    reg [31:0] tmp_data;
    req_kind = line.substr(0, 1);
    addr     = line.substr(3, 10).atohex();
    wdata    = '0;
    if (line.len() >= 64 + 2 + 8) begin
        wdata = line.substr(12, 19).atohex();
        wdata = wdata << 32;
        tmp_data = line.substr(20, 27).atohex();
        wdata = (wdata + tmp_data) << 32;
        tmp_data = line.substr(28, 35).atohex();
        wdata = (wdata + tmp_data) << 32;
        tmp_data = line.substr(36, 43).atohex();
        wdata = (wdata + tmp_data) << 32;
        tmp_data = line.substr(44, 51).atohex();
        wdata = (wdata + tmp_data) << 32;
        tmp_data = line.substr(52, 59).atohex();
        wdata = (wdata + tmp_data) << 32;
        tmp_data = line.substr(60, 67).atohex();
        wdata = (wdata + tmp_data) << 32;
        tmp_data = line.substr(68, 75).atohex();
        wdata = (wdata + tmp_data);
    end
endtask

// Fetch the next usable line ("RD xxxxxxxx" is 11 chars; anything shorter is skipped).
// ok = 0 when the file is exhausted.
task automatic tb_next_line(input integer fdesc, output string line, output logic ok);
    line = "";
    ok   = 1'b0;
    while (!$feof(fdesc)) begin
        void'($fgets(line, fdesc));
        if (line.len() >= 11) begin
            ok = 1'b1;
            return;
        end
    end
endtask

function automatic logic all_channels_trace_done();
    for (int j = 0; j < N_CHANNELS; j++)
        if (!channel_trace_done[j])
            return 1'b0;
    return 1'b1;
endfunction

function automatic logic all_reads_returned();
    for (int j = 0; j < N_CHANNELS; j++)
        if (n_rd_returned[j] < n_rd_issued[j])
            return 1'b0;
    return 1'b1;
endfunction

////////////////////////////////////////////////////////////////////////////////
// End of simulation: all traces issued and all reads back, or drain timeout.
////////////////////////////////////////////////////////////////////////////////
int unsigned drain_cycles = 0;
bit          sim_finished = 1'b0;
bit          dump_pending = 1'b0;   // set at the end: every channel lists the reads still pending



////////////////////////////////////////////////////////////////////////////////
// Per-channel stimulus + scoreboard
////////////////////////////////////////////////////////////////////////////////
genvar gi;
generate
    for (gi = 0; gi < N_CHANNELS; gi++) begin : g_ch_stim

        localparam int CLK_SRC = (gi == 7) ? 6 : (gi == 15) ? 14 : gi;
        wire ch_clk = clk_450[CLK_SRC];

        // Scoreboard state, one copy per channel.
        logic [31:0]  pending_addr [int];   // request_id -> address, for reads in flight
        logic [255:0] mem_model    [int];   // address    -> last data written

        // ---------------- stimulus ----------------
        always @(posedge ch_clk) begin
            string line;
            string request;
            reg [31:0]  address;
            reg [255:0] data;
            logic       ok;

            if (f_open[gi] == 0) begin
                request_valid[gi] <= 1'b0;
                fd[gi] = $fopen(TRACE_FILE, "r");
                if (fd[gi] == 0)
                    $fatal(1, "HBM_controller_top_tb: cannot open trace %s for channel %0d", TRACE_FILE, gi);
                f_open[gi] <= 1'b1;
            end

            if (reset_hbm_controller[gi] == 1'b1 && f_open[gi]) begin

                // The request on the bus has just been accepted (picked is the
                // registered ack of the previous edge). Log it with the values
                // still on the bus, then advance the id.
                if (request_valid[gi] && request_picked[gi]) begin
                    n_req_accepted[gi] = n_req_accepted[gi] + 1;
                    if (input_request[gi] == 2'b01) begin
                        n_rd_issued[gi] = n_rd_issued[gi] + 1;
                        pending_addr[int'(request_id[gi])] = input_address[gi];
                        $display("[TB ch %0d] REQ id=%0d RD addr=%08x accepted at %0t", gi, request_id[gi], input_address[gi], $time);
                    end else begin
                        n_wr_issued[gi] = n_wr_issued[gi] + 1;
                        mem_model[int'(input_address[gi])] = input_data[gi];
                        $display("[TB ch %0d] REQ id=%0d WR addr=%08x accepted at %0t", gi, request_id[gi], input_address[gi], $time);
                    end
                    request_id[gi] <= request_id[gi] + 1'b1;
                end

                // Present the next request as soon as the current one is
                // accepted (or if none is pending). Address/data/id all change
                // on the same edge, so the bus is stable during the picked cycle
                // (the CAS RAMs are written in that cycle).
                if (~request_valid[gi] || (request_valid[gi] && request_picked[gi])) begin
                    if (!channel_trace_done[gi]) begin
                        tb_next_line(fd[gi], line, ok);
                        if (ok) begin
                            tb_parse_trace_line(line, request, address, data);
                            if (request == "RD")
                                input_request[gi] <= 2'b01;
                            else
                                input_request[gi] <= 2'b00;
                            input_address[gi] <= address;
                            if (line.len() >= 64 + 2 + 8)
                                input_data[gi] <= data;
                            request_valid[gi] <= 1'b1;
                        end else begin
                            request_valid[gi] <= 1'b0;
                            $fclose(fd[gi]);
                            channel_trace_done[gi] <= 1'b1;
                            $display("[TB ch %0d] TRACE DONE: %0d requests accepted (%0d WR, %0d RD) at %0t",
                                     gi, n_req_accepted[gi], n_wr_issued[gi], n_rd_issued[gi], $time);
                        end
                    end else begin
                        request_valid[gi] <= 1'b0;
                    end
                end
            end
        end

        // ---------------- read-return monitor ----------------
        task automatic tb_check_return(
            input int                 ps,
            input logic [REQ_ID_W-1:0] rid,
            input logic [255:0]       rdata
        );
            logic [31:0]  addr;
            logic [255:0] expct;
            logic [255:0] swapped;
            string        fp;
            n_rd_returned[gi] = n_rd_returned[gi] + 1;
            if (pending_addr.exists(int'(rid)) == 0) begin
                n_rd_orphan[gi] = n_rd_orphan[gi] + 1;
                $display("[TB ch %0d] RET id=%0d ps%0d ORPHAN (id not pending) data=%064x at %0t", gi, rid, ps, rdata, $time);
                return;
            end
            addr = pending_addr[int'(rid)];
            pending_addr.delete(int'(rid));
            if (mem_model.exists(int'(addr)) == 0) begin
                n_rd_unknown[gi] = n_rd_unknown[gi] + 1;
                $display("[TB ch %0d] RET id=%0d ps%0d addr=%08x unknown (never written) at %0t", gi, rid, ps, addr, $time);
                return;
            end
            expct   = mem_model[int'(addr)];
            swapped = {expct[127:0], expct[255:128]};
            if (rdata === expct) begin
                n_rd_match[gi] = n_rd_match[gi] + 1;
                $display("[TB ch %0d] RET id=%0d ps%0d addr=%08x match at %0t", gi, rid, ps, addr, $time);
            end else if (rdata === swapped) begin
                n_rd_match_swapped[gi] = n_rd_match_swapped[gi] + 1;
                $display("[TB ch %0d] RET id=%0d ps%0d addr=%08x match-swapped (128b halves) at %0t", gi, rid, ps, addr, $time);
            end else begin
                n_rd_mismatch[gi] = n_rd_mismatch[gi] + 1;
                // lane fingerprint, 64-bit lanes [3]..[0]: m = matches expected, F = all ones,
                // 0 = all zeros, x = has X/Z, o = other value
                fp = "";
                for (int l = 3; l >= 0; l--) begin
                    logic [63:0] g = rdata[l*64 +: 64];
                    logic [63:0] e = expct[l*64 +: 64];
                    if (g === e)             fp = {fp, "m"};
                    else if (^g === 1'bx)    fp = {fp, "x"};
                    else if (g == 64'hFFFFFFFFFFFFFFFF) fp = {fp, "F"};
                    else if (g == 64'h0)     fp = {fp, "0"};
                    else                     fp = {fp, "o"};
                end
                if (fp == "FFFF")            n_mm_allff[gi] = n_mm_allff[gi] + 1;
                else if (fp.substr(0,1) == "FF" || fp.substr(2,3) == "FF") n_mm_halfff[gi] = n_mm_halfff[gi] + 1;
                else                         n_mm_other[gi] = n_mm_other[gi] + 1;
                $display("[TB ch %0d] RET id=%0d ps%0d addr=%08x MISMATCH lanes=%s at %0t", gi, rid, ps, addr, fp, $time);
                if (n_rd_mismatch[gi] <= MAX_MISMATCH_PRINTS)
                    $display("           got %064x\n           exp %064x", rdata, expct);
            end
        endtask

        always @(posedge ch_clk) begin
            if (rd_data_valid_ps0[gi] === 1'b1)
                tb_check_return(0, rd_data_req_id_ps0[gi], rd_data_ps0[gi]);
            if (rd_data_valid_ps1[gi] === 1'b1)
                tb_check_return(1, rd_data_req_id_ps1[gi], rd_data_ps1[gi]);
        end

        // At drain timeout: which reads never came back (id, address, PC of the address).
        bit pending_dumped = 1'b0;
        always @(posedge ch_clk) begin
            if (dump_pending && !pending_dumped) begin
                pending_dumped = 1'b1;
                foreach (pending_addr[k])
                    $display("[TB ch %0d] PENDING RD id=%0d addr=%08x (PC%0d) never returned", gi, k, pending_addr[k], (pending_addr[k] >> 2) & 1);
            end
        end
    end
endgenerate

task automatic tb_summary(input logic timed_out);
    int unsigned tot_req = 0, tot_rd = 0, tot_ret = 0, tot_mm = 0, tot_orph = 0, tot_sw = 0;
    $display("");
    $display("[TB SUMMARY] %s", timed_out ? "DRAIN TIMEOUT - some reads never returned" : "all issued reads returned");
    $display("[TB SUMMARY]  ch   req    wr    rd   ret  miss match  swap mism unkn orph");
    for (int j = 0; j < N_CHANNELS; j++) begin
        $display("[TB SUMMARY]  %2d %5d %5d %5d %5d %5d %5d %5d %4d %4d %4d",
                 j, n_req_accepted[j], n_wr_issued[j], n_rd_issued[j], n_rd_returned[j],
                 (n_rd_issued[j] > n_rd_returned[j]) ? (n_rd_issued[j] - n_rd_returned[j]) : 0,
                 n_rd_match[j], n_rd_match_swapped[j], n_rd_mismatch[j], n_rd_unknown[j], n_rd_orphan[j]);
        tot_req  += n_req_accepted[j];
        tot_rd   += n_rd_issued[j];
        tot_ret  += n_rd_returned[j];
        tot_mm   += n_rd_mismatch[j];
        tot_orph += n_rd_orphan[j];
        tot_sw   += n_rd_match_swapped[j];
    end
    $display("[TB SUMMARY] total: %0d requests, %0d reads issued, %0d returned, %0d mismatch, %0d swapped, %0d orphan",
             tot_req, tot_rd, tot_ret, tot_mm, tot_sw, tot_orph);
    $write("[TB SUMMARY] mismatch classes per channel (allFF/halfFF/other):");
    for (int j = 0; j < N_CHANNELS; j++) $write(" ch%0d=%0d/%0d/%0d", j, n_mm_allff[j], n_mm_halfff[j], n_mm_other[j]);
    $display("");
    $display("[TB SUMMARY] %s", (!timed_out && tot_mm == 0 && tot_orph == 0) ? "RESULT: PASS" : "RESULT: FAIL");
    $display("");
endtask

// Once every channel has issued its trace, only refresh traffic is left in the
// RTL log ("[ LLCF ]: REQ: 16777215 ..." = the refresh pseudo-id, all ones).
// Print a heartbeat so that phase is recognisable, then finish when all reads
// are back or after DRAIN_TIMEOUT cycles.
task automatic tb_print_outstanding();
    $write("[TB DRAIN] t=%0t outstanding reads per channel:", $time);
    for (int j = 0; j < N_CHANNELS; j++)
        $write(" ch%0d=%0d", j, (n_rd_issued[j] > n_rd_returned[j]) ? (n_rd_issued[j] - n_rd_returned[j]) : 0);
    $display("");
endtask

always @(posedge clk_450[0]) begin
    if (!sim_finished && all_channels_trace_done()) begin
        if (drain_cycles == 0) begin
            $display("[TB DRAIN] all channels finished issuing at %0t - waiting for outstanding reads (max %0d DFI cycles)", $time, DRAIN_TIMEOUT);
            tb_print_outstanding();
        end
        if (all_reads_returned()) begin
            sim_finished = 1'b1;
            tb_summary(1'b0);
            $finish;
        end else begin
            drain_cycles = drain_cycles + 1;
            if (drain_cycles % 1000 == 0)
                tb_print_outstanding();
            if (drain_cycles == DRAIN_TIMEOUT - 8)
                dump_pending = 1'b1;          // give every channel a few cycles to print
            if (drain_cycles >= DRAIN_TIMEOUT) begin
                sim_finished = 1'b1;
                tb_summary(1'b1);
                $finish;
            end
        end
    end
end

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
        $dumpfile("hbm_controller_dut.vcd");
        $dumpvars(0, u_hbm_core);
    end
end

endmodule
