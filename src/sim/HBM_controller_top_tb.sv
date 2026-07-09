`timescale 1ps/1ps

// VCD dump: hbm_controller_dut.vcd (always). For Vivado read_saif, convert with
// scripts/vcd_to_saif_wave2saif.sh (vcd2fst + wave2saif), then read_saif / report_power.

module HBM_controller_top_tb(

    );

    // Must match HBM_controller_top; PHY/MMCM/HBM stacks in that module are still built for 16 lanes unless you retarget them.
    localparam int N_CHANNELS = 16;
    localparam string TRACE_FILE = "./example_0.txt";

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

logic clk_450 [0:N_CHANNELS-1];

reg [31:0] input_address [0:N_CHANNELS-1];
reg [255:0] input_data [0:N_CHANNELS-1];
reg [1:0] input_request [0:N_CHANNELS-1];
reg request_valid[0:N_CHANNELS-1];
wire request_picked[0:N_CHANNELS-1];
wire reset_hbm_controller[0:N_CHANNELS-1];

integer fd [0:N_CHANNELS-1];
logic f_open [0:N_CHANNELS-1];
logic channel_trace_done [0:N_CHANNELS-1];

initial begin
    foreach (f_open[i]) begin
        f_open[i] = 1'b0;
        channel_trace_done[i] = 1'b0;
    end
end

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

function automatic logic all_channels_trace_done();
    for (int j = 0; j < N_CHANNELS; j++)
        if (!channel_trace_done[j])
            return 1'b0;
    return 1'b1;
endfunction

always @(posedge APB_PCLK) begin
    static bit sim_finished;
    if (!sim_finished && all_channels_trace_done()) begin
        sim_finished = 1'b1;
        $finish;
    end
end

genvar gi;
generate
    for (gi = 0; gi < N_CHANNELS; gi++) begin : g_ch_stim
        always @(posedge clk_450[gi]) begin
            string line;
            string request;
            reg [31:0] address;
            reg [255:0] data;

            if (f_open[gi] == 0) begin
                request_valid[gi] <= 1'b0;
                fd[gi] = $fopen(TRACE_FILE, "r");
                if (fd[gi] == 0)
                    $fatal(1, "HBM_controller_top_tb: cannot open trace %s for channel %0d", TRACE_FILE, gi);
                f_open[gi] <= 1'b1;
            end

            if (reset_hbm_controller[gi] == 1'b1) begin
                if (!$feof(fd[gi])) begin
                    if (~request_valid[gi] || (request_valid[gi] && request_picked[gi])) begin
                        void'($fgets(line, fd[gi]));
                        tb_parse_trace_line(line, request, address, data);
                        if (request == "RD")
                            input_request[gi] <= 2'b01;
                        else
                            input_request[gi] <= 2'b00;
                        input_address[gi] <= address;
                        if (line.len() >= 64 + 2 + 8)
                            input_data[gi] <= data;
                        request_valid[gi] <= 1'b1;
                    end
                end else begin
                    if (!channel_trace_done[gi]) begin
                        $fclose(fd[gi]);
                        channel_trace_done[gi] <= 1'b1;
                    end
                end
            end
        end
    end
endgenerate

wire          rd_data_valid_ps0    [0:N_CHANNELS-1];
wire          rd_data_valid_ps1    [0:N_CHANNELS-1];
wire [23:0]   rd_data_req_id_ps0   [0:N_CHANNELS-1];
wire [255:0]  rd_data_ps0          [0:N_CHANNELS-1];
wire [23:0]   rd_data_req_id_ps1   [0:N_CHANNELS-1];
wire [255:0]  rd_data_ps1          [0:N_CHANNELS-1];


logic [23:0] request_id [0:N_CHANNELS-1];

always_comb begin
    foreach (request_id[i]) request_id[i] = '0;
end


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
    .rd_data_req_id_ps0(rd_data_req_id_ps0),
    .rd_data_ps0(rd_data_ps0),
    .rd_data_req_id_ps1(rd_data_req_id_ps1),
    .rd_data_ps1(rd_data_ps1),

    .dfi_clk_buf(clk_450)
);

initial begin
    $dumpfile("hbm_controller_dut.vcd");
    $dumpvars(0, u_hbm_core);
end

endmodule
