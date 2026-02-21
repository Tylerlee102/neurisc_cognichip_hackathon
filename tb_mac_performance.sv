// =============================================================================
// Testbench: tb_mac_performance
// Description: Performance and functional verification for pipelined MAC unit
//              Tests both INT8 and INT4 modes with timing analysis
// =============================================================================

module tb_mac_performance;

    // Clock and reset
    logic clock;
    logic reset;
    
    // MAC unit signals
    logic        enable;
    logic        clear_acc;
    logic        i_int4_mode;
    logic signed [7:0]  weight_in;
    logic signed [7:0]  input_in;
    logic signed [7:0]  weight_out;
    logic signed [7:0]  input_out;
    logic signed [19:0] accumulator;
    logic        valid_out;
    
    // Test variables
    int error_count;
    int test_count;
    longint start_time, end_time;
    real throughput_int8, throughput_int4;
    
    // DUT instantiation
    mac_unit dut (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .clear_acc(clear_acc),
        .i_int4_mode(i_int4_mode),
        .weight_in(weight_in),
        .input_in(input_in),
        .weight_out(weight_out),
        .input_out(input_out),
        .accumulator(accumulator),
        .valid_out(valid_out)
    );
    
    // Clock generation (10ns period = 100MHz)
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end
    
    // =========================================================================
    // Helper Tasks
    // =========================================================================
    
    task automatic do_reset();
        reset = 1;
        repeat(5) @(posedge clock);
        reset = 0;
        @(posedge clock);
    endtask
    
    task automatic do_clear();
        @(negedge clock);
        clear_acc = 1;
        @(posedge clock);
        @(negedge clock);
        clear_acc = 0;
    endtask
    
    // Apply MAC operation and wait for valid_out
    task automatic do_mac_and_wait(
        input logic signed [7:0] w, 
        input logic signed [7:0] i,
        input logic int4_mode
    );
        @(negedge clock);
        weight_in = w;
        input_in = i;
        i_int4_mode = int4_mode;
        enable = 1;
        @(posedge clock);
        // Pulse enable for only 1 cycle
        @(negedge clock);
        enable = 0;
        
        // Wait for valid_out (pipeline latency = 2 cycles)
        wait(valid_out == 1);
        @(posedge clock);  // Wait one more cycle for valid to deassert
    endtask
    
    // =========================================================================
    // Test: Pipeline Latency Verification
    // =========================================================================
    task automatic test_pipeline_latency();
        int latency_cycles;
        
        $display("\n========================================");
        $display("Test: Pipeline Latency Measurement");
        $display("========================================");
        
        do_clear();
        @(posedge clock);
        
        // Apply MAC operation (pulse enable for 1 cycle only)
        @(negedge clock);
        weight_in = 8'sd5;
        input_in = 8'sd3;
        i_int4_mode = 0;
        enable = 1;
        
        // Measure cycles until valid_out
        latency_cycles = 0;
        @(posedge clock);
        latency_cycles++;
        
        // Disable enable after 1 cycle
        @(negedge clock);
        enable = 0;
        
        // Continue measuring latency
        while (valid_out == 0) begin
            @(posedge clock);
            latency_cycles++;
        end
        
        $display("  Pipeline Latency: %0d clock cycles", latency_cycles);
        
        if (latency_cycles == 2) begin
            $display("  PASS: Expected 2-cycle latency confirmed");
        end else begin
            $display("  WARN: Expected 2 cycles, measured %0d cycles", latency_cycles);
        end
        
        if (accumulator === 20'sd15) begin
            $display("  PASS: Correct result (5 x 3 = 15)");
        end else begin
            $display("  FAIL: Got %0d, expected 15", accumulator);
            error_count++;
        end
        
        test_count++;
    endtask
    
    // =========================================================================
    // Test: INT8 Mode Functional Tests
    // =========================================================================
    task automatic test_int8_mode();
        logic signed [19:0] expected;
        
        $display("\n========================================");
        $display("Test: INT8 Mode Functional Tests");
        $display("========================================");
        
        // Test 1: Basic multiplication
        $display("\n  Test 1a: 10 x 20 = 200");
        do_clear();
        do_mac_and_wait(8'sd10, 8'sd20, 0);
        
        expected = 20'sd200;
        if (accumulator === expected) begin
            $display("    PASS: Result = %0d", accumulator);
        end else begin
            $display("    FAIL: Got %0d, expected %0d", accumulator, expected);
            error_count++;
        end
        test_count++;
        
        // Test 2: Accumulation
        $display("\n  Test 1b: Accumulation (200 + 15x15 = 425)");
        do_mac_and_wait(8'sd15, 8'sd15, 0);
        
        expected = 20'sd425;
        if (accumulator === expected) begin
            $display("    PASS: Accumulated to %0d", accumulator);
        end else begin
            $display("    FAIL: Got %0d, expected %0d", accumulator, expected);
            error_count++;
        end
        test_count++;
        
        // Test 3: Negative numbers
        $display("\n  Test 1c: Negative numbers (-50 x 10 = -500)");
        do_clear();
        do_mac_and_wait(-8'sd50, 8'sd10, 0);
        
        expected = -20'sd500;
        if (accumulator === expected) begin
            $display("    PASS: Result = %0d", $signed(accumulator));
        end else begin
            $display("    FAIL: Got %0d, expected %0d", $signed(accumulator), $signed(expected));
            error_count++;
        end
        test_count++;
        
        // Test 4: Saturation (positive)
        $display("\n  Test 1d: Positive saturation");
        do_clear();
        
        @(negedge clock);
        enable = 1;
        weight_in = 8'sd127;
        input_in = 8'sd127;
        i_int4_mode = 0;
        repeat(50) @(posedge clock);
        @(negedge clock);
        enable = 0;
        
        // Wait for pipeline to flush
        repeat(3) @(posedge clock);
        
        if (accumulator === 20'sh7FFFF) begin
            $display("    PASS: Saturated to +524287 (0x%0h)", accumulator);
        end else begin
            $display("    FAIL: Got 0x%0h, expected 0x7FFFF", accumulator);
            error_count++;
        end
        test_count++;
    endtask
    
    // =========================================================================
    // Test: INT4 Mode Functional Tests
    // =========================================================================
    task automatic test_int4_mode();
        logic signed [9:0] expected_high, expected_low;
        logic signed [19:0] expected_full;
        
        $display("\n========================================");
        $display("Test: INT4 Mode Functional Tests");
        $display("========================================");
        
        // Test 1: Basic INT4 multiplication
        // weight_in = 8'b0011_0010 = {3, 2}
        // input_in  = 8'b0010_0011 = {2, 3}
        // Expected: high = 3*2=6, low = 2*3=6
        $display("\n  Test 2a: INT4 dual MAC {3,2} x {2,3}");
        do_clear();
        do_mac_and_wait(8'b0011_0010, 8'b0010_0011, 1);
        
        expected_high = 10'sd6;
        expected_low = 10'sd6;
        expected_full = {expected_high, expected_low};
        
        if (accumulator === expected_full) begin
            $display("    PASS: Result = 0x%05h (high=%0d, low=%0d)", 
                     accumulator, accumulator[19:10], accumulator[9:0]);
        end else begin
            $display("    FAIL: Got 0x%05h, expected 0x%05h", accumulator, expected_full);
            $display("          Got high=%0d, low=%0d", 
                     $signed(accumulator[19:10]), $signed(accumulator[9:0]));
            error_count++;
        end
        test_count++;
        
        // Test 2: INT4 accumulation
        $display("\n  Test 2b: INT4 accumulation");
        do_mac_and_wait(8'b0001_0010, 8'b0001_0001, 1);  // {1,2} x {1,1} = {1,2}
        
        expected_high = 10'sd7;  // 6 + 1
        expected_low = 10'sd8;   // 6 + 2
        expected_full = {expected_high, expected_low};
        
        if (accumulator === expected_full) begin
            $display("    PASS: Accumulated (high=%0d, low=%0d)", 
                     accumulator[19:10], accumulator[9:0]);
        end else begin
            $display("    FAIL: Expected high=%0d, low=%0d", expected_high, expected_low);
            $display("          Got high=%0d, low=%0d", 
                     $signed(accumulator[19:10]), $signed(accumulator[9:0]));
            error_count++;
        end
        test_count++;
        
        // Test 3: INT4 negative values
        // Using signed 4-bit: 0b1111 = -1, 0b1110 = -2
        $display("\n  Test 2c: INT4 with negative values");
        do_clear();
        do_mac_and_wait(8'b1111_1110, 8'b0010_0011, 1);  // {-1,-2} x {2,3} = {-2,-6}
        
        expected_high = -10'sd2;
        expected_low = -10'sd6;
        expected_full = {expected_high, expected_low};
        
        if (accumulator === expected_full) begin
            $display("    PASS: Result (high=%0d, low=%0d)", 
                     $signed(accumulator[19:10]), $signed(accumulator[9:0]));
        end else begin
            $display("    FAIL: Expected high=%0d, low=%0d", expected_high, expected_low);
            $display("          Got high=%0d, low=%0d", 
                     $signed(accumulator[19:10]), $signed(accumulator[9:0]));
            error_count++;
        end
        test_count++;
        
        // Test 4: INT4 saturation
        $display("\n  Test 2d: INT4 positive saturation");
        do_clear();
        
        @(negedge clock);
        enable = 1;
        weight_in = 8'b0111_0111;  // {7, 7}
        input_in = 8'b0111_0111;   // {7, 7}
        i_int4_mode = 1;
        repeat(20) @(posedge clock);  // 7*7*20 = 980 > 511
        @(negedge clock);
        enable = 0;
        
        repeat(3) @(posedge clock);
        
        if (accumulator[19:10] === 10'sd511 && accumulator[9:0] === 10'sd511) begin
            $display("    PASS: Both accumulators saturated to +511");
        end else begin
            $display("    FAIL: high=%0d (exp 511), low=%0d (exp 511)", 
                     $signed(accumulator[19:10]), $signed(accumulator[9:0]));
            error_count++;
        end
        test_count++;
    endtask
    
    // =========================================================================
    // Test: Throughput Measurement
    // =========================================================================
    task automatic test_throughput();
        int num_ops;
        real time_ns;
        
        $display("\n========================================");
        $display("Test: Throughput Measurement");
        $display("========================================");
        
        // INT8 Mode Throughput
        $display("\n  Measuring INT8 mode throughput...");
        num_ops = 1000;
        do_clear();
        
        start_time = $time;
        
        @(negedge clock);
        enable = 1;
        i_int4_mode = 0;
        weight_in = 8'sd7;
        input_in = 8'sd3;
        
        repeat(num_ops) @(posedge clock);
        
        @(negedge clock);
        enable = 0;
        end_time = $time;
        
        time_ns = (end_time - start_time) / 1000.0;  // Convert ps to ns
        throughput_int8 = (num_ops / time_ns) * 1000.0;  // MOps/sec
        
        $display("    Operations: %0d", num_ops);
        $display("    Time: %.1f ns", time_ns);
        $display("    Throughput: %.2f MOps/sec (@ 100 MHz)", throughput_int8);
        $display("    Note: Pipeline allows 1 op/cycle when fully loaded");
        
        // INT4 Mode Throughput (2x due to dual processing)
        $display("\n  Measuring INT4 mode throughput...");
        do_clear();
        
        start_time = $time;
        
        @(negedge clock);
        enable = 1;
        i_int4_mode = 1;
        weight_in = 8'b0011_0010;
        input_in = 8'b0010_0011;
        
        repeat(num_ops) @(posedge clock);
        
        @(negedge clock);
        enable = 0;
        end_time = $time;
        
        time_ns = (end_time - start_time) / 1000.0;
        // Each cycle does 2 MACs in INT4 mode
        throughput_int4 = (num_ops * 2 / time_ns) * 1000.0;
        
        $display("    Operations: %0d (x2 per cycle)", num_ops);
        $display("    Time: %.1f ns", time_ns);
        $display("    Throughput: %.2f MOps/sec (@ 100 MHz)", throughput_int4);
        $display("    Speedup vs INT8: %.2fx", throughput_int4 / throughput_int8);
        
        test_count++;
    endtask
    
    // =========================================================================
    // Test: Valid Signal Behavior
    // =========================================================================
    task automatic test_valid_signal();
        $display("\n========================================");
        $display("Test: Valid Signal Behavior");
        $display("========================================");
        
        do_clear();
        
        // Check valid_out goes high when enable is active
        $display("\n  Test: valid_out timing");
        @(negedge clock);
        enable = 1;
        weight_in = 8'sd10;
        input_in = 8'sd5;
        i_int4_mode = 0;
        
        @(posedge clock);  // Cycle 1: multiply stage
        @(negedge clock);
        enable = 0;  // Pulse enable for only 1 cycle
        
        @(posedge clock);  // Cycle 2: check valid before accumulate completes
        if (valid_out !== 0) begin
            $display("    FAIL: valid_out should be 0 before accumulation completes");
            error_count++;
        end
        
        @(posedge clock);  // Cycle 3: accumulate stage completes
        if (valid_out !== 1) begin
            $display("    FAIL: valid_out should be 1 after accumulation");
            error_count++;
        end else begin
            $display("    PASS: valid_out goes high after 2 cycles");
        end
        
        @(posedge clock);  // Cycle 4: valid should go low
        if (valid_out !== 0) begin
            $display("    FAIL: valid_out should go low after 1 cycle");
            error_count++;
        end else begin
            $display("    PASS: valid_out goes low when no more operations");
        end
        
        test_count++;
    endtask
    
    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        $display("\n");
        $display("================================================================================");
        $display("  MAC Unit Performance & Functional Testbench");
        $display("  Testing: 2-stage pipeline + Dual INT4/INT8 modes");
        $display("================================================================================\n");
        
        error_count = 0;
        test_count = 0;
        
        // Initialize signals
        reset = 1;
        enable = 0;
        clear_acc = 0;
        i_int4_mode = 0;
        weight_in = 0;
        input_in = 0;
        
        // Reset
        do_reset();
        
        // Run all tests
        test_pipeline_latency();
        test_int8_mode();
        test_int4_mode();
        test_valid_signal();
        test_throughput();
        
        // Final Summary
        $display("\n================================================================================");
        $display("  TEST SUMMARY");
        $display("================================================================================");
        $display("  Total Tests: %0d", test_count);
        $display("  Errors: %0d", error_count);
        $display("");
        
        if (error_count == 0) begin
            $display("  ✓ ALL TESTS PASSED");
            $display("TEST PASSED");
        end else begin
            $display("  ✗ TESTS FAILED");
            $display("TEST FAILED");
        end
        $display("================================================================================\n");
        
        #100;
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("mac_performance.fst");
        $dumpvars(0, tb_mac_performance);
    end
    
    // Timeout watchdog
    initial begin
        #1000000;
        $display("\nERROR: Test timeout!");
        $display("TEST FAILED");
        $finish;
    end

endmodule
