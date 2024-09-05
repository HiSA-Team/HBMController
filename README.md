# HBM Predictable Controller (HBM-PC)   
HBM-PC is a predictable memory controller for HBM. An extensive mathematical analysis has been conducted to validate predictability.

HBM-PC uses the AMD Xilinx HBM IP as PHY to talk to the memory through the DFI protocol. 

Vivado is needed to build, synthesize, and implement the project. It has been developed within Vivado v2023.1, so this is the only version working.

HBM IP requires an external simulator. Simulations were conducted using Questa Advanced Simulator v2020.4.

For now, the synthesis and implementation go well on the Alveo U280 card.

## Getting started

#### Create the build directory
~~~~
mkdir build && cd build
~~~~

#### Configure the project
~~~~
cmake .. -DDEBUG=1
~~~~

Following configuration options are provided:

| Name            | Values                   | Desription                                        |
| --------------- | ------------------------ | ------------------------------------------------- |
| DEBUG           | <**0**, 1>               | If 1 build the simulation project (1 channel only)|
| N_CHANNELS      | <**1**, 2, 4, 8, 16>     | Number of enabled channels                        |
| ADDRESS_MAPPING | <**1**, 2, 3, 4, 5>      | Address mapping policy                            |

The only supported card is Alveo U280 for now.

#### Build the project
~~~~
make HBMController
~~~~

Now the project is built. To simulate it, Questa Advanced Simulator v2020.4 is needed. All the simulation settings are made, you need to download and compile the Questa library.
Once you have compiled the library you can start a simulation, there is a sample memory trace in the example_traces folder.

#### Synthesize and Implement the project (only if DEBUG=0)
~~~~
make compile
~~~~

```bash
.
├── cmake
│   └── FindVivado.cmake
├── CMakeLists.txt
├── example_traces
│   └── example_0.txt
├── README.md
├── scripts
│   ├── base.tcl
│   ├── build_fifo_generator.tcl
│   ├── build_hbm_controller.tcl
│   ├── build_hbm_phy.tcl
│   ├── build_project.tcl
│   ├── compile.tcl
│   ├── configure_questa_simulator.tcl
│   └── configure_synth_option.tcl
└── src
    ├── hdl
    │   ├── async_dual_port_fifo.sv
    │   ├── bank_scheduler.sv
    │   ├── block_ram.sv
    │   ├── CAS_arbiter.sv
    │   ├── channel_scheduler.sv
    │   ├── distributed_ram.sv
    │   ├── dual_port_ram.sv
    │   ├── HBM_AXI_Wrapper_top.v
    │   ├── HBM_AXI_Wrapper.v
    │   ├── HBM_channel_controller.sv
    │   ├── HBM_controller_top.sv
    │   ├── last_level_command_forwarder.sv
    │   ├── RAS_arbiter.sv
    │   ├── REQ_to_CMD_translator.sv
    │   └── switch
    │       ├── Arbiter.sv
    │       ├── AXI4_peripheral_v2_0_M_AXI.sv
    │       ├── CH_Controller.sv
    │       ├── comp_in.sv
    │       ├── comp_out.sv
    │       ├── counter.sv
    │       ├── Demux_Addr.sv
    │       ├── Demux_FIFO_read.sv
    │       ├── demux_id.sv
    │       ├── Demux_Signal.sv
    │       ├── Demux_Write.sv
    │       ├── FIFO_Switch.sv
    │       ├── MEM_id_axi_addr.sv
    │       ├── Mux_Addr.sv
    │       ├── Mux_FIFO_write.sv
    │       ├── mux_id.sv
    │       ├── Mux_Read.sv
    │       ├── mux_selection.sv
    │       ├── Mux_Signal.sv
    │       ├── operational_switch.sv
    │       ├── reg_addr.sv
    │       ├── reg_data_read.sv
    │       ├── reg_data_req.sv
    │       ├── reg_id_pipe.sv
    │       ├── reg_id.sv
    │       ├── reg_pipe.sv
    │       ├── reg_read.sv
    │       ├── reg_selection.sv
    │       ├── reg_signal.sv
    │       ├── reg_write.sv
    │       ├── Switch_Crossbar.sv
    │       └── System.sv
    ├── sim
    │   ├── HBM_controller_top_tb.sv
    │   └── tb_System.sv
    └── xdc
        └── constraints.xdc
```