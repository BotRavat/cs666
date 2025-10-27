module MixColumns(stateIn, stateOut);
    input [127:0] stateIn;
    output [127:0] stateOut;

    // We'll process each 32-bit column independently
    genvar i;
    generate
        for(i = 0; i < 4; i = i + 1) begin: mixColumnsLoop
            wire [7:0] s0, s1, s2, s3;
            wire [7:0] s0_2, s1_2, s2_2, s3_2;  // xtime results
            wire [7:0] s0_3, s1_3, s2_3, s3_3;  // s0_2 ^ s0, etc.
            
            assign s0 = stateIn[32*i+24+:8];
            assign s1 = stateIn[32*i+16+:8];
            assign s2 = stateIn[32*i+8+:8];
            assign s3 = stateIn[32*i+:8];
            
            // Precompute all xtime values (parallel)
            function [7:0] xtime;
                input [7:0] in;
                xtime = (in[7]) ? ((in << 1) ^ 8'h1B) : (in << 1);
            endfunction
            
            assign s0_2 = xtime(s0);
            assign s1_2 = xtime(s1);
            assign s2_2 = xtime(s2);
            assign s3_2 = xtime(s3);
            
            // Precompute (2*s + s) = s_2 ^ s
            assign s0_3 = s0_2 ^ s0;
            assign s1_3 = s1_2 ^ s1;
            assign s2_3 = s2_2 ^ s2;
            assign s3_3 = s3_2 ^ s3;
            
            // Optimized equations with reduced XOR depth
            assign stateOut[32*i+24+:8] = s0_2 ^ s1_3 ^ s2 ^ s3;
            assign stateOut[32*i+16+:8] = s1_2 ^ s2_3 ^ s3 ^ s0;
            assign stateOut[32*i+8+:8]  = s2_2 ^ s3_3 ^ s0 ^ s1;
            assign stateOut[32*i+:8]    = s3_2 ^ s0_3 ^ s1 ^ s2;
        end
    endgenerate
endmodule