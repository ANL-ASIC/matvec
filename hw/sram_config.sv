module sram_writer #(
    parameter sram_width = 4,
    parameter weight_width = 2,
    parameter number_of_rows_per_frame = 4,
    parameter number_of_columns_per_frame = 4,
    parameter K = 2
)(
    input  logic clk,
    input  logic rst,  
    input  logic start, 
    input  logic [$clog2(number_of_rows_per_frame)-1:0] addr_in,
    input  logic [sram_width-1:0] write_data_in,
    output logic done,

    output logic [K * (number_of_columns_per_frame / (sram_width / weight_width)) - 1:0][$clog2(number_of_rows_per_frame)-1:0] addr_out,
    output logic [K * (number_of_columns_per_frame / (sram_width / weight_width)) - 1:0] we_out,
    output logic [K * (number_of_columns_per_frame / (sram_width / weight_width)) - 1:0][sram_width-1:0] data_out
);

    localparam NUM_SRAMS      = K * (number_of_columns_per_frame / (sram_width / weight_width));
    localparam ADDR_WIDTH     = $clog2(number_of_rows_per_frame);
    localparam SRAM_IDX_WIDTH = $clog2(NUM_SRAMS);
    localparam TOTAL_WRITES   = NUM_SRAMS * number_of_rows_per_frame;
    localparam COUNT_WIDTH    = $clog2(TOTAL_WRITES + 1);

    logic [COUNT_WIDTH-1:0] write_counter;
    logic writing;
    logic done_next_cycle;

    logic [NUM_SRAMS-1:0][ADDR_WIDTH-1:0] addr_array;
    logic [NUM_SRAMS-1:0][sram_width-1:0] data_array;
    logic [NUM_SRAMS-1:0] we_array;

    logic [SRAM_IDX_WIDTH-1:0] prev_sram_idx;
    logic clear_prev;

    assign addr_out = addr_array;
    assign data_out = data_array;
    assign we_out   = we_array;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            write_counter    <= 0;
            writing          <= 0;
            done             <= 0;
            done_next_cycle  <= 0;
            we_array         <= '{default: 0};
            addr_array       <= '{default: 0};
            data_array       <= '{default: 0};
            prev_sram_idx    <= 0;
            clear_prev       <= 0;
        end else begin
            
            we_array <= '{default: 0};
            done     <= done_next_cycle;
            done_next_cycle <= 0;

            
            if (clear_prev) begin
                addr_array[prev_sram_idx] <= '0;
                data_array[prev_sram_idx] <= '0;
                clear_prev <= 0;
            end

            
            if (start && !writing) begin
                writing <= 1;
                write_counter <= 0;
            end

            if (writing) begin
                
                logic [SRAM_IDX_WIDTH-1:0] sram_idx;
                logic [ADDR_WIDTH-1:0] sram_addr;

                sram_idx  = write_counter / number_of_rows_per_frame;
                sram_addr = write_counter % number_of_rows_per_frame;

                
                we_array[sram_idx]     <= 1;
                addr_array[sram_idx]   <= addr_in;
                data_array[sram_idx]   <= write_data_in;

                
                if (sram_addr == number_of_rows_per_frame - 1) begin
                    prev_sram_idx <= sram_idx;
                    clear_prev <= 1;
                end

                
                if (write_counter == TOTAL_WRITES - 1) begin
                    writing <= 0;
                    done_next_cycle <= 1;
                end

                
                write_counter <= write_counter + 1;
            end
        end
    end

endmodule
