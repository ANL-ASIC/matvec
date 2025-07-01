module matvec #(
    parameter IWIDTH = 12,
    parameter EWIDTH = 8,
    parameter WEIGHT_EWIDTH = 7,
    parameter SIGWIDTH = 23,
    parameter N /* verilator public */ = 16,
    parameter M /* verilator public */ = 8
) (
    input  logic clk,
    input  logic do_acc,
    input  logic dv,
    input  logic [N - 1 : 0][IWIDTH - 1 : 0] in,
    input  logic [M - 1 : 0][N - 1 : 0][EWIDTH + SIGWIDTH : 0] weights,
    output logic [M - 1 : 0][EWIDTH + SIGWIDTH : 0] out
);

    localparam WWIDTH = EWIDTH + SIGWIDTH + 1;

    logic [M - 1 : 0][N - 1 : 0][WWIDTH-1:0] mult_intermediates;
    logic [M - 1 : 0][N - 1 : 0][WWIDTH-1:0] mult_intermediates_reg;
    logic                                           dv_reg;
    logic                                           do_acc_reg;

    genvar i, j;

    generate
        // Multipliers
        for (i = 0; i < M; i = i + 1) begin : mult_rows
            for (j = 0; j < N; j = j + 1) begin : mult_cols
                int_fp_mult #(
                    .IWIDTH(IWIDTH),
                    .EWIDTH(WEIGHT_EWIDTH),
                    .OUTPUT_EWIDTH(EWIDTH),
                    .SIGWIDTH(SIGWIDTH)
                ) mult (
                    .a(in[j]),
                    .b(weights[i][j]),
                    .c(mult_intermediates[i][j])
                );
            end
        end
    endgenerate

    // Pipeline register between multiplier and accumulator
    always_ff @(posedge clk) begin
        mult_intermediates_reg <= mult_intermediates;
        dv_reg                  <= dv;
        do_acc_reg              <= do_acc;
    end

    generate
        // Accumulators
        for (i = 0; i < M; i = i + 1) begin : accumulators
            accumulator #(
                .N(N),
                .EWIDTH(EWIDTH),
                .SIGWIDTH(SIGWIDTH)
            ) acc (
                .clk(clk),
                .do_acc(do_acc_reg),
                .dv(dv_reg),
                .in(mult_intermediates_reg[i]),
                .out(out[i])
            );
        end
    endgenerate

endmodule
