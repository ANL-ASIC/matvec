module matvec_wrapper #(
    parameter IWIDTH = 12,
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23,
    parameter N /* verilator public */ = 16,
    parameter M /* verilator public */ = 8) (
    input clk,
    input do_acc,
    input dv,
    input [IWIDTH - 1 : 0] in[N - 1 : 0],
    input [WWIDTH - 1 : 0] weights[M - 1 : 0][N - 1 : 0],
    output [WWIDTH - 1 : 0] out[M - 1 : 0]
);

`ifdef VERILATOR
initial begin
    $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
    $display("[%0t] Model running...\n", $time);
end
`endif

localparam WWIDTH = EWIDTH + SIGWIDTH + 1;
localparam OWIDTH = WWIDTH;

logic [IWIDTH * N - 1 : 0] _in;
logic [WWIDTH * M * N - 1 : 0] _weights;
logic [WWIDTH * M - 1 : 0] _out;

genvar i, j;

generate
// remap arrays where necessary
for (i = 0; i < N; i = i + 1) begin : in_reassign
    assign _in[IWIDTH * (i + 1) - 1:IWIDTH * i] = in[i];
end
for (i = 0; i < M; i = i + 1) begin : weights_reassign_rows
    for (j = 0; j < N; j = j + 1) begin : weights_reassign
        assign _weights[N * WWIDTH * i + WWIDTH * (j + 1) - 1:N * WWIDTH * i + WWIDTH * j] = weights[i][j];
    end
end
for (i = 0; i < M; i = i + 1) begin : out_reassign
    assign out[i] = _out[OWIDTH * (i + 1) - 1:OWIDTH * i];
end
endgenerate

matvec#(
    .IWIDTH(IWIDTH),
    .EWIDTH(EWIDTH),
    .SIGWIDTH(SIGWIDTH),
    .N(N),
    .M(M))
mv (
    clk,
    do_acc,
    dv,
     _in,
     _weights,
     _out
);

endmodule
