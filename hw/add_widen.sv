module add_widen(
    input logic [WIDTH - 1 : 0] a,
    input logic [WIDTH - 1 : 0] b,
    output logic [OWIDTH - 1 : 0] c
);

parameter WIDTH = 16;
localparam OWIDTH = WIDTH + 1;

assign c = a + b;
endmodule
