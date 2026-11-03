`timescale 1ns/1ps

module baud_tick_generator #(
    parameter integer CLK_FREQ  = 1_000_000,
    parameter integer BAUD_RATE = 10_000
)(
    input  wire clk,
    input  wire rst,
    output reg  tick
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam integer COUNT_WIDTH =
        (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

    reg [COUNT_WIDTH-1:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            tick  <= 0;
        end else begin
            if (count == CLKS_PER_BIT - 1) begin
                count <= 0;
                tick  <= 1;
            end else begin
                count <= count + 1'b1;
                tick  <= 0;
            end
        end
    end

endmodule
