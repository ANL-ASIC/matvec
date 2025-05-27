module accumulator(
    input clk,
    input acc_rst,
    input [IWIDTH - 1 : 0] in[N - 1 : 0],
    output [OWIDTH - 1 : 0] out
);

wire [OWIDTH - 1 : 0] intermediates[ACCLEVELS : 0][N - 1 : 0] /* verilator split_var */;

reg [OWIDTH - 1 : 0] acc_reg;

parameter N = 16;
parameter IWIDTH = 16;
localparam OWIDTH = IWIDTH + $clog2(N);
localparam ACCLEVELS = $clog2(N);

genvar i, l;

generate
for (i = 0; i < N; i++) begin : mult_rows
    assign intermediates[ACCLEVELS][i] = {{(OWIDTH - IWIDTH){in[i][IWIDTH - 1]}}, in[i]};
end
endgenerate

generate
    for (l = ACCLEVELS - 1; l >= 0; l--) begin : acc_lvls
        for (i = 0; i < 2**l; i++) begin : acc_rows
            localparam AWIDTH = IWIDTH + ACCLEVELS - l - 1;
            add_widen #(AWIDTH) wa(intermediates[l + 1][2 * i][AWIDTH - 1 : 0], intermediates[l + 1][2 * i + 1][AWIDTH - 1 : 0], intermediates[l][i][AWIDTH : 0]);
        end
    end
endgenerate

generate
    always@(posedge clk) begin
        acc_reg <= intermediates[0][0] + (acc_rst == 1'b1 ? 0 : acc_reg);
    end
endgenerate

assign out = acc_reg;

endmodule
