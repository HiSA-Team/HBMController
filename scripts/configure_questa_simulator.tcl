set_property target_simulator Questa [current_project]
set_property questa.compile.vlog.more_options -value {+notimingchecks} -objects [get_filesets sim_1]
set_property questa.simulate.vsim.more_options -value {+notimingchecks -onfinish final} -objects [get_filesets sim_1]
