// Template testbench: DPI-C bridge to CrossSim (crosssim.so) + HBM_controller_top.
//
// This file is documentation scaffolding — it is not wired into the default Vivado
// project. Copy into your sim fileset, compile with DEBUG=1 (see hbm_controller.svh
// for P_REQ_ID_WIDTH), and complete the TODO blocks to exchange traffic with gem5.
//
// Build crosssim.so from: CrossSim/crosssim/
// Reference: CrossSim/README.md

`timescale 1ps/1ps

module HBM_controller_crosssim_dpi_tb_template;

    // Match Vivado generic N_CHANNELS and your co-simulation plan (often 1).
    localparam int N_CHANNELS = 1;

    // -------------------------------------------------------------------------
    // CrossSim DPI (same shared library as gem5 DpiMemCtrl loads)
    // Signatures must match CrossSim/crosssim/inc/crosssim.h
    // -------------------------------------------------------------------------
    import "DPI-C" function void initialize();
    import "DPI-C" function void finalize();
    import "DPI-C" function byte unsigned questa_send(
        byte unsigned id,
        byte unsigned ack,
        longint unsigned data,
        byte unsigned clock_cycles
    );
    import "DPI-C" function byte unsigned questa_receive(
        output byte unsigned id,
        output longint unsigned address,
        output longint unsigned data,
        output byte unsigned is_write
    );

    // -------------------------------------------------------------------------
    // Clocks / resets (same spirit as src/sim/HBM_controller_top_tb.sv)
    // -------------------------------------------------------------------------
    reg HBM_REF_CLK_0;
    reg ARESET_N_0;
    reg APB_PCLK;
    reg APB_PRESET_N;

    initial HBM_REF_CLK_0 = 1'b0;
    always HBM_REF_CLK_0 = #5000.00 ~HBM_REF_CLK_0;

    initial APB_PCLK = 1'b0;
    always APB_PCLK = #(10000/2.0) ~APB_PCLK;

    initial begin
        APB_PRESET_N = 1'b0;
        #200ns;
        #4500ns;
        APB_PRESET_N = 1'b1;
    end

    initial begin
        ARESET_N_0 = 1'b0;
        #200ns;
        #4500ns;
        ARESET_N_0 = 1'b1;
    end

    // -------------------------------------------------------------------------
    // DUT-facing stimulus (drive from questa_receive in TODO)
    // -------------------------------------------------------------------------
    logic clk_450 [0:N_CHANNELS-1];

    reg [31:0]               input_address       [0:N_CHANNELS-1];
    reg [255:0]              input_data          [0:N_CHANNELS-1];
    reg [1:0]                input_request       [0:N_CHANNELS-1];
    reg                      request_valid       [0:N_CHANNELS-1];
    wire                     request_picked      [0:N_CHANNELS-1];
    wire                     reset_hbm_controller[0:N_CHANNELS-1];
    // DEBUG build: P_REQ_ID_WIDTH = 24 (hbm_controller.svh)
    wire [23:0]              rd_data_req_id_ps0  [0:N_CHANNELS-1];
    wire [255:0]             rd_data_ps0         [0:N_CHANNELS-1];
    wire [23:0]              rd_data_req_id_ps1  [0:N_CHANNELS-1];
    wire [255:0]             rd_data_ps1         [0:N_CHANNELS-1];
    wire                     rd_data_valid_ps0   [0:N_CHANNELS-1];
    wire                     rd_data_valid_ps1   [0:N_CHANNELS-1];
    logic [23:0]             request_id          [0:N_CHANNELS-1];
    wire                     hbm_cattrip_output;

    initial begin
        foreach (input_address[i]) begin
            input_address[i]  = '0;
            input_data[i]     = '0;
            input_request[i]  = '0;
            request_valid[i]  = 1'b0;
            request_id[i]     = '0;
        end
    end

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    HBM_controller_top #(.N_CHANNELS(N_CHANNELS)) u_hbm_core (
        .HBM_REF_CLK_0          (HBM_REF_CLK_0),
        .ARESET_N_0             (ARESET_N_0),
        .APB_PCLK_0             (APB_PCLK),
        .APB_PRESET_N_0         (APB_PRESET_N),
        .ARESET_N_1             (ARESET_N_0),
        .APB_PCLK_1             (APB_PCLK),
        .APB_PRESET_N_1         (APB_PRESET_N),

        .address                (input_address),
        .request                (input_request),
        .write_data             (input_data),
        .request_valid          (request_valid),
        .request_picked         (request_picked),
        .request_id             (request_id),
        .reset_hbm_controller   (reset_hbm_controller),

        .rd_data_valid_ps0      (rd_data_valid_ps0),
        .rd_data_valid_ps1      (rd_data_valid_ps1),
        .rd_data_req_id_ps0     (rd_data_req_id_ps0),
        .rd_data_ps0            (rd_data_ps0),
        .rd_data_req_id_ps1     (rd_data_req_id_ps1),
        .rd_data_ps1            (rd_data_ps1),

        .dfi_clk_buf            (clk_450),
        .hbm_cattrip_output     (hbm_cattrip_output)
    );

    // -------------------------------------------------------------------------
    // Co-simulation lifecycle
    // -------------------------------------------------------------------------
    initial begin
        initialize();
        // TODO: fork threads — e.g. forever @(posedge clk) begin ... questa_receive ... end
        // TODO: on read/write completion, pack responses and call questa_send(...)
    end

    final begin
        finalize();
    end

endmodule
