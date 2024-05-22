source "${CMAKE_SOURCE_DIR}/build/base.tcl" -notrace


open_project "$project_dir/$project.xpr"

puts "**** Project opened"
puts "****"

# Reset
set cmd "reset_run synth_1"
eval $cmd

set cmd "reset_run impl_1 -prev_step "
eval $cmd

puts "**** Launching synthesis ..."
puts "****"

# Launch synthesis
# launch_runs synth_1 -jobs $cfg(cores)
launch_runs synth_1 -jobs 4

# Wait on completion
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {   
	puts "**** CERR: Synthesis failed"
	puts "****"
	exit 1
} else {
	puts "**** Synthesis passed"
	puts "****"
}


launch_runs impl_1 -jobs 4
# Wait on completion
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {   
	puts "**** CERR: Implementation failed"
	puts "****"
	exit 1
} else {
	puts "**** Implementation passed"
	puts "****"
}

# exec rm -rf "$build_dir/bitstreams"
# file mkdir "$build_dir/bitstreams"


# exec cp "$project_dir/$project.runs/impl_1/design_1_wrapper.bit" "$build_dir/bitstreams/design_1_wrapper.bit"
# if { [file exists "$project_dir/$project.runs/impl_1/design_1_wrapper.ltx"] == 1} { 
# 	exec cp "$project_dir/$project.runs/impl_1/design_1_wrapper.ltx" "$build_dir/bitstreams/design_1_wrapper.ltx"
# }

exit 0