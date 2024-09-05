add_files -norecurse -fileset sources_1 -copy_to $project_dir/$project.srcs/sources_1 " \
    $src_dir/hdl/block_ram.sv \
    $src_dir/hdl/distributed_ram.sv \
    $src_dir/hdl/dual_port_ram.sv \
    $src_dir/hdl/last_level_command_forwarder.sv \
    $src_dir/hdl/CAS_arbiter.sv \
    $src_dir/hdl/RAS_arbiter.sv \
    $src_dir/hdl/channel_scheduler.sv \
    $src_dir/hdl/bank_scheduler.sv \
    $src_dir/hdl/REQ_to_CMD_translator.sv \
    $src_dir/hdl/HBM_channel_controller.sv \
    $src_dir/hdl/HBM_controller_top.sv \
    $src_dir/hdl/switch/Arbiter.sv \
    $src_dir/hdl/switch/AXI4_peripheral_v2_0_M_AXI.sv \
    $src_dir/hdl/switch/CH_Controller.sv \
    $src_dir/hdl/switch/comp_in.sv \
    $src_dir/hdl/switch/comp_out.sv \
    $src_dir/hdl/switch/counter.sv \
    $src_dir/hdl/switch/Demux_Addr.sv \
    $src_dir/hdl/switch/Demux_FIFO_read.sv \
    $src_dir/hdl/switch/demux_id.sv \
    $src_dir/hdl/switch/Demux_Signal.sv \
    $src_dir/hdl/switch/Demux_Write.sv \
    $src_dir/hdl/switch/FIFO_Switch.sv \
    $src_dir/hdl/switch/MEM_id_axi_addr.sv \
    $src_dir/hdl/switch/Mux_Addr.sv \
    $src_dir/hdl/switch/Mux_FIFO_write.sv \
    $src_dir/hdl/switch/mux_id.sv \
    $src_dir/hdl/switch/Mux_Read.sv \
    $src_dir/hdl/switch/mux_selection.sv \
    $src_dir/hdl/switch/Mux_Signal.sv \
    $src_dir/hdl/switch/operational_switch.sv \
    $src_dir/hdl/switch/reg_addr.sv \
    $src_dir/hdl/switch/reg_data_read.sv \
    $src_dir/hdl/switch/reg_data_req.sv \
    $src_dir/hdl/switch/reg_id_pipe.sv \
    $src_dir/hdl/switch/reg_id.sv \
    $src_dir/hdl/switch/reg_pipe.sv \
    $src_dir/hdl/switch/reg_read.sv \
    $src_dir/hdl/switch/reg_selection.sv \
    $src_dir/hdl/switch/reg_signal.sv \
    $src_dir/hdl/switch/reg_write.sv \
    $src_dir/hdl/switch/Switch_Crossbar.sv \
    $src_dir/hdl/switch/System.sv \ "


add_files -norecurse -fileset constrs_1 -copy_to $project_dir/$project.srcs/constrs_1 "$src_dir/xdc/constraints.xdc"

add_files -norecurse -fileset sim_1 -copy_to $project_dir/$project.srcs/sim_1 " \ 
    $src_dir/sim/HBM_controller_top_tb.sv \ 
    $src_dir/sim/tb_System.sv \ "