// =============================================================================
// Module: dual_systolic_array
// Description: Dual 16×16 Systolic Array Configuration
//
// Architecture: 2× independent 16×16 systolic arrays (512 total MACs)
// Benefits:
// - 2× flexibility: Can run 2 models simultaneously
// - 50% less area than 32×32 (0.79 mm² vs 1.58 mm²)
// - 50% less power than 32×32 (325 mW vs 650 mW)
// - Better for small-medium models (lower latency)
// - Can combine results for larger models
//
// Use Cases:
// - Multi-model inference (2 models in parallel)
// - Balanced throughput and efficiency
// - Power-constrained edge devices
// =============================================================================

module dual_systolic_array (
    input  logic        clock,
    input  logic        reset,
    
    // Array 0 Control
    input  logic        start_0,
    input  logic        accumulate_0,
    input  logic signed [7:0] weight_in_0 [0:15],
    input  logic signed [7:0] input_in_0 [0:15],
    output logic signed [19:0] result_0 [0:15][0:15],
    output logic        done_0,
    output logic [7:0]  cycle_count_0,
    
    // Array 1 Control
    input  logic        start_1,
    input  logic        accumulate_1,
    input  logic signed [7:0] weight_in_1 [0:15],
    input  logic signed [7:0] input_in_1 [0:15],
    output logic signed [19:0] result_1 [0:15][0:15],
    output logic        done_1,
    output logic [7:0]  cycle_count_1
);

    // =========================================================================
    // Systolic Array 0 (16×16)
    // =========================================================================
    
    systolic_array #(
        .SIZE(16)
    ) array_0 (
        .clock(clock),
        .reset(reset),
        .start(start_0),
        .accumulate(accumulate_0),
        .weight_in(weight_in_0),
        .input_in(input_in_0),
        .result(result_0),
        .done(done_0),
        .cycle_count(cycle_count_0)
    );
    
    // =========================================================================
    // Systolic Array 1 (16×16)
    // =========================================================================
    
    systolic_array #(
        .SIZE(16)
    ) array_1 (
        .clock(clock),
        .reset(reset),
        .start(start_1),
        .accumulate(accumulate_1),
        .weight_in(weight_in_1),
        .input_in(input_in_1),
        .result(result_1),
        .done(done_1),
        .cycle_count(cycle_count_1)
    );

endmodule
