module KeyExpansionRound #(parameter Nk = 4, parameter Nr = 10) (roundCount, keyIn, keyOut);
    input [3:0] roundCount;
    input [32 * Nk - 1:0] keyIn;
    output [32 * Nk - 1:0] keyOut;

    // =======================================================
    // OPTIMIZATION 1: Simplified Word Extraction
    // =======================================================
    // Direct word assignment without generate block
    wire [31:0] word0 = keyIn[127:96];
    wire [31:0] word1 = keyIn[95:64]; 
    wire [31:0] word2 = keyIn[63:32];
    wire [31:0] word3 = keyIn[31:0];

    // =======================================================
    // OPTIMIZATION 2: Efficient RotWord + SubWord
    // =======================================================
    wire [31:0] rot_word = {word3[23:0], word3[31:24]};
    
    // Single S-box instantiation with direct mapping
    wire [31:0] sub_word;
    SubTable sbox0(rot_word[31:24], sub_word[31:24]);
    SubTable sbox1(rot_word[23:16], sub_word[23:16]);
    SubTable sbox2(rot_word[15:8],  sub_word[15:8]);
    SubTable sbox3(rot_word[7:0],   sub_word[7:0]);

    // =======================================================
    // OPTIMIZATION 3: Optimized Round Constant
    // =======================================================
    // Use lookup table instead of function (more hardware friendly)
    wire [7:0] rcon;
    assign rcon = (roundCount == 4'd1) ? 8'h01 :
                  (roundCount == 4'd2) ? 8'h02 :
                  (roundCount == 4'd3) ? 8'h04 :
                  (roundCount == 4'd4) ? 8'h08 :
                  (roundCount == 4'd5) ? 8'h10 :
                  (roundCount == 4'd6) ? 8'h20 :
                  (roundCount == 4'd7) ? 8'h40 :
                  (roundCount == 4'd8) ? 8'h80 :
                  (roundCount == 4'd9) ? 8'h1b :
                  (roundCount == 4'd10) ? 8'h36 : 8'h00;
    
    wire [31:0] round_constant = {rcon, 24'h0};

    // =======================================================
    // OPTIMIZATION 4: Simplified Key Expansion Logic
    // =======================================================
    // First word calculation
    wire [31:0] new_word0 = word0 ^ sub_word ^ round_constant;
    
    // Remaining words (simplified for AES-128)
    wire [31:0] new_word1 = word1 ^ new_word0;
    wire [31:0] new_word2 = word2 ^ new_word1; 
    wire [31:0] new_word3 = word3 ^ new_word2;

    // Output assignment
    assign keyOut = {new_word0, new_word1, new_word2, new_word3};

endmodule


module KeyExpansion #(parameter Nk = 4, parameter Nr = 10) (
    input clk, reset,
    input [127:0] keyIn,
    output reg [(Nr+1)*128-1:0] keysOut
);
    localparam TOTAL_KEYS = Nr + 1;

    reg [127:0] expanded_keys [0:TOTAL_KEYS-1];
    wire [127:0] next_key [0:TOTAL_KEYS-2];

    genvar i;
    generate
        for (i = 0; i < TOTAL_KEYS-1; i = i + 1) begin: RoundGen
            KeyExpansionRound #(Nk, Nr) round(
                .roundCount(i[3:0] + 4'd1),
                .keyIn(expanded_keys[i]),
                .keyOut(next_key[i])
            );
        end
    endgenerate

    integer j;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            expanded_keys[0] <= keyIn;
            for (j = 1; j < TOTAL_KEYS; j = j + 1)
                expanded_keys[j] <= 0;
        end else begin
            expanded_keys[0] <= keyIn;
            for (j = 0; j < TOTAL_KEYS-1; j = j + 1)
                expanded_keys[j+1] <= next_key[j];
        end
    end

    // Flatten array to single output bus
    always @(*) begin
        for (j = 0; j < TOTAL_KEYS; j = j + 1)
            keysOut[((TOTAL_KEYS - j) * 128) - 1 -: 128] = expanded_keys[j];
    end
endmodule

