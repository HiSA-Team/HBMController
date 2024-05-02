create_ip -name hbm -vendor xilinx.com -library ip -version 1.0 -module_name hbm_0

set_property -dict [list \
  CONFIG.USER_APB_EN {false} \
  CONFIG.USER_CTRL_PHY_MODE {Physical_Layer_Only} \
] [get_ips hbm_0]