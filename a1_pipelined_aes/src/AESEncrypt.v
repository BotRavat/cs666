// ============================================================================
// AES-128 Encryption Core - 1-stage pipeline (register between rounds only)
// ============================================================================
module AESEncrypt #(
    parameter Nk = 4,
    parameter Nr = 10
)(
    input  wire [127:0] data,
    input  wire [((Nr + 1) * 128) - 1:0] allKeys,
    input  wire clk,
    input  wire reset,
    input  wire key_ready,
    output reg  done,
    output reg  [127:0] state
);

    // ------------------------------------------------------------------------
    // Pipeline registers (1 stage per AES round)
    // ------------------------------------------------------------------------
    reg [127:0] round_stage [0:Nr];

    // ------------------------------------------------------------------------
    // Round function wires
    // ------------------------------------------------------------------------
    wire [127:0] sb_out, sr_out, mc_out, add_out;
    wire [127:0] next_state [0:Nr];

    // ------------------------------------------------------------------------
    // Initial AddRoundKey
    // ------------------------------------------------------------------------
    AddRoundKey addkey_0 (
        data,
        allKeys[((Nr + 1) * 128) - 1 -: 128],
        next_state[0]
    );

    always @(posedge clk or posedge reset) begin
        if (reset)
            round_stage[0] <= 128'h0;
        else if (key_ready)
            round_stage[0] <= next_state[0];
    end

    // ------------------------------------------------------------------------
    // AES Rounds (1 register between each round)
    // ------------------------------------------------------------------------
    genvar i;
    generate
        for (i = 1; i < Nr; i = i + 1) begin : aes_rounds
            wire [127:0] sb, sr, mc, ak;

            SubBytes   sb_inst(round_stage[i-1], sb);
            ShiftRows  sr_inst(sb, sr);
            MixColumns mc_inst(sr, mc);
            AddRoundKey ak_inst(mc, allKeys[((Nr - i + 1) * 128) - 1 -: 128], ak);

            assign next_state[i] = ak;

            always @(posedge clk or posedge reset) begin
                if (reset)
                    round_stage[i] <= 128'h0;
                else if (key_ready)
                    round_stage[i] <= next_state[i];
            end
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Final Round (no MixColumns)
    // ------------------------------------------------------------------------
    wire [127:0] sb_final, sr_final, ak_final;
    SubBytes   sb_final_inst(round_stage[Nr-1], sb_final);
    ShiftRows  sr_final_inst(sb_final, sr_final);
    AddRoundKey ak_final_inst(sr_final, allKeys[0 +: 128], ak_final);

    assign next_state[Nr] = ak_final;

    // ------------------------------------------------------------------------
    // Control Logic
    // ------------------------------------------------------------------------
    reg [5:0] cycle_count;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle_count <= 0;
            done <= 0;
        end else if (key_ready) begin
            if (cycle_count < Nr + 1)
                cycle_count <= cycle_count + 1;
            else
                done <= 1;
        end
    end

    // ------------------------------------------------------------------------
    // Output register
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= 128'h0;
        else if (key_ready)
            state <= next_state[Nr];
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
