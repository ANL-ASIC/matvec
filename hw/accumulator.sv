module accumulator(
    input clk,
    input acc_rst,
    input [IWIDTH - 1 : 0] in[N - 1 : 0][M - 1 : 0],
    output [OWIDTH - 1 : 0] out[M - 1 : 0]
);

wire [OWIDTH - 1 : 0] intermediates[M - 1 : 0][ACCLEVELS : 0][N - 1 : 0] /* verilator split_var */;

reg [OWIDTH - 1 : 0] acc_reg[M - 1 : 0];

parameter N = 16, M = 8;
parameter IWIDTH = 16;
localparam OWIDTH = IWIDTH + $clog2(N);
localparam ACCLEVELS = $clog2(N);

genvar i, j, l;

generate
for (i = 0; i < N; i++) begin : mult_rows
    for (j = 0; j < M; j++) begin : mult_cols
        assign intermediates[j][ACCLEVELS][i] = {{(OWIDTH - IWIDTH){in[i][j][IWIDTH - 1]}}, in[i][j]};
    end
end
endgenerate

generate
for (j = 0; j < M; j++) begin : acc_cols
    for (l = ACCLEVELS - 1; l >= 0; l--) begin : acc_lvls
        for (i = 0; i < 2**l; i++) begin : acc_rows
            localparam AWIDTH = IWIDTH + ACCLEVELS - l - 1;
            add_widen #(AWIDTH) wa(intermediates[j][l + 1][2 * i][AWIDTH - 1 : 0], intermediates[j][l + 1][2 * i + 1][AWIDTH - 1 : 0], intermediates[j][l][i][AWIDTH : 0]);
        end
    end
end
endgenerate

generate
    for (i = 0; i < M; i++) begin : acc_reg_map
        always@(posedge clk) begin
            acc_reg[i] <= intermediates[i][0][0] + (acc_rst == 1'b1 ? 0 : acc_reg[i]);
        end
    end
endgenerate

assign out = acc_reg;

endmodule
