module KeyExpansionPipelined #(parameter Nk = 4, parameter Nr = 10) (
    input clk,
    input reset,
    input [Nk*32-1:0] keyIn,
    output reg [((Nr+1)*128)-1:0] allKeys,
    output reg key_ready
);
    // Generate round keys sequentially
    reg [3:0] roundCount;
    reg [Nk*32-1:0] currentKey;

    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            roundCount <= 0;
            currentKey <= keyIn;
            allKeys <= {keyIn, {Nr*128{1'b0}}};
            key_ready <= 0;
        end else begin
            if (roundCount < Nr) begin
                roundCount <= roundCount + 1;

                // Compute next round key
                currentKey <= KeyExpansionRoundFunc(currentKey, roundCount + 1);

                // Store in allKeys
                allKeys[((Nr+1)*128 - 1) - (roundCount*128) -: 128] <= currentKey;
            end else begin
                key_ready <= 1;  // all keys generated
            end
        end
    end

    // Function version of KeyExpansionRound (combinational)
    function [Nk*32-1:0] KeyExpansionRoundFunc;
        input [Nk*32-1:0] keyIn;
        input [3:0] roundCount;
        integer j;
        reg [31:0] words [0:Nk-1];
        reg [31:0] w3Rot, w3Sub, wSub, roundConst32;
        begin
            // Split words
            for (j=0;j<Nk;j=j+1) words[j] = keyIn[(Nk*32-1)-j*32 -:32];
            // rotWord
            w3Rot = {words[Nk-1][23:0], words[Nk-1][31:24]};
            // subWord (simple S-box substitution)
            for (j=0;j<4;j=j+1) w3Sub[8*j +:8] = SubTableFunc(w3Rot[8*j +:8]);
            // round constant
            roundConst32 = {RoundConst(roundCount),24'h0};
            // first word
            KeyExpansionRoundFunc[(Nk*32-1) -:32] = words[0] ^ w3Sub ^ roundConst32;
            // remaining words
            for (j=1;j<Nk;j=j+1) begin
                if (Nk==8 && j==4) begin
                    // subword for 256-bit key
                    for (int k=0;k<4;k=k+1) wSub[8*(3-k)+:8] = SubTableFunc(KeyExpansionRoundFunc[(Nk*32-1)-3*32-8*k -:8]);
                    KeyExpansionRoundFunc[(Nk*32-1)-j*32 -:32] = words[j] ^ wSub;
                end else begin
                    KeyExpansionRoundFunc[(Nk*32-1)-j*32 -:32] = words[j] ^ KeyExpansionRoundFunc[(Nk*32-1)-(j-1)*32 -:32];
                end
            end
        end
    endfunction

    // Simple S-box function (replace with real table)
    function [7:0] SubTableFunc;
        input [7:0] in;
        begin
            SubTableFunc = in ^ 8'h63; // placeholder
        end
    endfunction

    // Round constant function
    function [7:0] RoundConst;
        input [3:0] roundCount;
        begin
            case(roundCount)
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

endmodule
