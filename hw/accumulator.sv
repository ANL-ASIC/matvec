module accumulator#(
    parameter N = 16,
    parameter IWIDTH = 32
    ) (
    input clk,
    input acc_rst,
    input [IWIDTH * N - 1 : 0] _in,
    output [IWIDTH - 1 : 0] out
);

localparam OWIDTH = IWIDTH;
localparam ACCLEVELS = $clog2(N);

wire [OWIDTH - 1 : 0] intermediates[ACCLEVELS : 0][N - 1 : 0] /* verilator split_var */;

reg [OWIDTH - 1 : 0] acc_reg;
wire [OWIDTH - 1 : 0] acc_in;
wire [OWIDTH - 1 : 0] acc_out;
wire [IWIDTH - 1 : 0] in[N - 1 : 0];

genvar i, l;

assign acc_out = acc_reg;

generate
for (i = 0; i < N; i = i + 1) begin : mult_rows
    assign in[i] = _in[IWIDTH * (i + 1) - 1:IWIDTH * i];
    assign intermediates[ACCLEVELS][i] = {{(OWIDTH - IWIDTH){in[i][IWIDTH - 1]}}, in[i]};
end
endgenerate

generate
    for (l = ACCLEVELS - 1; l >= 0; l = l - 1) begin : acc_lvls
        for (i = 0; i < 2**l; i = i + 1) begin : acc_rows
            // localparam AWIDTH = IWIDTH + ACCLEVELS - l - 1;
            // add_widen #(AWIDTH) wa(intermediates[l + 1][2 * i][AWIDTH - 1 : 0], intermediates[l + 1][2 * i + 1][AWIDTH - 1 : 0], intermediates[l][i][AWIDTH : 0]);
            FPadd #(.EWIDTH(8), .SIGWIDTH(23)) fpadd(intermediates[l + 1][2 * i][IWIDTH - 1 : 0], intermediates[l + 1][2 * i + 1][IWIDTH - 1 : 0], intermediates[l][i][IWIDTH - 1 : 0]);
        end
    end
endgenerate

generate
    always@(posedge clk) begin
        // acc_reg <= intermediates[0][0] + (acc_rst == 1'b1 ? 0 : acc_reg);
        acc_reg <= acc_in;
    end
endgenerate

FPadd #(.EWIDTH(8), .SIGWIDTH(23)) fpadd((acc_rst == 1'b1 ? 0 : acc_out), intermediates[0][0], acc_in);

assign out = acc_reg;

endmodule
