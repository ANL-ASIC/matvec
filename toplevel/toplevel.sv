module top_level #(
    parameter pixel_data_width             = 12,
    parameter number_of_columns_per_frame  = 192,
    parameter number_of_rows_per_frame     = 168,
    parameter K                            = 10,
    parameter IWIDTH                       = 12,
    parameter EWIDTH                       = 8,
    parameter SIGWIDTH                     = 23
)(
    input  logic clk,
    input  logic reset,
    input  logic SRO,

    // SRAM init interface
    input  logic write_enable,
    input  logic [$clog2(number_of_rows_per_frame)-1:0] write_addr,
    input  logic [weight_width-1:0][number_of_columns_per_frame-1:0][K-1:0] write_data, // packed

    // Main input/output
    input  logic [pixel_data_width-1:0][number_of_columns_per_frame-1:0] pixel_data,     // packed
    output logic [pixel_data_width + weight_width + $clog2(K) - 1:0] result
);

    localparam WWIDTH = EWIDTH + SIGWIDTH + 1;
    
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
        .addr_out(addr_out)
    );

    // -----------------------------------
    // SRAM signals
    // -----------------------------------
    logic [weight_width-1:0][number_of_columns_per_frame-1:0][K-1:0] read_data; // packed

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
        .WWIDTH(weight_width),
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
