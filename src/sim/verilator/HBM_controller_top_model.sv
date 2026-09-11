`timescale 1ps/1ps

`include "hbm_controller.svh"

// ---------------------------------------------------------------------------
// Behavioural stand-in for HBM_controller_top, for fast functional checks of
// the NMP accelerator with Verilator (no Xilinx HBM PHY / simlib needed).
//
// NOT the controller: it only reproduces the request-port contract and the
// gross timing features the accelerator has to cope with:
//   * request accepted when the target bank has no pending command;
//     request_picked is registered (one cycle after sampling); the bus is
//     read again in the picked cycle (write data, id) - so at most one
//     request every two cycles;
//   * mapping policy 1: PC = a[2], bank = a[6:3], column = a[14:10], row = a[28:15];
//   * open-row per bank: hit = short latency, miss = PRE+ACT+CAS latency;
//   * data returns per PS in CAS-issue order, i.e. OUT OF ORDER w.r.t. the
//     acceptance order when a hit overtakes a miss;
//   * a refresh window every tREFP cycles during which no CAS is issued;
//   * at most P_RD_ID_BUFFER_LEN reads in flight per PS (error if exceeded).
// Only channel 0 keeps data (associative memory); the other channels are idle.
// Do not add this file to the Vivado project: it redefines HBM_controller_top.
// ---------------------------------------------------------------------------

module HBM_controller_top #(
    parameter N_CHANNELS   = 16,
    parameter P_DATA_WIDTH = 256
)(
    input  HBM_REF_CLK_0,
    input  ARESET_N_0,
    input  APB_PCLK_0,
    input  APB_PRESET_N_0,
    input  ARESET_N_1,
    input  APB_PCLK_1,
    input  APB_PRESET_N_1,

    output logic                      dfi_clk_buf [0:N_CHANNELS-1],
    output logic                      hbm_cattrip_output,

    input  [31:0]                     address              [0:N_CHANNELS-1],
    input  [1:0]                      request              [0:N_CHANNELS-1],
    input  [P_DATA_WIDTH-1:0]         write_data           [0:N_CHANNELS-1],
    input                             request_valid        [0:N_CHANNELS-1],
    output logic                      request_picked       [0:N_CHANNELS-1],
    output logic                      reset_hbm_controller [0:N_CHANNELS-1],
    input  [P_REQ_ID_WIDTH-1:0]       request_id           [0:N_CHANNELS-1],

    output logic                      rd_data_valid_ps0    [0:N_CHANNELS-1],
    output logic                      rd_data_valid_ps1    [0:N_CHANNELS-1],
    output logic [P_REQ_ID_WIDTH-1:0] rd_data_req_id_ps0   [0:N_CHANNELS-1],
    output logic [P_DATA_WIDTH-1:0]   rd_data_ps0          [0:N_CHANNELS-1],
    output logic [P_REQ_ID_WIDTH-1:0] rd_data_req_id_ps1   [0:N_CHANNELS-1],
    output logic [P_DATA_WIDTH-1:0]   rd_data_ps1          [0:N_CHANNELS-1]
);

    // Timing of the model, in channel cycles (450 MHz -> 2222 ps)
    localparam int CLK_HALF_PS   = 1111;
    localparam int LAT_HIT       = 24;     // accept -> data, row hit
    localparam int LAT_MISS      = 24 + 28;// + tRP + tRCD
    localparam int BANK_BUSY_HIT = 2;      // cycles the bank queue stays non-empty
    localparam int BANK_BUSY_MISS= 30;
    localparam int REF_PERIOD    = 1220;
    localparam int REF_WINDOW    = 120;    // no CAS issued in this window
    localparam int RESET_CYCLES  = 300;

    assign hbm_cattrip_output = 1'b0;

    logic clk;
    initial clk = 1'b0;
    always #(CLK_HALF_PS) clk = ~clk;

    genvar g;
    generate
        for (g = 0; g < N_CHANNELS; g++) begin : g_ch
            assign dfi_clk_buf[g] = clk;
        end
    endgenerate

    // reset release
    int rst_cnt = 0;
    always @(posedge clk) begin
        if (!ARESET_N_0) begin
            rst_cnt = 0;
            for (int i = 0; i < N_CHANNELS; i++) reset_hbm_controller[i] = 1'b0;
        end else if (rst_cnt < RESET_CYCLES) begin
            rst_cnt++;
            if (rst_cnt == RESET_CYCLES)
                for (int i = 0; i < N_CHANNELS; i++) reset_hbm_controller[i] = 1'b1;
        end
    end

    // ---------------- channel 0 model ----------------
    logic [P_DATA_WIDTH-1:0] mem [logic [31:0]];
    longint  cyc = 0;
    longint  bank_free  [0:31];        // cycle at which the bank queue is empty again
    int      open_row   [0:31];
    int      inflight_ps0 = 0, inflight_ps1 = 0;
    int      max_inflight_ps0 = 0, max_inflight_ps1 = 0;
    int      n_ooo = 0;               // returns that overtook an earlier-accepted read
    longint  last_ret_accept_ps0 = -1, last_ret_accept_ps1 = -1;
    int      n_acc = 0, n_miss = 0;

    typedef struct { longint ready; longint acc_cyc; logic [P_REQ_ID_WIDTH-1:0] id; logic [P_DATA_WIDTH-1:0] data; } pend2_t;
    pend2_t  q0 [$];
    pend2_t  q1 [$];

    logic        pending_accept;     // a request was sampled this cycle -> picked next cycle
    logic [31:0] acc_addr;
    logic [1:0]  acc_req;
    longint      acc_lat;             // accept -> data latency decided at sampling time

    initial begin
        for (int b = 0; b < 32; b++) begin bank_free[b] = 0; open_row[b] = -1; end
        pending_accept = 1'b0;
        for (int i = 0; i < N_CHANNELS; i++) begin
            request_picked[i]     = 1'b0;
            rd_data_valid_ps0[i]  = 1'b0;
            rd_data_valid_ps1[i]  = 1'b0;
            rd_data_req_id_ps0[i] = '0;
            rd_data_req_id_ps1[i] = '0;
            rd_data_ps0[i]        = '0;
            rd_data_ps1[i]        = '0;
        end
    end

    function automatic int f_bank(input logic [31:0] a);   // 0..31, bit 4 = PS
        return int'({a[2], a[6:3]});
    endfunction
    function automatic int f_row(input logic [31:0] a);
        return int'(a[28:15]);
    endfunction
    function automatic bit f_in_refresh(input longint c);
        return ((c % REF_PERIOD) < REF_WINDOW);
    endfunction

    // Return path: pick the ready entry with the smallest ready time (CAS order)
    task automatic ret_ps(ref pend2_t q [$], input int ps);
        int best = -1;
        longint bestready = 0;
        for (int i = 0; i < q.size(); i++) begin
            if (q[i].ready <= cyc && (best < 0 || q[i].ready < bestready)) begin
                best = i; bestready = q[i].ready;
            end
        end
        if (ps == 0) rd_data_valid_ps0[0] <= 1'b0; else rd_data_valid_ps1[0] <= 1'b0;
        if (best >= 0) begin
            if (ps == 0) begin
                rd_data_valid_ps0[0]  <= 1'b1;
                rd_data_req_id_ps0[0] <= q[best].id;
                rd_data_ps0[0]        <= q[best].data;
                inflight_ps0--;
                if (q[best].acc_cyc < last_ret_accept_ps0) n_ooo++;
                if (q[best].acc_cyc > last_ret_accept_ps0) last_ret_accept_ps0 = q[best].acc_cyc;
            end else begin
                rd_data_valid_ps1[0]  <= 1'b1;
                rd_data_req_id_ps1[0] <= q[best].id;
                rd_data_ps1[0]        <= q[best].data;
                inflight_ps1--;
                if (q[best].acc_cyc < last_ret_accept_ps1) n_ooo++;
                if (q[best].acc_cyc > last_ret_accept_ps1) last_ret_accept_ps1 = q[best].acc_cyc;
            end
            q.delete(best);
        end
    endtask

    always @(posedge clk) begin
        int b, row;
        bit hit;
        longint lat, busy;
        pend2_t e;
        cyc++;

        // ---- acceptance (translator) ----
        // Edge E   : the bus (set by the requester at E-1) is sampled; if the
        //            bank queue is empty, request_picked rises (registered).
        // Edge E+1 : picked cycle, bus still stable: write data / id captured,
        //            command enters the bank queue. No sampling on this edge.
        // Edge E+2 : the next request (set by the requester at E+1) is sampled.
        request_picked[0] <= 1'b0;
        if (pending_accept) begin
            pending_accept <= 1'b0;
            if (acc_req == P_WRT_REQ) begin
                mem[acc_addr] = write_data[0];
            end else begin
                b         = f_bank(acc_addr);
                e.id      = request_id[0];
                e.acc_cyc = cyc;
                e.data    = mem.exists(acc_addr) ? mem[acc_addr] : {P_DATA_WIDTH{1'b1}};
                e.ready   = cyc + acc_lat;
                if (b < 16) begin
                    q0.push_back(e);
                    inflight_ps0++;
                    if (inflight_ps0 > max_inflight_ps0) max_inflight_ps0 = inflight_ps0;
                end else begin
                    q1.push_back(e);
                    inflight_ps1++;
                    if (inflight_ps1 > max_inflight_ps1) max_inflight_ps1 = inflight_ps1;
                end
                if (inflight_ps0 > P_RD_ID_BUFFER_LEN || inflight_ps1 > P_RD_ID_BUFFER_LEN)
                    $display("[ MODEL ]: ERROR more than %0d reads in flight on a PS at cycle %0d", P_RD_ID_BUFFER_LEN, cyc);
            end
        end
        else if (reset_hbm_controller[0] && request_valid[0]) begin
            b   = f_bank(address[0]);
            row = f_row(address[0]);
            if (bank_free[b] <= cyc) begin
                hit  = (open_row[b] == row);
                busy = hit ? BANK_BUSY_HIT : BANK_BUSY_MISS;
                lat  = hit ? LAT_HIT : LAT_MISS;
                if (f_in_refresh(cyc)) begin
                    busy += (REF_WINDOW - (cyc % REF_PERIOD));
                    lat  += (REF_WINDOW - (cyc % REF_PERIOD));
                end
                bank_free[b]      = cyc + busy;
                open_row[b]       = row;
                request_picked[0] <= 1'b1;
                pending_accept    <= 1'b1;
                acc_addr          <= address[0];
                acc_req           <= request[0];
                acc_lat           <= lat;
                n_acc++;
                if (!hit) n_miss++;
            end
        end

        // ---- return path, one beat per PS per cycle ----
        ret_ps(q0, 0);
        ret_ps(q1, 1);
    end

    final begin
        $display("[ MODEL ]: %0d requests accepted, %0d row misses, max in flight ps0=%0d ps1=%0d, %0d out-of-order returns",
                 n_acc, n_miss, max_inflight_ps0, max_inflight_ps1, n_ooo);
    end

endmodule
