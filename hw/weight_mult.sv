module weight_mult #(
    parameter IWIDTH = 12,
    parameter WWIDTH = 32) (
    input wire [IWIDTH - 1:0] a,
    input wire [WWIDTH - 1:0] b,
    output wire [WWIDTH - 1:0] c
);

// localparam OWIDTH = IWIDTH + WWIDTH;
// localparam OWIDTH = WWIDTH;

// assign c = a * b;
int_fp_mult #(.IWIDTH(IWIDTH), .EWIDTH(8), .SIGWIDTH(23)) mult(a, b, c);

endmodule
