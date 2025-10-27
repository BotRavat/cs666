module AESEncrypt (data, allKeys, state, clk, reset, done);
    
    parameter Nk = 4; 
    parameter Nr = 10;
    
    input [127:0] data;
    input [((Nr + 1) * 128) - 1:0] allKeys;
    input clk;
    input reset;
    output reg done;
    output reg [127:0] state;

    // =======================================================
    // NEW: Enhanced Pipeline Registers for 2-Stage Inner Pipeline
    // =======================================================
    
    // Outer pipeline registers (after complete rounds)
    reg [127:0] round_stage [0:Nr-1]; 
    
    // NEW: Inner pipeline registers (after SubBytes+ShiftRows for rounds 1-9)
    reg [127:0] sub_shift_stage [0:Nr-2]; // 9 registers

    // Wires for each of the 10 rounds
    wire [127:0] subByteWire [1:Nr];
    wire [127:0] shiftRowsWire [1:Nr];
    wire [127:0] mixColumnsWire [1:Nr-1];
    wire [127:0] stateOut [0:Nr];

    // =======================================================
    // 0. Initial Round (AddRoundKey only - Stage 0)
    // =======================================================
    AddRoundKey addkey_0 (
        data,
        allKeys[((Nr + 1) * 128) - 128 +: 128],
        stateOut[0]
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            round_stage[0] <= 128'h0;
        end else begin
            round_stage[0] <= stateOut[0];
        end
    end

    // =======================================================
    // 1. Modified Pipeline Stages (Round 1 to Round 9) with 2-Stage Inner Pipeline
    // =======================================================
    generate
        genvar i;
        for (i = 1; i <= Nr - 1; i = i + 1) begin : round_i
            
            // --- STAGE 1: SubBytes + ShiftRows ---
            // Input comes from the previous outer register stage: round_stage[i-1]
            
            SubBytes sub (
                round_stage[i-1],
                subByteWire[i]
            );
            
            ShiftRows shft (
                subByteWire[i],
                shiftRowsWire[i]
            );
            
            // NEW: First inner pipeline register (after SubBytes+ShiftRows)
            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    sub_shift_stage[i-1] <= 128'h0;
                end else begin
                    sub_shift_stage[i-1] <= shiftRowsWire[i];
                end
            end
            
            // --- STAGE 2: MixColumns + AddRoundKey ---
            // Input comes from the inner pipeline register: sub_shift_stage[i-1]
            
            MixColumns mix (
                sub_shift_stage[i-1],
                mixColumnsWire[i]
            );
            
            AddRoundKey addkey (
                mixColumnsWire[i],
                allKeys[((Nr-i) * 128) +: 128],
                stateOut[i]
            );

            // Outer pipeline register (after complete round)
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
    // Note: Final round doesn't need inner pipelining since it skips MixColumns
    
    SubBytes sub_final (
        round_stage[Nr-1],
        subByteWire[Nr]
    );
    
    ShiftRows shft_final (
        subByteWire[Nr],
        shiftRowsWire[Nr]
    );

    AddRoundKey addkey_final (
        shiftRowsWire[Nr],
        allKeys[0 +: 128],
        stateOut[Nr]
    );

    // =======================================================
    // 3. Enhanced Control Logic for Extended Pipeline
    // =======================================================
    // NEW: Extended counter to handle 20 pipeline stages (was 11)
    reg [4:0] round_counter;  // Expanded from 4 to 5 bits
    reg done_internal;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            round_counter <= 0;
            done_internal <= 0;
            done <= 0;
        end else begin
            // NEW: Count up to 20 cycles total pipeline depth
            if (round_counter < (Nr * 2)) begin  // 10 rounds * 2 stages = 20
                round_counter <= round_counter + 1;
            end
            
            // NEW: Set done when counter reaches 19 (end of cycle 19)
            if (round_counter == (Nr * 2 - 1)) begin  // 20 - 1 = 19
                done_internal <= 1;
            end
            
            done <= done_internal;
        end
    end

    // =======================================================
    // 4. Final Output Register Assignment
    // =======================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= 128'h0;
        end else begin
            state <= stateOut[Nr];
        end
    end

endmodule

// DUT module remains unchanged
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