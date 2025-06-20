module int_fp_mult #(
    parameter IWIDTH = 12,
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23) (
    input [IWIDTH - 1:0] a,
    input [EWIDTH + SIGWIDTH:0] b,
    output [EWIDTH + SIGWIDTH:0] c
);

localparam FWIDTH = EWIDTH + SIGWIDTH + 1;
localparam PRODWIDTH = SIGWIDTH + IWIDTH + 1;
localparam SHIFTWIDTH = $clog2(SIGWIDTH + IWIDTH + 1);

logic is_zero;

logic b_sign, c_sign;
logic [EWIDTH - 1:0] b_exp, c_exp, c_exp_unrounded;
logic [SIGWIDTH:0] b_sig;

// verilator lint_off UNUSEDSIGNAL
logic [SIGWIDTH:0] c_sig;
logic [PRODWIDTH - 1:0] prod_shifted;
logic [SIGWIDTH + 3:0] c_sig_unrounded;
// verilator lint_onn UNUSEDSIGNAL

logic [SHIFTWIDTH - 1:0] leading_bit_index;
logic [PRODWIDTH - 1:0] product;

int i;

assign is_zero = a == '0 || b[FWIDTH - 2:0] == '0;

assign b_sign = b[FWIDTH - 1];
assign b_exp = b[FWIDTH - 2:SIGWIDTH];
assign b_sig = {(|b_exp), b[SIGWIDTH - 1:0]};

assign product = a * b_sig;

always_comb begin
    leading_bit_index = (SHIFTWIDTH)'(0);
    for (i = SIGWIDTH; i < PRODWIDTH; i++) begin
        if (product[i] == 1'b1)
            leading_bit_index = (SHIFTWIDTH)'(i);
    end
end

assign c_sign = b_sign;
assign c_exp_unrounded = b_exp + ((EWIDTH)'(leading_bit_index) - (EWIDTH)'(SIGWIDTH));
assign prod_shifted = product << (PRODWIDTH - 1 - leading_bit_index);
assign c_sig_unrounded = {prod_shifted[PRODWIDTH - 1:PRODWIDTH - (SIGWIDTH + 1) - 2], |prod_shifted[PRODWIDTH - (SIGWIDTH + 1) - 3:0]};

FPround #(
    .SIGWIDTH(SIGWIDTH),
    .EWIDTH(EWIDTH))
    round(
    .EXP_in(c_exp_unrounded),
    .SIG_in(c_sig_unrounded),
    .EXP_out(c_exp),
    .SIG_out(c_sig));

assign c = is_zero == 1'b1 ? '0 : {c_sign, c_exp, c_sig[SIGWIDTH - 1:0]};

endmodule
