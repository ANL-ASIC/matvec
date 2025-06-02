module int_fp_mult #(
    parameter IWIDTH = 12,
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23) (
    input [IWIDTH - 1:0] a,
    input [EWIDTH + SIGWIDTH:0] b,
    output [EWIDTH + SIGWIDTH:0] c
);

localparam FWIDTH = EWIDTH + SIGWIDTH + 1;

wire [FWIDTH - 1: 0] a_float;

int_to_float #(.IWIDTH(IWIDTH), .EWIDTH(EWIDTH), .SIGWIDTH(SIGWIDTH)) conv (a, a_float);
FPmul #(.EWIDTH(EWIDTH), .SIGWIDTH(SIGWIDTH)) mult (a_float, b, c);

endmodule
