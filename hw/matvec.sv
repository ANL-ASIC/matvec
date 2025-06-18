
module matvec #(
    parameter IWIDTH = 12,
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23,
    parameter N /* verilator public */ = 16,
    parameter M /* verilator public */ = 8) (
    input clk,
    input do_acc,
    input dv,
    input [N - 1 : 0][IWIDTH - 1 : 0] in,
    input [M - 1 : 0][N - 1 : 0][EWIDTH + SIGWIDTH : 0] weights,
    output [M - 1 : 0][EWIDTH + SIGWIDTH : 0] out
);

genvar i, j;

localparam WWIDTH = EWIDTH + SIGWIDTH + 1;

logic [M - 1 : 0][N - 1 : 0][WWIDTH - 1 : 0] mult_intermediates;

generate

// multipliers
for (i = 0; i < M; i = i + 1) begin : mult_rows
    for (j = 0; j < N; j = j + 1) begin : mult_cols
        int_fp_mult #(IWIDTH, EWIDTH, SIGWIDTH) mult(in[j], weights[i][j], mult_intermediates[i][j]);
    end
end

// accumulators
for (i = 0; i < M; i = i + 1) begin : accumulators
    accumulator #(N, EWIDTH, SIGWIDTH) acc(.clk(clk), .do_acc(do_acc), .dv(dv), .in(mult_intermediates[i]), .out(out[i]));
end
endgenerate

endmodule
