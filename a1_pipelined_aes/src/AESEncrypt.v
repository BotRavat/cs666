module AESEncrypt (data, allKeys, state, clk, reset, done);
	
	parameter Nk = 4; 
	parameter Nr = 10;
	
	input [127:0] data;
	input [((Nr + 1) * 128) - 1:0] allKeys;
	input clk;
	input reset;
	output reg done;
	output reg [127:0] state;

	reg [5:0] roundCount;

	wire [127:0] subByteWire;
	wire [127:0] shiftRowsWire;
	wire [127:0] mixColumnsWire;
	wire [127:0] roundKeyInput;
	wire [127:0] stateOut;

	SubBytes sub(state, subByteWire);
	ShiftRows shft(subByteWire, shiftRowsWire);
	MixColumns mix(shiftRowsWire, mixColumnsWire);
	AddRoundKey addkey(roundKeyInput, allKeys[((Nr + 1) * 128) - (roundCount - 1) * 128 - 1 -: 128], stateOut);

	assign roundKeyInput = (roundCount == 1) ? data : 
	                       (roundCount < Nr + 1) ? mixColumnsWire : 
	                       shiftRowsWire;

	always @(negedge clk or posedge reset) begin
		if (reset) begin
			roundCount <= 1;
			state <= 128'h0;
			done <= 0;
		end
		else if (roundCount <= Nr + 1) begin
			state <= stateOut;
			roundCount <= roundCount + 1;
			
			if (roundCount == Nr + 1) begin
				done <= 1;
			end
		end
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

	KeyExpansion #(.Nk(Nk), .Nr(Nr)) ke(key, allKeys);
	AESEncrypt #(.Nk(Nk), .Nr(Nr)) aes_enc(data, allKeys, out, clk, reset, done);

endmodule
