`timescale 1ns / 1ps

module sram_addr_fsm_tb;

    // Parameters
    parameter SRAM_DEPTH = 168;
    localparam ADDR_WIDTH = $clog2(SRAM_DEPTH);

    // Signals
    logic clk;
    logic reset;
    logic frame_ready;
    logic [ADDR_WIDTH-1:0] addr_out;

    // Instantiate DUT
    sram_addr_fsm #(
        .SRAM_DEPTH(SRAM_DEPTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .frame_ready(frame_ready),
        .addr_out(addr_out)
    );

    // Clock generation (10 ns period)
    always #5 clk = ~clk;

    // Task: wait for 1 positive clock edge
    task automatic wait_clock(input int count = 1);
        repeat (count) @(posedge clk);
    endtask

    // Test sequence
    initial begin
        
        clk = 0;
        reset = 1;
        frame_ready = 0;

        // Apply reset
        wait_clock(2);
        reset = 0;

        // ------------------------------------
        // 1. Send single-cycle frame_ready pulse
        // ------------------------------------
        #23;
        frame_ready = 1;
        wait_clock(1);
        frame_ready = 0;
                // Step through several address values
        wait_clock(5);
  
        // ------------------------------------
        // 2. Mid-operation reset
        // ------------------------------------
        $display(">> Applying reset during counting...");
        reset = 1;
        wait_clock(1);
        reset = 0;

        // FSM should return to IDLE and address 0
        wait_clock(2);

        // ------------------------------------
        // 3. Restart after reset using frame_ready pulse
        // ------------------------------------
        frame_ready = 1;
        wait_clock(1);
        frame_ready = 0;
 
        // Run until just before last address
        wait_clock(SRAM_DEPTH - 2);  // Now addr_out should be SRAM_DEPTH - 2
 

        // FSM should wrap and return to IDLE
        wait_clock(1);
        
   
        // ------------------------------------
        // 4. Final restart with another frame_ready pulse
        // ------------------------------------
        wait_clock(2);
        frame_ready = 1;
        wait_clock(1);
        frame_ready = 0;
        
        // Check first few values again
        wait_clock(3);
        
        $finish;
    end

endmodule
