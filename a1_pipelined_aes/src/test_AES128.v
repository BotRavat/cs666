`timescale 1ps / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.08.2025
// Design Name: AES-128 Pipelined Validation
// Module Name: test_AES128
// Description: Feeds AES-128 pipeline with new data each clock cycle.
//              Measures latency and throughput.
// 
//////////////////////////////////////////////////////////////////////////////////

module test_AES128();

    parameter CLK_PERIOD = 25;     // 50 MHz
    parameter NUM_BLOCKS = 15;     // number of parallel input blocks
    parameter MAX_LATENCY = 20;    // expected latency cycles

    reg  [127:0] data;
    reg  [127:0] key;
    reg clk, reset;
    wire [127:0] out;
    wire done;

    // DUT Instance
    AESEncrypt128_DUT aes (
        .data(data),
        .key(key),
        .clk(clk),
        .reset(reset),
        .out(out),
        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test Vectors
    reg [127:0] data_vec [0:NUM_BLOCKS-1];
    reg [127:0] out_vec  [0:NUM_BLOCKS-1];
    reg [127:0] expected_cipher [0:NUM_BLOCKS-1];
    integer i;

    initial begin
        // Common key for all
        key = 128'h000102030405060708090a0b0c0d0e0f;

        // Generate input plaintexts
        data_vec[0] = 128'h00112233445566778899aabbccddeeff;
        for (i = 1; i < NUM_BLOCKS; i = i + 1)
            data_vec[i] = data_vec[i-1] ^ (128'h01010101010101010101010101010101 * i);
            
             // Expected Ciphertexts ( plain text cipher pair avalaible in ciphers.txt file)
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

    // Tracking variables
    integer input_index = 0;
    integer output_index = 0;
    integer cycles = 0;
    time start_time, first_out_time;

    // Clocked process: count cycles
    always @(posedge clk)
        if (!reset) cycles <= cycles + 1;
        else cycles <= 0;

    // Feed new input each clock (simulate full pipeline usage)
    always @(posedge clk) begin
        if (reset) begin
            input_index <= 0;
            data <= 0;
        end else begin
            if (input_index < NUM_BLOCKS) begin
                data <= data_vec[input_index];
                input_index <= input_index + 1;
                $display("Input #%0d applied @ %0t ns : %032x",
                          input_index, $time, data_vec[input_index]);
            end else begin
                data <= 128'h0;
            end
        end
    end

    // Capture outputs when done signal toggles or new block exits pipeline
    always @(posedge clk) begin
        if (!reset && done) begin
            out_vec[output_index] = out;
            if (output_index == 0) first_out_time = $time;

            if (out === expected_cipher[output_index])
                $display("Output #%0d ready @ %0t ns : %032x  --> Correct ✅",
                          output_index, $time, out);
            else
                $display("Output #%0d ready @ %0t ns : %032x  --> Incorrect ❌ (Expected: %032x)",
                          output_index, $time, out, expected_cipher[output_index]);

            output_index = output_index + 1;
        end
    end

    // Test sequence
    initial begin
        $display("=== AES-128 PIPELINED ENCRYPTION TEST ===");
        $display("Key: %h", key);
        $display("Clock: %0d ns period\n", CLK_PERIOD);

        reset = 1;
        #100;
        reset = 0;
        start_time = $time;

        $display("Reset deasserted at %0t ns\n", start_time);

        // Wait for all outputs
        wait (output_index == NUM_BLOCKS);
        $display("\n=== AES-128 PIPELINE PERFORMANCE REPORT ===");
        $display("Total Inputs : %0d", NUM_BLOCKS);
        $display("Latency (ns) : %0t", first_out_time - start_time);
        $display("Latency (cycles): %0d", (first_out_time - start_time) / CLK_PERIOD);
        $display("Throughput   : 1 block per %0d ns (%.2f blocks/sec)",
                  CLK_PERIOD, 1.0e9 / CLK_PERIOD);
        $display("Simulation End @ %0t ns", $time);
        $finish;
    end
endmodule
