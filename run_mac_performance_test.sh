#!/bin/bash
# Script to run MAC unit performance test with Icarus Verilog

echo "========================================="
echo "MAC Unit Performance Test"
echo "========================================="
echo ""

# Compile
echo "Compiling..."
iverilog -g2012 -o mac_perf_sim \
    rtl/mac_unit.sv \
    tb/tb_mac_performance.sv

if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

echo "Compilation successful!"
echo ""

# Run simulation
echo "Running simulation..."
echo "========================================="
vvp mac_perf_sim

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo "Simulation completed successfully"
    
    # Check if waveform was generated
    if [ -f mac_performance.fst ]; then
        echo "Waveform saved to: mac_performance.fst"
        echo "View with: gtkwave mac_performance.fst"
    fi
else
    echo ""
    echo "Simulation failed!"
    exit 1
fi
