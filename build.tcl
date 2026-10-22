# From the project root:   vivado -mode batch -source vivado/build.tcl -tclargs fpga_top
#                          vivado -mode batch -source vivado/build.tcl -tclargs pine_test
set top [expr {[llength $argv] > 0 ? [lindex $argv 0] : "fpga_top"}]
set part xc7s15ftgb196-1
read_verilog -sv rtl/pe.sv rtl/systolic_matmul.sv fpga/fpga_top.sv fpga/pine_test.sv
read_xdc fpga/pine_s7.xdc
synth_design -top $top -part $part -include_dirs fpga
opt_design; place_design; route_design
file mkdir out
report_utilization    -file out/${top}_util.rpt
report_timing_summary -file out/${top}_timing.rpt
write_bitstream -force out/${top}.bit
puts "DONE: out/${top}.bit"
