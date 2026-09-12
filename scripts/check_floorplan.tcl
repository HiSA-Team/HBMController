# -----------------------------------------------------------------------------
# Controlla che il floorplan sia stato applicato davvero.
#
# Da agganciare come hook dopo opt_design (vedi configure_synth_option.tcl):
#     set_property STEPS.OPT_DESIGN.TCL.POST \
#         $root_dir/scripts/check_floorplan.tcl [get_runs impl_1]
#
# Perche' esiste: fino al 12 set 2026 place_and_route.xdc nominava i channel
# controller come genblk2[i], mentre il netlist li chiamava genblk4[i]. get_cells
# non trovava niente, add_cells_to_pblock aggiungeva una lista vuota, Vivado
# emetteva un warning che annegava nel log, e il floorplan non veniva applicato
# per mesi. Il percorso peggiore era 3 ns di puro routing con zero livelli di
# logica.
#
# Un floorplan che non fa niente in silenzio e' peggio di nessun floorplan:
# qui si ferma la run.
# -----------------------------------------------------------------------------

puts "================ CHECK FLOORPLAN ================"

set ch_cells [get_cells -quiet -hier -filter {NAME =~ "*HBM_channel_controller_i"}]
set n_ch     [llength $ch_cells]
puts "FLOORPLAN: channel controller nel netlist : $n_ch"

if { $n_ch == 0 } {
    error "CHECK FLOORPLAN: nessun HBM_channel_controller_i nel netlist. Gerarchia cambiata?"
}

foreach pb {pblock_1 pblock_2} {
    set p [get_pblocks -quiet $pb]
    if { [llength $p] == 0 } {
        error "CHECK FLOORPLAN: il pblock '$pb' non esiste. place_and_route.xdc non e' stato letto?"
    }
    set n [llength [get_cells -quiet -of_objects $p]]
    set r [get_property -quiet GRID_RANGES $p]
    puts [format "FLOORPLAN: %-10s -> %6d celle   regioni: %s" $pb $n $r]
    if { $n == 0 } {
        error "CHECK FLOORPLAN: '$pb' e' VUOTO. I nomi delle celle nell'XDC non corrispondono\
al netlist: controlla come si chiamano davvero con\n\
  lsort \[get_cells -hier -filter {NAME =~ \"*HBM_channel_controller_i\"}\]"
    }
}

# I nomi veri, per averli nel log quando serviranno la prossima volta.
puts "FLOORPLAN: primo channel controller trovato: [lindex [lsort $ch_cells] 0]"
puts "================================================"
