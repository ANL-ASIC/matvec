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

wire X_sign;
wire Y_sign;
reg sum_sign;
wire [EWIDTH - 1:0] X_exp;
wire [EWIDTH - 1:0] Y_exp;
wire [EWIDTH - 1:0] sum_exp, norm_exp, round_exp;
wire [SIGWIDTH + 3:0] X_sig, Y_sig;
wire [SIGWIDTH + 3:0] X_aligned_sig, Y_aligned_sig;
reg [SIGWIDTH + 4:0] sum_significand;

wire [EWIDTH:0] expdiff, abs_diff;
reg [SIGWIDTH + 4:0] sum_significand_temp;
reg [SIGWIDTH + 3:0] norm_significand;
// verilator lint_off UNUSEDSIGNAL
reg [SIGWIDTH:0] round_significand;
// verilator lint_on UNUSEDSIGNAL

    assign sum = {sum_sign, round_exp, round_significand[SIGWIDTH - 1:0]};

    assign X_sign = X[WIDTH - 1];
    assign X_exp = X[WIDTH - 2:SIGWIDTH];
    assign X_sig = {1'b1, X[SIGWIDTH - 1:0], 3'd0};
    assign Y_sign = Y[WIDTH - 1];
    assign Y_exp = Y[WIDTH - 2:SIGWIDTH];
    assign Y_sig = {1'b1, Y[SIGWIDTH - 1:0], 3'd0};

    assign sum_exp = expdiff[EWIDTH] ? Y_exp : X_exp;			//Greater exp taken

    assign X_aligned_sig = expdiff[EWIDTH] ? X_sig >> abs_diff : X_sig;	//X sig shifts if expdiff[EWIDTH]
    assign Y_aligned_sig = expdiff[EWIDTH] ? Y_sig : Y_sig >> abs_diff;   //Y sig shifts if !expdiff[EWIDTH]

    assign expdiff = X_exp - Y_exp;
    assign abs_diff = {1'b0, (expdiff[EWIDTH] ? ~(expdiff[EWIDTH - 1:0]) + 1'b1 : expdiff[EWIDTH - 1:0])};	//Absolute difference

    always @ (*)
    begin

        sum_sign = X_sign & Y_sign;
        if (!(X_sign ^ Y_sign)) begin
            sum_significand_temp = X_aligned_sig + Y_aligned_sig;
            sum_significand = sum_significand_temp;
        end else begin
            if (X_sign)
                sum_significand_temp = Y_aligned_sig - X_aligned_sig;
            else
                sum_significand_temp = X_aligned_sig - Y_aligned_sig;

            if (sum_significand_temp[SIGWIDTH + 4] == 1'b1) begin
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
