`timescale 1ns / 1ps

module test_AES128();

reg [127:0] data, key;
reg clk, reset;
wire [127:0] out;
wire done;

AESEncrypt128_DUT aes(data, key, clk, reset, out, done);

initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

initial begin
    data = 128'h00112233445566778899aabbccddeeff;
    key  = 128'h000102030405060708090a0b0c0d0e0f;
    reset = 1;
    
    $display("=== AES-128 Encryption Test ===");
    $display("Input:  %h", data);
    $display("Key:    %h", key);
    
    #100 reset = 0;
    $display("Reset released at time %0t", $time);
    
    #500;
    
    $display("\n=== Results ===");
    $display("Done:     %b", done);
    $display("Output:   %h", out);
    $display("Expected: 69c4e0d86a7b0430d8cdb78070b4c55a");
    
    if (out == 128'h69c4e0d86a7b0430d8cdb78070b4c55a) begin
        $display("Status: PASSED");
    end else begin
        $display("Status: FAILED");
    end
    
    $display("\nSimulation time: %0t ns", $time);
    $finish;
end

endmodule
