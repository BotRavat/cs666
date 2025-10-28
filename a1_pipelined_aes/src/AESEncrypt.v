module AESEncrypt_Optimized (
    input clk,
    input reset,
    input [127:0] data,
    input [127:0] key,
    output reg [127:0] out,
    output reg done
);
    parameter Nk = 4;
    parameter Nr = 10;

    // =======================================================
    // Key Expansion Pipeline
    // =======================================================
    wire [((Nr+1)*128)-1:0] allKeys;
    wire key_ready;

    KeyExpansion_Pipelined #(.Nk(Nk), .Nr(Nr)) ke (
        .clk(clk),
        .reset(reset),
        .keyIn(key),
        .allKeys(allKeys),
        .key_ready(key_ready)
    );

    // =======================================================
    // AES Round Pipeline Registers
    // =======================================================
    reg [127:0] stage1 [0:Nr-1]; // after SubBytes+ShiftRows
    reg [127:0] stage2 [0:Nr-1]; // after MixColumns+AddRoundKey
    reg [4:0] round_counter;

    integer i;

    // =======================================================
    // Control Logic
    // =======================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i=0;i<Nr;i=i+1) begin
                stage1[i] <= 128'h0;
                stage2[i] <= 128'h0;
            end
            out <= 128'h0;
            round_counter <= 0;
            done <= 0;
        end else if (key_ready) begin
            // === Round 0: AddRoundKey on input data ===
            stage2[0] <= data ^ allKeys[Nr*128 +: 128];

            // === Subsequent rounds ===
            for (i=1; i<Nr; i=i+1) begin
                // Stage1: SubBytes + ShiftRows
                stage1[i] <= SubBytesShiftRows(stage2[i-1]);

                // Stage2: MixColumns + AddRoundKey
                stage2[i] <= MixColumns(stage1[i]) ^ allKeys[(Nr-i)*128 +: 128];
            end

            // === Final Round (Nr): SubBytes+ShiftRows + AddRoundKey, no MixColumns ===
            stage1[Nr] <= SubBytesShiftRows(stage2[Nr-1]);
            out <= stage1[Nr] ^ allKeys[0 +: 128];

            // Update done
            done <= 1;
        end
    end

    // =======================================================
    // Combinational functions for inner stages
    // =======================================================
    function [127:0] SubBytesShiftRows;
        input [127:0] state_in;
        integer b;
        reg [7:0] sbox_out[0:15];
        begin
            // Apply S-box
            for (b=0;b<16;b=b+1)
                sbox_out[b] = SubTable(state_in[127-8*b -:8]);

            // ShiftRows transformation
            SubBytesShiftRows = {
                sbox_out[0],  sbox_out[5],  sbox_out[10], sbox_out[15],
                sbox_out[4],  sbox_out[9],  sbox_out[14], sbox_out[3],
                sbox_out[8],  sbox_out[13], sbox_out[2],  sbox_out[7],
                sbox_out[12], sbox_out[1],  sbox_out[6],  sbox_out[11]
            };
        end
    endfunction

    function [127:0] MixColumns;
        input [127:0] state_in;
        begin
            // Call your MixColumns combinational module here
            // Placeholder: identity function
            MixColumns = state_in; 
        end
    endfunction

    function [7:0] SubTable;
        input [7:0] byte_in;
        begin
            // Replace with actual AES S-box table
            SubTable = byte_in ^ 8'h63; // placeholder
        end
    endfunction

endmodule

// =======================================================
// Pipelined Key Expansion
// Generates one round key per cycle
// =======================================================
module KeyExpansion_Pipelined #(parameter Nk=4, Nr=10)(
    input clk,
    input reset,
    input [Nk*32-1:0] keyIn,
    output reg [((Nr+1)*128)-1:0] allKeys,
    output reg key_ready
);
    reg [3:0] roundCount;
    reg [Nk*32-1:0] currentKey;

    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            roundCount <= 0;
            currentKey <= keyIn;
            allKeys <= {keyIn, {(Nr*128){1'b0}}};
            key_ready <= 0;
        end else begin
            if (roundCount < Nr) begin
                roundCount <= roundCount + 1;
                currentKey <= KeyExpansionRoundFunc(currentKey, roundCount+1);
                allKeys[((Nr+1)*128-1) - (roundCount*128) -:128] <= currentKey;
            end else begin
                key_ready <= 1;
            end
        end
    end

    // Functional round key generation
    function [Nk*32-1:0] KeyExpansionRoundFunc;
        input [Nk*32-1:0] key_in;
        input [3:0] rcnt;
        integer j,k;
        reg [31:0] words [0:Nk-1];
        reg [31:0] w3Rot,w3Sub,wSub,roundConst32;
        begin
            for (j=0;j<Nk;j=j+1) words[j] = key_in[(Nk*32-1)-j*32 -:32];
            w3Rot = {words[Nk-1][23:0], words[Nk-1][31:24]};
            for (j=0;j<4;j=j+1) w3Sub[8*j +:8] = SubTable(w3Rot[8*j +:8]);
            roundConst32 = {RoundConst(rcnt),24'h0};
            KeyExpansionRoundFunc[(Nk*32-1) -:32] = words[0] ^ w3Sub ^ roundConst32;
            for (j=1;j<Nk;j=j+1) begin
                if (Nk==8 && j==4) begin
                    for (k=0;k<4;k=k+1) wSub[8*(3-k)+:8] = SubTable(KeyExpansionRoundFunc[(Nk*32-1)-3*32-8*k -:8]);
                    KeyExpansionRoundFunc[(Nk*32-1)-j*32 -:32] = words[j] ^ wSub;
                end else begin
                    KeyExpansionRoundFunc[(Nk*32-1)-j*32 -:32] = words[j] ^ KeyExpansionRoundFunc[(Nk*32-1)-(j-1)*32 -:32];
                end
            end
        end
    endfunction

    function [7:0] RoundConst;
        input [3:0] rcnt;
        begin
            case(rcnt)
                1: RoundConst = 8'h01;
                2: RoundConst = 8'h02;
                3: RoundConst = 8'h04;
                4: RoundConst = 8'h08;
                5: RoundConst = 8'h10;
                6: RoundConst = 8'h20;
                7: RoundConst = 8'h40;
                8: RoundConst = 8'h80;
                9: RoundConst = 8'h1b;
                10: RoundConst = 8'h36;
                default: RoundConst = 8'h00;
            endcase
        end
    endfunction

    function [7:0] SubTable;
        input [7:0] b;
        begin
            SubTable = b ^ 8'h63; // placeholder
        end
    endfunction

endmodule
