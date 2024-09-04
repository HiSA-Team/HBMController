cmake_minimum_required(VERSION 3.22)
project(HBMController)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_SOURCE_DIR}/cmake)

# Find Vivado
find_package(Vivado REQUIRED)
if (NOT VIVADO_FOUND)
   message(FATAL_ERROR "Vivado not found.")
endif()

# Check the board name
# if(FDEV_NAME STREQUAL "u280")
    set(PART xcu280-fsvh2892-2L-e CACHE STRING "FPGA device.")
    set(BOARD_PART xilinx.com:au280:part0:1.2 CACHE STRING "Board.")
    set(REDUCED_BOARD_PART au280 CACHE STRING "Reduced board.")
# endif()

if ( NOT N_CHANNELS )   
 set( N_CHANNELS 1 CACHE STRING "Number of HBM channels" ) 
endif()

if ( NOT ADDRESS_MAPPING )   
 set( ADDRESS_MAPPING 1 CACHE STRING "Address mapping policy" ) 
endif()

if ( NOT DEBUG )   
 set( DEBUG 0 CACHE STRING "Debug" ) 
endif()

# Configure files
# file(MAKE_DIRECTORY "./build")
configure_file(${CMAKE_SOURCE_DIR}/scripts/base.tcl ${CMAKE_SOURCE_DIR}/build/base.tcl)
configure_file(${CMAKE_SOURCE_DIR}/scripts/build_project.tcl ${CMAKE_SOURCE_DIR}/build/build_design.tcl)
configure_file(${CMAKE_SOURCE_DIR}/scripts/compile.tcl ${CMAKE_SOURCE_DIR}/build/compile.tcl)
configure_file(${CMAKE_SOURCE_DIR}/scripts/build_hbm_phy.tcl ${CMAKE_SOURCE_DIR}/build/build_hbm_phy.tcl)
configure_file(${CMAKE_SOURCE_DIR}/scripts/build_hbm_controller.tcl ${CMAKE_SOURCE_DIR}/build/build_hbm_controller.tcl)
configure_file(${CMAKE_SOURCE_DIR}/scripts/build_fifo_generator.tcl ${CMAKE_SOURCE_DIR}/build/build_fifo_generator.tcl)
configure_file(${CMAKE_SOURCE_DIR}/scripts/configure_synth_option.tcl ${CMAKE_SOURCE_DIR}/build/configure_synth_option.tcl)
configure_file(${CMAKE_SOURCE_DIR}/scripts/configure_questa_simulator.tcl ${CMAKE_SOURCE_DIR}/build/configure_questa_simulator.tcl)

# Generate targets
add_custom_target(HBMController COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_SOURCE_DIR}/build/build_design.tcl -notrace -nolog -nojournal)
add_custom_target(compile COMMAND ${VIVADO_BINARY} -mode tcl -source ${CMAKE_SOURCE_DIR}/build/compile.tcl -notrace -nolog -nojournal)
