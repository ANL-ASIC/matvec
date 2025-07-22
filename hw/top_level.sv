`include "SRAM.sv"
`include "SRAM_bank.sv"
`include "SRAM_block.sv"
`include "sram_addr_fsm.sv"
`include "matvec.sv"
`include "FPpack.sv"
`include "FPunpack.sv"
`include "FPround.sv"
`include "FPnormalizeAdd.sv"
`include "int_to_float.sv"
`include "int_fp_mult.sv"
`include "weight_mult.sv"
`include "FPadd.sv"
`include "accumulator.sv"

module top_level #(
    parameter pixel_data_width             = 12,
    parameter number_of_columns_per_frame  = 2,
    parameter number_of_rows_per_frame     = 2,
    parameter K                            = 2,
    parameter EWIDTH                       = 8,
    parameter SIGWIDTH                     = 23,
    parameter WEIGHT_EWIDTH                = 8,
    parameter WEIGHT_SIGWIDTH              = 23,
    parameter WEIGHT_BIAS                  = 2 ** 7 - 1,
    parameter PROD_EWIDTH                  = 8,
    parameter PROD_SIGWIDTH                = 23
)(
    input  logic clk,
    input  logic reset,
    input  logic SRO,
    input  logic dv,

    // SRAM init interface
    input  logic write_enable,
    input  logic [$clog2(number_of_rows_per_frame)-1:0] write_addr,
    input  logic [K-1:0][number_of_columns_per_frame-1:0][WEIGHT_EWIDTH + WEIGHT_SIGWIDTH:0] write_data,

    // Main input/output
    input  logic [number_of_columns_per_frame-1:0][pixel_data_width-1:0] pixel_data,
    output logic [K - 1:0][EWIDTH + SIGWIDTH:0] result,

    // error signals
    output SRO_invalid,
    output dv_invalid
);

    localparam weight_width = WEIGHT_EWIDTH + WEIGHT_SIGWIDTH + 1;

    // -----------------------------------
    // Address FSM
    // -----------------------------------
    logic [$clog2(number_of_rows_per_frame)-1:0] addr_out;
    logic do_acc;

    sram_addr_fsm #(
        .SRAM_DEPTH(number_of_rows_per_frame)
    ) fsm (
        .clk(clk),
        .reset(reset),
        .SRO(SRO),
        .dv(dv),
        .do_acc(do_acc),
        .addr_out(addr_out),
        .SRO_invalid(SRO_invalid),
        .dv_invalid(dv_invalid)
    );

    // -----------------------------------
    // SRAM signals
    // -----------------------------------
    logic [K-1:0][number_of_columns_per_frame - 1:0][weight_width - 1:0] read_data; // packed

    SRAM #(
        .K(K),
        .num_col_per_frame(number_of_columns_per_frame),
        .weight_width(weight_width),
        .num_row_per_frame(number_of_rows_per_frame)
    ) sram_inst (
        .clk(clk),
        .write_enable(write_enable),
        .write_addr(write_addr),
        .addr(addr_out),
        .write_data(write_data),
        .data_out(read_data)
    );

    // -----------------------------------
    // Multiplier-Accumulator Block
    // -----------------------------------
    matvec #(
        .IWIDTH(pixel_data_width),
        .SIGWIDTH(SIGWIDTH),
        .EWIDTH(EWIDTH),
        .WEIGHT_EWIDTH(WEIGHT_EWIDTH),
        .WEIGHT_SIGWIDTH(WEIGHT_SIGWIDTH),
        .WEIGHT_BIAS(WEIGHT_BIAS),
        .PROD_EWIDTH(PROD_EWIDTH),
        .PROD_SIGWIDTH(PROD_SIGWIDTH),
        .M(K),
        .N(number_of_columns_per_frame)
    ) mac (
        .clk(clk),
        .do_acc(do_acc),
        .dv(dv),
        .in(pixel_data),
        .weights(read_data),
        .out(result)
    );

`ifdef COCOTB_SIM
    // FOR COCOTB TESTING ONLY
    // -----------------------------------
    // Single adder unit test
    // -----------------------------------
    (* keep = "true" *) logic [EWIDTH + SIGWIDTH:0] X;
    (* keep = "true" *) logic [EWIDTH + SIGWIDTH:0] Y;
    (* keep = "true" *) logic [EWIDTH + SIGWIDTH:0] sum;
    (* keep = "true" *) logic [EWIDTH + SIGWIDTH:0] product;
    FPadd #(
        .EWIDTH(EWIDTH),
        .SIGWIDTH(SIGWIDTH)
    ) adder (
        .X(X),
        .Y(Y),
        .sum(sum)
    );
`endif

endmodule
