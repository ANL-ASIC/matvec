`include "SRAM_bank.sv"

module SRAM #(
    parameter K = 10,
    parameter num_col_per_frame = 192,
    parameter weight_width = 12,
    parameter num_row_per_frame = 168
) (
    input  logic clk,
    input  logic write_enable,
    input  logic [$clog2(num_row_per_frame)-1:0] addr,
    input  logic [$clog2(num_row_per_frame)-1:0] write_addr,
    input  logic [K-1:0][num_col_per_frame-1:0][weight_width-1:0] write_data, 
    output logic [K-1:0][num_col_per_frame-1:0][weight_width-1:0] data_out    
);

    genvar k;
    generate
        for (k = 0; k < K; k++) begin : bank_gen
            SRAM_bank #(
                .weight_width(weight_width),
                .num_row_per_frame(num_row_per_frame),
                .num_col_per_frame(num_col_per_frame)
            ) bank (
                .clk(clk),
                .write_enable(write_enable),
                .addr(addr),
                .write_addr(write_addr),
                .write_data(write_data[k]),
                .data_out(data_out[k])
            );
        end
    endgenerate

endmodule
