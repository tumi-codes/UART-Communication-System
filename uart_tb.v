`timescale 1ns/1ps

module uart_tb;

    // 1 MHz clock, 10,000 baud.
    // Each UART bit lasts 100 clock cycles.
    localparam integer CLKS_PER_BIT = 100;

    reg clk;
    reg rst;
    reg tx_start;
    reg [7:0] tx_data;

    wire tx_serial;
    wire tx_busy;
    wire tx_done;

    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_error;

    integer pass_count;
    integer fail_count;
    integer timeout_count;

    uart_top #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),

        .tx_serial(tx_serial),
        .tx_busy(tx_busy),
        .tx_done(tx_done),

        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_error(rx_error)
    );

    // Clock period = 1000 ns = 1 MHz.
    initial clk = 1'b0;
    always #500 clk = ~clk;

    // Send one byte and verify the received result.
    task transmit_and_check;
        input [7:0] test_data;

        begin
            wait (tx_busy == 1'b0);

            @(negedge clk);
            tx_data  = test_data;
            tx_start = 1'b1;

            @(negedge clk);
            tx_start = 1'b0;

            // Wait for rx_valid, with a timeout.
            timeout_count = 0;

            while ((rx_valid !== 1'b1) &&
                   (timeout_count < 2000)) begin

                @(negedge clk);
                timeout_count = timeout_count + 1;

            end

            if (timeout_count >= 2000) begin

                $display(
                    "FAIL: Timeout while waiting for 0x%02h",
                    test_data
                );

                fail_count = fail_count + 1;

            end else if (rx_data !== test_data) begin

                $display(
                    "FAIL: Sent 0x%02h, received 0x%02h",
                    test_data,
                    rx_data
                );

                fail_count = fail_count + 1;

            end else begin

                $display(
                    "PASS: Sent 0x%02h, received 0x%02h",
                    test_data,
                    rx_data
                );

                pass_count = pass_count + 1;

            end

            // Wait until the current transmission finishes.
            wait (tx_busy == 1'b0);

            repeat (2) @(negedge clk);
        end
    endtask

    initial begin

        // Enable waveform generation.
        $dumpfile("uart_waveform.vcd");
        $dumpvars(0, uart_tb);

        rst = 1'b1;
        tx_start = 1'b0;
        tx_data = 8'h00;

        pass_count = 0;
        fail_count = 0;
        timeout_count = 0;

        repeat (5) @(negedge clk);

        rst = 1'b0;

        repeat (5) @(negedge clk);

        $display("------------------------------------");
        $display("Starting UART loopback tests");
        $display("------------------------------------");

        transmit_and_check(8'h00);
        transmit_and_check(8'hFF);
        transmit_and_check(8'hA5);
        transmit_and_check(8'h55);
        transmit_and_check(8'h81);

        $display("------------------------------------");
        $display("Tests passed: %0d", pass_count);
        $display("Tests failed: %0d", fail_count);

        if (fail_count == 0)
            $display("OVERALL RESULT: PASS");
        else
            $display("OVERALL RESULT: FAIL");

        $display("Waveform: uart_waveform.vcd");
        $display("------------------------------------");

        $finish;
    end

endmodule
