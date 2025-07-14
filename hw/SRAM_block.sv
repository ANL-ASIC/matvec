module SRAM_block #(
    parameter weight_width = 12,
    parameter num_row_per_frame = 168,
    parameter num_weights_per_word = 12,
    parameter freq_factor = 4
) (
    input  logic clk,
    input  logic write_enable,
    input  logic [$clog2(freq_factor*num_row_per_frame)-1:0] addr,
    input  logic [$clog2(freq_factor*num_row_per_frame)-1:0] write_addr,
    input  logic [(num_weights_per_word*weight_width)-1:0] write_data,
    output logic [(num_weights_per_word*weight_width)-1:0] data_out
);

endmodule
