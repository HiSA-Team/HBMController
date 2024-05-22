source "${CMAKE_SOURCE_DIR}/build/base.tcl" -notrace

# Set project properties
create_project $project $project_dir -part $part -force
set_property board_part $board_part [current_project]

# Create filset
source "$build_dir/build_hbm_phy.tcl" -notrace
source "$build_dir/build_hbm_controller.tcl" -notrace


# Set HBM_controller as out of context module for synthesis
# update_compile_order -fileset sources_1
# create_fileset -blockset -define_from HBM_channel_controller HBM_channel_controller
# add_files -norecurse -fileset HBM_channel_controller -copy_to $project_dir/$project.srcs/constrs_1 "$src_dir/xdc/HBM_channel_controller.xdc"

update_compile_order -fileset sources_1
# Configure simulation
source "$build_dir/configure_questa_simulator.tcl" -notrace

update_compile_order -fileset sources_1

puts "${N_CHANNELS}"

set_property generic {N_CHANNELS=${N_CHANNELS}} [current_fileset]

source "$build_dir/configure_synth_option.tcl" -notrace

exit 0