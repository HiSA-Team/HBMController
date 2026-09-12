#------------------------------------------------------------------------------
# Clocks
#------------------------------------------------------------------------------
create_clock -period 10.000 [get_ports APB_PCLK_0]
create_clock -period 10.000 [get_ports HBM_REF_CLK_0]
create_clock -period 10.000 [get_ports APB_PCLK_1]
#create_clock -period 10.000 [get_ports HBM_REF_CLK_1]

#------------------------------------------------------------------------------
# Pin di package.
#
# ATTENZIONE: BJ43 e D32 sono pin della AU280. Sulla AU50 Vivado risponde
#   [Common 17-69] 'BJ43' is not a valid site or package pin name
# e il vincolo viene semplicemente saltato (l'implementazione continua, ma quei
# due segnali vengono piazzati dove capita). Se la AU50 serve davvero, questi
# due vanno spostati in un XDC per board.
#------------------------------------------------------------------------------
set_property PACKAGE_PIN BJ43 [get_ports HBM_REF_CLK_0]
set_property PACKAGE_PIN D32  [get_ports hbm_cattrip_output]
#set_property PACKAGE_PIN G31  [get_ports APB_PCLK_0]
#set_property PACKAGE_PIN G31  [get_ports APB_PCLK_1]
#set_property PACKAGE_PIN BH6  [get_ports HBM_REF_CLK_1]

set_property IOSTANDARD LVCMOS18 [get_ports APB_PCLK_0]
set_property IOSTANDARD LVCMOS18 [get_ports APB_PRESET_N_0]
set_property IOSTANDARD LVCMOS18 [get_ports HBM_REF_CLK_0]
set_property IOSTANDARD LVCMOS18 [get_ports ARESET_N_0]
set_property IOSTANDARD LVCMOS18 [get_ports APB_PCLK_1]
set_property IOSTANDARD LVCMOS18 [get_ports APB_PRESET_N_1]
#set_property IOSTANDARD LVCMOS18 [get_ports HBM_REF_CLK_1]
set_property IOSTANDARD LVCMOS18 [get_ports ARESET_N_1]
set_property IOSTANDARD LVCMOS18 [get_ports hbm_cattrip_output]

#------------------------------------------------------------------------------
# Floorplan
#
# 2026-09-12: qui c'era scritto genblk2[i], ma il netlist chiamava quei blocchi
# genblk4[i] - i generate in HBM_controller_top.sv erano anonimi e Vivado li
# numera da solo. get_cells non trovava niente, add_cells_to_pblock aggiungeva
# una lista vuota, e il floorplan non veniva applicato: ogni canale finiva
# sparso su ~20 regioni di clock e il percorso peggiore era 3 ns di puro
# routing con ZERO livelli di logica (flop -> pin WDATA dell'HBM).
#
# Ora i generate hanno un nome (g_channel), quindi questi path sono stabili.
# Il controllo che i pblock siano davvero pieni sta in
# scripts/check_floorplan.tcl, agganciato come hook post-opt_design: in un XDC
# non si possono usare if/foreach (Designutils 20-1307).
#------------------------------------------------------------------------------
create_pblock pblock_1
add_cells_to_pblock [get_pblocks pblock_1] [get_cells [list \
    {u_hbm_core/g_channel[0].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[1].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[2].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[3].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[4].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[5].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[6].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[7].HBM_channel_controller_i} \
    {u_hbm_core/u_mmcm_0} ]]
resize_pblock [get_pblocks pblock_1] -add {CLOCKREGION_X0Y0:CLOCKREGION_X3Y2}

create_pblock pblock_2
add_cells_to_pblock [get_pblocks pblock_2] [get_cells [list \
    {u_hbm_core/g_channel[8].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[9].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[10].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[11].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[12].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[13].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[14].HBM_channel_controller_i} \
    {u_hbm_core/g_channel[15].HBM_channel_controller_i} \
    {u_hbm_core/u_mmcm_1} ]]
resize_pblock [get_pblocks pblock_2] -add {CLOCKREGION_X4Y0:CLOCKREGION_X7Y2}

# Le regioni sono tarate sulla AU50 (2 SLR, X0..X7 Y0..Y7, HBM in basso).
# Sulla AU280 la geometria e' diversa (3 SLR): se resta congestionata, e' il
# primo numero da rivedere. Dopo place_design:
#     report_utilization -pblocks [get_pblocks]

#------------------------------------------------------------------------------
# False path
#------------------------------------------------------------------------------
set_false_path -from [get_clocks *APB_PCLK_0] -to [get_clocks *APB_PCLK_1]
set_false_path -from [get_clocks *APB_PCLK_1] -to [get_clocks *APB_PCLK_0]

# Rilascio del reset: primo stadio del sincronizzatore, per canale.
set_false_path -from [get_pins u_hbm_core/rst_st0_n_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[0]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[1]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[2]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[3]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[4]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[5]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[6]/D}]
#set_false_path -from [get_pins u_hbm_core/rst_st0_n_1_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[7]/D}]

set_false_path -from [get_pins u_hbm_core/rst_st0_n_1_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[8]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_1_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[9]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_1_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[10]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_1_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[11]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_1_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[12]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_1_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[13]/D}]
set_false_path -from [get_pins u_hbm_core/rst_st0_n_1_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[14]/D}]
# set_false_path -from [get_pins u_hbm_core/rst_st0_n_2_reg/C] -to [get_pins {u_hbm_core/rst0_st0_r1_n_reg[15]/D}]

#------------------------------------------------------------------------------
# NON abilitare finche' non abbiamo guardato cosa attraversa davvero.
#
# report_clock_interaction classifica APB_PCLK_0 -> dfi_clk_in[*] come
# "No Common Clock / Timed (unsafe)": ~36000 endpoint, TNS -886 ns, cioe' lo
# 0,7 % del totale. NON e' il collo di bottiglia (il 99,3 % e' dfi[i] -> dfi[i]).
#
# Fra quegli endpoint ci sono i /CE di cmd_queue_reg nei bank scheduler: un
# enable che nasce a 100 MHz e arriva su flop a 450 MHz. Se non e' sincronizzato
# e' un bug CDC vero, e dichiarare i domini asincroni lo nasconderebbe.
#
# set_clock_groups -asynchronous \
#     -group [get_clocks {APB_PCLK_0 APB_PCLK_1}] \
#     -group [get_clocks dfi_clk_in*]
#------------------------------------------------------------------------------
