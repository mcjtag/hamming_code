`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Dmitry Matyunin (https://github.com/mcjtag)
// 
// Create Date: 11.08.2023 19:17:36
// Design Name: 
// Module Name:
// Project Name: hamming_code 
// Target Devices: 
// Tool Versions: 
// Description: Binary Hamming code (n,k,r) implementation
// Dependencies: 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// License: MIT
//  Copyright (c) 2023 Dmitry Matyunin
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
// 
//////////////////////////////////////////////////////////////////////////////////

//
// Hamming(n,k,r) Encoder
//
module hamming_encoder #(
	parameter R_VALUE = 3,							// parameter 'r', num of parity bits 
	parameter B_WIDTH = 2**R_VALUE - 1,				// parameter 'n', block length
	parameter M_WIDTH = 2**R_VALUE - R_VALUE - 1	// parameter 'k', message length
)
(
	input wire [M_WIDTH-1:0]mdata,		// Message
	output wire [B_WIDTH-1:0]bdata		// Encoded block
);

hamming_encoder_core #(
	.R_VALUE(R_VALUE),
	.B_WIDTH(B_WIDTH),
	.M_WIDTH(M_WIDTH)
) hec_inst (
	.mdata(mdata),
	.bdata(bdata),
	.pbits(),
	.ext_p()
);

endmodule

//
// Hamming(n,k,r) Decoder
//
module hamming_decoder #(
	parameter R_VALUE = 3,							// parameter 'r', num of parity bits 
	parameter B_WIDTH = 2**R_VALUE - 1,				// parameter 'n', block length
	parameter M_WIDTH = 2**R_VALUE - R_VALUE - 1	// parameter 'k', message length
)
(
	input wire [B_WIDTH-1:0]bdata,		// Encoded block
	output wire [M_WIDTH-1:0]mdata		// Decoded message
);

hamming_decoder_core #(
	.R_VALUE(R_VALUE),
	.B_WIDTH(B_WIDTH),
	.M_WIDTH(M_WIDTH)
) hdc_inst (
	.bdata(bdata),
	.mdata(mdata),
	.pbits(),
	.ext_p()
);

endmodule

//
// Extended Hamming(n,k,r) 'SECDED' Encoder
//
module hamming_encoder_ext #(
	parameter R_VALUE = 3,							// parameter 'r', num of parity bits 
	parameter B_WIDTH = 2**R_VALUE - 1,				// parameter 'n', block length
	parameter M_WIDTH = 2**R_VALUE - R_VALUE - 1	// parameter 'k', message length
)
(
	input wire [M_WIDTH-1:0]mdata,		// Message
	output wire [B_WIDTH:0]bdata		// Encoded block
);

wire [B_WIDTH-1:0]bdata_tmp;
wire ext_p;

assign bdata = {ext_p, bdata_tmp};

hamming_encoder_core #(
	.R_VALUE(R_VALUE),
	.B_WIDTH(B_WIDTH),
	.M_WIDTH(M_WIDTH)
) hec_inst (
	.mdata(mdata),
	.bdata(bdata_tmp),
	.pbits(),
	.ext_p(ext_p)
);

endmodule

//
// Extended Hamming(n,k,r) 'SECDED' Decoder
//
module hamming_decoder_ext #(
	parameter R_VALUE = 3,							// parameter 'r', num of parity bits 
	parameter B_WIDTH = 2**R_VALUE - 1,				// parameter 'n', block length
	parameter M_WIDTH = 2**R_VALUE - R_VALUE - 1	// parameter 'k', message length
)
(
	input wire [B_WIDTH:0]bdata,		// Encoded block
	output wire [M_WIDTH-1:0]mdata,		// Decoded message
	output wire d_err					// Double Error flag
);

wire [R_VALUE-1:0]pbits;
wire ext_p;

assign d_err = (pbits != {R_VALUE{1'b0}}) ? (ext_p ^ bdata[B_WIDTH]) : 1'b0;

hamming_decoder_core #(
	.R_VALUE(R_VALUE),
	.B_WIDTH(B_WIDTH),
	.M_WIDTH(M_WIDTH)
) hdc_inst (
	.bdata(bdata[B_WIDTH-1:0]),
	.mdata(mdata),
	.pbits(pbits),
	.ext_p(ext_p)
);

endmodule


module hamming_encoder_core #(
	parameter R_VALUE = 3,
	parameter B_WIDTH = 2**R_VALUE - 1,
	parameter M_WIDTH = 2**R_VALUE - R_VALUE - 1
)
(
	input wire [M_WIDTH-1:0]mdata,
	output wire [B_WIDTH-1:0]bdata,
	output wire [R_VALUE-1:0]pbits,
	output wire ext_p
);

reg [R_VALUE:0]b_table[B_WIDTH-1:0];
reg [R_VALUE-1:0]pbits_reg; 
reg [B_WIDTH-1:0]bdata_reg;
reg ext_par;

integer i, j, m_i;

assign bdata = bdata_reg;
assign pbits = pbits_reg;
assign ext_p = ext_par;

always @(*) begin
	m_i = 0;
	pbits_reg = {R_VALUE{1'b0}};
	ext_par = 1'b0;
	
	for (i = 0; i < B_WIDTH; i = i + 1) begin
		b_table[i] = {{R_VALUE{1'b0}}, 1'b1};
		bdata_reg[i] = 1'b0;
	end

	for (i = 0; i < R_VALUE; i = i + 1) begin
		b_table[2**i-1] = {2**i, 1'b0};
	end

	for (i = 0; i < B_WIDTH; i = i + 1) begin
		if (b_table[i] == {{R_VALUE{1'b0}}, 1'b1}) begin
			b_table[i] = {i + 1, mdata[m_i]};
			bdata_reg[i] = mdata[m_i];
			m_i = m_i + 1;
		end
	end
	
	for (i = 0; i < R_VALUE; i = i + 1) begin
		for (j = 0; j < B_WIDTH; j = j + 1) begin
			pbits_reg[i] = pbits_reg[i] ^ (b_table[j][0] & b_table[j][i+1]);
		end
	end
	
	for (i = 0; i < R_VALUE; i = i + 1) begin
		bdata_reg[2**i-1] = pbits_reg[i];
	end
	
	for (i = 0; i < B_WIDTH; i = i + 1) begin
		ext_par = ext_par ^ bdata_reg[i];
	end
	
end

endmodule


module hamming_decoder_core #(
	parameter R_VALUE = 3,
	parameter B_WIDTH = 2**R_VALUE - 1,
	parameter M_WIDTH = 2**R_VALUE - R_VALUE - 1
)
(
	input wire [B_WIDTH-1:0]bdata,
	output wire [M_WIDTH-1:0]mdata,
	output wire [R_VALUE-1:0]pbits,
	output wire ext_p
);

reg [R_VALUE:0]b_table[B_WIDTH-1:0];
reg [B_WIDTH-1:0]mbits_msk;
reg [R_VALUE-1:0]pbits_reg; 
reg [M_WIDTH-1:0]mdata_reg;
reg ext_par;

integer i, j, m_i;

assign mdata = mdata_reg;
assign pbits = pbits_reg;
assign ext_p = ext_par;

always @(*) begin
	pbits_reg = {R_VALUE{1'b0}};
	mbits_msk = {B_WIDTH{1'b1}};
	mdata_reg = {M_WIDTH{1'b0}};
	ext_par = 1'b0;
	m_i = 0;
	
	for (i = 0; i < B_WIDTH; i = i + 1) begin
		b_table[i] = {i + 1, bdata[i]};
	end

	for (i = 0; i < R_VALUE; i = i + 1) begin
		mbits_msk[2**i-1] = 1'b0;
	end

	for (i = 0; i < R_VALUE; i = i + 1) begin
		for (j = 0; j < B_WIDTH; j = j + 1) begin
			pbits_reg[i] = pbits_reg[i] ^ (b_table[j][0] & b_table[j][i+1]);
		end
	end
	
	if (pbits_reg != {R_VALUE{1'b0}}) begin
		b_table[pbits_reg - 1][0] = b_table[pbits_reg - 1][0] ^ 1;
	end
	
	for (i = 0; i < B_WIDTH; i = i + 1) begin
		if (mbits_msk[i] == 1'b1) begin
			mdata_reg[m_i] = b_table[i][0];
			m_i = m_i + 1;
		end
	end
	
	for (i = 0; i < B_WIDTH; i = i + 1) begin
		ext_par = ext_par ^ b_table[i][0];
	end
	
end

endmodule
