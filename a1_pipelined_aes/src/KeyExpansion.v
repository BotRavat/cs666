module KeyExpansion #(parameter Nk = 4, parameter Nr = 10) (
    input clk,
    input reset,
    input [127:0] keyIn,
    output reg [(Nr+1)*128-1:0] keysOut,
    output reg key_ready
);
    localparam TOTAL_KEYS = Nr + 1;

    // storage
    reg [127:0] round_keys [0:TOTAL_KEYS-1];
    reg [3:0] round_idx;
    reg [1:0] phase;

    // Pipeline registers - carefully track round index through stages
    reg [31:0] w0_s0, w1_s0, w2_s0, w3_s0;
    reg [31:0] rot_word_s0;
    reg [3:0] round_idx_s0;
    
    reg [31:0] w0_s1, w1_s1, w2_s1, w3_s1;
    reg [31:0] rot_word_s1;
    reg [3:0] round_idx_s1;
    
    reg [31:0] w0_s2, w1_s2, w2_s2, w3_s2;
    reg [31:0] sb_s2;
    reg [31:0] rcon_s2;
    reg [3:0] round_idx_s2;

    // combinational wires
    wire [31:0] w0_c = round_keys[round_idx][127:96];
    wire [31:0] w1_c = round_keys[round_idx][95:64];
    wire [31:0] w2_c = round_keys[round_idx][63:32];
    wire [31:0] w3_c = round_keys[round_idx][31:0];
    wire [31:0] rot_word_c = {w3_c[23:0], w3_c[31:24]};

    // S-box
    wire [7:0] sb0, sb1, sb2, sb3;
    SubTable s0(rot_word_s1[31:24], sb0);
    SubTable s1(rot_word_s1[23:16], sb1);
    SubTable s2(rot_word_s1[15:8],  sb2);
    SubTable s3(rot_word_s1[7:0],   sb3);
    wire [31:0] sub_word_c = {sb0, sb1, sb2, sb3};

    // rcon function
    function [7:0] get_rcon(input [3:0] rc);
        case(rc)
            4'd1:  get_rcon = 8'h01; 4'd2:  get_rcon = 8'h02; 4'd3:  get_rcon = 8'h04;
            4'd4:  get_rcon = 8'h08; 4'd5:  get_rcon = 8'h10; 4'd6:  get_rcon = 8'h20;
            4'd7:  get_rcon = 8'h40; 4'd8:  get_rcon = 8'h80; 4'd9:  get_rcon = 8'h1b;
            4'd10: get_rcon = 8'h36; default: get_rcon = 8'h00;
        endcase
    endfunction

    // Final combinational logic - ONLY 2 XOR levels now
    wire [127:0] next_key_c;
    assign next_key_c[127:96] = w0_s2 ^ sb_s2 ^ rcon_s2;  // This is the only 3-input XOR
    assign next_key_c[95:64]  = w1_s2 ^ next_key_c[127:96];
    assign next_key_c[63:32]  = w2_s2 ^ next_key_c[95:64]; 
    assign next_key_c[31:0]   = w3_s2 ^ next_key_c[63:32];

    integer k;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            round_keys[0] <= keyIn;
            for (k = 1; k < TOTAL_KEYS; k = k + 1) round_keys[k] <= 128'h0;
            round_idx <= 0; 
            phase <= 0; 
            key_ready <= 0;
            
            // Reset all pipeline registers
            w0_s0 <= 0; w1_s0 <= 0; w2_s0 <= 0; w3_s0 <= 0; rot_word_s0 <= 0; round_idx_s0 <= 0;
            w0_s1 <= 0; w1_s1 <= 0; w2_s1 <= 0; w3_s1 <= 0; rot_word_s1 <= 0; round_idx_s1 <= 0;
            w0_s2 <= 0; w1_s2 <= 0; w2_s2 <= 0; w3_s2 <= 0; sb_s2 <= 0; rcon_s2 <= 0; round_idx_s2 <= 0;
        end else begin
            // Pipeline stage 3: Store result (always happens when pipeline is full)
            if (phase == 2'b11) begin
                round_keys[round_idx_s2 + 1] <= next_key_c;
                if (round_idx_s2 == Nr - 1) begin
                    key_ready <= 1;
                end
                round_idx <= round_idx + 1;  // Only increment when we store
            end

            // Pipeline progression
            case (phase)
                2'b00: begin // Stage 0: Capture input key words
                    if (round_idx < Nr) begin
                        w0_s0 <= w0_c; 
                        w1_s0 <= w1_c; 
                        w2_s0 <= w2_c; 
                        w3_s0 <= w3_c;
                        rot_word_s0 <= rot_word_c; 
                        round_idx_s0 <= round_idx;
                        phase <= 2'b01;
                    end
                end
                2'b01: begin // Stage 1: Propagate to S-box input
                    w0_s1 <= w0_s0; w1_s1 <= w1_s0; w2_s1 <= w2_s0; w3_s1 <= w3_s0;
                    rot_word_s1 <= rot_word_s0; 
                    round_idx_s1 <= round_idx_s0;
                    phase <= 2'b10;
                end
                2'b10: begin // Stage 2: S-box + Rcon computation
                    w0_s2 <= w0_s1; w1_s2 <= w1_s1; w2_s2 <= w2_s1; w3_s2 <= w3_s1;
                    sb_s2 <= sub_word_c;
                    rcon_s2 <= {get_rcon(round_idx_s1 + 1), 24'h0};
                    round_idx_s2 <= round_idx_s1;
                    phase <= 2'b11;
                end
                2'b11: begin // Stage 3: XOR computation happens combinationally, result stored above
                    phase <= (round_idx < Nr) ? 2'b00 : 2'b11; // Continue or stay done
                end
            endcase
        end
    end

    // flatten keys
    always @(*) begin
        for (k = 0; k < TOTAL_KEYS; k = k + 1)
            keysOut[((TOTAL_KEYS - k) * 128) - 1 -: 128] = round_keys[k];
    end
endmodule