source "${CMAKE_SOURCE_DIR}/build/base.tcl" -notrace

create_project $project $project_dir -part $part -force
set_property board_part $board_part [current_project]

source "$build_dir/build_hbm_phy.tcl" -notrace
source "$build_dir/build_hbm_controller.tcl" -notrace
update_compile_order -fileset sources_1

exit 0