# MAC Unit Performance Testing Guide

This guide explains how to measure the performance improvement from the pipelined MAC unit with dual INT4/INT8 capability.

## What Makes It Faster?

### 1. **Pipeline Benefits (Increased Fmax)**
- **Original Design**: Single-cycle path = Multiply → Add → Saturate (~3-5ns critical path)
- **Pipelined Design**: Two shorter paths:
  - Stage 1: Multiply only (~2-3ns)
  - Stage 2: Add + Saturate (~2-3ns)
- **Expected Improvement**: ~1.5-2× higher maximum clock frequency

### 2. **INT4 Mode Benefits (Increased Throughput)**
- **INT8 Mode**: 1 MAC operation per cycle
- **INT4 Mode**: 2 MAC operations per cycle (dual 4×4 multipliers)
- **Expected Improvement**: 2× throughput for INT4 workloads

## Testing Methods

### Method 1: Functional Simulation (Immediate Testing)

I've created a comprehensive performance testbench that measures:
- ✓ Pipeline latency (2 cycles)
- ✓ Throughput in both modes
- ✓ Functional correctness
- ✓ Valid signal timing

#### Run the test (Windows PowerShell):
```powershell
./run_mac_performance_test.ps1
```

#### Run the test (Linux/Mac):
```bash
chmod +x run_mac_performance_test.sh
./run_mac_performance_test.sh
```

#### Manual execution:
```bash
# Compile
iverilog -g2012 -o mac_perf_sim rtl/mac_unit.sv tb/tb_mac_performance.sv

# Run
vvp mac_perf_sim

# View waveforms
gtkwave mac_performance.fst
```

**What you'll see:**
```
Pipeline Latency: 2 clock cycles
INT8 Throughput: 100.00 MOps/sec (@ 100 MHz)
INT4 Throughput: 200.00 MOps/sec (@ 100 MHz)
Speedup vs INT8: 2.00x
```

### Method 2: Synthesis Timing Analysis (Real Fmax)

This is the **most accurate** way to measure clock frequency improvement.

#### Using Yosys (Open Source):

```bash
# Synthesize original design (from git backup if available)
yosys -p "read_verilog -sv mac_unit_original.sv; synth; abc -g AND; stat" > original_timing.txt

# Synthesize pipelined design
yosys -p "read_verilog -sv rtl/mac_unit.sv; synth; abc -g AND; stat" > pipelined_timing.txt
```

**Look for:**
- `Chip area` - Resource usage
- Longest path delay - Critical path timing

#### Using Commercial Tools (Vivado/Quartus):

```tcl
# Vivado example
create_project mac_test
add_files rtl/mac_unit.sv
synth_design -top mac_unit -part xc7a35tcsg324-1
report_timing_summary
```

**What to compare:**
- **Worst Negative Slack (WNS)**: Should improve (less negative)
- **Maximum Frequency**: Should increase by 1.5-2×
- **Example**: 
  - Original: 200 MHz max
  - Pipelined: 300-400 MHz max

### Method 3: Cycle Count Analysis (Throughput)

Compare cycle counts for the same workload:

```systemverilog
// Original: N operations = N cycles (steady state)
// Pipelined: N operations = N cycles (steady state, after 2-cycle warmup)

// Key difference: Same throughput, but can run at higher clock frequency!
```

**Throughput Calculation:**
```
Original:     N ops × (1 / Fmax_original)
Pipelined:    N ops × (1 / Fmax_pipelined)

If Fmax_pipelined = 2 × Fmax_original:
  → 2× faster total execution time
```

### Method 4: Power Efficiency Analysis

With synthesis tools, you can also measure power:

```bash
# Vivado
report_power

# Quartus
report_power_analyzer
```

**Expected results:**
- Similar or slightly lower power per operation
- Much better performance per watt at higher frequencies

## Performance Comparison Summary

| Metric | Original | Pipelined | Improvement |
|--------|----------|-----------|-------------|
| **Pipeline Depth** | 1 stage | 2 stages | - |
| **Latency** | 1 cycle | 2 cycles | +1 cycle |
| **Throughput** | 1 op/cycle | 1 op/cycle | Same |
| **Max Frequency** | ~200 MHz | ~300-400 MHz | **1.5-2×** |
| **INT4 Throughput** | N/A | 2 ops/cycle | **2× vs INT8** |
| **Overall Speedup** | Baseline | **1.5-2×** | For INT8 |
| **Overall Speedup** | Baseline | **3-4×** | For INT4 |

## Quick Start Testing

1. **Run the functional test first:**
   ```powershell
   ./run_mac_performance_test.ps1
   ```

2. **Check the output for:**
   - ✓ All tests PASSED
   - ✓ Pipeline latency = 2 cycles
   - ✓ INT4 throughput = 2× INT8 throughput

3. **For real Fmax numbers, run synthesis** with your target FPGA/ASIC tool

## Understanding the Results

### Pipeline Latency vs Throughput
- **Latency increased** from 1 to 2 cycles (time for one result)
- **Throughput unchanged** at 1 op/cycle when running continuously
- **Clock frequency increased** significantly (shorter critical path)
- **Net result**: Faster overall execution due to higher clock speed

### INT4 Mode Benefits
- Processes two 4×4 MACs in parallel
- Perfect for quantized neural networks
- Doubles computational throughput for INT4 workloads
- Combined with higher Fmax = 3-4× overall speedup

## Files Created

- `tb/tb_mac_performance.sv` - Comprehensive performance testbench
- `run_mac_performance_test.ps1` - Windows PowerShell test script
- `run_mac_performance_test.sh` - Linux/Mac bash test script
- `MAC_PERFORMANCE_TESTING_GUIDE.md` - This guide

## Next Steps

1. Run the functional simulation to verify correctness
2. Integrate the new MAC unit into your systolic array
3. Update systolic array to handle the new `i_int4_mode` and `valid_out` signals
4. Run synthesis to measure actual Fmax improvement
5. Measure power consumption at different clock frequencies
6. Profile your neural network workloads with INT4 mode enabled

## Notes

- The `valid_out` signal indicates when accumulator data is valid (tracks pipeline)
- The `i_int4_mode` signal selects between INT8 (0) and INT4 (1) modes
- Pass-through signals maintain 1-cycle delay for systolic array compatibility
- Pipeline can be kept full by continuously feeding operations
