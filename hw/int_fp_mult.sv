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

logic [IWIDTH - 1:0] a_shifted;
logic b_sign, c_sign;
logic [EWIDTH - 1:0] b_exp, c_exp;
logic [SIGWIDTH:0] b_sig, c_sig;

logic [SHIFTWIDTH - 1:0] leading_bit_index;
logic [PRODWIDTH - 1:0] product, c_sig_ext;

int i;

assign is_zero = a == '0 || b[FWIDTH - 2:0] == '0;

assign b_sign = b[FWIDTH - 1];
assign b_exp = b[FWIDTH - 2:SIGWIDTH];
assign b_sig = {(|b_exp), b[SIGWIDTH - 1:0]};

assign product = a * b_sig;

always_comb begin
    leading_bit_index = 0;
    for (i = 0; i < PRODWIDTH; i++) begin
        if (product[i] == 1'b1)
            leading_bit_index = (SHIFTWIDTH)'(i);
    end
end

assign c_sign = b_sign;
assign c_exp =  b_exp + (leading_bit_index - SIGWIDTH);
assign c_sig_ext = product << (PRODWIDTH - 1 - leading_bit_index);
assign c_sig = c_sig_ext[PRODWIDTH - 1:IWIDTH];
assign c = is_zero == 1'b1 ? '0 : {c_sign, c_exp, c_sig[SIGWIDTH - 1:0]};

endmodule
