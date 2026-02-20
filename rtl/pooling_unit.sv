// =============================================================================
// Module: pooling_unit
// Description: 2x2 Max Pooling Unit for MobileNet Acceleration
//
// This module sits between the activation_unit and dma_controller to perform
// spatial downsampling through 2x2 max pooling, reducing output dimensions by 2x.
//
// Features:
// - Line buffer to store one full row of image data
// - 2x2 max pooling with stride 2
// - Bypass mode for zero-latency pass-through
// - Configurable image width (default 112 for MobileNet)
// =============================================================================

module pooling_unit #(
    parameter int IMAGE_WIDTH = 112  // Default for MobileNet feature maps
)(
    input  logic        clk,
    input  logic        reset,
    
    // Input data stream
    input  logic        valid_in,
    input  logic [7:0]  data_in,      // INT8 signed data
    
    // Control
    input  logic        enable_pooling,
    
    // Output data stream
    output logic        valid_out,
    output logic [7:0]  data_out
);

    // =========================================================================
    // Line Buffer - Stores one complete row for pooling
    // =========================================================================
    
    logic [7:0] line_buffer [0:IMAGE_WIDTH-1];
    
    // =========================================================================
    // State and Counters
    // =========================================================================
    
    typedef enum logic [1:0] {
        ROW_EVEN = 2'b00,  // Processing even row (0, 2, 4, ...)
        ROW_ODD  = 2'b01   // Processing odd row (1, 3, 5, ...)
    } row_state_t;
    
    row_state_t row_state, row_state_next;
    
    // Column counter for input
    logic [$clog2(IMAGE_WIDTH)-1:0] col_count;
    logic [$clog2(IMAGE_WIDTH)-1:0] col_count_next;
    
    // Column counter for output (pools every 2 pixels)
    logic [$clog2(IMAGE_WIDTH/2)-1:0] out_col_count;
    
    // Pixel buffer for current 2x2 block
    logic [7:0] pixel_00, pixel_01;  // Previous row (from line buffer)
    logic [7:0] pixel_10, pixel_11;  // Current row (incoming data)
    
    // =========================================================================
    // Internal pooling outputs
    // =========================================================================
    
    logic        pooling_valid;
    logic [7:0]  pooling_data;
    
    // =========================================================================
    // State Machine - Row Tracking
    // =========================================================================
    
    always_ff @(posedge clk) begin
        if (reset) begin
            row_state <= ROW_EVEN;
            col_count <= '0;
        end else if (enable_pooling && valid_in) begin
            row_state <= row_state_next;
            col_count <= col_count_next;
        end
    end
    
    always_comb begin
        row_state_next = row_state;
        col_count_next = col_count + 1'b1;
        
        // End of row reached
        if (col_count == IMAGE_WIDTH - 1) begin
            col_count_next = '0;
            // Toggle between even and odd rows
            row_state_next = (row_state == ROW_EVEN) ? ROW_ODD : ROW_EVEN;
        end
    end
    
    // =========================================================================
    // Line Buffer Management
    // =========================================================================
    
    always_ff @(posedge clk) begin
        if (reset) begin
            // Clear line buffer
            for (int i = 0; i < IMAGE_WIDTH; i++) begin
                line_buffer[i] <= 8'h00;
            end
        end else if (enable_pooling && valid_in) begin
            if (row_state == ROW_EVEN) begin
                // Store even rows in line buffer for next odd row
                line_buffer[col_count] <= data_in;
            end
            // Odd rows are processed immediately with stored even row
        end
    end
    
    // =========================================================================
    // 2x2 Max Pooling Logic
    // =========================================================================
    
    // Buffering for 2x2 block (need 2 consecutive pixels from each row)
    logic [7:0] prev_pixel;
    logic       prev_pixel_valid;
    
    always_ff @(posedge clk) begin
        if (reset) begin
            prev_pixel       <= 8'h00;
            prev_pixel_valid <= 1'b0;
            out_col_count    <= '0;
        end else if (enable_pooling && valid_in) begin
            if (row_state == ROW_ODD) begin
                // Processing odd row - perform pooling
                if (col_count[0] == 1'b0) begin
                    // Even column: store pixel for next comparison
                    prev_pixel       <= data_in;
                    prev_pixel_valid <= 1'b1;
                end else begin
                    // Odd column: we have 2x2 block, compute max
                    prev_pixel_valid <= 1'b0;
                    
                    // Increment output column
                    if (out_col_count == (IMAGE_WIDTH/2 - 1)) begin
                        out_col_count <= '0;
                    end else begin
                        out_col_count <= out_col_count + 1'b1;
                    end
                end
            end else begin
                // Even row: just storing, no output
                prev_pixel_valid <= 1'b0;
                out_col_count    <= '0;
            end
        end
    end
    
    // Max computation for 2x2 block
    logic [7:0] max_val;
    logic [7:0] max_01, max_23;
    
    always_comb begin
        // Get 4 pixels of 2x2 block
        if (col_count > 0) begin
            pixel_00 = line_buffer[col_count - 1];  // Previous row, previous col
        end else begin
            pixel_00 = 8'h80;  // Minimum signed value (border handling)
        end
        
        pixel_01 = line_buffer[col_count];      // Previous row, current col
        pixel_10 = prev_pixel;                   // Current row, previous col
        pixel_11 = data_in;                      // Current row, current col
        
        // Compare as signed values (INT8)
        // Stage 1: Compare pairs
        if ($signed(pixel_00) > $signed(pixel_01)) begin
            max_01 = pixel_00;
        end else begin
            max_01 = pixel_01;
        end
        
        if ($signed(pixel_10) > $signed(pixel_11)) begin
            max_23 = pixel_10;
        end else begin
            max_23 = pixel_11;
        end
        
        // Stage 2: Compare winners
        if ($signed(max_01) > $signed(max_23)) begin
            max_val = max_01;
        end else begin
            max_val = max_23;
        end
    end
    
    // =========================================================================
    // Output Generation (Pooling Mode)
    // =========================================================================
    
    always_ff @(posedge clk) begin
        if (reset) begin
            pooling_valid <= 1'b0;
            pooling_data  <= 8'h00;
        end else begin
            // Output valid on odd rows, odd columns (after 2x2 block complete)
            if (enable_pooling && valid_in && row_state == ROW_ODD && col_count[0] == 1'b1 && prev_pixel_valid) begin
                pooling_valid <= 1'b1;
                pooling_data  <= max_val;
            end else begin
                pooling_valid <= 1'b0;
                pooling_data  <= 8'h00;
            end
        end
    end
    
    // =========================================================================
    // Output Multiplexer - Bypass vs Pooling Mode
    // =========================================================================
    
    always_comb begin
        if (!enable_pooling) begin
            // Bypass mode: direct pass-through (zero latency)
            valid_out = valid_in;
            data_out  = data_in;
        end else begin
            // Pooling mode: use computed values
            valid_out = pooling_valid;
            data_out  = pooling_data;
        end
    end

endmodule
