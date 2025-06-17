
`timescale 1ns/1ps

module tb_SRAM_bank;

    // Parameters
    parameter weight_width       = 12;
    parameter num_row_per_frame  = 8;   // Small for testing
    parameter num_col_per_frame  = 4;
    localparam ADDR_WIDTH        = $clog2(num_row_per_frame);

    // DUT I/O
    logic clk;
    logic write_enable;
    logic [ADDR_WIDTH-1:0] addr;
    logic [ADDR_WIDTH-1:0] write_addr;
    logic [weight_width-1:0] write_data [num_col_per_frame-1:0];
    logic [weight_width-1:0] data_out   [num_col_per_frame-1:0];

    // Expected data store
    logic [weight_width-1:0] expected_mem [num_col_per_frame-1:0][num_row_per_frame-1:0];

    // Instantiate DUT
    SRAM_bank #(
        .weight_width(weight_width),
        .num_row_per_frame(num_row_per_frame),
        .num_col_per_frame(num_col_per_frame)
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

    // Task to write data to all SRAM blocks
    task write_all_data();
        for (int row = 0; row < num_row_per_frame; row++) begin
            @(posedge clk);
            write_enable = 1;
            write_addr = row;
            for (int col = 0; col < num_col_per_frame; col++) begin
                expected_mem[col][row] = $urandom_range(0, (1 << weight_width) - 1);
                write_data[col] = expected_mem[col][row];
            end
        end
        @(posedge clk);
        write_enable = 0;
    endtask

    // Task to read and verify all data
    task verify_all_data();
        for (int row = 0; row < num_row_per_frame; row++) begin
            @(posedge clk);
            addr = row;
            @(posedge clk);  // wait for data to register
        end
    endtask

    // Main test sequence
    initial begin
        write_enable = 0;
        addr = 0;
        write_addr = 0;

        // Let clock stabilize
        repeat (3) @(posedge clk);

        // Write and verify
        write_all_data();
        repeat (3) @(posedge clk);
        verify_all_data();

        $finish;
    end

endmodule
