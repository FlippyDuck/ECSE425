proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
    add wave -position end sim:/processor_tb/rst_processor
    add wave -position end sim:/processor_tb/rst_cache
    add wave -position end sim:/processor_tb/clk
    add wave -position end sim:/processor_tb/p2ic_addr
    add wave -position end sim:/processor_tb/p2ic_read
    add wave -position end sim:/processor_tb/ic2p_readdata
    add wave -position end sim:/processor_tb/ic2p_waitrequest
    add wave -position end sim:/processor_tb/p2dc_addr
    add wave -position end sim:/processor_tb/p2dc_read
    add wave -position end sim:/processor_tb/dc2p_readdata
    add wave -position end sim:/processor_tb/p2dc_write
    add wave -position end sim:/processor_tb/p2dc_writedata
    add wave -position end sim:/processor_tb/dc2p_waitrequest
    add wave -position end sim:/processor_tb/ic2m_addr
    add wave -position end sim:/processor_tb/ic2m_read
    add wave -position end sim:/processor_tb/m2ic_readdata
    add wave -position end sim:/processor_tb/ic2m_write
    add wave -position end sim:/processor_tb/ic2m_writedata
    add wave -position end sim:/processor_tb/m2ic_waitrequest
    add wave -position end sim:/processor_tb/dc2m_addr
    add wave -position end sim:/processor_tb/dc2m_read
    add wave -position end sim:/processor_tb/m2dc_readdata
    add wave -position end sim:/processor_tb/dc2m_write
    add wave -position end sim:/processor_tb/dc2m_writedata
    add wave -position end sim:/processor_tb/m2dc_waitrequest
    add wave -position end sim:/processor_tb/dut/register_bank
    add wave -position end sim:/processor_tb/imem_out
    add wave -position end sim:/processor_tb/dmem_out
}

vlib work

;# Compile components if any
vcom cache.vhd
vcom memory.vhd
vcom processor.vhd
vcom processor_tb.vhd

;# Start simulation
vsim -t 1ps processor_tb

;# Generate a clock with 1ns period
force -deposit clk 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 10000 ns
run 10000ns
