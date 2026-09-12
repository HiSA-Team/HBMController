# Create run synth_1
# create_run -flow {Vivado Synthesis 2023} synth_1
# Add retiming to snth_1
set_property -dict [ 
    list STEPS.SYNTH_DESIGN.ARGS.RETIMING true \
    STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AreaOptimized_high \
    STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none
] [get_runs synth_1]

# Create run impl_1
# create_run impl_1 -parent_run synth_1 -flow {Vivado Implementation 2023}

# Config run impl_1
set_property -dict [ 
    list STEPS.OPT_DESIGN.IS_ENABLED true \
    STEPS.OPT_DESIGN.IS_ENABLED true \
    STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore \
    STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore \
    STEPS.PHYS_OPT_DESIGN.IS_ENABLED true \
    STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore \
    STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore \
    STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true \
    STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore 
] [get_runs impl_1]

# STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore

# Add retiming to HBM_channel_controller out of context synthesis
# set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs HBM_channel_controller_synth_1]

# Controllo del floorplan: ferma la run se i pblock restano vuoti.
# Vedi scripts/check_floorplan.tcl e il commento in place_and_route.xdc:
# in un XDC non si possono usare if/foreach (Designutils 20-1307), quindi il
# controllo vive qui, come hook dopo opt_design.
set_property STEPS.OPT_DESIGN.TCL.POST "$root_dir/scripts/check_floorplan.tcl" [get_runs impl_1]
