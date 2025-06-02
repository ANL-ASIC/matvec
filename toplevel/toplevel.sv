module top_level #(
    parameter pixel_data_width         = 12,
    parameter weight_width             = 12,
    parameter number_of_columns_per_frame = 192,
    parameter number_of_rows_per_frame    = 168,
    parameter K                         = 10
)(
    input  logic clk,
    input  logic reset,
    input  logic frame_ready,
    
    //for sram init only/////
    input  logic write_enable,
    input  logic [$clog2(number_of_rows_per_frame)-1:0] write_addr; 
    input  logic [weight_width-1:0] write_data [K-1:0][number_of_columns_per_frame-1:0];
    ////////////////////////////
    
    //Main in and out
    input  logic [pixel_data_width-1:0] pixel_data [number_of_columns_per_frame-1:0],
    output logic [pixel_data_width + weight_width + $clog2(K)-1:0] result /////
);

    // -----------------------------------
    // Address FSM
    // -----------------------------------
    logic [$clog2(number_of_rows_per_frame)-1:0] addr_out;
    sram_addr_fsm #(
        .SRAM_DEPTH(number_of_rows_per_frame)
    ) fsm (
        .clk(clk),
        .reset(reset),
        .frame_ready(frame_ready),
        .addr_out(addr_out)
    );

    // -----------------------------------
    // SRAM signals
    // -----------------------------------
    logic [weight_width-1:0] read_data  [K-1:0][number_of_columns_per_frame-1:0];
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
