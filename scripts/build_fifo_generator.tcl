create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name fifo_generator_0
set_property -dict [list \
  CONFIG.Fifo_Implementation {Independent_Clocks_Builtin_FIFO} \
  CONFIG.INTERFACE_TYPE {Native} \
  CONFIG.Input_Data_Width {558} \
  CONFIG.Input_Depth {512} \
  CONFIG.Performance_Options {First_Word_Fall_Through} \
  CONFIG.Read_Clock_Frequency {450} \
  CONFIG.Valid_Flag {true} \
  CONFIG.Write_Acknowledge_Flag {true} \
  CONFIG.Write_Clock_Frequency {250} \
] [get_ips fifo_generator_0]

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name fifo_generator_1
set_property -dict [list \
  CONFIG.Fifo_Implementation {Independent_Clocks_Builtin_FIFO} \
  CONFIG.Input_Data_Width {524} \
  CONFIG.Input_Depth {512} \
  CONFIG.Performance_Options {First_Word_Fall_Through} \
  CONFIG.Read_Clock_Frequency {250} \
  CONFIG.Valid_Flag {true} \
  CONFIG.Write_Acknowledge_Flag {true} \
  CONFIG.Write_Clock_Frequency {450} \
] [get_ips fifo_generator_1]

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name fifo_generator_2
set_property -dict [list \
  CONFIG.Fifo_Implementation {Independent_Clocks_Builtin_FIFO} \
  CONFIG.Input_Data_Width {1} \
  CONFIG.Input_Depth {512} \
  CONFIG.Performance_Options {First_Word_Fall_Through} \
  CONFIG.Read_Clock_Frequency {250} \
  CONFIG.Valid_Flag {true} \
  CONFIG.Write_Acknowledge_Flag {true} \
  CONFIG.Write_Clock_Frequency {450} \
] [get_ips fifo_generator_2]