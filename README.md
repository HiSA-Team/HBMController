# HBM Predictable Controller (HBM-PC)   
HBM-PC is a predictable memory controller for HBM. An extensive mathematical analysis has been conducted to validate predictability.

HBM-PC uses the AMD Xilinx HBM IP as PHY to talk to the memory through the DFI protocol. 

Vivado is needed to build, synthesize, and implement the project. It has been developed within Vivado v2023.1, so this is the only version working.

HBM IP requires an external simulator. Simulations were conducted using Questa Advanced Simulator v2020.4.

For now, the synthesis and implementation go well on the Alveo U280 card.

## Getting started

#### Create the build directory :
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