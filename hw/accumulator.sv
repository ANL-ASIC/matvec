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

logic [OWIDTH - 1 : 0] intermediates[ACCLEVELS : 0][2 ** ACCLEVELS - 1 : 0] /* verilator split_var */;

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

function automatic int get_num_total_inputs(int initial_inputs, int level);
    int temp = initial_inputs;
    int div;
    for (div = 0; div < level; div++) begin
        if (temp % 2 == 1)
            temp = temp + 1;
        temp = temp / 2;
    end

    return temp;
endfunction

generate
    for (l = ACCLEVELS - 1; l >= 0; l--) begin : acc_lvls
        localparam num_total_inputs = get_num_total_inputs(N, ACCLEVELS - 1 - l);
        localparam num_sum_inputs = num_total_inputs - (num_total_inputs % 1 == 0 ? 0 : 1);
        for (i = 0; i < num_sum_inputs / 2; i = i + 1) begin : acc_rows
            FPadd #(.EWIDTH(EWIDTH), .SIGWIDTH(SIGWIDTH)) fpadd(intermediates[l + 1][2 * i][IWIDTH - 1 : 0], intermediates[l + 1][2 * i + 1][IWIDTH - 1 : 0], intermediates[l][i][IWIDTH - 1 : 0]);
        end
        if (num_total_inputs % 2 == 1) begin : passthrough
            assign intermediates[l][num_total_inputs / 2][IWIDTH - 1 : 0] = intermediates[l + 1][num_total_inputs - 1][IWIDTH - 1 : 0];
        end
    end
endgenerate

always@(posedge clk) begin
    acc_reg <= acc_out;
end

FPadd #(.EWIDTH(EWIDTH), .SIGWIDTH(SIGWIDTH)) fpadd(acc_in, intermediates[0][0], acc_out);

assign out = acc_reg;

endmodule
