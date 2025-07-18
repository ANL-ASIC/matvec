module accumulator#(
    parameter N = 16,
    parameter INPUT_EWIDTH = 8,
    parameter INPUT_SIGWIDTH = 23,
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23) (
    input clk,
    input do_acc,
    input dv,
    input [N - 1 : 0][INPUT_EWIDTH + INPUT_SIGWIDTH : 0] in,
    output [EWIDTH + SIGWIDTH : 0] out
);

localparam IWIDTH = INPUT_EWIDTH + INPUT_SIGWIDTH + 1;
localparam OWIDTH = EWIDTH + SIGWIDTH + 1;
localparam ACCLEVELS = $clog2(N);

logic [IWIDTH - 1 : 0] intermediates[ACCLEVELS : 0][2 ** ACCLEVELS - 1 : 0] /* verilator split_var */;
logic [IWIDTH - 1 : 0] intermediates_reg[ACCLEVELS - 1 : 0][2 ** ACCLEVELS - 1 : 0] /* verilator split_var */;

logic [OWIDTH - 1 : 0] acc_reg;
logic [OWIDTH - 1 : 0] acc_in;
logic [OWIDTH - 1 : 0] acc_in2;
logic [OWIDTH - 1 : 0] acc_out;

logic do_acc_delayed[ACCLEVELS - 1:0];
logic dv_delayed[ACCLEVELS - 1:0];

genvar i, l;

assign acc_in = do_acc_delayed[0] == 1'b1 ? acc_reg : (OWIDTH)'(0);
assign acc_in2 = dv_delayed[0] == 1'b1 ?
    {intermediates_reg[0][0][IWIDTH - 1],
    (EWIDTH)'(intermediates_reg[0][0][IWIDTH - 2:INPUT_SIGWIDTH]),
    (SIGWIDTH)'(intermediates_reg[0][0][INPUT_SIGWIDTH - 1:0])} :
    (OWIDTH)'(0);

generate
for (i = 0; i < N; i = i + 1) begin : mult_rows
    assign intermediates[ACCLEVELS][i] = in[i];
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
            if (l == ACCLEVELS - 1) begin : first_lvl
                FPadd #(.EWIDTH(INPUT_EWIDTH), .SIGWIDTH(INPUT_SIGWIDTH)) fpadd(
                    .X(intermediates[l + 1][2 * i][IWIDTH - 1 : 0]),
                    .Y(intermediates[l + 1][2 * i + 1][IWIDTH - 1 : 0]),
                    .sum(intermediates[l][i][IWIDTH - 1 : 0]));
            end else begin : lvls
                FPadd #(.EWIDTH(INPUT_EWIDTH), .SIGWIDTH(INPUT_SIGWIDTH)) fpadd(
                    .X(intermediates_reg[l + 1][2 * i][IWIDTH - 1 : 0]),
                    .Y(intermediates_reg[l + 1][2 * i + 1][IWIDTH - 1 : 0]),
                    .sum(intermediates[l][i][IWIDTH - 1 : 0]));
            end
        end
        if (num_total_inputs % 2 == 1) begin : passthrough
            assign intermediates[l][num_total_inputs / 2][IWIDTH - 1 : 0] = intermediates[l + 1][num_total_inputs - 1][IWIDTH - 1 : 0];
        end
    end
endgenerate

always_ff@ (posedge clk) begin
    do_acc_delayed <= {do_acc, do_acc_delayed[ACCLEVELS - 1:1]};
    dv_delayed <= {dv, dv_delayed[ACCLEVELS - 1:1]};
    intermediates_reg <= intermediates[ACCLEVELS - 1:0];
    acc_reg <= acc_out;
end

FPadd #(.EWIDTH(EWIDTH), .SIGWIDTH(SIGWIDTH)) fpadd(
    .X(acc_in),
    .Y(acc_in2),
    .sum(acc_out));

assign out = acc_reg;

endmodule
