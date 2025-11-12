
module KeyExpansion #(
    parameter Nk = 4,               
    parameter Nr = 10              
) (
    input  wire                   clk,
    input  wire                   reset,
    input  wire [127:0]           keyIn,
    output reg  [(Nr+1)*128-1:0]  keysOut,
    output reg                    key_ready
);
    localparam TOTAL_KEYS = Nr + 1;

    // reg [127:0] round_keys [0:TOTAL_KEYS-1];
    reg  [3:0]  round_idx;
    reg [127:0] src_key_reg;
    reg         pending_launch;

    // Stage 0 regs
    reg         s0_valid;
    reg  [3:0]  round_idx_s0;
    reg [31:0]  w0_s0, w1_s0, w2_s0, w3_s0;
    reg [31:0]  rot_word_s0;

    // Stage 1 regs
    reg         s1_valid;
    reg  [3:0]  round_idx_s1;
    reg [31:0]  w0_s1, w1_s1, w2_s1, w3_s1;
    reg [31:0]  rot_word_s1;

    // Stage 2 regs
    reg         s2_valid;
    reg  [3:0]  round_idx_s2;
    reg [31:0]  w0_s2, w1_s2, w2_s2, w3_s2;
    reg [31:0]  sb_s2;
    reg [31:0]  rcon_s2;

   
    wire [31:0] w0_src = src_key_reg[127:96];
    wire [31:0] w1_src = src_key_reg[95:64];
    wire [31:0] w2_src = src_key_reg[63:32];
    wire [31:0] w3_src = src_key_reg[31:0];
    wire [31:0] rot_word_src = {w3_src[23:0], w3_src[31:24]};

    wire [7:0] sb0, sb1, sb2, sb3;
    SubTable u_sbox0(rot_word_s1[31:24], sb0);
    SubTable u_sbox1(rot_word_s1[23:16], sb1);
    SubTable u_sbox2(rot_word_s1[15:8],  sb2);
    SubTable u_sbox3(rot_word_s1[7:0],   sb3);
    wire [31:0] sub_word_c = {sb0, sb1, sb2, sb3};

    // Rcon
    function [7:0] get_rcon(input [3:0] rc);
        case (rc)
            4'd1:  get_rcon = 8'h01; 4'd2:  get_rcon = 8'h02; 4'd3:  get_rcon = 8'h04;
            4'd4:  get_rcon = 8'h08; 4'd5:  get_rcon = 8'h10; 4'd6:  get_rcon = 8'h20;
            4'd7:  get_rcon = 8'h40; 4'd8:  get_rcon = 8'h80; 4'd9:  get_rcon = 8'h1b;
            4'd10: get_rcon = 8'h36; default: get_rcon = 8'h00;
        endcase
    endfunction

    
    wire [127:0] next_key_c;
    assign next_key_c[127:96] = w0_s2 ^ sb_s2 ^ rcon_s2;  
    assign next_key_c[95:64]  = w1_s2 ^ next_key_c[127:96];
    assign next_key_c[63:32]  = w2_s2 ^ next_key_c[95:64];
    assign next_key_c[31:0]   = w3_s2 ^ next_key_c[63:32];

    wire pipeline_idle = ~s0_valid & ~s1_valid & ~s2_valid;
    wire can_launch    = (round_idx < Nr);
    wire launch_now    = pending_launch & pipeline_idle & can_launch;

    integer k;

 
    // Sequential 
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // round_keys[0] <= keyIn;
            // for (k = 1; k < TOTAL_KEYS; k = k + 1)
            //     round_keys[k] <= 128'h0;


            src_key_reg    <= keyIn;
            round_idx      <= 4'd0;
            key_ready      <= 1'b0;
            s0_valid       <= 1'b0;
            s1_valid       <= 1'b0;
            s2_valid       <= 1'b0;
            round_idx_s0   <= 4'd0;
            round_idx_s1   <= 4'd0;
            round_idx_s2   <= 4'd0;

            w0_s0 <= 32'd0; w1_s0 <= 32'd0; w2_s0 <= 32'd0; w3_s0 <= 32'd0; rot_word_s0 <= 32'd0;
            w0_s1 <= 32'd0; w1_s1 <= 32'd0; w2_s1 <= 32'd0; w3_s1 <= 32'd0; rot_word_s1 <= 32'd0;
            w0_s2 <= 32'd0; w1_s2 <= 32'd0; w2_s2 <= 32'd0; w3_s2 <= 32'd0; sb_s2 <= 32'd0; rcon_s2 <= 32'd0;

            pending_launch <= 1'b1;
            keysOut <= {((Nr+1)*128){1'b0}};
            keysOut[((TOTAL_KEYS - 0) * 128) - 1 -: 128] <= keyIn;


        end else begin
            // Stage 2 -> Commit result
            if (s2_valid) begin
                // round_keys[round_idx_s2 + 1] <= next_key_c;
                 keysOut[((TOTAL_KEYS - (round_idx_s2 + 1)) * 128) - 1 -: 128] <= next_key_c;
                src_key_reg <= next_key_c;
                round_idx <= round_idx + 1;

                if (round_idx_s2 == 2)
                    key_ready <= 1'b1;

                if (round_idx_s2 + 1 < Nr)
                    pending_launch <= 1'b1;
                else
                    pending_launch <= 1'b0;
            end else begin
                if (launch_now)
                    pending_launch <= 1'b0;
            end
            
            s2_valid   <= s1_valid;
            if (s1_valid) begin
                w0_s2        <= w0_s1;
                w1_s2        <= w1_s1;
                w2_s2        <= w2_s1;
                w3_s2        <= w3_s1;
                sb_s2        <= sub_word_c;
                rcon_s2      <= {get_rcon(round_idx_s1 + 1), 24'h0};
                round_idx_s2 <= round_idx_s1;
            end

        
            s1_valid   <= s0_valid;
            if (s0_valid) begin
                w0_s1        <= w0_s0;
                w1_s1        <= w1_s0;
                w2_s1        <= w2_s0;
                w3_s1        <= w3_s0;
                rot_word_s1  <= rot_word_s0;
                round_idx_s1 <= round_idx_s0;
            end

         
            s0_valid <= launch_now;
            if (launch_now) begin
                w0_s0        <= w0_src;
                w1_s0        <= w1_src;
                w2_s0        <= w2_src;
                w3_s0        <= w3_src;
                rot_word_s0  <= rot_word_src;
                round_idx_s0 <= round_idx;   
            end

            // for (k = 0; k < TOTAL_KEYS; k = k + 1)
            //     keysOut[((TOTAL_KEYS - k) * 128) - 1 -: 128] <= round_keys[k];
        end
    end

endmodule
