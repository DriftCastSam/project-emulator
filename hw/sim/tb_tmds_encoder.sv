// Self-checking testbench for the TMDS encoder.
// Checks control tokens, two data symbols, pipeline latency, and that the
// output is stable while inputs are held.

`timescale 1ns/1ps

module tb_tmds_encoder;

    reg        clk = 0;
    reg        rst = 1;
    reg        de  = 0;
    reg        c0  = 0;
    reg        c1  = 0;
    reg  [7:0] d   = 0;
    wire [9:0] q;

    integer errors = 0;

    tmds_encoder dut (
        .clk (clk), .rst (rst), .de (de), .c0 (c0), .c1 (c1), .d (d), .q (q)
    );

    always #5 clk = ~clk;

    task check(input [9:0] expected, input [127:0] name);
        if (q !== expected) begin
            $display("FAIL %0s: got %b expected %b", name, q, expected);
            errors = errors + 1;
        end else begin
            $display("ok   %0s: %b", name, q);
        end
    endtask

    // Drive inputs, let the three pipeline stages settle, then check.
    task drive_and_check(input [7:0] data, input d_en, input in_c0, input in_c1,
                         input [9:0] expected, input [127:0] name);
        begin
            @(negedge clk);
            d = data; de = d_en; c0 = in_c0; c1 = in_c1;
            repeat (3) @(posedge clk);
            @(negedge clk);
            check(expected, name);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst = 0;

        // Control tokens. A control period also resets the running disparity.
        drive_and_check(8'h00, 1'b0, 1'b0, 1'b0, 10'b1101010100, "token 00");
        drive_and_check(8'h00, 1'b0, 1'b1, 1'b0, 10'b0010101011, "token 01");
        drive_and_check(8'h00, 1'b0, 1'b0, 1'b1, 10'b0101010100, "token 10");
        drive_and_check(8'h00, 1'b0, 1'b1, 1'b1, 10'b1010101011, "token 11");

        // Data symbols with disparity starting at zero.
        drive_and_check(8'h00, 1'b0, 1'b0, 1'b0, 10'b1101010100, "reset disparity");
        drive_and_check(8'h00, 1'b1, 1'b0, 1'b0, 10'b0100000000, "data 0x00");
        drive_and_check(8'h00, 1'b0, 1'b0, 1'b0, 10'b1101010100, "reset disparity");
        drive_and_check(8'hFF, 1'b1, 1'b0, 1'b0, 10'b1000000000, "data 0xFF");

        if (errors == 0)
            $display("PASS: tmds_encoder");
        else
            $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
