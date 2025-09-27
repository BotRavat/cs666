`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.08.2025 18:18:23
// Design Name: 
// Module Name: test_AES128
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_AES128();

reg [127:0] data,key;
reg clk,reset;
wire [127:0] out;
wire done;

AESEncrypt128_DUT aes(data,key,clk,reset,out,done);

initial begin
clk<=0;
forever #10 clk<=~clk;
end

initial
begin
data<=128'h00112233445566778899aabbccddeeff;
key <=128'h000102030405060708090a0b0c0d0e0f;
reset<=1;
#100 
reset<=0;
end


endmodule
