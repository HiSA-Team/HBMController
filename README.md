# High-Bandwidth Memory Controller

This project is the RTL implementation of a memory controller for HBM.
The controller uses the AMD Xilinx HBM IP as PHY to talk to the memory through the DFI protocol.
Vivado is needed to build, synthesize, and implement the project. The only tested version is Vivado 2023.2.
HBM IP requires an external simulator. Simulations were conducted using Questa Advanced Simulator v2020.4.
> NOTE: The design has been validated only in simulation. Physical validation is ongoing.

## CrossSim co-simulation

**CrossSim** is a co-simulation bridge between an RTL simulator (for example Questa) and **gem5**. A DPI-C shared library (`crosssim.so`) and POSIX shared-memory queues carry memory requests and responses between the two processes. That lets a full-system or trace-driven gem5 model drive the same memory interface your RTL exposes, instead of (or in addition to) file-based traces.

A short overview of CrossSim in the context of this work is available as a PDF: **[`doc/CrossSim.pdf`](doc/CrossSim.pdf)**.

**Reproducing the CrossSim setup:** step-by-step instructions (gem5 integration, building `crosssim.so`, Vivado sim libraries, and the RTL DPI hook) are in **[`doc/CrossSim/README.md`](doc/CrossSim/README.md)**. The **gem5** and **crosssim** sources live under [`CrossSim/`](CrossSim/README.md). This repository does **not** include the upstream Vivado example testbenches; you implement the Questa testbench with `import "DPI-C"` against `crosssim.so`. A starting point is **[`doc/CrossSim/HBM_controller_crosssim_dpi_tb_template.sv`](doc/CrossSim/HBM_controller_crosssim_dpi_tb_template.sv)**.

---

## Controller features (what they do, parameters, configuration)

The following maps major **functional blocks** to the knobs that control them. RTL paths are under `src/rtl/` unless noted.

### Multi-channel top (`HBM_controller_top`)

**What it does.** Wraps clocking (MMCM), APB access to the Xilinx HBM subsystem, per-channel `HBM_channel_controller` instances, and DFI toward the PHY. Exposes a simple read/write **request port** per channel (address, request type, write data, valid/ready style handshaking, read returns on pseudo-channels ps0/ps1).

**Parameters / symbols.** `N_CHANNELS` on `HBM_controller_top` (number of active controller channels). `P_APB_PCLK0_BUFFERED` selects whether `APB_PCLK_0` is buffered inside the core or assumed already on a BUFG net from a parent (see `HBM_controller_fpga_top`).

**How to configure.** Pass `N_CHANNELS` as a Vivado generic on `sources_1` and `sim_1` (set from CMake via `build_project.tcl` after `cmake .. -DN_CHANNELS=…`). For the FPGA wrapper pinout, see `HBM_controller_fpga_top.sv`. Set `P_APB_PCLK0_BUFFERED` when instantiating `HBM_controller_top` if you follow the same BUFG pattern as the FPGA top.

### Per-channel controller (`HBM_channel_controller`)

**What it does.** Splits each logical channel into **two pseudo-channels** (ps0/ps1) according to the bank address, maps the custom request interface into row/column/bank fields, buffers write/read CAS context in block RAMs, and hosts the per-bank **REQ-to-CMD translators**, **bank schedulers**, and **channel scheduler** that eventually drive the low-level DFI command stack.

**Parameters / symbols.** Widths and depths come from `src/rtl/include/hbm_controller.svh` (for example `P_DATA_WIDTH`, `P_BA_N_PS`, `P_TOTAL_PER_CHANNEL_BANK_N`, `P_QUEUE_LEN`, `P_RD_ID_BUFFER_LEN`, `P_WRT_DATA_BUFFER_LEN`). Timing budgets for schedulers come from `src/rtl/include/hbm_timing_constraints.svh` (`tRCD`, `tRP`, `tRL`, `tWL`, `tFAW`, …).

**How to configure.** Edit the `localparam` values in `hbm_controller.svh` and `hbm_timing_constraints.svh`, then rebuild the Vivado project. Keep timing parameters consistent with your HBM speed grade and PHY configuration.

### Address mapping policies

**What it does.** Derives `row_address`, `column_address`, and `bank_address` from the 32-bit request address. Five policies are implemented as `generate` branches in `HBM_channel_controller.sv` (labels in comments: e.g. **14R-5C-2BG-2B-PC** for policy 1).

**Parameters / symbols.** `P_MAPPING_POLICY` in `hbm_controller.svh` (integer 1–5).

**How to configure.** Set `P_MAPPING_POLICY` in `src/rtl/include/hbm_controller.svh` to the desired policy and rebuild. The CMake option `ADDRESS_MAPPING` is passed into Vivado as verilog defines `ADDRESS_MAPPING_1` … `ADDRESS_MAPPING_5`, but the **active** decode is selected only by `P_MAPPING_POLICY`; keep them consistent if you use both.

### REQ-to-CMD translation (`REQ_to_CMD_translator`)

**What it does.** Translates high-level read/write requests into row commands for the bank scheduler, maintaining a small command queue and tracking the **currently open row** to decide when to accept new requests.

**Parameters / symbols.** Queue depth `P_QUEUE_LEN` in `hbm_controller.svh`. Command and request encodings in `commands.svh`.

**How to configure.** Adjust `P_QUEUE_LEN` in `hbm_controller.svh` (trade-off between pipelining and area/timing).

### Bank scheduling (`bank_scheduler`)

**What it does.** Per-bank FSM and timing checks enforce **intra-bank** DRAM constraints (activate, precharge, read/write, refresh interactions) before handing a command to the channel scheduler.

**Parameters / symbols.** `P_BANK_INDEX` is set per generated instance. Timing: `hbm_timing_constraints.svh` (`tRCD`, `tRP`, `tRAS`, `tRFCpb`, `tREFP`, …).

**How to configure.** Tune `hbm_timing_constraints.svh` to match your memory datasheet and configured HBM timing mode.

### Channel scheduling and DFI command path (LLCF stack)

**What it does.** The **channel scheduler** arbitrates among banks, manages read/write datapath timing to the pseudo-channels, and interfaces to the **last-level command forwarder** and driver/checker blocks (`llcf_*`, `CAS_arbiter`, `RAS_arbiter`, …) that emit legal DFI transactions.

**Parameters / symbols.** Inter-bank / interface spacing: `hbm_timing_constraints.svh` (`tCCDl`, `tRRD`, `tFAW`, `tRTW`, `tWTRl`, …).

**How to configure.** Same as bank timing: edit `hbm_timing_constraints.svh` coherently with PHY and JEDEC-mode settings.

### AXI wrapper (`HBM_AXI_Wrapper.v` / `HBM_AXI_Wrapper_top.v`)

**What it does.** Bridges AXI4 memory-mapped traffic to the custom request interface expected by `HBM_controller_top`, including ID tracking for read data routing.

**Parameters / symbols.** `MAPPING_POLICY` parameter on the wrapper (intended to track address-mapping choice when using the AXI path).

**How to configure.** Set `MAPPING_POLICY` when instantiating the wrapper so it matches `P_MAPPING_POLICY` in `hbm_controller.svh`.

### Simulation-only build (`DEBUG`)

**What it does.** With `DEBUG` defined, `hbm_controller.svh` uses a wider `P_REQ_ID_WIDTH` for simulation visibility; the default trace testbench targets this mode.

**How to configure.** Configure with `cmake .. -DDEBUG=1` so Vivado defines `DEBUG=1` on the **sim_1** fileset (`build_project.tcl`). Synthesis uses the non-DEBUG defines for `sources_1` so `HBM_controller_fpga_top` port widths stay aligned.

### FPGA integration wrapper (`HBM_controller_fpga_top`)

**What it does.** Minimal-pin top for synthesis/implementation: package clocks/resets/APB, internal tie-offs or slow strobes so request paths are not optimized away, and `P_APB_PCLK0_BUFFERED=1` with a single IBUF+BUFG for APB.

**How to configure.** Use as the Vivado top for implementation (`build_project.tcl` sets `top` to `HBM_controller_fpga_top`). Adjust board/part via CMake (`FDEV_NAME` for `au50` vs default `au280`).

---

## Controller architecture

Since each HBM channel is fully independent from the others, each channel has its own HBM-Channel-Controller as shown in the following figure. At the lowest level (depicted on the right side of the figure), the HBM stack comprises M independent channels, each interfacing with the controller via a PHY. Communication between each PHY and the controller is facilitated through the DDR PHY Interface (DFI). HBM-Channel-Controllers interact with the interconnect fabric using two ports of a custom protocol, one per PC. The interconnect enables communication between each processing unit (PU) and all HBM-Channel-Controllers. PUs interface with the interconnect via the Advanced eXtensible Interface (AXI) protocol, while the custom protocol follows a conventional valid/ready handshake mechanism.

![HBM controller block diagram](doc/HBM_controller.png "HBM Controller architecture")

The architecture of the single HBM-Channel-Controller is shown in the following figure. The figure adheres to a consistent notation to represent protocols. Each arrow is labeled in the format Protocol[Data Type], where Protocol specifies the communication protocol used, and Data Type denotes the type of data being transmitted. For example, C[REQ] indicates that the custom protocol is being used to transmit a memory request.

![HBM channel controller block diagram](doc/HBM_channel_controller.png "HBM Channel Controller architecture")

---

## Getting started

#### Create the build directory

```
mkdir build && cd build
```

#### Configure the project

```
cmake .. -DDEBUG=1
```

Following configuration options are provided:

| Name            | Values                   | Description                                        |
| --------------- | ------------------------ | -------------------------------------------------- |
| DEBUG           | <**0**, 1>               | If 1, enable `DEBUG=1` on the Vivado **sim_1** fileset (wider `P_REQ_ID_WIDTH` in `hbm_controller.svh`); not defined on synth sources |
| N_CHANNELS      | <**1**, 2, 4, 8, 16>     | Number of enabled channels                         |
| ADDRESS_MAPPING | <**1**, 2, 3, 4, 5>      | Passed as verilog defines (see address mapping note above) |
| FDEV_NAME       | **au280**, au50          | Board / part selection (CMakeLists)                |

The only tested board is the Alveo U280.

#### Build the project

```
make HBMController
```

If the simulation libraries are needed:

```
export COMPILE_SIMLIB=1
make HBMController
```

QuestaSim is needed.

#### Synthesize and implement the project (only if DEBUG=0)

```
make compile
```

---

## Simulation flow

The default flow is the trace-based simulation flow shown in the following figure.

![Trace-based simulation flow](doc/Trace_based_simulation_flow.png "Trace-based simulation flow")

Basically the SystemVerilog testbench (`src/sim/HBM_controller_top_tb.sv`) takes a requests trace in input and sends them (one-by-one) to the controller.

Once the project is built, to simulate it, Questa Advanced Simulator v2020.4 is needed. All the simulation settings are made; you need to download QuestaSim (recommended v2020.4) and compile the simulation libraries if you did not export the `COMPILE_SIMLIB` variable in the build phase. Once you have compiled the library you can start a simulation; there is a sample memory trace in the `example_traces` folder. To properly start the simulation, the simulation trace must be placed in the (project) directory specified in the testbench.

### Requests trace

The requests trace could be generated through any tools or flow. The only requirement is that it adheres to the following format:

```
REQ ADDRESS [DATA]
```

Where `REQ` can be `WR` or `RD`; `ADDRESS` is the target address in hex without a `0x` prefix; and `DATA` is the 32-byte write data in hex without a prefix when `REQ` is `WR`.

In the `utils` directory there are two scripts to generate traces. The `gem5_to_req.py` script can be used to generate the request trace from a gem5-generated memory trace, while `req_to_cmd.py` serves to generate a commands trace from a requests trace. The latter can be used to test the controller without the REQ-to-CMD-Translator component (not recommended).
