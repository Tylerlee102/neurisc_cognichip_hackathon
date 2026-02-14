# =============================================================================
# File: synthesis_script.tcl
# Description: Synthesis Script for NeuroRISC SoC
# 
# Tool: Synopsys Design Compiler or Cadence Genus
# Target: Generic 28nm Standard Cell Library
# Clock: 1 GHz (1.0 ns period)
# 
# Usage:
#   dc_shell -f synthesis_script.tcl
#   or
#   genus -f synthesis_script.tcl
# =============================================================================

# =============================================================================
# Setup and Configuration
# =============================================================================

puts "========================================"
puts "  NeuroRISC SoC Synthesis Script"
puts "  Target: 28nm @ 1GHz"
puts "========================================\n"

# Design name
set DESIGN_NAME "neurisc_soc"

# Set search paths (adjust based on your library location)
set search_path ". ../rtl /path/to/stdcell/28nm/synopsys"
set link_library "* typical.db slow.db fast.db"
set target_library "typical.db"
set symbol_library "typical.sdb"

# =============================================================================
# Read Design Files
# =============================================================================

puts "Reading RTL files..."

# Read all RTL modules in dependency order
read_verilog -sv ../rtl/mac_unit.sv
read_verilog -sv ../rtl/systolic_array.sv
read_verilog -sv ../rtl/activation_unit.sv
read_verilog -sv ../rtl/weight_buffer.sv
read_verilog -sv ../rtl/activation_buffer.sv
read_verilog -sv ../rtl/dma_controller.sv
read_verilog -sv ../rtl/custom_instruction_decoder.sv
read_verilog -sv ../rtl/neurisc_soc.sv

# =============================================================================
# Elaborate Design
# =============================================================================

puts "\nElaborating design..."
current_design $DESIGN_NAME

# Link the design
link

# Check design for issues
check_design -summary
check_design > reports/check_design.rpt

# =============================================================================
# Apply Constraints
# =============================================================================

puts "\nApplying timing constraints..."
source constraints.sdc

# Check timing constraints
check_timing -verbose > reports/check_timing.rpt

# =============================================================================
# Compile Strategy
# =============================================================================

puts "\nCompiling design..."

# Set compile options
set compile_ultra_ungroup_dw false
set compile_seqmap_propagate_constants false

# Initial compile with medium effort
compile_ultra -gate_clock -no_autoungroup

puts "\nFirst compile complete. Checking timing..."

# Generate timing report after first compile
report_timing -path full -delay max -max_paths 10 \
    -nworst 1 -format {timing startpoint endpoint slack} \
    > reports/timing_initial.rpt

report_area -hierarchy > reports/area_initial.rpt

# =============================================================================
# Incremental Compile for Timing Optimization
# =============================================================================

if {[get_attribute [current_design] slack] < 0} {
    puts "\nTiming not met. Running incremental compile..."
    
    # Incremental compile with higher effort
    compile_ultra -incremental -no_autoungroup
    
    report_timing -path full -delay max -max_paths 10 \
        -nworst 1 -format {timing startpoint endpoint slack} \
        > reports/timing_incremental.rpt
}

# =============================================================================
# DFT Insertion (Scan Chain)
# =============================================================================

puts "\nInserting scan chains for testability..."

set_scan_configuration -style multiplexed_flip_flop
set_dft_signal -view existing_dft -type ScanEnable -port scan_enable -active_state 1
set_dft_signal -view spec -type ScanClock -port clock -timing {45 55}

# Preview DFT
preview_dft -show all > reports/dft_preview.rpt

# Insert DFT
insert_dft

# Compile after DFT insertion
compile_ultra -scan -incremental

# =============================================================================
# Power Optimization
# =============================================================================

puts "\nOptimizing for power..."

# Clock gating
compile_ultra -gate_clock -self_gating

# Multi-Vt optimization
set_multi_vt_constraint -low_vt_percentage 20
optimize_power

# =============================================================================
# Final Reports
# =============================================================================

puts "\nGenerating final reports..."

# Create reports directory if it doesn't exist
file mkdir reports

# -----------------------------------------------------------------------------
# Timing Reports
# -----------------------------------------------------------------------------

puts "  - Timing reports..."

# Overall timing summary
report_timing -path full -delay max -max_paths 10 \
    -nworst 1 -format {timing startpoint endpoint slack} \
    > reports/timing_final.rpt

# Detailed timing for critical paths
report_timing -path full -delay max -max_paths 100 \
    -transition_time -capacitance -nets -input_pins \
    > reports/timing_detailed.rpt

# Timing histogram
report_timing -histogram > reports/timing_histogram.rpt

# Setup and hold check summary
report_constraint -all_violators > reports/constraints_violators.rpt

# Clock report
report_clock -skew -attribute > reports/clock_report.rpt

# -----------------------------------------------------------------------------
# Area Reports
# -----------------------------------------------------------------------------

puts "  - Area reports..."

# Hierarchical area breakdown
report_area -hierarchy > reports/area_hierarchy.rpt

# Cell type breakdown
report_area -designware > reports/area_designware.rpt

# Reference summary
report_reference -hierarchy > reports/reference.rpt

# Total area summary
report_area > reports/area_summary.rpt

# -----------------------------------------------------------------------------
# Power Reports
# -----------------------------------------------------------------------------

puts "  - Power reports..."

# Power analysis
report_power -analysis_effort high \
    -verbose -hierarchy \
    > reports/power_detailed.rpt

# Power by hierarchy
report_power -hierarchy -levels 2 > reports/power_hierarchy.rpt

# Switching activity
report_power -cell > reports/power_cells.rpt

# Clock tree power
report_clock_gating -multi_stage -verbose \
    > reports/clock_gating.rpt

# Leakage power breakdown
report_power -nosplit -hierarchy -levels 3 \
    > reports/power_leakage.rpt

# -----------------------------------------------------------------------------
# Quality of Results (QoR) Summary
# -----------------------------------------------------------------------------

puts "  - QoR summary..."

# Overall QoR
report_qor > reports/qor_summary.rpt

# Design statistics
report_design > reports/design_stats.rpt

# Resources
report_resources > reports/resources.rpt

# =============================================================================
# Performance Metrics Extraction
# =============================================================================

puts "\nExtracting performance metrics..."

# Get timing slack
set wns [get_attribute [get_timing_paths -max_paths 1 -nworst 1] slack]
set tns [get_attribute [current_design] tns]

# Get area
set total_area [get_attribute [current_design] area]

# Get power
set dynamic_power [get_attribute [current_design] dynamic_power]
set leakage_power [get_attribute [current_design] leakage_power]
set total_power [expr $dynamic_power + $leakage_power]

# Calculate achieved frequency
set critical_path_delay [expr 1.0 - $wns]
set achieved_freq [expr 1000 / $critical_path_delay]

# Count cells
set total_cells [sizeof_collection [get_cells -hierarchical]]
set mac_units [sizeof_collection [get_cells -hierarchical *mac_unit*]]
set sequential_cells [sizeof_collection [get_cells -hierarchical -filter "is_sequential==true"]]
set combinational_cells [expr $total_cells - $sequential_cells]

# Write metrics to file
set metrics_file [open "reports/metrics_summary.txt" w]
puts $metrics_file "NeuroRISC SoC Synthesis Metrics"
puts $metrics_file "================================\n"
puts $metrics_file "Target Clock Period:     1.000 ns"
puts $metrics_file "Target Frequency:        1000.0 MHz"
puts $metrics_file "Worst Negative Slack:    [format "%.3f" $wns] ns"
puts $metrics_file "Total Negative Slack:    [format "%.3f" $tns] ns"
puts $metrics_file "Critical Path Delay:     [format "%.3f" $critical_path_delay] ns"
puts $metrics_file "Achieved Frequency:      [format "%.1f" $achieved_freq] MHz"
puts $metrics_file "\nArea:"
puts $metrics_file "  Total Area:            [format "%.2f" $total_area] um²"
puts $metrics_file "  Total Cells:           $total_cells"
puts $metrics_file "  Sequential Cells:      $sequential_cells"
puts $metrics_file "  Combinational Cells:   $combinational_cells"
puts $metrics_file "  MAC Units:             $mac_units"
puts $metrics_file "\nPower @ 1GHz:"
puts $metrics_file "  Dynamic Power:         [format "%.3f" $dynamic_power] mW"
puts $metrics_file "  Leakage Power:         [format "%.3f" $leakage_power] mW"
puts $metrics_file "  Total Power:           [format "%.3f" $total_power] mW"
puts $metrics_file "\nTechnology: 28nm"
puts $metrics_file "Libraries: typical/slow/fast"
close $metrics_file

# Print summary to console
puts "\n========================================"
puts "  Synthesis Complete!"
puts "========================================" 
puts "Worst Negative Slack: [format "%.3f" $wns] ns"
puts "Total Area:           [format "%.2f" $total_area] um²"
puts "Total Power:          [format "%.3f" $total_power] mW"
puts "========================================\n"

# =============================================================================
# Write Out Synthesized Design
# =============================================================================

puts "Writing output files..."

# Write netlist
write -format verilog -hierarchy -output "outputs/${DESIGN_NAME}_netlist.v"
write -format ddc -hierarchy -output "outputs/${DESIGN_NAME}.ddc"

# Write SDF for back-annotation
write_sdf "outputs/${DESIGN_NAME}.sdf"

# Write constraints
write_sdc "outputs/${DESIGN_NAME}.sdc"

# Write parasitics
write_parasitics -format SPEF -output "outputs/${DESIGN_NAME}.spef"

puts "\nAll output files written to outputs/ directory"
puts "All reports written to reports/ directory"

# =============================================================================
# Cleanup and Exit
# =============================================================================

puts "\n========================================"
puts "  Synthesis Flow Complete!"
puts "========================================\n"

exit
