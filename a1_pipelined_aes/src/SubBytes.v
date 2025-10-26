module SubBytes(
    input  [127:0] oriBytes,   // Original input bytes
    output [127:0] subBytes    // Corresponding SubBytes output
);
    genvar i;
    generate
        for (i = 0; i < 128; i = i + 8) begin : SubTableLoop
            SubTable s (
                .oriByte(oriBytes[i +: 8]),
                .subByte(subBytes[i +: 8])
            );
        end
    endgenerate
endmodule
