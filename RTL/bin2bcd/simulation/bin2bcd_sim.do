# Execute Python script to generate test vectors and status report files
cd ../scripts
if {$tcl_platform(os) eq "Windows NT"} {
    exec python gen_vectors.py
} else {
    exec python3 gen_vectors.py
}

# Ensure you're in the build directory before compiling sources and running simulation
# Reason: ModelSim auto-generated files will be dumped here
cd ../build

# Create libraries
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile SystemVerilog design and testbench files
vlog -work work -sv -stats=none ../../src/bin2bcd_v1.sv
vlog -work work -sv -stats=none ../../src/bin2bcd_v2.sv
vlog -work work -sv -stats=none ../../src/bin2bcd.sv
vlog -work work -sv -stats=none ../testbench/bin2bcd_tb.sv

# Load design
vsim work.bin2bcd_tb

# Run simulation
run -all