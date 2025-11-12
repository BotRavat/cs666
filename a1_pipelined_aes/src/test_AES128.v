`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AES-128 Pipelined Validation - Testbench (Cycle-based timing)
// - Uses clock-cycle counters instead of ns/$time for all latency/throughput logs
//////////////////////////////////////////////////////////////////////////////////

module test_AES128();

    parameter CLK_PERIOD = 25;     // 50 MHz (used only to generate clk)
    parameter NUM_BLOCKS = 15;

    reg  [127:0] data;
    reg  [127:0] key;
    reg clk, reset;
    wire [127:0] out;
    wire done;
    wire key_ready;

    // DUT Instance
    AESEncrypt128_DUT aes (
        .data(data),
        .key(key),
        .clk(clk),
        .reset(reset),
        .out(out),
        .done(done),
        .key_ready(key_ready)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // =========================
    // Cycle counters / markers
    // =========================
    integer cycle;             // free-running cycle counter (counts posedges after reset deassert)
    integer start_cycle;       // cycle when reset is deasserted
    integer first_out_cycle;   // cycle when the first valid 'done' occurs
    integer last_out_cycle;    // cycle of the most recent 'done'
    reg     seen_first_out;

    // free-running cycle counter
    always @(posedge clk) begin
        if (reset) begin
            cycle <= 0;
        end else begin
            cycle <= cycle + 1;
        end
    end

    // Test Vectors
    reg [127:0] data_vec [0:NUM_BLOCKS-1];
    reg [127:0] out_vec  [0:NUM_BLOCKS-1];
    reg [127:0] expected_cipher [0:NUM_BLOCKS-1];
    integer i;

    // FIFO to track inputs for matching outputs (kept from your original)
    reg [127:0] fifo [0:NUM_BLOCKS-1];
    integer fifo_head = 0;
    integer fifo_tail = 0;

    initial begin
        // Initialize arrays
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin
            data_vec[i] = 128'h0;
            expected_cipher[i] = 128'h0;
            out_vec[i] = 128'hx;
            fifo[i] = 128'h0;
        end

        // Key
        key = 128'h000102030405060708090a0b0c0d0e0f;

        // Input plaintexts
        data_vec[0] = 128'h00112233445566778899aabbccddeeff;
        for (i = 1; i < NUM_BLOCKS; i = i + 1)
            data_vec[i] = data_vec[i-1] ^ (128'h01010101010101010101010101010101 * i);

        // Expected Ciphertexts
        expected_cipher[0]  = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        expected_cipher[1]  = 128'ha9541c06f1c21125e44013531e18f406;
        expected_cipher[2]  = 128'h042735ab9246a07bdeb21dfeb6ad1192;
        expected_cipher[3]  = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        expected_cipher[4]  = 128'h9662f54d756d02c274271598b73e0da6;
        expected_cipher[5]  = 128'ha9541c06f1c21125e44013531e18f406;
        expected_cipher[6]  = 128'h4605a49219c3459631f29dcff0a6f7da;
        expected_cipher[7]  = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        expected_cipher[8]  = 128'hbcb2935cec550e9fc91d45ebcf9d3c91;
        expected_cipher[9]  = 128'ha9541c06f1c21125e44013531e18f406;
        expected_cipher[10] = 128'h6f7f9d8d39be19e94064cc1e9f0c0eb4;
        expected_cipher[11] = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
        expected_cipher[12] = 128'h73e392a54e42743b613ef53c1c6a25f7;
        expected_cipher[13] = 128'ha9541c06f1c21125e44013531e18f406;
        expected_cipher[14] = 128'ha3b364bf5b70887b3b3fd6e5e47baefd;
    end

    // Feed inputs and store in FIFO
    integer input_index = 0;
    always @(posedge clk) begin
        if (reset) begin
            input_index <= 0;
            data <= 128'h0;
            fifo_head <= 0;
        end else begin
            if (input_index < NUM_BLOCKS && key_ready) begin
                data <= data_vec[input_index];
                fifo[fifo_head] <= data_vec[input_index];
                $display("Input  #%0d applied @ cycle %0d : %032x",
                         input_index, cycle, data_vec[input_index]);
                input_index <= input_index + 1;
                fifo_head <= fifo_head + 1;
            end else begin
                data <= 128'h0; // zeros after all inputs
            end
        end
    end

    // Capture outputs and match expected cipher
    integer output_index = 0;
    always @(posedge clk) begin
        if (!reset && done) begin
            out_vec[output_index] = out;

            if (!seen_first_out) begin
                first_out_cycle <= cycle;
                seen_first_out  <= 1'b1;
            end
            last_out_cycle <= cycle;

            if (^out === 1'bx) begin
                $display("Output #%0d @ cycle %0d : DUT produced X's ❌ (Possible RTL bug)",
                         output_index, cycle);
            end else if (out === expected_cipher[output_index]) begin
                $display("Output #%0d @ cycle %0d : %032x --> Correct ✅",
                         output_index, cycle, out);
            end else begin
                $display("Output #%0d @ cycle %0d : %032x --> Incorrect ❌ (Expected: %032x)",
                         output_index, cycle, out, expected_cipher[output_index]);
            end

            output_index = output_index + 1;
            fifo_tail = fifo_tail + 1; // advance FIFO
        end
    end

    // Test sequence (cycle-only reporting)
    real cycles_per_block;
    initial begin
        $display("=== AES-128 PIPELINED ENCRYPTION TEST (Cycle-Based) ===");
        $display("Key: %h", key);
        $display("Clock period param (ignored for logs): %0d", CLK_PERIOD);

        // Synchronous reset
        reset = 1;
        seen_first_out = 1'b0;
        start_cycle = 0;
        first_out_cycle = 0;
        last_out_cycle  = 0;

        // Hold reset for a few cycles, then release
        repeat (4) @(posedge clk);
        reset = 0;
        start_cycle = cycle;  // mark the cycle immediately after deassertion
        $display("Reset deasserted at cycle %0d\n", start_cycle);

        // Wait for all outputs to be observed
        wait (output_index == NUM_BLOCKS);

        // Performance report (all in cycles)
        $display("\n=== AES-128 PIPELINE PERFORMANCE REPORT (Cycles) ===");
        $display("Total Inputs        : %0d", NUM_BLOCKS);
        $display("First Output Cycle  : %0d", first_out_cycle);
        $display("Start Cycle         : %0d", start_cycle);
        $display("Latency (cycles)    : %0d", (first_out_cycle - start_cycle));
        $display("Last Output Cycle   : %0d", last_out_cycle);

        // Average throughput in cycles/block measured from first->last outputs
        if (NUM_BLOCKS > 0) begin
            cycles_per_block = (last_out_cycle - first_out_cycle + 1.0) / NUM_BLOCKS;
            $display("Avg Throughput      : %.3f cycles/block", cycles_per_block);
        end

        $display("Simulation End @ cycle %0d", cycle);
        $finish;
    end

endmodule
