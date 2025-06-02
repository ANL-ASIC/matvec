module matvec #(
    parameter IWIDTH = 12,
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23,
    parameter N /* verilator public */ = 16,
    parameter M /* verilator public */ = 8) (
    input clk,
    input acc_rst,
    input [IWIDTH - 1 : 0] in[N - 1 : 0],
    input [EWIDTH + SIGWIDTH : 0] weights[N - 1 : 0][M - 1 : 0],
    output [EWIDTH + SIGWIDTH : 0] out[M - 1 : 0]
);

genvar i, j;

localparam WWIDTH = EWIDTH + SIGWIDTH + 1;

wire [M - 1 : 0][N - 1 : 0][WWIDTH - 1 : 0] mult_intermediates;

generate

// multipliers
for (i = 0; i < N; i = i + 1) begin : mult_rows
    for (j = 0; j < M; j = j + 1) begin : mult_cols
        weight_mult #(IWIDTH, EWIDTH, SIGWIDTH) wm(in[i], weights[i][j], mult_intermediates[j][i]);
    end
end

// accumulators
for (i = 0; i < M; i = i + 1) begin : accumulators
    accumulator #(N, EWIDTH, SIGWIDTH) acc(clk, acc_rst, mult_intermediates[i], out[i]);
end
endgenerate

endmodule
