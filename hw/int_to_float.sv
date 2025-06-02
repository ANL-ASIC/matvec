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

localparam FWIDTH = EWIDTH + SIGWIDTH + 1;
localparam [EWIDTH - 1:0] BIAS = 2 ** (EWIDTH - 1) - 1;
localparam SHIFT_BITS = $clog2(SIGWIDTH);

// verilator lint_off UNUSEDSIGNAL
wire [FWIDTH - 1:0] sig;
// verilator lint_on UNUSEDSIGNAL
wire [EWIDTH - 1:0] exp;
wire sign;
wire [SHIFT_BITS - 1:0] shift_factor;
reg [SHIFT_BITS - 1:0] leading_bit_pos;
reg [$clog2(IWIDTH) - 1:0] i;

    assign sign = 1'b0; // always using unsigned integers
    always @(*) begin
        leading_bit_pos = 0;
        for (i = 0; i < IWIDTH; i = i + 1) begin
            if (in[i] == 1'b1)
                leading_bit_pos = {{(SHIFT_BITS - $clog2(IWIDTH)){1'b0}}, i};
        end
    end

    assign exp = (in == 0) ? {EWIDTH{1'b0}} : ({{(EWIDTH - SHIFT_BITS){1'b0}}, leading_bit_pos} + BIAS);
    assign shift_factor = SIGWIDTH - leading_bit_pos;
    assign sig = {{(FWIDTH - IWIDTH){1'b0}}, in} << shift_factor;

    assign out = {sign, exp, sig[SIGWIDTH - 1:0]};
endmodule
