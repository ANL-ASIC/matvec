module accumulator#(
    parameter N = 16,
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23) (
    input clk,
    input do_acc,
    input [N - 1 : 0][EWIDTH + SIGWIDTH : 0] in,
    output [EWIDTH + SIGWIDTH : 0] out
);

localparam IWIDTH = EWIDTH + SIGWIDTH + 1;
localparam OWIDTH = EWIDTH + SIGWIDTH + 1;
localparam ACCLEVELS = $clog2(N);

wire [OWIDTH - 1 : 0] intermediates[ACCLEVELS : 0][N - 1 : 0] /* verilator split_var */;

reg [OWIDTH - 1 : 0] acc_reg;
wire [OWIDTH - 1 : 0] acc_in;
wire [OWIDTH - 1 : 0] acc_out;

genvar i, l;

initial begin
    acc_reg = (OWIDTH)'(0);
end

assign acc_in = do_acc == 1'b1 ? acc_reg : (OWIDTH)'(0) ;

generate
for (i = 0; i < N; i = i + 1) begin : mult_rows
    assign intermediates[ACCLEVELS][i] = {{(OWIDTH - IWIDTH){in[i][IWIDTH - 1]}}, in[i]};
end
endgenerate

generate
    for (l = ACCLEVELS - 1; l >= 0; l = l - 1) begin : acc_lvls
        for (i = 0; i < 2**l; i = i + 1) begin : acc_rows
            FPadd #(.EWIDTH(EWIDTH), .SIGWIDTH(SIGWIDTH)) fpadd(intermediates[l + 1][2 * i][IWIDTH - 1 : 0], intermediates[l + 1][2 * i + 1][IWIDTH - 1 : 0], intermediates[l][i][IWIDTH - 1 : 0]);
        end
    end
endgenerate

always@(posedge clk) begin
    acc_reg <= acc_out;
end

FPadd #(.EWIDTH(EWIDTH), .SIGWIDTH(SIGWIDTH)) fpadd(acc_in, intermediates[0][0], acc_out);

assign out = acc_reg;

endmodule
