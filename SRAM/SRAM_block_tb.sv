
`timescale 1ns/1ps

module tb_SRAM_block;

    // Parameters
    parameter weight_width = 12;
    parameter num_row_per_frame = 12;  // use small number for test
    localparam ADDR_WIDTH = $clog2(num_row_per_frame);

    // DUT I/O signals
    logic clk;
    logic write_enable;
    logic [ADDR_WIDTH-1:0] addr;
    logic [ADDR_WIDTH-1:0] write_addr;
    logic [weight_width-1:0] write_data;
    logic [weight_width-1:0] data_out;

    // Expected memory
    logic [weight_width-1:0] expected_mem [0:num_row_per_frame-1];

    // DUT instantiation
    SRAM_block #(
        .weight_width(weight_width),
        .num_row_per_frame(num_row_per_frame)
    ) dut (
        .clk(clk),
        .write_enable(write_enable),
        .addr(addr),
        .write_addr(write_addr),
        .write_data(write_data),
        .data_out(data_out)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Write task
    task write_data_to_sram();
        for (int i = 0; i < num_row_per_frame; i++) begin
            @(posedge clk);
            write_enable = 1;
            write_addr = i;
            expected_mem[i] = $urandom_range(0, (1 << weight_width) - 1);
            write_data = expected_mem[i];
        end
        @(posedge clk);
        write_enable = 0;
    endtask

    // Read and verify task
    task read_and_verify();
        for (int i = 0; i < num_row_per_frame; i++) begin
            @(posedge clk);
            addr = i;
        end
    endtask

    // Main sequence
    initial begin
        write_enable = 0;
        addr = 0;
        write_addr = 0;
        write_data = 0;

        repeat (3) @(posedge clk);  // settle clock

        write_data_to_sram();
        repeat (2) @(posedge clk);  // wait before read
        read_and_verify();
    
        $finish;
    end

endmodule
