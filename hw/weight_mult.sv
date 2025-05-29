module weight_mult(
    input wire [IWIDTH - 1:0] a,
    input wire [WWIDTH - 1:0] b,
    output wire [OWIDTH - 1:0] c
);

parameter IWIDTH = 12, WWIDTH = 32;
// localparam OWIDTH = IWIDTH + WWIDTH;
localparam OWIDTH = WWIDTH;
// assign c = a * b;
int_fp_mult #(.IWIDTH(IWIDTH), .EWIDTH(8), .SIG_WIDTH(23)) mult(a, b, c);

endmodule
