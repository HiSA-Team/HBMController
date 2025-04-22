add_files -norecurse -fileset sources_1 -copy_to $project_dir/$project.srcs/sources_1 " \

    $src_dir/rtl/include/commands.svh \
    $src_dir/rtl/include/dfi_interface.svh \
    $src_dir/rtl/include/hbm_controller.svh \
    $src_dir/rtl/include/hbm_timing_constraints.svh \

    $src_dir/rtl/controller/block_ram.sv \
    $src_dir/rtl/controller/distributed_ram.sv \
    $src_dir/rtl/controller/dual_port_ram.sv \
    $src_dir/rtl/controller/last_level_command_forwarder.sv \
    $src_dir/rtl/controller/CAS_arbiter.sv \
    $src_dir/rtl/controller/RAS_arbiter.sv \
    $src_dir/rtl/controller/channel_scheduler.sv \
    $src_dir/rtl/controller/bank_scheduler.sv \
    $src_dir/rtl/controller/REQ_to_CMD_translator.sv \
    $src_dir/rtl/controller/HBM_channel_controller.sv \
    $src_dir/rtl/controller/HBM_controller_top.sv \

    $src_dir/rtl/controller/llcf_init_sequence_driver.sv \
    $src_dir/rtl/controller/llcf_cas_constraints_checker.sv \
    $src_dir/rtl/controller/llcf_ras_constraints_checker.sv \
    $src_dir/rtl/controller/llcf_cas_cmd_driver.sv \
    $src_dir/rtl/controller/llcf_ras_cmd_driver.sv \
    $src_dir/rtl/controller/llcf_read_data_driver.sv \
    $src_dir/rtl/controller/llcf_write_data_driver.sv \

    $src_dir/rtl/controller/bs_cmd_internal.sv \
    $src_dir/rtl/controller/bs_constraints_checker.sv \ "


add_files -norecurse -fileset constrs_1 -copy_to $project_dir/$project.srcs/constrs_1 "$src_dir/constraints/place_and_route.xdc"

add_files -norecurse -fileset sim_1 -copy_to $project_dir/$project.srcs/sim_1 "$src_dir/sim/HBM_controller_top_tb.sv"