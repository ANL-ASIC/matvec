module matvec(
    input clk,
    input acc_rst,
    input [IWIDTH - 1 : 0] in[N - 1 : 0],
    input [WWIDTH - 1 : 0] weights[N - 1 : 0][M - 1 : 0],
    output [OWIDTH - 1 : 0] out[M - 1 : 0]
);

initial begin
    $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
    $display("[%0t] Model running...\n", $time);
end


genvar i, j;

parameter IWIDTH = 12, WWIDTH = 4;
parameter N /* verilator public */ = 16, M /* verilator public */ = 8;
localparam INTWIDTH = IWIDTH + WWIDTH;
localparam OWIDTH = INTWIDTH + $clog2(N);

wire [INTWIDTH - 1 : 0] mult_intermediates[N - 1 : 0][M - 1 : 0];

generate
for (i = 0; i < N; i++) begin : mult_rows
    for (j = 0; j < M; j++) begin : mult_cols
        weight_mult wm(in[i], weights[i][j], mult_intermediates[i][j]);
    end
end
endgenerate

accumulator #(N, M, INTWIDTH) acc(clk, acc_rst, mult_intermediates, out);

endmodule
