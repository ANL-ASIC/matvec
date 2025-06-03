
module matvec #(
    parameter IWIDTH = 12,
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23,
    parameter N /* verilator public */ = 16,
    parameter M /* verilator public */ = 8) (
    input clk,
    input acc_rst,
    input [N - 1 : 0][IWIDTH - 1 : 0] in,
    input [M - 1 : 0][N - 1 : 0][EWIDTH + SIGWIDTH : 0] weights,
    output [M - 1 : 0][EWIDTH + SIGWIDTH : 0] out
);

genvar i, j;

localparam WWIDTH = EWIDTH + SIGWIDTH + 1;

wire [M - 1 : 0][N - 1 : 0][WWIDTH - 1 : 0] mult_intermediates;

generate

// multipliers
for (i = 0; i < M; i = i + 1) begin : mult_rows
    for (j = 0; j < N; j = j + 1) begin : mult_cols
        weight_mult #(IWIDTH, EWIDTH, SIGWIDTH) wm(in[j], weights[i][j], mult_intermediates[i][j]);
    end
end

// accumulators
for (i = 0; i < M; i = i + 1) begin : accumulators
    accumulator #(N, EWIDTH, SIGWIDTH) acc(clk, acc_rst, mult_intermediates[i], out[i]);
end
endgenerate

endmodule
