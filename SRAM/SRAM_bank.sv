

module SRAM_bank #(
    parameter weight_width = 12,
    parameter num_row_per_frame = 12,
    parameter num_col_per_frame = 4
) (
    input  logic clk,
    input  logic write_enable,
    input  logic [$clog2(num_row_per_frame)-1:0] addr,
    input  logic [$clog2(num_row_per_frame)-1:0] write_addr,
    input  logic [num_col_per_frame-1:0][weight_width-1:0] write_data,
    output logic [num_col_per_frame-1:0][weight_width-1:0] data_out   
);

    genvar i;
    generate
        for (i = 0; i < num_col_per_frame; i++) begin : col_gen
            SRAM_block #(
                .weight_width(weight_width),
                .num_row_per_frame(num_row_per_frame)
            ) sram_blk (
                .clk(clk),
                .write_enable(write_enable),
                .addr(addr),
                .write_addr(write_addr),
                .write_data(write_data[i]),
                .data_out(data_out[i])
            );
        end
    endgenerate

endmodule
