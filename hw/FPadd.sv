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

logic X_sign;
logic Y_sign;
logic sum_sign;
logic [EWIDTH - 1:0] X_exp;
logic [EWIDTH - 1:0] Y_exp;
logic [EWIDTH - 1:0] sum_exp, norm_exp, round_exp;
logic [SIGWIDTH:0] X_sig, Y_sig;
logic [2 * SIGWIDTH:0] X_aligned_sig, Y_aligned_sig;
// verilator lint_off UNUSEDSIGNAL
logic [2 * SIGWIDTH + 1:0] sum_significand;
// verilator lint_on UNUSEDSIGNAL

logic [EWIDTH:0] expdiff, abs_diff;
logic [2 * SIGWIDTH + 1:0] sum_significand_temp;
logic [SIGWIDTH + 2:0] norm_significand;
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

assign sum_exp = expdiff[EWIDTH] ? Y_exp : X_exp;			//Greater exp taken

assign X_aligned_sig = expdiff[EWIDTH] ? {X_sig, (SIGWIDTH)'(0)} >> abs_diff : {X_sig, (SIGWIDTH)'(0)};	              //X sig shifts if expdiff[EWIDTH]
assign Y_aligned_sig = expdiff[EWIDTH] ? {Y_sig, (SIGWIDTH)'(0)}             : {Y_sig, (SIGWIDTH)'(0)} >> abs_diff;   //Y sig shifts if !expdiff[EWIDTH]

assign expdiff = X_exp - Y_exp;
assign abs_diff = {1'b0, (expdiff[EWIDTH] ? ~(expdiff[EWIDTH - 1:0]) + 1'b1 : expdiff[EWIDTH - 1:0])};	//Absolute difference

always_comb begin
    sum_sign = X_sign & Y_sign;
    sum_significand_temp = 0;
    if (!(X_sign ^ Y_sign)) begin
        // simply add together the signficands if operands are same sign
        sum_significand = {1'b0, X_aligned_sig} + {1'b0, Y_aligned_sig};
    end else begin
        // determine operand order depending on which operand is negative
        if (X_sign)
            sum_significand_temp = Y_aligned_sig - X_aligned_sig;
        else
            sum_significand_temp = X_aligned_sig - Y_aligned_sig;

        // check for underflow and convert back to unsigned
        if (sum_significand_temp[2 * SIGWIDTH + 1] == 1'b1) begin
            sum_significand = ~sum_significand_temp + 1;
            sum_sign = 1'b1;
        end else begin
            sum_significand = sum_significand_temp;
        end
    end
end

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
