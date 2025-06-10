module sram_addr_fsm #(
    parameter SRAM_DEPTH = 168  // Number of SRAM words
)(
    input  logic clk,
    input  logic reset,          // Active-high reset
    input  logic SRO,            // Start Read Operation signal
    input  logic dv,             // Data-valid input pulse: enables address increment
    output logic do_acc,        // output signal to set accumulator register to 0
    output logic [$clog2(SRAM_DEPTH)-1:0] addr_out // SRAM address
);

    localparam ADDR_WIDTH = $clog2(SRAM_DEPTH);

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        RUN  = 2'b01
    } state_t;

    state_t current_state, next_state;
    logic [ADDR_WIDTH-1:0] addr_reg;

    assign addr_out = addr_reg;

    // FSM State Register
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // FSM Next-State Logic
    always_comb begin
        case (current_state)
            IDLE:
                if (SRO)
                    next_state = RUN;
                else
                    next_state = IDLE;

            RUN:
                if ((addr_reg == SRAM_DEPTH - 1) && dv)
                    next_state = IDLE;
                else
                    next_state = RUN;

            default: next_state = IDLE;
        endcase
    end

    // Address Register Logic (increment only when dv is high)
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            addr_reg <= '0;
        end else begin
            case (current_state)
                IDLE: begin
                    addr_reg <= '0;
                end
                RUN: begin
                    if (dv) begin
                        if (addr_reg < SRAM_DEPTH - 1)
                            addr_reg <= addr_reg + 1;
                        else
                            addr_reg <= addr_reg; // Hold last address
                    end
                end
                default: addr_reg <= '0;
            endcase
        end

        do_acc <= current_state == RUN;
    end

endmodule
