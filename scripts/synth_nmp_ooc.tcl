# -----------------------------------------------------------------------------
# Out-of-context synthesis of the NMP accelerator, on its own.
#
#   vivado -mode batch -source scripts/synth_nmp_ooc.tcl -tclargs [periods...]
#
# No wrapper and no pins: -mode out_of_context turns the module ports into the
# boundary of the run, so what comes out is the cost of the accelerator alone,
# with no controller and no PHY around it to blur the numbers.
#
# For every clock period in the list the script runs a fresh synthesis and
# records the worst slack, then prints one table. The frequency a single run
# reports is only a lower bound - the tool stops optimising once the target is
# met - so a real Fmax needs the period pushed down until the slack goes
# negative. Default list: 4.0 3.0 2.5 2.2 ns (250 to 455 MHz).
#
# DEBUG is not defined: since 2026-09-11 it only adds $display tracing, and
# P_REQ_ID_WIDTH is one width (15) for every build. See doc/nmp/CHANGELOG.md.
#
# Reports land in build/nmp_ooc/ :
#   util_<T>.rpt        utilisation, per module (hierarchy is kept)
#   timing_<T>.rpt      timing summary
#   critpath_<T>.rpt    the 10 worst paths, with the full cell chain
#   summary.txt         the table printed at the end
# -----------------------------------------------------------------------------

set part    "xcu280-fsvh2892-2L-e"
set top     "nmp_head_engine"

set periods [expr {[llength $argv] > 0 ? $argv : {4.0 3.0 2.5 2.2}}]

set root [file normalize [file join [file dirname [info script]] ..]]
set src  "$root/src/rtl"
set out  "$root/build/nmp_ooc"
file mkdir $out

set sources [list \
    "$src/nmp_accelerator/nmp_address_generator.sv" \
    "$src/nmp_accelerator/nmp_lane_array.sv" \
    "$src/nmp_accelerator/nmp_token_table.sv" \
    "$src/nmp_accelerator/nmp_output_acc.sv" \
    "$src/nmp_accelerator/nmp_exp2.sv" \
    "$src/nmp_accelerator/nmp_head_engine.sv" \
    "$src/controller/dual_port_ram.sv" \
]

set incdirs [list "$src/include" "$src/nmp_accelerator"]

set results {}

foreach T $periods {
    puts "\n================ target period $T ns ================"

    catch { close_design }

    read_verilog -sv $sources

    # timing driven synthesis needs the clock BEFORE synth_design, not after
    set xdc "$out/clk_$T.xdc"
    set fh [open $xdc w]
    puts $fh "create_clock -name clk -period $T \[get_ports clock_i\]"
    puts $fh "set_input_delay  -clock clk 0.100 \[filter \[all_inputs\]  {NAME !~ clock_i}\]"
    puts $fh "set_output_delay -clock clk 0.100 \[all_outputs\]"
    close $fh
    read_xdc $xdc

    # flatten_hierarchy none keeps the per module breakdown in the utilisation
    # report, and matches what scripts/configure_synth_option.tcl asks for the
    # controller, so the two sets of numbers are comparable.
    synth_design -top $top -part $part -mode out_of_context \
                 -include_dirs $incdirs \
                 -flatten_hierarchy none \
                 -retiming

    report_utilization      -hierarchical -file "$out/util_$T.rpt"
    report_timing_summary   -delay_type min_max -report_unconstrained \
                            -file "$out/timing_$T.rpt"
    report_timing -sort_by group -max_paths 10 -path_type full_clock_expanded \
                  -input_pins -file "$out/critpath_$T.rpt"

    set wns  [get_property SLACK [get_timing_paths -delay_type max]]
    set luts [llength [get_cells -hier -filter {PRIMITIVE_GROUP == LUT}]]
    set ffs  [llength [get_cells -hier -filter {PRIMITIVE_GROUP == REGISTER}]]
    set dsps [llength [get_cells -hier -filter {PRIMITIVE_GROUP == ARITHMETIC}]]
    set rams [llength [get_cells -hier -filter {PRIMITIVE_GROUP == BLOCKRAM}]]

    # achieved period = target - slack; only meaningful while the slack is small
    set achieved [expr {$T - $wns}]
    set fmax     [expr {1000.0 / $achieved}]
    lappend results [list $T $wns $fmax $luts $ffs $dsps $rams]

    puts [format "period %s ns  WNS %+.3f ns  -> %.1f MHz   LUT %d  FF %d  DSP %d  BRAM %d" \
          $T $wns $fmax $luts $ffs $dsps $rams]
}

set fh [open "$out/summary.txt" w]
set hdr [format "%-8s %10s %10s %8s %8s %6s %6s" "T (ns)" "WNS (ns)" "Fmax MHz" "LUT" "FF" "DSP" "BRAM"]
puts $hdr
puts $fh $hdr
foreach r $results {
    set line [format "%-8s %+10.3f %10.1f %8d %8d %6d %6d" \
              [lindex $r 0] [lindex $r 1] [lindex $r 2] \
              [lindex $r 3] [lindex $r 4] [lindex $r 5] [lindex $r 6]]
    puts $line
    puts $fh $line
}
puts $fh ""
puts $fh "Fmax is trustworthy only on the rows where WNS is close to zero."
puts $fh "A row with a large positive WNS means the tool stopped early: push the period down."
close $fh

puts "\nreports in $out"
exit 0
