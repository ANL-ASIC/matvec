`timescale 1ns/1ps

module tb_SRAM;

    // Parameters for test
    parameter K                 = 2;   // Number of banks
    parameter NUM_COLS         = 2;   // SRAM blocks per bank
    parameter NUM_ROWS         = 8;   // Words per block
    parameter WEIGHT_WIDTH     = 12;
    localparam ADDR_WIDTH      = $clog2(NUM_ROWS);

    // DUT I/O
    logic clk;
    logic write_enable;
    logic [ADDR_WIDTH-1:0] addr;
    logic [ADDR_WIDTH-1:0] write_addr;
    logic [WEIGHT_WIDTH-1:0] write_data [K-1:0][NUM_COLS-1:0];
    logic [WEIGHT_WIDTH-1:0] data_out   [K-1:0][NUM_COLS-1:0];

    // Expected data for verification
    logic [WEIGHT_WIDTH-1:0] expected_data [K-1:0][NUM_COLS-1:0][NUM_ROWS-1:0];

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // DUT instantiation
    SRAM #(
        .K(K),
        .num_col_per_frame(NUM_COLS),
        .weight_width(WEIGHT_WIDTH),
        .num_row_per_frame(NUM_ROWS)
    ) dut (
        .clk(clk),
        .write_enable(write_enable),
        .addr(addr),
        .write_addr(write_addr),
        .write_data(write_data),
        .data_out(data_out)
    );

    // Task: Write all data (signals set on negedge clk before posedge clk)
    task write_all_data();
        for (int row = 0; row < NUM_ROWS; row++) begin
            @(negedge clk);  // Set signals before rising edge
            write_enable = 1;
            write_addr   = row;
            for (int s = 0; s < K; s++) begin
                for (int col = 0; col < NUM_COLS; col++) begin
                    expected_data[s][col][row] = $urandom_range(0, (1 << WEIGHT_WIDTH) - 1);
                    write_data[s][col] = expected_data[s][col][row];
                end
            end
            @(posedge clk); // Write occurs here
        end
        @(negedge clk);
        write_enable = 0;
    endtask

    // Task: Read and verify all data (set addr on negedge before read on posedge)
    task verify_all_data();
        for (int row = 0; row < NUM_ROWS; row++) begin
            @(negedge clk);
            addr = row;
            @(posedge clk); // Read occurs here
            
        end
    endtask

    // Main test sequence
    initial begin
        write_enable = 0;
        addr = 0;
        write_addr = 0;

        // Let clock stabilize
        repeat (2) @(posedge clk);

        // Run tests
        write_all_data();
        repeat (2) @(posedge clk); // Wait for last write to settle
        verify_all_data();

        $finish;
    end
endmodule
