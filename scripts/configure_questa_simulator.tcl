set_property target_simulator Questa [current_project]
set_property questa.compile.vlog.more_options -value {+notimingchecks} -objects [get_filesets sim_1]
set_property questa.simulate.vsim.more_options -value {+notimingchecks -onfinish final} -objects [get_filesets sim_1]
set_property questa.simulate.log_all_signals -value {true} -objects [get_filesets sim_1]

if {$::env(COMPILE_SIMLIB)==1} {
    compile_simlib -simulator questa -simulator_exec_path $::env(MODELSIM_LOC) -family all -language all -library all -dir $::env(HOME)/questa_compiled_libs -verbose 
}
