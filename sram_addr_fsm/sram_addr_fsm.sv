module sram_addr_fsm #( 
    parameter SRAM_DEPTH = 168  // Number of SRAM words
    )(
    input  logic clk,
    input  logic reset,          // Active-high reset
    input  logic frame_ready,    // Indicating that the pixel frame is ready
    output logic [$clog2(SRAM_DEPTH)-1:0] addr_out // SRAM address selection bus
);
    
    // Local parameter for address width
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

    // FSM Next State Logic
    always_comb begin
        case (current_state)
            IDLE:
                if (frame_ready)
                    next_state = RUN;
                else
                    next_state = IDLE;

            RUN:
                if (addr_reg == (SRAM_DEPTH - 1))
                    next_state = IDLE;
                else
                    next_state = RUN;

            default: next_state = IDLE;
        endcase
    end

    // Address Register Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            addr_reg <= '0;
        else begin
            case (current_state)
                IDLE:
                    addr_reg <= '0;  // Always reset addr in IDLE
                RUN: begin
                    if (addr_reg == (SRAM_DEPTH - 1))
                        addr_reg <= '0;
                    else
                        addr_reg <= addr_reg + 1;
                end
            endcase
        end
    end

endmodule
