module int_fp_mult(
    input [IWIDTH - 1:0] a,
    input [FWIDTH - 1:0] b,
    output [FWIDTH - 1:0] c
);

parameter IWIDTH = 12;
parameter EWIDTH = 8;
parameter SIG_WIDTH = 23;
localparam FWIDTH = EWIDTH + SIG_WIDTH + 1;

wire [FWIDTH - 1: 0] a_float;

int_to_float #(.IWIDTH(IWIDTH), .EWIDTH(EWIDTH), .SIG_WIDTH(SIG_WIDTH)) conv (a, a_float);
FPmul #(.EWIDTH(EWIDTH), .SIG_WIDTH(SIG_WIDTH)) mult (a_float, b, c);

endmodule
