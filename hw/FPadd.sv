module FPadd(
    input [WIDTH - 1 : 0] X,
    input [WIDTH - 1 : 0] Y,
    output [WIDTH - 1 : 0] sum);

parameter EWIDTH = 8;
parameter SIG_WIDTH = 23;
localparam WIDTH = 1 + EWIDTH + SIG_WIDTH;

initial begin
    $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
    $display("[%0t] Model running...\n", $time);
end

logic X_sign;
logic Y_sign;
logic sum_sign;
logic [EWIDTH - 1:0] X_exp;
logic [EWIDTH - 1:0] Y_exp;
logic [EWIDTH - 1:0] sum_exp, norm_exp, round_exp;
logic [SIG_WIDTH + 3:0] X_sig, Y_sig;
logic [SIG_WIDTH + 3:0] X_aligned_sig, Y_aligned_sig;
logic [SIG_WIDTH + 4:0] sum_significand;

logic [EWIDTH:0] expdiff, abs_diff;
logic [SIG_WIDTH + 4:0] sum_significand_temp;
logic [SIG_WIDTH + 3:0] norm_significand;
// verilator lint_off UNUSEDSIGNAL
logic [SIG_WIDTH:0] round_significand;
// verilator lint_on UNUSEDSIGNAL

    assign sum = {sum_sign, round_exp, round_significand[SIG_WIDTH - 1:0]};

    always @ (*)
    begin
        X_sign = X[31];
        X_exp = X[WIDTH - 2:SIG_WIDTH];
        X_sig = {1'b1, X[SIG_WIDTH - 1:0], 3'd0};
        Y_sign = Y[31];
        Y_exp = Y[WIDTH - 2:SIG_WIDTH];
        Y_sig = {1'b1, Y[SIG_WIDTH - 1:0], 3'd0};

        expdiff = X_exp - Y_exp;
        abs_diff = {1'b0, (expdiff[EWIDTH] ? ~(expdiff[EWIDTH - 1:0]) + 1'b1 : expdiff[EWIDTH - 1:0])};	//Absolute difference
        X_aligned_sig = expdiff[EWIDTH] ? X_sig >> abs_diff : X_sig;	//X sig shifts if expdiff[EWIDTH]
        Y_aligned_sig = expdiff[EWIDTH] ? Y_sig : Y_sig >> abs_diff;   //Y sig shifts if !expdiff[EWIDTH]

        sum_exp = expdiff[EWIDTH] ? Y_exp : X_exp;			//Greater exp taken

        sum_sign = X_sign & Y_sign;
        if (!(X_sign ^ Y_sign)) begin
            sum_significand_temp = X_aligned_sig + Y_aligned_sig;
            sum_significand = sum_significand_temp;
        end else begin
            if (X_sign)
                sum_significand_temp = Y_aligned_sig - X_aligned_sig;
            else
                sum_significand_temp = X_aligned_sig - Y_aligned_sig;

            if (sum_significand_temp[SIG_WIDTH + 4] == 1'b1) begin
                sum_significand = ~sum_significand_temp + 1;
                sum_sign = 1'b1;
            end else begin
                sum_significand = sum_significand_temp;
            end
        end
    end

    FPnormalizeAdd #(
        .SIG_WIDTH(SIG_WIDTH),
        .EWIDTH(EWIDTH),
        .SIG_WIDTH_EXT(SIG_WIDTH + 5))
      norm(
        .SIG_in(sum_significand),
        .EXP_in(sum_exp),
        .SIG_out(norm_significand),
        .EXP_out(norm_exp));

    FPround #(
        .SIG_WIDTH(SIG_WIDTH),
        .EWIDTH(EWIDTH))
      round(
        .SIG_in(norm_significand),
        .EXP_in(norm_exp),
        .SIG_out(round_significand),
        .EXP_out(round_exp));

endmodule
