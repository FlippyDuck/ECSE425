proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
    ;#add wave -position end sim:/processor_tb/rst_processor
    ;#add wave -position end sim:/processor_tb/rst_cache
    add wave -position end sim:/processor_tb/clk
    add wave -position end sim:/processor_tb/p2ic_addr
    add wave -position end sim:/processor_tb/p2ic_read
    add wave -position end sim:/processor_tb/ic2p_readdata
    add wave -position end sim:/processor_tb/ic2p_waitrequest
    ;#add wave -position end sim:/processor_tb/dut/inst_addr
    add wave -position end sim:/processor_tb/p2dc_addr
    add wave -position end sim:/processor_tb/p2dc_read
    add wave -position end sim:/processor_tb/dc2p_readdata
    add wave -position end sim:/processor_tb/p2dc_write
    add wave -position end sim:/processor_tb/p2dc_writedata
    add wave -position end sim:/processor_tb/dc2p_waitrequest
    ;#add wave -position end sim:/processor_tb/ic2m_addr
    ;#add wave -position end sim:/processor_tb/ic2m_read
    ;#add wave -position end sim:/processor_tb/m2ic_readdata
    ;#add wave -position end sim:/processor_tb/ic2m_write
    ;#add wave -position end sim:/processor_tb/ic2m_writedata
    ;#add wave -position end sim:/processor_tb/m2ic_waitrequest
    ;#add wave -position end sim:/processor_tb/inmem/address
    ;#add wave -position end sim:/processor_tb/dc2m_addr
    ;#add wave -position end sim:/processor_tb/dc2m_read
    ;#add wave -position end sim:/processor_tb/m2dc_readdata
    ;#add wave -position end sim:/processor_tb/dc2m_write
    ;#add wave -position end sim:/processor_tb/dc2m_writedata
    ;#add wave -position end sim:/processor_tb/m2dc_waitrequest
    add wave -position end sim:/processor_tb/dut/register_bank
    add wave -position end sim:/processor_tb/incache/cache_data
    ;#add wave -position end sim:/processor_tb/im_write
    ;#add wave -position end sim:/processor_tb/im_writedata
    ;#add wave -position end sim:/processor_tb/dm_read
    ;#add wave -position end sim:/processor_tb/dm_readdata
    ;#add wave -position end sim:/processor_tb/imem_addr
    add wave -position end sim:/processor_tb/dut/fetch_state
    add wave -position end sim:/processor_tb/dut/program_counter
    add wave -position end sim:/processor_tb/dut/if_id_instruction
    add wave -position end sim:/processor_tb/dut/id_ex_opcode
    add wave -position end sim:/processor_tb/dut/id_ex_funct
    add wave -position end sim:/processor_tb/dut/id_ex_register_s
    add wave -position end sim:/processor_tb/dut/id_ex_register_t
    add wave -position end sim:/processor_tb/dut/ex_mem_aluresult
    add wave -position end sim:/processor_tb/dut/ex_mem_branchtaken
    add wave -position end sim:/processor_tb/dut/ex_mem_regvalue
    add wave -position end sim:/processor_tb/dut/mem_wb_writeback
    add wave -position end sim:/processor_tb/dut/mem_wb_writeback_index
    add wave -position end sim:/processor_tb/dut/mem_waiting
    add wave -position end sim:/processor_tb/dut/fetch_stall
    add wave -position end sim:/processor_tb/dut/decode_stall
    add wave -position end sim:/processor_tb/dut/execute_stall
    add wave -position end sim:/processor_tb/dut/branch_stall
    add wave -position end sim:/processor_tb/dut/memory_stall
    add wave -position end sim:/processor_tb/dut/writeback_stall
    add wave -position end sim:/processor_tb/dut/memory_state
    add wave -position end sim:/processor_tb/datcache/state
}

vlib work

;# Compile components if any
vcom cache.vhd
vcom memory.vhd
vcom processor.vhd
vcom vmux.vhd
vcom bmux.vhd
vcom processor_tb.vhd

;# Start simulation
vsim -t 1ps processor_tb

;# Generate a clock with 1ns period
force -deposit clk 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 100000 ns
run 200000ns
