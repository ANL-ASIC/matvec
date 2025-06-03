`include "/local/ralsaeed/top/matvec/SRAM/SRAM.sv"
`include "/local/ralsaeed/top/matvec/SRAM/SRAM_bank.sv"
`include "/local/ralsaeed/top/matvec/SRAM/SRAM_block.sv"
`include "/local/ralsaeed/top/matvec/sram_addr_fsm/sram_addr_fsm.sv"
`include "/local/ralsaeed/top/matvec/hw/matvec.sv"
`include "/local/ralsaeed/top/matvec/hw/FPpack.sv"
`include "/local/ralsaeed/top/matvec/hw/FPunpack.sv"
`include "/local/ralsaeed/top/matvec/hw/FPround.sv"
`include "/local/ralsaeed/top/matvec/hw/FPnormalizeAdd.sv"
`include "/local/ralsaeed/top/matvec/hw/FPnormalizeMul.sv"
`include "/local/ralsaeed/top/matvec/hw/int_to_float.sv"
`include "/local/ralsaeed/top/matvec/hw/FPmul.sv"
`include "/local/ralsaeed/top/matvec/hw/int_fp_mult.sv"
`include "/local/ralsaeed/top/matvec/hw/weight_mult.sv"
`include "/local/ralsaeed/top/matvec/hw/FPadd.sv"
`include "/local/ralsaeed/top/matvec/hw/accumulator.sv"


module top_level #(
    parameter pixel_data_width             = 12,
    parameter number_of_columns_per_frame  = 10,
    parameter number_of_rows_per_frame     = 8,
    parameter K                            = 10,
    parameter EWIDTH                       = 8,
    parameter SIGWIDTH                     = 23
)(
    input  logic clk,
    input  logic reset,
    input  logic SRO,
    input  logic dv, 

    // SRAM init interface
    input  logic write_enable,
    input  logic [$clog2(number_of_rows_per_frame)-1:0] write_addr,
    input  logic [K-1:0][number_of_columns_per_frame-1:0][EWIDTH + SIGWIDTH:0] write_data,

    // Main input/output
    input  logic [number_of_columns_per_frame-1:0][pixel_data_width-1:0] pixel_data,     
    output logic [k - 1:0][EWIDTH + SIGWIDTH:0] result
);

    localparam weight_width = EWIDTH + SIGWIDTH + 1;
    
    // -----------------------------------
    // Address FSM
    // -----------------------------------
    logic [$clog2(number_of_rows_per_frame)-1:0] addr_out;

    sram_addr_fsm #(
        .SRAM_DEPTH(number_of_rows_per_frame)
    ) fsm (
        .clk(clk),
        .reset(reset),
        .SRO(SRO),
        .addr_out(addr_out),
        .dv(dv)
    );

    // -----------------------------------
    // SRAM signals
    // -----------------------------------
    logic [K-1:0][number_of_columns_per_frame-1:0][weight_width-1:0] read_data; // packed

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
        .WWIDTH(WWIDTH),
        .EWIDTH(EWIDTH),
        .M(K),
        .N(number_of_columns_per_frame)
    ) mac (
        .clk(clk),
        .acc_rst(reset),
        .in(pixel_data),
        .weights(read_data),
        .out(result)
    );

endmodule
