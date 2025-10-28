module AESEncrypt (data, allKeys, state, clk, reset, done);
    
    parameter Nk = 4; 
    parameter Nr = 10;
    
    input [127:0] data;
    input [((Nr + 1) * 128) - 1:0] allKeys;
    input clk;
    input reset;
    output reg done;
    output reg [127:0] state;

   
     // ----------------------------
    // Pipeline Registers
    // ----------------------------
    reg [127:0] round_stage [0:Nr-1];       // Outer stage after full round
    reg [127:0] subbyte_stage [0:Nr-2];     // Stage 1: After SubBytes
    reg [127:0] shift_mix_stage [0:Nr-2];   // Stage 2: After ShiftRows+MixColumns

    // Wires
    wire [127:0] subByteWire [1:Nr];
    wire [127:0] shiftRowsWire [1:Nr];
    wire [127:0] mixColumnsWire [1:Nr-1];
    wire [127:0] stateOut [0:Nr];

    // ----------------------------
    // 0. Initial Round: AddRoundKey
    // ----------------------------
    AddRoundKey addkey_0 (
        data,
        allKeys[((Nr+1)*128)-1 -: 128], // highest round key first
        stateOut[0]
    );

    always @(posedge clk or posedge reset) begin
        if(reset)
            round_stage[0] <= 128'h0;
        else
            round_stage[0] <= stateOut[0];
    end

    // ----------------------------
    // 1. Rounds 1 to Nr-1
    // ----------------------------
    genvar i;
    generate
        for(i = 1; i <= Nr-1; i=i+1) begin: rounds
            // Stage 1: SubBytes
            SubBytes sub (
                round_stage[i-1],
                subByteWire[i]
            );

            always @(posedge clk or posedge reset) begin
                if(reset)
                    subbyte_stage[i-1] <= 128'h0;
                else
                    subbyte_stage[i-1] <= subByteWire[i];
            end

            // Stage 2: ShiftRows + MixColumns
            ShiftRows shft (
                subbyte_stage[i-1],
                shiftRowsWire[i]
            );

            MixColumns mix (
                shiftRowsWire[i],
                mixColumnsWire[i]
            );

            always @(posedge clk or posedge reset) begin
                if(reset)
                    shift_mix_stage[i-1] <= 128'h0;
                else
                    shift_mix_stage[i-1] <= mixColumnsWire[i];
            end

            // Stage 3: AddRoundKey
            AddRoundKey addkey (
                shift_mix_stage[i-1],
                allKeys[((Nr-i+1)*128)-1 -: 128], // next highest round key
                stateOut[i]
            );

            always @(posedge clk or posedge reset) begin
                if(reset)
                    round_stage[i] <= 128'h0;
                else
                    round_stage[i] <= stateOut[i];
            end
        end
    endgenerate

    // ----------------------------
    // 2. Final Round: Nr (SubBytes -> ShiftRows -> AddRoundKey)
    // ----------------------------
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
        allKeys[0 +: 128], // lowest round key last
        stateOut[Nr]
    );

    // ----------------------------
    // 3. Control Logic
    // ----------------------------
    reg [5:0] cycle_count;
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            cycle_count <= 0;
            done <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if(cycle_count >= (Nr-1)*3 + 2) // pipeline full
                done <= 1;
        end
    end

    // ----------------------------
    // 4. Final Output
    // ----------------------------
    always @(posedge clk or posedge reset) begin
        if(reset)
            state <= 128'h0;
        else
            state <= stateOut[Nr];
    end



endmodule


module AESEncrypt128_DUT(data, key, clk, reset, out, done);
    parameter Nk = 4;
    parameter Nr = 10;

    input [127:0] data;
    input [Nk * 32 - 1:0] key;
    input clk, reset;
    output [127:0] out;
    output done;
    
    wire [((Nr + 1) * 128) - 1:0] allKeys;

    KeyExpansion #(.Nk(Nk), .Nr(Nr)) ke(clk, reset, key, allKeys);
    AESEncrypt #(.Nk(Nk), .Nr(Nr)) aes_enc(data, allKeys, out, clk, reset, done);

endmodule