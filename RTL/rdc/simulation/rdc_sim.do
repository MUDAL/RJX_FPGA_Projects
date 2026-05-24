# Ensure you're in the build directory before compiling sources and running simulation
# Reason: ModelSim auto-generated files will be dumped here

# Create libraries
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile SystemVerilog design and testbench files
vlog -work work -sv -stats=none ../../src/rdc.sv
vlog -work work -sv -stats=none ../testbench/rdc_tb.sv

# Load design
vsim work.rdc_tb

# Run simulation
run -all