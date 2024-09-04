source "${CMAKE_SOURCE_DIR}/build/base.tcl" -notrace

# Set project properties
create_project $project $project_dir -part $part -force
set_property board_part $board_part [current_project]

# Create filset
source "$build_dir/build_hbm_phy.tcl" -notrace
source "$build_dir/build_hbm_controller.tcl" -notrace
source "$build_dir/build_fifo_generator.tcl" -notrace


# Set HBM_controller as out of context module for synthesis
# update_compile_order -fileset sources_1
# create_fileset -blockset -define_from HBM_channel_controller HBM_channel_controller
# add_files -norecurse -fileset HBM_channel_controller -copy_to $project_dir/$project.srcs/constrs_1 "$src_dir/xdc/HBM_channel_controller.xdc"

update_compile_order -fileset sources_1
# Configure simulation
source "$build_dir/configure_questa_simulator.tcl" -notrace

update_compile_order -fileset sources_1

puts "N_CHANNELS = ${N_CHANNELS}"
puts "ADDRESS_MAPPING = ${ADDRESS_MAPPING}"
puts "DEBUG = ${DEBUG}"

set_property generic {N_CHANNELS=${N_CHANNELS}} [get_filesets sources_1]
set_property generic {N_CHANNELS=${N_CHANNELS}} [get_filesets sim_1]

set verilog_define_list {}


if {${ADDRESS_MAPPING}==1} {
    append verilog_define_list " " ADDRESS_MAPPING_1=1
} elseif {${ADDRESS_MAPPING}==2} {
    append verilog_define_list " " ADDRESS_MAPPING_2=1
} elseif {${ADDRESS_MAPPING}==3} {
    append verilog_define_list " " ADDRESS_MAPPING_3=1
} elseif {${ADDRESS_MAPPING}==4} {
    append verilog_define_list " " ADDRESS_MAPPING_4=1
} elseif {${ADDRESS_MAPPING}==5} {
    append verilog_define_list " " ADDRESS_MAPPING_5=1
} else {
    append verilog_define_list " " ADDRESS_MAPPING_1=1
}

if {${DEBUG}==1} {
    append verilog_define_list " " DEBUG=1
} 

set_property verilog_define $verilog_define_list [get_filesets sources_1]
set_property verilog_define $verilog_define_list [get_filesets sim_1]

source "$build_dir/configure_synth_option.tcl" -notrace

exit 0