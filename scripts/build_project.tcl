source "${CMAKE_SOURCE_DIR}/build/base.tcl" -notrace

# Set project properties
create_project $project $project_dir -part $part -force
set_property board_part $board_part [current_project]

# Create filset
source "$build_dir/build_hbm_phy.tcl" -notrace
source "$build_dir/build_hbm_controller.tcl" -notrace
update_compile_order -fileset sources_1

# Configure simulation
source "$build_dir/configure_questa_simulator.tcl" -notrace

update_compile_order -fileset sources_1

exit 0