module AESEncrypt (data, allKeys, state, clk, reset,done);
	
	
	parameter Nk = 4; parameter Nr = 10;
	
	input [127:0] data;
	input [((Nr + 1) * 128) - 1:0] allKeys;
	input clk;
	input reset;
	output done;
	output reg [127:0] state; // Holds the state of the AES encryption

	reg [5:0] roundCount ; // Holds the current round count

	wire [127:0] subByteWire;
	wire [127:0] shiftRowsWire;
	wire [127:0] mixColumnsWire;
	wire [127:0] roundKeyInput;
	wire [127:0] stateOut;

	// Instantiate AES modules needed for encryption
	SubBytes sub(state, subByteWire);
	ShiftRows shft(subByteWire, shiftRowsWire);
	MixColumns mix(shiftRowsWire, mixColumnsWire);
	AddRoundKey addkey(roundKeyInput , allKeys[((Nr + 1) * 128) - (roundCount - 1) * 128 - 1 -: 128], stateOut);

	// Assign roundKeyInput based on roundCount
	// roundCount = 1 -> Data
	// roundCount = 2 to Nr -> mixColumnsWire
	// roundCount = Nr + 1 -> shiftRowsWire
	assign roundKeyInput = (roundCount == 1) ? data : (roundCount < Nr + 1) ? mixColumnsWire : shiftRowsWire;


	// Update state based on roundCount
	always @(negedge clk or posedge reset) begin
		if (reset)
			roundCount <= 1;
		else if (roundCount <= Nr + 1) begin
			state <= stateOut;
			roundCount <= roundCount + 6'b000001;
		end
	end
assign done=(roundCount>Nr+1)?1'd1:1'd0;

endmodule

module AESEncrypt128_DUT(data,key,clk,reset,out,done);
	localparam Nk = 4;
	localparam Nr = 10;

	input [127:0] data;
	input [Nk * 32 - 1:0] key;
	input clk,reset;
	output [127:0] out;
	output done;
	
	wire [((Nr + 1) * 128) - 1:0] allKeys;
	
	

	KeyExpansion #(Nk, Nr) ke(key, allKeys);
	AESEncrypt #(Nk, Nr) aes(data, allKeys, out, clk,reset,done);

endmodule


