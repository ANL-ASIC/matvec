module int_to_float #(
    parameter IWIDTH = 12,
    parameter EWIDTH = 8,
    parameter SIGWIDTH = 23) (
    input [IWIDTH - 1:0] in,
    output [EWIDTH + SIGWIDTH:0] out
);

`ifdef VERILATOR
initial begin
    $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
    $display("[%0t] Model running...\n", $time);
end
`endif

localparam [EWIDTH - 1:0] BIAS = 2 ** (EWIDTH - 1) - 1;

// verilator lint_off UNUSEDSIGNAL
logic [SIGWIDTH - 1:0] sig;
// verilator lint_on UNUSEDSIGNAL
logic [EWIDTH - 1:0] exp;
logic sign;
logic [EWIDTH:0] shift_factor;
logic [IWIDTH - 1:0] shifted;
logic [EWIDTH:0] leading_bit_pos;
int i;

assign sign = 1'b0; // always using unsigned integers
always @(*) begin
    leading_bit_pos = 0;
    for (i = 0; i < IWIDTH; i = i + 1) begin
        if (in[i] == 1'b1)
            leading_bit_pos = (EWIDTH + 1)'(i);
    end
end

assign exp = (in == 0) ? {EWIDTH{1'b0}} : (EWIDTH)'(leading_bit_pos + BIAS);
assign shift_factor = IWIDTH - leading_bit_pos;
assign shifted = in << shift_factor;

generate
    if (SIGWIDTH <= IWIDTH) begin : sig_assign
        assign sig = shifted[IWIDTH - 1: IWIDTH - 1 - SIGWIDTH];
    end else begin : sig_assign_alt
        assign sig = {shifted[IWIDTH - 1: 0], (SIGWIDTH - IWIDTH)'(0)};
    end
endgenerate

assign out = {sign, exp, sig};

endmodule
