`timescale 1ns/1ps

module uart_rx #(
    parameter integer CLKS_PER_BIT = 100
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,

    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        rx_error
);

    localparam [1:0] S_IDLE        = 2'd0;
    localparam [1:0] S_START_CHECK = 2'd1;
    localparam [1:0] S_DATA        = 2'd2;
    localparam [1:0] S_STOP_CHECK  = 2'd3;

    localparam integer COUNT_WIDTH =
        (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

    localparam integer HALF_BIT = CLKS_PER_BIT / 2;

    reg [1:0] state;
    reg [COUNT_WIDTH-1:0] bit_timer;
    reg [2:0] bit_index;
    reg [7:0] shift_reg;

    reg rx_meta;
    reg rx_sync;

    // Synchronize asynchronous serial input.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            bit_timer <= 0;
            bit_index <= 0;
            shift_reg <= 0;
            rx_data   <= 0;
            rx_valid  <= 0;
            rx_error  <= 0;
        end else begin

            rx_valid <= 1'b0;
            rx_error <= 1'b0;

            case (state)

                S_IDLE: begin
                    bit_timer <= 0;
                    bit_index <= 0;

                    if (rx_sync == 1'b0) begin
                        state     <= S_START_CHECK;
                        bit_timer <= 0;
                    end
                end

                S_START_CHECK: begin
                    // Sample halfway through the start bit.
                    if (bit_timer == HALF_BIT - 1) begin
                        bit_timer <= 0;

                        if (rx_sync == 1'b0) begin
                            bit_index <= 0;
                            state     <= S_DATA;
                        end else begin
                            // Reject a false start.
                            state <= S_IDLE;
                        end
                    end else begin
                        bit_timer <= bit_timer + 1'b1;
                    end
                end

                S_DATA: begin
                    // Sample each data bit one bit period apart.
                    if (bit_timer == CLKS_PER_BIT - 1) begin
                        bit_timer <= 0;

                        shift_reg[bit_index] <= rx_sync;

                        if (bit_index == 3'd7) begin
                            state <= S_STOP_CHECK;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        bit_timer <= bit_timer + 1'b1;
                    end
                end

                S_STOP_CHECK: begin
                    // Check the stop bit.
                    if (bit_timer == CLKS_PER_BIT - 1) begin
                        bit_timer <= 0;
                        state     <= S_IDLE;

                        if (rx_sync == 1'b1) begin
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end else begin
                            rx_error <= 1'b1;
                        end
                    end else begin
                        bit_timer <= bit_timer + 1'b1;
                    end
                end

                default: begin
                    state     <= S_IDLE;
                    bit_timer <= 0;
                end

            endcase
        end
    end

endmodule