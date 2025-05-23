module add_widen(
    input wire [WIDTH - 1 : 0] a,
    input wire [WIDTH - 1 : 0] b,
    output wire [OWIDTH - 1 : 0] c
);

parameter WIDTH = 16;
localparam OWIDTH = WIDTH + 1;

assign c = a + b;
endmodule
