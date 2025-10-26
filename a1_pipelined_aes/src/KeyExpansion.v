`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: 
// Design Name: AES-128 Sequential Key Expansion
// Description: Sequential version of KeyExpansion to reduce critical path delay.
//              Generates one round key per clock cycle.
//////////////////////////////////////////////////////////////////////////////////

module KeyExpansionRound (
    input  wire [3:0]  roundCount,
    input  wire [127:0] keyIn,
    output reg  [127:0] keyOut
);
    integer i;
    wire [31:0] w [0:3];
    wire [31:0] w_sub, w_rot, w_rcon;
    wire [7:0] rcon_byte;

    // Split input key into 4 words
    assign {w[0], w[1], w[2], w[3]} = keyIn;

    // Rotate last word
    assign w_rot = {w[3][23:0], w[3][31:24]};

    // SubWord using S-box
    wire [31:0] w_sub_temp;
    genvar j;
    generate
        for (j = 0; j < 4; j = j + 1) begin : SBOX_SUB
            SubTable sbox_inst (w_rot[8*j +: 8], w_sub_temp[8*j +: 8]);
        end
    endgenerate

    // Round constant selection
    assign rcon_byte = (roundCount == 1) ? 8'h01 :
                       (roundCount == 2) ? 8'h02 :
                       (roundCount == 3) ? 8'h04 :
                       (roundCount == 4) ? 8'h08 :
                       (roundCount == 5) ? 8'h10 :
                       (roundCount == 6) ? 8'h20 :
                       (roundCount == 7) ? 8'h40 :
                       (roundCount == 8) ? 8'h80 :
                       (roundCount == 9) ? 8'h1b :
                       (roundCount == 10)? 8'h36 : 8'h00;
    assign w_rcon = {rcon_byte, 24'h000000};

    // Compute next round key combinationally
    wire [31:0] t0 = w[0] ^ w_sub_temp ^ w_rcon;
    wire [31:0] t1 = w[1] ^ t0;
    wire [31:0] t2 = w[2] ^ t1;
    wire [31:0] t3 = w[3] ^ t2;

    always @(*) begin
        keyOut = {t0, t1, t2, t3};
    end
endmodule


//////////////////////////////////////////////////////////////////////////////////
// Sequential Key Expansion Controller
//////////////////////////////////////////////////////////////////////////////////
module KeyExpansion #(
    parameter Nk = 4,
    parameter Nr = 10
)(
    input  wire         clk,
    input  wire         reset,
    input  wire [127:0] keyIn,
    output reg  [127:0] roundKey,
    output reg  [3:0]   roundCount,
    output reg          valid
);

    // Internal storage for current key
    reg [127:0] currentKey;
    wire [127:0] nextKey;

    // Instantiate one round generator
    KeyExpansionRound roundGen (
        .roundCount(roundCount),
        .keyIn(currentKey),
        .keyOut(nextKey)
    );

    // Sequential control
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            currentKey <= keyIn;
            roundKey   <= keyIn;
            roundCount <= 4'd1;
            valid      <= 1'b1; // first key valid immediately
        end else begin
            currentKey <= nextKey;
            roundKey   <= nextKey;
            valid      <= 1'b1;
            roundCount <= roundCount + 1;
        end
    end

endmodule
