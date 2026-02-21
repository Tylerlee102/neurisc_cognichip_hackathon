// =============================================================================
// Testbench: tb_pooling_unit
// Description: Comprehensive verification for 2x2 max pooling unit
//              Tests bypass mode, pooling mode, and data reduction
// =============================================================================

module tb_pooling_unit;

    // Test parameters
    localparam int TEST_WIDTH = 8;  // Small width for easy verification
    
    // Clock and reset
    logic clk;
    logic reset;
    
    // DUT signals
    logic       valid_in;
    logic [7:0] data_in;
    logic       enable_pooling;
    logic       valid_out;
    logic [7:0] data_out;
    
    // Test variables
    int error_count;
    int test_count;
    int output_count;
    
    // Expected output tracking
    logic [7:0] expected_outputs [$];
    logic [7:0] received_outputs [$];
    
    // DUT instantiation with small width for testing
    pooling_unit #(
        .IMAGE_WIDTH(TEST_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .data_in(data_in),
        .enable_pooling(enable_pooling),
        .valid_out(valid_out),
        .data_out(data_out)
    );
    
    // Clock generation (10ns period = 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Collect outputs
    always_ff @(posedge clk) begin
        if (valid_out) begin
            received_outputs.push_back(data_out);
            output_count++;
        end
    end
    
    // =========================================================================
    // Helper Tasks
    // =========================================================================
    
    task automatic do_reset();
        reset = 1;
        valid_in = 0;
        data_in = 0;
        enable_pooling = 0;
        repeat(5) @(posedge clk);
        reset = 0;
        @(posedge clk);
    endtask
    
    // Send a single pixel
    task automatic send_pixel(input logic [7:0] pixel);
        @(negedge clk);
        valid_in = 1;
        data_in = pixel;
        @(posedge clk);
        @(negedge clk);
        valid_in = 0;
    endtask
    
    // Send multiple pixels continuously
    task automatic send_pixels(input logic [7:0] pixels[], input int count);
        for (int i = 0; i < count; i++) begin
            @(negedge clk);
            valid_in = 1;
            data_in = pixels[i];
            @(posedge clk);
        end
        @(negedge clk);
        valid_in = 0;
    endtask
    
    // Send a complete row
    task automatic send_row(input logic [7:0] row_data[]);
        for (int i = 0; i < TEST_WIDTH; i++) begin
            @(negedge clk);
            valid_in = 1;
            data_in = row_data[i];
            @(posedge clk);
        end
        @(negedge clk);
        valid_in = 0;
    endtask
    
    // =========================================================================
    // Test 1: Bypass Mode (Zero Latency Pass-Through)
    // =========================================================================
    task automatic test_bypass_mode();
        logic [7:0] test_data [4];
        int received_count;
        
        $display("\n========================================");
        $display("Test 1: Bypass Mode");
        $display("========================================");
        
        do_reset();
        enable_pooling = 0;  // Bypass mode
        output_count = 0;
        
        // Prepare test data
        test_data[0] = 8'h10;
        test_data[1] = 8'h20;
        test_data[2] = 8'h30;
        test_data[3] = 8'h40;
        
        // Send pixels and check immediate pass-through
        for (int i = 0; i < 4; i++) begin
            @(negedge clk);
            valid_in = 1;
            data_in = test_data[i];
            @(posedge clk);
            
            // Check combinational output (should be immediate)
            if (valid_out !== 1'b1) begin
                $display("  FAIL: valid_out should be 1 in bypass mode");
                error_count++;
            end
            if (data_out !== test_data[i]) begin
                $display("  FAIL: data_out = 0x%02h, expected 0x%02h", data_out, test_data[i]);
                error_count++;
            end
        end
        
        @(negedge clk);
        valid_in = 0;
        @(posedge clk);
        
        if (valid_out !== 1'b0) begin
            $display("  FAIL: valid_out should be 0 when valid_in is 0");
            error_count++;
        end
        
        if (error_count == 0) begin
            $display("  PASS: Bypass mode works correctly (zero latency)");
        end
        
        test_count++;
    endtask
    
    // =========================================================================
    // Test 2: Basic 2x2 Max Pooling
    // =========================================================================
    task automatic test_basic_pooling();
        logic [7:0] row0 [8];
        logic [7:0] row1 [8];
        
        $display("\n========================================");
        $display("Test 2: Basic 2x2 Max Pooling");
        $display("========================================");
        
        do_reset();
        enable_pooling = 1;  // Pooling mode
        output_count = 0;
        expected_outputs.delete();
        received_outputs.delete();
        
        // Create 2x8 test pattern with known max values
        // Row 0: [10, 20, 30, 40, 50, 60, 70, 80]
        // Row 1: [15, 25, 35, 45, 55, 65, 75, 85]
        // Expected 2x2 blocks:
        //   Block 0: max(10,20,15,25) = 25
        //   Block 1: max(30,40,35,45) = 45
        //   Block 2: max(50,60,55,65) = 65
        //   Block 3: max(70,80,75,85) = 85
        
        for (int i = 0; i < TEST_WIDTH; i++) begin
            row0[i] = 8'(10 + i*10);
            row1[i] = 8'(15 + i*10);
        end
        
        // Expected outputs
        expected_outputs.push_back(8'd25);
        expected_outputs.push_back(8'd45);
        expected_outputs.push_back(8'd65);
        expected_outputs.push_back(8'd85);
        
        $display("  Sending row 0...");
        send_row(row0);
        
        // Should have no outputs yet (waiting for second row)
        @(posedge clk);
        if (output_count != 0) begin
            $display("  FAIL: Should have no outputs after first row");
            error_count++;
        end
        
        $display("  Sending row 1...");
        send_row(row1);
        
        // Wait for outputs to complete
        repeat(10) @(posedge clk);
        
        // Check output count
        if (output_count != 4) begin
            $display("  FAIL: Expected 4 outputs, got %0d", output_count);
            error_count++;
        end else begin
            $display("  PASS: Correct output count (4 pooled values)");
        end
        
        // Verify outputs
        for (int i = 0; i < expected_outputs.size(); i++) begin
            if (i < received_outputs.size()) begin
                if (received_outputs[i] === expected_outputs[i]) begin
                    $display("  PASS: Output[%0d] = %0d (correct)", i, received_outputs[i]);
                end else begin
                    $display("  FAIL: Output[%0d] = %0d, expected %0d", 
                             i, received_outputs[i], expected_outputs[i]);
                    error_count++;
                end
            end else begin
                $display("  FAIL: Missing output[%0d]", i);
                error_count++;
            end
        end
        
        test_count++;
    endtask
    
    // =========================================================================
    // Test 3: Negative Numbers (Signed INT8)
    // =========================================================================
    task automatic test_negative_numbers();
        logic [7:0] row0 [8];
        logic [7:0] row1 [8];
        
        $display("\n========================================");
        $display("Test 3: Negative Numbers");
        $display("========================================");
        
        do_reset();
        enable_pooling = 1;
        output_count = 0;
        expected_outputs.delete();
        received_outputs.delete();
        
        // Create pattern with negative numbers
        // Row 0: [-10, -5, 20, 15, -30, -25, 40, 35]
        // Row 1: [-15, -8, 18, 12, -28, -20, 38, 30]
        // Expected max in each 2x2:
        //   Block 0: max(-10,-5,-15,-8) = -5
        //   Block 1: max(20,15,18,12) = 20
        //   Block 2: max(-30,-25,-28,-20) = -20
        //   Block 3: max(40,35,38,30) = 40
        
        row0[0] = -10; row0[1] = -5;  row0[2] = 20;  row0[3] = 15;
        row0[4] = -30; row0[5] = -25; row0[6] = 40;  row0[7] = 35;
        
        row1[0] = -15; row1[1] = -8;  row1[2] = 18;  row1[3] = 12;
        row1[4] = -28; row1[5] = -20; row1[6] = 38;  row1[7] = 30;
        
        expected_outputs.push_back(8'(-5));
        expected_outputs.push_back(8'd20);
        expected_outputs.push_back(8'(-20));
        expected_outputs.push_back(8'd40);
        
        send_row(row0);
        send_row(row1);
        
        repeat(10) @(posedge clk);
        
        // Verify signed comparison worked correctly
        for (int i = 0; i < expected_outputs.size(); i++) begin
            if (i < received_outputs.size()) begin
                if ($signed(received_outputs[i]) === $signed(expected_outputs[i])) begin
                    $display("  PASS: Output[%0d] = %0d (correct)", 
                             i, $signed(received_outputs[i]));
                end else begin
                    $display("  FAIL: Output[%0d] = %0d, expected %0d", 
                             i, $signed(received_outputs[i]), $signed(expected_outputs[i]));
                    error_count++;
                end
            end
        end
        
        test_count++;
    endtask
    
    // =========================================================================
    // Test 4: Multiple Row Pairs (Continuous Processing)
    // =========================================================================
    task automatic test_multiple_row_pairs();
        logic [7:0] rows [4][8];  // 4 rows
        int match_count;
        
        $display("\n========================================");
        $display("Test 4: Multiple Row Pairs");
        $display("========================================");
        
        do_reset();
        enable_pooling = 1;
        output_count = 0;
        expected_outputs.delete();
        received_outputs.delete();
        
        // Create 4 rows (2 pairs)
        // Pair 1: rows 0&1
        // Pair 2: rows 2&3
        
        for (int r = 0; r < 4; r++) begin
            for (int c = 0; c < TEST_WIDTH; c++) begin
                rows[r][c] = 8'(r * 20 + c * 2);
            end
        end
        
        // Expected outputs from pair 1 (rows 0&1)
        for (int i = 0; i < TEST_WIDTH/2; i++) begin
            int c = i * 2;
            logic [7:0] p00 = rows[0][c];
            logic [7:0] p01 = rows[0][c+1];
            logic [7:0] p10 = rows[1][c];
            logic [7:0] p11 = rows[1][c+1];
            logic [7:0] max_val;
            
            // Find max
            max_val = p00;
            if ($signed(p01) > $signed(max_val)) max_val = p01;
            if ($signed(p10) > $signed(max_val)) max_val = p10;
            if ($signed(p11) > $signed(max_val)) max_val = p11;
            
            expected_outputs.push_back(max_val);
        end
        
        // Expected outputs from pair 2 (rows 2&3)
        for (int i = 0; i < TEST_WIDTH/2; i++) begin
            int c = i * 2;
            logic [7:0] p00 = rows[2][c];
            logic [7:0] p01 = rows[2][c+1];
            logic [7:0] p10 = rows[3][c];
            logic [7:0] p11 = rows[3][c+1];
            logic [7:0] max_val;
            
            max_val = p00;
            if ($signed(p01) > $signed(max_val)) max_val = p01;
            if ($signed(p10) > $signed(max_val)) max_val = p10;
            if ($signed(p11) > $signed(max_val)) max_val = p11;
            
            expected_outputs.push_back(max_val);
        end
        
        // Send all 4 rows
        for (int r = 0; r < 4; r++) begin
            $display("  Sending row %0d...", r);
            send_row(rows[r]);
        end
        
        repeat(10) @(posedge clk);
        
        // Should have 8 outputs (4 from each pair)
        if (output_count != 8) begin
            $display("  FAIL: Expected 8 outputs, got %0d", output_count);
            error_count++;
        end else begin
            $display("  PASS: Correct output count (8 pooled values from 2 pairs)");
        end
        
        // Verify all outputs
        match_count = 0;
        for (int i = 0; i < expected_outputs.size(); i++) begin
            if (i < received_outputs.size()) begin
                if (received_outputs[i] === expected_outputs[i]) begin
                    match_count++;
                end else begin
                    $display("  FAIL: Output[%0d] = %0d, expected %0d", 
                             i, received_outputs[i], expected_outputs[i]);
                    error_count++;
                end
            end
        end
        
        if (match_count == expected_outputs.size()) begin
            $display("  PASS: All %0d outputs correct", match_count);
        end
        
        test_count++;
    endtask
    
    // =========================================================================
    // Test 5: Data Reduction Ratio
    // =========================================================================
    task automatic test_data_reduction();
        int input_count;
        
        $display("\n========================================");
        $display("Test 5: Data Reduction Ratio");
        $display("========================================");
        
        do_reset();
        enable_pooling = 1;
        output_count = 0;
        input_count = 0;
        
        // Send 4 complete rows (32 pixels total for 8-wide image)
        for (int r = 0; r < 4; r++) begin
            for (int c = 0; c < TEST_WIDTH; c++) begin
                @(negedge clk);
                valid_in = 1;
                data_in = 8'(r * 10 + c);
                input_count++;
                @(posedge clk);
            end
        end
        
        @(negedge clk);
        valid_in = 0;
        
        repeat(10) @(posedge clk);
        
        $display("  Input pixels: %0d", input_count);
        $display("  Output pixels: %0d", output_count);
        
        // Expected: 32 inputs -> 8 outputs (4:1 reduction)
        if (input_count == 32 && output_count == 8) begin
            $display("  PASS: 4:1 data reduction achieved (32 -> 8)");
        end else begin
            $display("  FAIL: Expected 4:1 reduction, got %0d:%0d", 
                     input_count, output_count);
            error_count++;
        end
        
        test_count++;
    endtask
    
    // =========================================================================
    // Test 6: Mode Switching
    // =========================================================================
    task automatic test_mode_switching();
        $display("\n========================================");
        $display("Test 6: Mode Switching");
        $display("========================================");
        
        do_reset();
        
        // Test switching from bypass to pooling
        enable_pooling = 0;
        @(negedge clk);
        valid_in = 1;
        data_in = 8'h55;
        @(posedge clk);
        
        if (valid_out !== 1'b1 || data_out !== 8'h55) begin
            $display("  FAIL: Bypass mode initial state");
            error_count++;
        end
        
        // Switch to pooling mode
        @(negedge clk);
        enable_pooling = 1;
        @(posedge clk);
        
        // Valid should go low in pooling mode (waiting for complete blocks)
        @(posedge clk);
        if (valid_out !== 1'b0) begin
            $display("  FAIL: Should have no valid output immediately after switch");
            error_count++;
        end else begin
            $display("  PASS: Correct mode switching behavior");
        end
        
        @(negedge clk);
        valid_in = 0;
        
        test_count++;
    endtask
    
    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        $display("\n");
        $display("================================================================================");
        $display("  Pooling Unit Testbench");
        $display("  Testing: 2x2 max pooling with line buffer and bypass mode");
        $display("  Image Width: %0d pixels", TEST_WIDTH);
        $display("================================================================================\n");
        
        error_count = 0;
        test_count = 0;
        output_count = 0;
        
        // Initialize signals
        reset = 1;
        valid_in = 0;
        data_in = 0;
        enable_pooling = 0;
        
        // Run all tests
        test_bypass_mode();
        test_basic_pooling();
        test_negative_numbers();
        test_multiple_row_pairs();
        test_data_reduction();
        test_mode_switching();
        
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
        $dumpfile("pooling_unit.fst");
        $dumpvars(0, tb_pooling_unit);
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("\nERROR: Test timeout!");
        $display("TEST FAILED");
        $finish;
    end

endmodule
