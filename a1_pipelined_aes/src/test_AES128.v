`timescale 1ns / 1ps

module test_AES128();

// Constants
parameter NUM_BLOCKS = 3;
parameter CLK_PERIOD = 20; // 10ns high, 10ns low -> 50 MHz clock

// Testbench Signals
reg [127:0] data, key;
reg clk, reset;
wire [127:0] out;
wire done;

// Internal Registers for Sequencing and Timing
reg [127:0] test_data [0:NUM_BLOCKS-1];
reg [127:0] expected_out [0:NUM_BLOCKS-1];
reg [31:0] cycles_to_done;
integer data_index;
integer output_count;
time reset_release_time;
time previous_time; // FIXED: Declared outside initial/always blocks

// Instantiate the DUT (Design Under Test)
AESEncrypt128_DUT aes(data, key, clk, reset, out, done);

// --- Clock Generation ---
initial begin
    clk = 0;
    // Clock period is 20ns (50 MHz frequency)
    forever #10 clk = ~clk; 
end

// --- Cycle Counter (Latency Measurement) ---
always @(posedge clk) begin
    if (reset) begin
        cycles_to_done <= 0;
    end else if (done == 0) begin
        // Count cycles until the first block completes
        cycles_to_done <= cycles_to_done + 1;
    end
end

// --- Input Sequencer (Throughput Testing) ---
always @(posedge clk) begin
    if (reset) begin
        data_index <= 0;
        data <= 128'h0; // Initialize input data during reset
    end else if (data_index < NUM_BLOCKS) begin
        // Pipelined Core: Load a new block every clock cycle
        data <= test_data[data_index];
        data_index <= data_index + 1;
    end
end

// --- Output Verification and Simulation Control ---
initial begin
    // 1. Define Test Vectors and Expected Outputs
    key  = 128'h000102030405060708090a0b0c0d0e0f;
    
    // Block 0: Known Test Vector (Expected: 69c4e0d86a7b0430d8cdb78070b4c55a)
    test_data[0]    = 128'h00112233445566778899aabbccddeeff;
    expected_out[0] = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
    
    // Block 1: Placeholder for streaming test (Use actual values if known)
    test_data[1]    = 128'h102030405060708090a0b0c0d0e0f000;
    expected_out[1] = 128'h11112222333344445555666677778888;
    
    // Block 2: Placeholder for streaming test (Use actual values if known)
    test_data[2]    = 128'habcdef0123456789abcdef0123456789;
    expected_out[2] = 128'hffffffffaaaabbbbccccddddeeeeeeee;
    
    // 2. Start Simulation
    reset = 1;
    output_count = 0;
    previous_time = 0;
    
    $display("=== AES-128 Pipelined Encryption Test ===");
    $display("Test Key: %h", key);
    
    // Apply reset pulse
    #100;
    reset = 0;
    reset_release_time = $time;
    $display("Reset released at time %0t ns", reset_release_time);
    
    // 3. Wait for the First Output (Latency Measurement)
    @(posedge done); 
    
    $display("\n=============================================");
    $display("=== Pipelined Performance Report ===");
    $display("=============================================");
    
    // Latency Report (Should be 11 cycles for 10 rounds)
    $display("Input Block 0 complete!");
    $display("LATENCY (Cycles): %0d", cycles_to_done);
    $display("LATENCY (Time):   %0t ns (from reset release)", $time - reset_release_time);
    $display("---------------------------------------------");
    
    // Initialize previous_time for the throughput check
    previous_time = $time;
    
    // 4. Verification Loop
    
    // The 'done' signal stays high as long as results are streaming
    repeat (NUM_BLOCKS) begin
        
        // Wait for the next output cycle
        @(posedge clk); 
        
        $display("Output %0d @ %0t ns | Status: %s", 
                 output_count, $time,
                 (out == expected_out[output_count]) ? "PASSED" : "FAILED");
        $display("   Input:  %h", test_data[output_count]);
        $display("   Actual: %h", out);
        $display("   Expected: %h", expected_out[output_count]);

        // Throughput Check: time elapsed since the last output must be exactly one clock period
        if (output_count > 0 && ($time - previous_time) == CLK_PERIOD) begin
             $display("   Throughput Check: PASSED (1 block/cycle)");
        end else if (output_count > 0) begin
             $display("   Throughput Check: FAILED (Time difference: %0t ns)", $time - previous_time);
        end
        
        output_count = output_count + 1;
        
        // Update previous_time for the next iteration check
        previous_time = $time;
    end
    
    // 5. End Simulation
    // Wait for the last block to stream out
    # (CLK_PERIOD * 2); 
    $display("\nSimulation End Time: %0t ns", $time);
    $finish;
end

endmodule