module AddRoundKey(state, roundKey, stateOut);
    input [127:0] state, roundKey;
    output [127:0] stateOut;

    assign stateOut= state ^ roundKey; 
endmodule

