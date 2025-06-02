module weight_mult #(
    parameter IWIDTH = 12,
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23) (
    input wire [IWIDTH - 1:0] a,
    input wire [EWIDTH + SIGWIDTH:0] b,
    output wire [EWIDTH + SIGWIDTH:0] c
);

// localparam OWIDTH = IWIDTH + WWIDTH;
// localparam OWIDTH = WWIDTH;

// assign c = a * b;
int_fp_mult #(.IWIDTH(IWIDTH), .EWIDTH(EWIDTH), .SIGWIDTH(SIGWIDTH)) mult(a, b, c);

endmodule
