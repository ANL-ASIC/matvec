module matvec #(
    parameter IWIDTH = 12,
    parameter WWIDTH = 32,
    parameter N /* verilator public */ = 16,
    parameter M /* verilator public */ = 8)
(
    input clk,
    input acc_rst,
    input [IWIDTH * N - 1 : 0] _in,
    input [WWIDTH * N * M - 1 : 0] _weights,
    output [WWIDTH * 8 - 1 : 0] _out
);

genvar i, j;

localparam INTWIDTH = WWIDTH;
localparam OWIDTH = WWIDTH;

wire [IWIDTH - 1 : 0] in [N - 1:0];
wire [WWIDTH - 1 : 0] weights [N - 1:0][M - 1:0];
wire [OWIDTH - 1 : 0] out [M - 1:0];

wire [INTWIDTH - 1 : 0] mult_intermediates[M - 1 : 0][N - 1 : 0];
wire [INTWIDTH * N - 1 : 0] _mult_intermediates[M - 1 : 0];

generate

// remap arrays where necessary
for (i = 0; i < N; i = i + 1) begin : in_reassign
    assign in[i] = _in[IWIDTH * (i + 1) - 1:IWIDTH * i];
end
for (i = 0; i < N; i = i + 1) begin : weights_reassign_rows
    for (j = 0; j < M; j = j + 1) begin : weights_reassign
        assign weights[i][j] = _weights[M * WWIDTH * i + WWIDTH * (j + 1) - 1:M * WWIDTH * i + WWIDTH * j];
    end
end
for (i = 0; i < M; i = i + 1) begin : out_reassign
    assign _out[OWIDTH * (i + 1) - 1:OWIDTH * i] = out[i];
end
for (i = 0; i < N; i = i + 1) begin : intermediate_reassign
    for (j = 0; j < M; j = j + 1) begin : intermediate_reassign_col
        assign _mult_intermediates[j][INTWIDTH * (i + 1) - 1:INTWIDTH * i] = mult_intermediates[j][i];
    end
end

// multipliers
for (i = 0; i < N; i = i + 1) begin : mult_rows
    for (j = 0; j < M; j = j + 1) begin : mult_cols
        weight_mult wm(in[i], weights[i][j], mult_intermediates[j][i]);
    end
end

// accumulators
for (i = 0; i < M; i = i + 1) begin : accumulators
    accumulator #(N, INTWIDTH) acc(clk, acc_rst, _mult_intermediates[i], out[i]);
end
endgenerate

endmodule
