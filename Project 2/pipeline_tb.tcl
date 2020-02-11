proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
    add wave -position end sim:/pipeline_tb/clk
    add wave -position end sim:/pipeline_tb/s_a
    radix signal sim:/pipeline_tb/s_a decimal -showbase d
    add wave -position end sim:/pipeline_tb/s_b
    radix signal sim:/pipeline_tb/s_b decimal -showbase d
    add wave -position end sim:/pipeline_tb/s_c
    radix signal sim:/pipeline_tb/s_c decimal -showbase d
    add wave -position end sim:/pipeline_tb/s_d
    radix signal sim:/pipeline_tb/s_d decimal -showbase d
    add wave -position end sim:/pipeline_tb/s_e
    radix signal sim:/pipeline_tb/s_e decimal -showbase d
    add wave -position end sim:/pipeline_tb/s_op1
    radix signal sim:/pipeline_tb/s_op1 decimal -showbase d
    add wave -position end sim:/pipeline_tb/s_op2
    radix signal sim:/pipeline_tb/s_op2 decimal -showbase d
    add wave -position end sim:/pipeline_tb/s_op3
    radix signal sim:/pipeline_tb/s_op3 decimal -showbase d
    add wave -position end sim:/pipeline_tb/s_op4
    radix signal sim:/pipeline_tb/s_op4 decimal -showbase d
    add wave -position end sim:/pipeline_tb/s_op5
    radix signal sim:/pipeline_tb/s_op5 decimal -showbase d
    add wave -position end sim:/pipeline_tb/s_final_output
    radix signal sim:/pipeline_tb/s_final_output decimal -showbase d
}

vlib work

;# Compile components if any
vcom pipeline.vhd
vcom pipeline_tb.vhd

;# Start simulation
vsim -t 100ps pipeline_tb

;# Generate a clock with 1ns period
force -deposit clk 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 50 ns
run 50ns
