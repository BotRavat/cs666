module AESEncrypt #(parameter Nk = 4, parameter Nr = 10) (
    input [127:0] data,
    input [((Nr + 1) * 128) - 1:0] allKeys,
    input clk,
    input reset,
    input key_ready,        // <-- added
    output reg done,
    output reg [127:0] state
);

    // ----------------------------
    // Pipeline Registers
    // ----------------------------
    reg [127:0] round_stage [0:Nr-1];       
    reg [127:0] subbyte_stage [0:Nr-2];     
    reg [127:0] shift_mix_stage [0:Nr-2];   

    // Wires
    wire [127:0] subByteWire [1:Nr];
    wire [127:0] shiftRowsWire [1:Nr];
    wire [127:0] mixColumnsWire [1:Nr-1];
    wire [127:0] stateOut [0:Nr];

    // Initial Round
    AddRoundKey addkey_0 (
        data,
        allKeys[((Nr+1)*128)-1 -: 128],
        stateOut[0]
    );

    always @(posedge clk or posedge reset) begin
        if(reset)
            round_stage[0] <= 128'h0;
        else if(key_ready)
            round_stage[0] <= stateOut[0];
    end

    // Rounds 1 to Nr-1
    genvar i;
    generate
        for(i = 1; i <= Nr-1; i=i+1) begin: rounds
            SubBytes sub (round_stage[i-1], subByteWire[i]);
            always @(posedge clk or posedge reset) begin
                if(reset) subbyte_stage[i-1] <= 128'h0;
                else if(key_ready) subbyte_stage[i-1] <= subByteWire[i];
            end

            ShiftRows shft (subbyte_stage[i-1], shiftRowsWire[i]);
            MixColumns mix (shiftRowsWire[i], mixColumnsWire[i]);
            always @(posedge clk or posedge reset) begin
                if(reset) shift_mix_stage[i-1] <= 128'h0;
                else if(key_ready) shift_mix_stage[i-1] <= mixColumnsWire[i];
            end

            AddRoundKey addkey (shift_mix_stage[i-1], allKeys[((Nr-i+1)*128)-1 -: 128], stateOut[i]);
            always @(posedge clk or posedge reset) begin
                if(reset) round_stage[i] <= 128'h0;
                else if(key_ready) round_stage[i] <= stateOut[i];
            end
        end
    endgenerate

    // Final Round
    SubBytes sub_final (round_stage[Nr-1], subByteWire[Nr]);
    ShiftRows shft_final (subByteWire[Nr], shiftRowsWire[Nr]);
    AddRoundKey addkey_final (shiftRowsWire[Nr], allKeys[0 +: 128], stateOut[Nr]);

    // Control Logic
    reg [5:0] cycle_count;
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            cycle_count <= 0;
            done <= 0;
        end else if(key_ready) begin
            cycle_count <= cycle_count + 1;
            if(cycle_count >= (Nr-1)*3 + 2)
                done <= 1;
        end
    end

    // Final Output
    always @(posedge clk or posedge reset) begin
        if(reset) state <= 128'h0;
        else if(key_ready) state <= stateOut[Nr];
    end

endmodule



module AESEncrypt128_DUT(
    input [127:0] data,
    input [127:0] key,
    input clk, reset,
    output [127:0] out,
    output done,
    output key_ready 
);
    parameter Nk = 4;
    parameter Nr = 10;

    wire [((Nr + 1) * 128) - 1:0] allKeys;

    KeyExpansion #(.Nk(Nk), .Nr(Nr)) ke(
        .clk(clk),
        .reset(reset),
        .keyIn(key),
        .keysOut(allKeys),
        .key_ready(key_ready)     // <-- added
    );

    AESEncrypt #(.Nk(Nk), .Nr(Nr)) aes_enc(
        .data(data),
        .allKeys(allKeys),
        .clk(clk),
        .reset(reset),
        .key_ready(key_ready),    // <-- added
        .done(done),
        .state(out)
    );
endmodule
