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

module top_level_no_sram #(
    parameter pixel_data_width             = 12,
    parameter number_of_columns_per_frame  = 4,
    parameter number_of_rows_per_frame     = 168,
    parameter K                            = 4,
    parameter EWIDTH                       = 5,
    parameter WEIGHT_EWIDTH                = 4,
    parameter SIGWIDTH                     = 10
)(
    input  logic clk,
    input  logic reset,
    input  logic SRO,
    input  logic dv,

    
    input logic [K-1:0][number_of_columns_per_frame-1:0][WEIGHT_EWIDTH + SIGWIDTH :0] read_data, // packed

    // Main input/output
    input  logic [number_of_columns_per_frame-1:0][pixel_data_width-1:0] pixel_data,
    output logic [$clog2(number_of_rows_per_frame)-1:0] addr_out,
    output logic [K - 1:0][EWIDTH + SIGWIDTH:0] result
);

    localparam weight_width = WEIGHT_EWIDTH + SIGWIDTH + 1;

    // -----------------------------------
    // Address FSM
    // -----------------------------------
    //logic [$clog2(number_of_rows_per_frame)-1:0] addr_out;
    logic do_acc;

    sram_addr_fsm #(
        .SRAM_DEPTH(number_of_rows_per_frame)
    ) fsm (
        .clk(clk),
        .reset(reset),
        .SRO(SRO),
        .dv(dv),
        .do_acc(do_acc),
        .addr_out(addr_out)
    );

    // -----------------------------------
    // Multiplier-Accumulator Block
    // -----------------------------------
    matvec #(
        .IWIDTH(pixel_data_width),
        .SIGWIDTH(SIGWIDTH),
        .EWIDTH(EWIDTH),
        .WEIGHT_EWIDTH(WEIGHT_EWIDTH),
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

endmodule
