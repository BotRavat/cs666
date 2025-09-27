module SubBytes(oriBytes, subBytes);
	input [127:0] oriBytes; // Original input bytes
	output wire [127:0] subBytes; // Corresponding sub_bytes 

	genvar i;
	generate 
		for (i=7;i<128;i=i+8) begin: SubTableLoop
			SubTable s(oriBytes[i -:8],subBytes[i -:8]);
		end
	endgenerate
endmodule

