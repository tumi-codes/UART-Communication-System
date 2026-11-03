`timescale 1ns/1ps

module uart_tx #(
    parameter integer CLKS_PER_BIT = 100
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       tx_start,
    input  wire [7:0] tx_data,

    output reg        tx,
    output reg        tx_busy,
    output reg        tx_done
);

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_START = 2'd1;
    localparam [1:0] S_DATA  = 2'd2;
    localparam [1:0] S_STOP  = 2'd3;

    localparam integer COUNT_WIDTH =
        (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

    reg [1:0] state;
    reg [COUNT_WIDTH-1:0] bit_timer;
    reg [2:0] bit_index;
    reg [7:0] shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            bit_timer <= 0;
            bit_index <= 0;
            shift_reg <= 0;
            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
        end else begin

            tx_done <= 1'b0;

            case (state)

                S_IDLE: begin
                    tx        <= 1'b1;
                    tx_busy   <= 1'b0;
                    bit_timer <= 0;
                    bit_index <= 0;

                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tx        <= 1'b0;
                        tx_busy   <= 1'b1;
                        bit_timer <= 0;
                        state     <= S_START;
                    end
                end

                S_START: begin
                    if (bit_timer == CLKS_PER_BIT - 1) begin
                        bit_timer <= 0;
                        bit_index <= 0;

                        tx    <= shift_reg[0];
                        state <= S_DATA;
                    end else begin
                        bit_timer <= bit_timer + 1'b1;
                    end
                end

                S_DATA: begin
                    if (bit_timer == CLKS_PER_BIT - 1) begin
                        bit_timer <= 0;

                        if (bit_index == 3'd7) begin
                            tx    <= 1'b1;
                            state <= S_STOP;
                        end else begin
                            shift_reg <= {
                                1'b0,
                                shift_reg[7:1]
                            };

                            bit_index <= bit_index + 1'b1;
                            tx        <= shift_reg[1];
                        end
                    end else begin
                        bit_timer <= bit_timer + 1'b1;
                    end
                end

                S_STOP: begin
                    if (bit_timer == CLKS_PER_BIT - 1) begin
                        bit_timer <= 0;
                        tx        <= 1'b1;
                        tx_busy   <= 1'b0;
                        tx_done   <= 1'b1;
                        state     <= S_IDLE;
                    end else begin
                        bit_timer <= bit_timer + 1'b1;
                    end
                end

                default: begin
                    state     <= S_IDLE;
                    tx        <= 1'b1;
                    tx_busy   <= 1'b0;
                    bit_timer <= 0;
                end

            endcase
        end
    end

endmodule
