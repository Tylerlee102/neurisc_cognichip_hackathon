// for systolic array
// =============================================================================
// Enhanced MAC Unit with 2-stage pipeline and Dual-Mode INT4/INT8 support
// 
// Pipeline Stages:
//   Stage 1: Multiply (compute products)
//   Stage 2: Accumulate (add to accumulator with saturation)
//
// Operating Modes:
//   i_int4_mode = 0: INT8 mode (8x8 multiply, 20-bit accumulator)
//   i_int4_mode = 1: INT4 mode (dual 4x4 multiply, two 10-bit accumulators)
// =============================================================================

module mac_unit (
    input  logic        clock,
    input  logic        reset,
    input  logic        enable,
    input  logic        clear_acc,
    input  logic        i_int4_mode,        // 0=INT8, 1=INT4 dual mode
    input  logic signed [7:0] weight_in,
    input  logic signed [7:0] input_in,
    
    output logic signed [7:0]  weight_out,
    output logic signed [7:0]  input_out,
    output logic signed [19:0] accumulator,
    output logic        valid_out           // Valid signal for pipeline
);

    // =========================================================================
    // Pipeline Stage 1: Multiply
    // =========================================================================
    
    // Stage 1 pipeline registers
    logic signed [15:0] product_pipe;       // Full 8x8 product for INT8 mode
    logic signed [7:0]  prod_high_pipe;     // High 4x4 product for INT4 mode
    logic signed [7:0]  prod_low_pipe;      // Low 4x4 product for INT4 mode
    logic               enable_pipe;
    logic               int4_mode_pipe;
    logic               valid_stage2;        // Valid data at output
    
    // Stage 1 combinational logic
    logic signed [15:0] product_full;
    logic signed [3:0]  weight_high, weight_low;
    logic signed [3:0]  input_high, input_low;
    logic signed [7:0]  prod_high, prod_low;
    
    always_comb begin
        // INT8 mode: Full 8x8 multiplication
        product_full = weight_in * input_in;
        
        // INT4 mode: Split into high and low 4-bit signed values
        // Sign-extend the 4-bit values to maintain signed arithmetic
        weight_high = weight_in[7:4];
        weight_low  = weight_in[3:0];
        input_high  = input_in[7:4];
        input_low   = input_in[3:0];
        
        // Two parallel 4x4 multiplications (results are 8-bit)
        prod_high = $signed(weight_high) * $signed(input_high);
        prod_low  = $signed(weight_low) * $signed(input_low);
    end
    
    // Stage 1 sequential logic: Register all multiply results and control signals
    always_ff @(posedge clock) begin
        if (reset) begin
            product_pipe    <= 16'sh0;
            prod_high_pipe  <= 8'sh0;
            prod_low_pipe   <= 8'sh0;
            enable_pipe     <= 1'b0;
            int4_mode_pipe  <= 1'b0;
        end else if (clear_acc) begin
            // Clear flushes the pipeline
            product_pipe    <= 16'sh0;
            prod_high_pipe  <= 8'sh0;
            prod_low_pipe   <= 8'sh0;
            enable_pipe     <= 1'b0;
            int4_mode_pipe  <= 1'b0;
        end else begin
            product_pipe    <= product_full;
            prod_high_pipe  <= prod_high;
            prod_low_pipe   <= prod_low;
            enable_pipe     <= enable;
            int4_mode_pipe  <= i_int4_mode;
        end
    end
    
    // =========================================================================
    // Pipeline Stage 2: Accumulate
    // =========================================================================
    
    // Split accumulator for INT4 mode (two independent 10-bit accumulators)
    logic signed [9:0] acc_high;            // Upper 10 bits for INT4 mode
    logic signed [9:0] acc_low;             // Lower 10 bits for INT4 mode
    
    // Stage 2 combinational logic: Accumulation with saturation
    logic signed [31:0] sum_int8;
    logic signed [19:0] next_acc_int8;
    logic signed [15:0] sum_high_int4;
    logic signed [9:0]  next_acc_high;
    logic signed [15:0] sum_low_int4;
    logic signed [9:0]  next_acc_low;
    
    always_comb begin
        // INT8 mode: 20-bit accumulator with saturation
        sum_int8 = $signed(accumulator) + $signed(product_pipe);
        if (sum_int8 > 32'sd524287)
            next_acc_int8 = 20'sd524287;
        else if (sum_int8 < -32'sd524288)
            next_acc_int8 = -20'sd524288;
        else
            next_acc_int8 = sum_int8[19:0];
        
        // INT4 mode: Two 10-bit accumulators with saturation
        // High accumulator (range: -512 to +511)
        sum_high_int4 = $signed(acc_high) + $signed(prod_high_pipe);
        if (sum_high_int4 > 16'sd511)
            next_acc_high = 10'sd511;
        else if (sum_high_int4 < -16'sd512)
            next_acc_high = -10'sd512;
        else
            next_acc_high = sum_high_int4[9:0];
        
        // Low accumulator (range: -512 to +511)
        sum_low_int4 = $signed(acc_low) + $signed(prod_low_pipe);
        if (sum_low_int4 > 16'sd511)
            next_acc_low = 10'sd511;
        else if (sum_low_int4 < -16'sd512)
            next_acc_low = -10'sd512;
        else
            next_acc_low = sum_low_int4[9:0];
    end
    
    // Stage 2 sequential logic: Update accumulators and valid signal
    always_ff @(posedge clock) begin
        if (reset) begin
            accumulator  <= 20'sh0;
            acc_high     <= 10'sh0;
            acc_low      <= 10'sh0;
            valid_stage2 <= 1'b0;
        end else if (clear_acc) begin
            // Clear has immediate effect (not pipelined)
            accumulator  <= 20'sh0;
            acc_high     <= 10'sh0;
            acc_low      <= 10'sh0;
            valid_stage2 <= 1'b0;
        end else begin
            // Update accumulator when we have valid pipelined data (enable_pipe)
            // enable_pipe indicates that stage 1 computed a product that should be accumulated
            if (enable_pipe) begin
                if (int4_mode_pipe) begin
                    // INT4 mode: Update split accumulators
                    acc_high    <= next_acc_high;
                    acc_low     <= next_acc_low;
                    // Combine into output (for compatibility)
                    accumulator <= {next_acc_high, next_acc_low};
                end else begin
                    // INT8 mode: Update full accumulator
                    accumulator <= next_acc_int8;
                    // Keep split accumulators synchronized
                    acc_high    <= next_acc_int8[19:10];
                    acc_low     <= next_acc_int8[9:0];
                end
            end
            // Track valid output (valid when we just accumulated)
            valid_stage2 <= enable_pipe;
        end
    end
    
    // Output valid signal
    assign valid_out = valid_stage2;
    
    // =========================================================================
    // Data pass-through for systolic array (maintains single-cycle delay)
    // =========================================================================
    always_ff @(posedge clock) begin
        if (reset) begin
            weight_out <= 8'sh0;
            input_out  <= 8'sh0;
        end else begin
            weight_out <= weight_in;
            input_out  <= input_in;
        end
    end

endmodule
