module weight_mult(
    input wire [IWIDTH - 1:0] a,
    input wire [WWIDTH - 1:0] b,
    output wire [OWIDTH - 1:0] c
);

parameter IWIDTH = 12, WWIDTH = 4;
localparam OWIDTH = IWIDTH + WWIDTH;
assign c = a * b;

endmodule
