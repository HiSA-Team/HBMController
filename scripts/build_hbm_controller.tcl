add_files -norecurse -fileset sources_1 -copy_to $project_dir/$project.srcs/sources_1 "\
    $src_dir/hdl/block_ram.sv \
    $src_dir/hdl/last_level_command_forwarder.sv \
    $src_dir/hdl/CAS_arbiter.sv \
    $src_dir/hdl/RAS_arbiter.sv \
    $src_dir/hdl/channel_scheduler.sv \
    $src_dir/hdl/bank_scheduler.sv \
    $src_dir/hdl/REQ_to_CMD_translator.sv \
    $src_dir/hdl/HBM_channel_controller.sv \
    $src_dir/hdl/HBM_controller_top.sv"

# set_property generic {N_CHANNELS = ${N_CHANNELS} } [current_fileset]

add_files -norecurse -fileset constrs_1 -copy_to $project_dir/$project.srcs/constrs_1 "$src_dir/xdc/constraints.xdc"