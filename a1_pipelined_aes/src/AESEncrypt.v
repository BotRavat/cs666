module AESEncrypt (data, allKeys, state, clk, reset, done);
    
    parameter Nk = 4; 
    parameter Nr = 10;
    
    input [127:0] data;
    input [((Nr + 1) * 128) - 1:0] allKeys;
    input clk;
    input reset;
    output reg done;
    output reg [127:0] state;

    // 10 registers for the intermediate states between rounds (Stage 0 to Stage 9)
    // round_stage[0] holds the output of the Initial AddRoundKey (Round 0)
    // round_stage[9] holds the output of Round 9, which feeds Round 10 (Final)
    reg [127:0] round_stage [0:Nr-1]; 

    // Wires for each of the 10 rounds, plus the initial AddRoundKey (Round 0)
    wire [127:0] subByteWire [1:Nr];
    wire [127:0] shiftRowsWire [1:Nr];
    wire [127:0] mixColumnsWire [1:Nr-1]; // MixColumns is skipped in the last round (Nr=10)
    wire [127:0] stateOut [0:Nr]; // Output of each AddRoundKey: stateOut[0] is Initial, stateOut[10] is final

    // Assuming the keys are laid out such that:
    // allKeys[((Nr+1)*128)-1 -: 128] is Key 0 (Initial AddRoundKey)
    // allKeys[127:0] is Key 10 (Final Round)

    // =======================================================
    // 0. Initial Round (AddRoundKey only - Stage 0)
    // =======================================================
    // Positional Mapping: AddRoundKey(data_in, round_key, data_out)
    AddRoundKey addkey_0 (
        data,                                          // 1. data_in
        allKeys[((Nr + 1) * 128) - 128 +: 128],        // 2. round_key (Key 0, highest index)
        stateOut[0]                                    // 3. data_out
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            round_stage[0] <= 128'h0;
        end else begin
            // Stage 0 Register
            round_stage[0] <= stateOut[0];
        end
    end

    // =======================================================
    // 1. Unrolled Pipeline Stages (Round 1 to Round 9)
    // =======================================================
    generate
        genvar i;
        for (i = 1; i <= Nr - 1; i = i + 1) begin : round_i
            // --- Combinational Logic ---
            // Input comes from the previous register stage: round_stage[i-1]
            
            // SubBytes (data_in, data_out)
            SubBytes sub (
                round_stage[i-1],   // 1. data_in
                subByteWire[i]      // 2. data_out
            );
            
            // ShiftRows (data_in, data_out)
            ShiftRows shft (
                subByteWire[i],     // 1. data_in
                shiftRowsWire[i]    // 2. data_out
            );
            
            // MixColumns (data_in, data_out)￼
t
Add file￼
Add file
More options￼
Latest commit
￼
aneels3
Update mux.v
c0fa561
 · 
7 years ago
History
History
Folders and files
Name	Last commit message	Last commit date
parent directory
..
AES_Encryption.v
Update AES_Encryption.v
7 years ago
DFF_128.v
Add files via upload
7 years ago
Key.v
Update Key.v
7 years ago
MUX2_1.v
Add files via upload
7 years ago
Mix_Column.v
Add files via upload
7 years ago
Round_reg.v
Update Round_reg.v
7 years ago
Shift_Rows.v
Update Shift_Rows.v
7 years ago
Sub_Bytes.v
Add files via upload
7 years ago
Sub_Key.v
Add files via upload
7 years ago
mux.v
Update mux.v
7 years ago

            MixColumns mix (
                shiftRowsWire[i],   // 1. data_in
                mixColumnsWire[i]   // 2. data_out
            );
            
            // AddRoundKey (data_in, round_key, data_out)
            AddRoundKey addkey (
                mixColumnsWire[i],                      // 1. data_in
                allKeys[((Nr - i) * 128) +: 128],       // 2. round_key (Key i)
                stateOut[i]                             // 3. data_out
            );

            // --- Pipeline Register ---
            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    round_stage[i] <= 128'h0;
                end else begin
                    round_stage[i] <= stateOut[i];
                end
            end
        end
    endgenerate

    // =======================================================
    // 2. Final Round (Round 10 - Skips MixColumns)
    // =======================================================
    // Input comes from the last register stage: round_stage[Nr-1] (i.e., round_stage[9])
    
    // SubBytes (data_in, data_out)
    SubBytes sub_final (
        round_stage[Nr-1],  // 1. data_in
        subByteWire[Nr]     // 2. data_out
    );
    
    // ShiftRows (data_in, data_out)
    ShiftRows shft_final (
        subByteWire[Nr],    // 1. data_in
        shiftRowsWire[Nr]   // 2. data_out
    );
    // MixColumns is SKIPPED

    // Final AddRoundKey (data_in, round_key, data_out)
    AddRoundKey addkey_final (
        shiftRowsWire[Nr],  // 1. data_in
        allKeys[0 +: 128],  // 2. round_key (Key 10, lowest index)
        stateOut[Nr]        // 3. data_out (Final result)
    );

	

    // =======================================================
    // 3. Final Output Register and Done Signal
    // =======================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= 128'h0;
            done <= 0;
        end else begin
            // Final output register (Latency is Nr + 1 cycles)
            state <= stateOut[Nr];
            // 'done' signal indicates the first block is complete and output is valid
            done <= 1; 
        end
    end

endmodule

// The DUT module remains unchanged as it only instantiates AESEncrypt
module AESEncrypt128_DUT(data, key, clk, reset, out, done);
    parameter Nk = 4;
    parameter Nr = 10;

    input [127:0] data;
    input [Nk * 32 - 1:0] key;
    input clk, reset;
    output [127:0] out;
    output done;
    
    wire [((Nr + 1) * 128) - 1:0] allKeys;

    KeyExpansion #(.Nk(Nk), .Nr(Nr)) ke(key, allKeys);
    AESEncrypt #(.Nk(Nk), .Nr(Nr)) aes_enc(data, allKeys, out, clk, reset, done);

endmodule