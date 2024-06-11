create_clock -period 10.000 [get_ports APB_PCLK_0]
create_clock -period 10.000 [get_ports HBM_REF_CLK_0]
create_clock -period 10.000 [get_ports APB_PCLK_1]
#create_clock -period 10.000 [get_ports HBM_REF_CLK_1]

#set_property PACKAGE_PIN G31  [get_ports APB_PCLK_0]
set_property PACKAGE_PIN BJ43 [get_ports HBM_REF_CLK_0]

#set_property PACKAGE_PIN G31  [get_ports APB_PCLK_1]
#set_property PACKAGE_PIN BH6 [get_ports HBM_REF_CLK_1]

set_property IOSTANDARD LVCMOS18 [get_ports APB_PCLK_0]
set_property IOSTANDARD LVCMOS18 [get_ports APB_PRESET_N_0]
set_property IOSTANDARD LVCMOS18 [get_ports HBM_REF_CLK_0]
set_property IOSTANDARD LVCMOS18 [get_ports ARESET_N_0]
set_property IOSTANDARD LVCMOS18 [get_ports APB_PCLK_1]
set_property IOSTANDARD LVCMOS18 [get_ports APB_PRESET_N_1]
#set_property IOSTANDARD LVCMOS18 [get_ports HBM_REF_CLK_1]
set_property IOSTANDARD LVCMOS18 [get_ports ARESET_N_1]

set_property PACKAGE_PIN D32 [get_ports hbm_cattrip_output]
set_property IOSTANDARD LVCMOS18 [get_ports hbm_cattrip_output]

create_pblock pblock_1
add_cells_to_pblock [get_pblocks pblock_1] [get_cells  [list {genblk2[0].HBM_channel_controller_i} {genblk2[1].HBM_channel_controller_i} {genblk2[2].HBM_channel_controller_i} {genblk2[3].HBM_channel_controller_i} {genblk2[4].HBM_channel_controller_i} {genblk2[5].HBM_channel_controller_i} {genblk2[6].HBM_channel_controller_i} {genblk2[7].HBM_channel_controller_i} {u_mmcm_0}]]
resize_pblock [get_pblocks pblock_1] -add {CLOCKREGION_X0Y0:CLOCKREGION_X3Y2}
create_pblock pblock_2
add_cells_to_pblock [get_pblocks pblock_2] [get_cells  [list {genblk2[8].HBM_channel_controller_i} {genblk2[9].HBM_channel_controller_i} {genblk2[10].HBM_channel_controller_i} {genblk2[11].HBM_channel_controller_i} {genblk2[12].HBM_channel_controller_i} {genblk2[13].HBM_channel_controller_i} {genblk2[14].HBM_channel_controller_i} {genblk2[15].HBM_channel_controller_i} {u_mmcm_1} ]] 
resize_pblock [get_pblocks pblock_2] -add {CLOCKREGION_X4Y0:CLOCKREGION_X7Y2}

set_false_path -from [get_clocks *APB_PCLK_0] -to [get_clocks *APB_PCLK_1]
set_false_path -from [get_clocks *APB_PCLK_1] -to [get_clocks *APB_PCLK_0] 

set_false_path -from [get_pins rst_st0_n_reg/C] -to [get_pins {rst0_st0_r1_n_reg[0]/D}]
set_false_path -from [get_pins rst_st0_n_reg/C] -to [get_pins {rst0_st0_r1_n_reg[1]/D}]
set_false_path -from [get_pins rst_st0_n_reg/C] -to [get_pins {rst0_st0_r1_n_reg[2]/D}]
set_false_path -from [get_pins rst_st0_n_reg/C] -to [get_pins {rst0_st0_r1_n_reg[3]/D}]
set_false_path -from [get_pins rst_st0_n_reg/C] -to [get_pins {rst0_st0_r1_n_reg[4]/D}]
set_false_path -from [get_pins rst_st0_n_reg/C] -to [get_pins {rst0_st0_r1_n_reg[5]/D}]
set_false_path -from [get_pins rst_st0_n_reg/C] -to [get_pins {rst0_st0_r1_n_reg[6]/D}]
#set_false_path -from [get_pins rst_st0_n_1_reg/C] -to [get_pins {rst0_st0_r1_n_reg[7]/D}]

set_false_path -from [get_pins rst_st0_n_1_reg/C] -to [get_pins {rst0_st0_r1_n_reg[8]/D}]
set_false_path -from [get_pins rst_st0_n_1_reg/C] -to [get_pins {rst0_st0_r1_n_reg[9]/D}]
set_false_path -from [get_pins rst_st0_n_1_reg/C] -to [get_pins {rst0_st0_r1_n_reg[10]/D}]
set_false_path -from [get_pins rst_st0_n_1_reg/C] -to [get_pins {rst0_st0_r1_n_reg[11]/D}]
set_false_path -from [get_pins rst_st0_n_1_reg/C] -to [get_pins {rst0_st0_r1_n_reg[12]/D}]
set_false_path -from [get_pins rst_st0_n_1_reg/C] -to [get_pins {rst0_st0_r1_n_reg[13]/D}]
set_false_path -from [get_pins rst_st0_n_1_reg/C] -to [get_pins {rst0_st0_r1_n_reg[14]/D}]
# set_false_path -from [get_pins rst_st0_n_2_reg/C] -to [get_pins {rst0_st0_r1_n_reg[15]/D}]