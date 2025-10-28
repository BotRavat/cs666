`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Pipelined KeyExpansionRound
// -----------------------------------------------------------------------------
module KeyExpansionRound #(parameter Nk = 4, parameter Nr = 10)(
    input  wire clk,
    input  wire reset,
    input  wire [3:0] roundCount,
    input  wire [32*Nk-1:0] keyIn,
    output reg  [32*Nk-1:0] keyOut
);
    // Pipeline registers
    reg [31:0] word0_r1, word1_r1, word2_r1, word3_r1;
    reg [31:0] rot_word_r2, sub_word_r2;
    reg [31:0] new_word0_r3;
    reg [31:0] new_word1_r4, new_word2_r4, new_word3_r4;
    
    // Round constant
    reg [31:0] round_constant_r2;

    // =======================================================
    // Stage 1: Register input words
    // =======================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            word0_r1 <= 32'h0;
            word1_r1 <= 32'h0;
            word2_r1 <= 32'h0;
            word3_r1 <= 32'h0;
        end else begin
            word0_r1 <= keyIn[127:96];
            word1_r1 <= keyIn[95:64];
            word2_r1 <= keyIn[63:32];
            word3_r1 <= keyIn[31:0];
        end
    end

    // =======================================================
    // Stage 2: RotWord + SubWord + Rcon
    // =======================================================
    wire [31:0] rot_word = {word3_r1[23:0], word3_r1[31:24]};
    wire [31:0] sub_word;
    SubTable sbox0(rot_word[31:24], sub_word[31:24]);
    SubTable sbox1(rot_word[23:16], sub_word[23:16]);
    SubTable sbox2(rot_word[15:8],  sub_word[15:8]);
    SubTable sbox3(rot_word[7:0],   sub_word[7:0]);

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
                  (roundCount == 4'd10)? 8'h36 : 8'h00;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rot_word_r2 <= 32'h0;
            sub_word_r2 <= 32'h0;
            round_constant_r2 <= 32'h0;
        end else begin
            rot_word_r2 <= rot_word;
            sub_word_r2 <= sub_word;
            round_constant_r2 <= {rcon, 24'h0};
        end
    end

    // =======================================================
    // Stage 3: Compute new_word0
    // =======================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            new_word0_r3 <= 32'h0;
        end else begin
            new_word0_r3 <= word0_r1 ^ sub_word_r2 ^ round_constant_r2;
        end
    end

    // =======================================================
    // Stage 4: Compute remaining words and output
    // =======================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            new_word1_r4 <= 32'h0;
            new_word2_r4 <= 32'h0;
            new_word3_r4 <= 32'h0;
            keyOut      <= 128'h0;
        end else begin
            new_word1_r4 <= word1_r1 ^ new_word0_r3;
            new_word2_r4 <= word2_r1 ^ new_word1_r4;
            new_word3_r4 <= word3_r1 ^ new_word2_r4;
            keyOut <= {new_word0_r3, new_word1_r4, new_word2_r4, new_word3_r4};
        end
    end
endmodule

// -----------------------------------------------------------------------------
// Top-level pipelined KeyExpansion
// -----------------------------------------------------------------------------
module KeyExpansion #(parameter Nk=4, Nr=10)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire [127:0] keyIn,
    output reg [(Nr+1)*128-1:0] keysOut,
    output reg done
);
    localparam TOTAL_KEYS = Nr + 1;
    localparam LAT = 4; // internal round latency of KeyExpansionRound

    reg [127:0] stage_keys [0:TOTAL_KEYS-1];
    reg [3:0]   stage_valid [0:TOTAL_KEYS-1];
    integer i;

    wire [127:0] next_key [0:TOTAL_KEYS-2];

    genvar k;
    generate
        for (k=0; k<TOTAL_KEYS-1; k=k+1) begin: ROUND_GEN
            KeyExpansionRound #(Nk,Nr) round_inst(
                .clk(clk),
                .reset(reset),
                .roundCount(k[3:0]+4'd1),
                .keyIn(stage_keys[k]),
                .keyOut(next_key[k])
            );
        end
    endgenerate

    // =======================================================
    // Pipeline control
    // =======================================================
    reg [5:0] cycle_cnt; // enough to count TOTAL_KEYS*LAT

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i=0;i<TOTAL_KEYS;i=i+1) stage_keys[i] <= 128'h0;
            for (i=0;i<TOTAL_KEYS;i=i+1) stage_valid[i] <= 0;
            keysOut <= {(Nr+1)*128{1'b0}};
            done <= 0;
            cycle_cnt <= 0;
        end else begin
            done <= 0;
            cycle_cnt <= cycle_cnt + 1;

            if (start) begin
                stage_keys[0] <= keyIn;
                stage_valid[0] <= LAT; // countdown for output ready
                for (i=1;i<TOTAL_KEYS;i=i+1) stage_valid[i] <= 0;
            end else begin
                for (i=0;i<TOTAL_KEYS-1;i=i+1) begin
                    if (stage_valid[i] > 0) begin
                        stage_keys[i+1] <= next_key[i];
                        stage_valid[i+1] <= LAT;
                        stage_valid[i] <= stage_valid[i]-1;
                    end
                end
            end

            // Capture final keysOut when last stage valid ready
            if (stage_valid[TOTAL_KEYS-1] == 1) begin
                for (i=0;i<TOTAL_KEYS;i=i+1) begin
                    keysOut[((TOTAL_KEYS-i)*128)-1 -: 128] <= stage_keys[i];
                end
                done <= 1;
            end
        end
    end
endmodule
