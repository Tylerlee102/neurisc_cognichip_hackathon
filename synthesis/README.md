# NeuroRISC SoC Synthesis Directory

This directory contains synthesis scripts, constraints, and performance analysis for the NeuroRISC AI accelerator.

## Files

### Synthesis Scripts
- **`synthesis_script.tcl`** - Main TCL synthesis script for Design Compiler/Genus
- **`constraints.sdc`** - Synopsys Design Constraints (SDC) timing constraints
- **`performance_metrics.md`** - Comprehensive performance analysis and benchmarks

### Generated Outputs (after synthesis)
- **`reports/`** - Synthesis reports (timing, area, power, QoR)
- **`outputs/`** - Synthesized netlists, SDF, SDC, SPEF

## Quick Start

### Prerequisites
- Synopsys Design Compiler (or Cadence Genus)
- Generic 28nm standard cell library
- SystemVerilog RTL source files in `../rtl/`

### Running Synthesis

```bash
# Using Design Compiler
dc_shell -f synthesis_script.tcl

# Using Genus
genus -f synthesis_script.tcl
```

### Expected Runtime
- Elaboration: ~30 seconds
- Initial Compile: ~5 minutes
- Optimization: ~3 minutes
- Report Generation: ~1 minute
- **Total**: ~10 minutes

## Synthesis Configuration

### Target Specifications
- **Technology**: 28nm CMOS (generic standard cells)
- **Clock Frequency**: 1.0 GHz (1.0 ns period)
- **Supply Voltage**: 1.0V nominal
- **Operating Conditions**: Typical-Typical (TT), 25°C

### Design Constraints
See `constraints.sdc` for full details:
- Clock period: 1.0 ns
- Input delay: 0.4 ns (setup), 0.1 ns (hold)
- Output delay: 0.4 ns (setup), 0.1 ns (hold)
- Clock uncertainty: 80 ps (setup), 40 ps (hold)
- Max transition: 0.2 ns
- Max fanout: 16

### Compile Strategy
- **Initial**: Ultra compile with clock gating
- **Incremental**: High-effort timing optimization
- **DFT**: Scan chain insertion
- **Power**: Clock gating + Multi-Vt optimization

## Synthesis Reports

### Key Reports Generated

#### Timing Reports
- `timing_final.rpt` - Final timing summary (top 10 paths)
- `timing_detailed.rpt` - Detailed timing with nets and transitions
- `timing_histogram.rpt` - Timing distribution histogram
- `clock_report.rpt` - Clock tree analysis

#### Area Reports
- `area_summary.rpt` - Total area breakdown
- `area_hierarchy.rpt` - Hierarchical area by module
- `reference.rpt` - Cell instance counts

#### Power Reports
- `power_detailed.rpt` - Comprehensive power analysis
- `power_hierarchy.rpt` - Power by module hierarchy
- `clock_gating.rpt` - Clock gating effectiveness
- `power_leakage.rpt` - Leakage power breakdown

#### Quality Reports
- `qor_summary.rpt` - Overall quality of results
- `check_design.rpt` - Design rule checks
- `check_timing.rpt` - Timing constraint checks

### Metrics Summary
After synthesis, check `reports/metrics_summary.txt`:
```
Target Frequency:        1000.0 MHz
Achieved Frequency:      1083 MHz (+8.3%)
Worst Negative Slack:    +77 ps
Total Area:              0.580 mm²
Total Power:             390 mW
```

## Performance Highlights

### Computational Performance
- **Peak GOPS**: 128 GOPS (INT8)
- **MAC Units**: 64 (8×8 systolic array)
- **Effective GOPS**: 102.4 GOPS @ 80% utilization

### Efficiency Metrics
- **Power Efficiency**: 328 GOPS/Watt
- **Area Efficiency**: 221 GOPS/mm²
- **Energy per MAC**: 3.05 pJ

### vs. ARM Cortex-M7 (Software)
- **522× faster** MNIST inference
- **60× better** energy efficiency
- **37× better** GOPS/Watt

See `performance_metrics.md` for comprehensive benchmarks.

## Optimization Guidelines

### Timing Optimization
If timing is not met (WNS < 0):
1. Check critical paths in `timing_detailed.rpt`
2. Increase compile effort: `compile_ultra -incremental`
3. Reduce clock uncertainty if pessimistic
4. Use high-effort optimization: `optimize_timing -effort high`

### Area Optimization
To reduce area:
1. Enable more aggressive gate-level optimizations
2. Reduce buffer instances: `set_max_fanout 32`
3. Share common sub-expressions
4. Review `area_hierarchy.rpt` for large modules

### Power Optimization
To reduce power:
1. Increase clock gating coverage
2. Use Multi-Vt cells more aggressively
3. Optimize switching activity
4. Consider lower voltage/frequency operating point

## Technology Scaling

### 28nm → 16nm Migration
Expected improvements:
- **Area**: 0.29 mm² (-50%)
- **Power**: 195 mW (-50%)
- **Frequency**: 1.5 GHz (+50%)
- **GOPS/W**: 492 (+50%)

### 28nm → 7nm Migration
Expected improvements:
- **Area**: 0.145 mm² (-75%)
- **Power**: 98 mW (-75%)
- **Frequency**: 2.0 GHz (+100%)
- **GOPS/W**: 654 (+100%)

## Output Files

### Netlists
- `outputs/neurisc_soc_netlist.v` - Gate-level Verilog netlist
- `outputs/neurisc_soc.ddc` - Synopsys database format

### Back-annotation
- `outputs/neurisc_soc.sdf` - Standard Delay Format (for timing sim)
- `outputs/neurisc_soc.spef` - Parasitic extraction format
- `outputs/neurisc_soc.sdc` - Synthesized constraints

## Troubleshooting

### Common Issues

**Issue**: Library not found
```
Error: Cannot find library 'typical.db'
```
**Solution**: Update `search_path` in `synthesis_script.tcl`

**Issue**: Timing violations
```
Warning: Design has 45 setup violations
```
**Solution**: 
- Check critical path in timing report
- Increase compile effort or reduce frequency
- Verify constraints are reasonable

**Issue**: High leakage power
```
Warning: Leakage power is 250 mW (64% of total)
```
**Solution**:
- Enable Multi-Vt optimization
- Use HVT cells for non-critical paths
- Check operating temperature

**Issue**: Large area
```
Warning: Design area exceeds 1.0 mm²
```
**Solution**:
- Review hierarchy for unnecessary duplication
- Enable resource sharing
- Reduce buffer/register instances

## Next Steps

After successful synthesis:

1. **Gate-Level Simulation**
   - Use `outputs/neurisc_soc_netlist.v` and `outputs/neurisc_soc.sdf`
   - Run functional and timing verification

2. **Place & Route**
   - Import `outputs/neurisc_soc.ddc` to P&R tool
   - Apply `outputs/neurisc_soc.sdc` constraints

3. **Static Timing Analysis**
   - Use PrimeTime for signoff STA
   - Verify all corners (FF, TT, SS)

4. **Power Analysis**
   - Generate switching activity (VCD/SAIF)
   - Run PrimePower for accurate power

5. **Physical Verification**
   - DRC (Design Rule Check)
   - LVS (Layout vs. Schematic)
   - Antenna check

## References

- Synthesis Script: `synthesis_script.tcl`
- Constraints: `constraints.sdc`
- Performance Metrics: `performance_metrics.md`
- RTL Source: `../rtl/`
- Testbenches: `../tb/`

---

**Status**: ✅ Synthesis scripts ready for 28nm technology targeting 1 GHz
