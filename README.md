# HBM Predictable Controller (HBM-PC)   
HBM-PC is a predictable memory controller for HBM. An extensive mathematical analysis has been conducted to validate predictability.

HBM-PC uses the AMD Xilinx HBM IP as PHY to talk to the memory through the DFI protocol. 

Vivado is needed to build, synthesize, and implement the project. It has been developed within Vivado v2023.1, so this is the only version working.

HBM IP requires an external simulator. Simulations were conducted using Questa Advanced Simulator v2020.4.

For now, the synthesis and implementation go well on the Alveo U280 board.

## Getting started

#### Create the build directory :
~~~~
mkdir build && cd build
~~~~

#### Configure the project
~~~~
cmake ..
~~~~

#### Build the project
~~~~
$ make HBMController
~~~~

Now the project is built. To simulate it, Questa Advanced Simulator v2020.4 is needed. All the simulation settings are made, you need to download and compile the Questa library.