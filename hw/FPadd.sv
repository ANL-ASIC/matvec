module FPadd #(
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23) (
    input [(EWIDTH + SIGWIDTH + 1) - 1 : 0] X,
    input [(EWIDTH + SIGWIDTH + 1) - 1 : 0] Y,
    output [(EWIDTH + SIGWIDTH + 1) - 1 : 0] sum);

localparam WIDTH = 1 + EWIDTH + SIGWIDTH;

`ifdef VERILATOR
initial begin
    $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
    $display("[%0t] Model running...\n", $time);
end
`endif

logic X_sign, Y_sign;
logic bigger_sign, smaller_sign;
logic sum_sign;
logic [EWIDTH - 1:0] X_exp, Y_exp;
logic [EWIDTH - 1:0] bigger_exp;
logic [EWIDTH - 1:0] sum_exp, norm_exp, round_exp;
logic [SIGWIDTH:0] X_sig, Y_sig;
logic [SIGWIDTH:0] smaller_sig;
logic [SIGWIDTH + 4:0] bigger_sig, smaller_aligned_sig;
logic sticky_bit;
// verilator lint_off UNUSEDSIGNAL
logic [SIGWIDTH + 4:0] sum_significand;
// verilator lint_on UNUSEDSIGNAL

logic [EWIDTH:0] expdiff, abs_diff;
logic [SIGWIDTH + 3:0] norm_significand;
// verilator lint_off UNUSEDSIGNAL
logic [SIGWIDTH:0] round_significand;
// verilator lint_on UNUSEDSIGNAL
logic is_Z;

assign is_Z = (~X_sign == Y_sign) && (X_sig == Y_sig) && (X_exp == Y_exp);
assign sum = is_Z == 1'b1 ? (EWIDTH + SIGWIDTH + 1)'(0) : {sum_sign, round_exp, round_significand[SIGWIDTH - 1:0]};

assign X_sign = X[WIDTH - 1];
assign X_exp = X[WIDTH - 2:SIGWIDTH];
assign X_sig = {(|X_exp), X[SIGWIDTH - 1:0]};
assign Y_sign = Y[WIDTH - 1];
assign Y_exp = Y[WIDTH - 2:SIGWIDTH];
assign Y_sig = {(|Y_exp), Y[SIGWIDTH - 1:0]};

assign expdiff = X_exp - Y_exp;
assign abs_diff = {1'b0, (expdiff[EWIDTH] == 1'b1 ? ~(expdiff[EWIDTH - 1:0]) + 1'b1 : expdiff[EWIDTH - 1:0])};	//Absolute difference

always_comb begin
    if (expdiff[EWIDTH] == 1'b1 || (X_exp == Y_exp && Y_sig > X_sig)) begin
        bigger_sign = Y_sign;
        bigger_exp = Y_exp;
        bigger_sig = {1'b0, Y_sig, 3'd0};
        smaller_sign = X_sign;
        smaller_sig = X_sig;
    end else begin
        bigger_sign = X_sign;
        bigger_exp = X_exp;
        bigger_sig = {1'b0, X_sig, 3'd0};
        smaller_sign = Y_sign;
        smaller_sig = Y_sig;
    end
end

assign sticky_bit = |(smaller_sig << (SIGWIDTH + 3 < abs_diff ? '0 : (SIGWIDTH + 3 - abs_diff)));
assign smaller_aligned_sig = {{1'b0, smaller_sig, 2'd0} >> abs_diff, sticky_bit};

assign sum_sign = bigger_sign;
assign sum_exp = bigger_exp;

assign sum_significand = !(bigger_sign ^ smaller_sign) ?
    bigger_sig + smaller_aligned_sig :
    bigger_sig - smaller_aligned_sig;

FPnormalizeAdd #(
    .SIGWIDTH(SIGWIDTH),
    .EWIDTH(EWIDTH))
    norm(
    .SIG_in(sum_significand),
    .EXP_in(sum_exp),
    .SIG_out(norm_significand),
    .EXP_out(norm_exp));

FPround #(
    .SIGWIDTH(SIGWIDTH),
    .EWIDTH(EWIDTH))
    round(
    .SIG_in(norm_significand),
    .EXP_in(norm_exp),
    .SIG_out(round_significand),
    .EXP_out(round_exp));

endmodule
