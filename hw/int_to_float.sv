module int_to_float(
    input [IWIDTH - 1:0] in,
    output [FWIDTH - 1:0] out
);

initial begin
    $display("[%0t] Tracing to logs/vlt_dump.vcd...\n", $time);
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
    $display("[%0t] Model running...\n", $time);
end

parameter IWIDTH = 12;
parameter EWIDTH = 8;
parameter SIG_WIDTH = 23;
localparam FWIDTH = EWIDTH + SIG_WIDTH + 1;
localparam [EWIDTH - 1:0] BIAS = 2 ** (EWIDTH - 1) - 1;
localparam SHIFT_BITS = $clog2(SIG_WIDTH);

// verilator lint_off UNUSEDSIGNAL
wire [FWIDTH - 1:0] sig;
// verilator lint_on UNUSEDSIGNAL
wire [EWIDTH - 1:0] exp;
wire sign;
logic [SHIFT_BITS - 1:0] shift_factor;
logic [SHIFT_BITS - 1:0] leading_bit_pos;
int i;

    assign sign = 1'b0; // always using unsigned integers
    always_comb begin
        leading_bit_pos = 0;
        for (i = 0; i < IWIDTH; i++) begin
            if (in[i] == 1'b1)
                leading_bit_pos = SHIFT_BITS'(i);
        end
    end

    assign exp = (in == 0) ? EWIDTH'(0) : (EWIDTH'(leading_bit_pos) + BIAS);
    assign shift_factor = SIG_WIDTH - leading_bit_pos;
    assign sig = {{(FWIDTH - IWIDTH){1'b0}}, in} << shift_factor;

    assign out = {sign, exp, sig[SIG_WIDTH - 1:0]};
endmodule
