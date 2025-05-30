module SRAM_block #(
    parameter weight_width = 12,
    parameter num_row_per_frame = 168
) (
    input  logic clk,
    input  logic write_enable,
    input  logic [$clog2(num_row_per_frame)-1:0] addr,
    input  logic [$clog2(num_row_per_frame)-1:0] write_addr,
    input  logic [weight_width-1:0] write_data,
    output logic [weight_width-1:0] data_out
);


    logic [weight_width-1:0] mem [0:num_row_per_frame-1];
    
    assign data_out = mem[addr];
    
    always_ff @(posedge clk) begin
        if (write_enable)
            mem[write_addr] <= write_data;
    end

endmodule
