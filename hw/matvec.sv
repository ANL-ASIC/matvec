module matvec #(
    parameter IWIDTH = 12,
    parameter WWIDTH = 32,
    parameter N /* verilator public */ = 16,
    parameter M /* verilator public */ = 8) (
    input clk,
    input acc_rst,
    input [IWIDTH - 1 : 0] in[N - 1 : 0],
    input [WWIDTH - 1 : 0] weights[N - 1 : 0][M - 1 : 0],
    output [WWIDTH - 1 : 0] out[M - 1 : 0]
);

genvar i, j;

localparam INTWIDTH = WWIDTH;

wire [M - 1 : 0][N - 1 : 0][INTWIDTH - 1 : 0] mult_intermediates;

generate

// multipliers
for (i = 0; i < N; i = i + 1) begin : mult_rows
    for (j = 0; j < M; j = j + 1) begin : mult_cols
        weight_mult wm(in[i], weights[i][j], mult_intermediates[j][i]);
    end
end

// accumulators
for (i = 0; i < M; i = i + 1) begin : accumulators
    accumulator #(N, INTWIDTH) acc(clk, acc_rst, mult_intermediates[i], out[i]);
end
endgenerate

endmodule
