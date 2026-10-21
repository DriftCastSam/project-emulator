// Self-checking testbench for the timing generator, using a small raster so
// the test finishes in a few hundred cycles.

`timescale 1ns/1ps

module tb_video_timing;

    localparam [11:0] H_ACTIVE = 12'd8;
    localparam [11:0] H_FP     = 12'd2;
    localparam [11:0] H_SYNC   = 12'd2;
    localparam [11:0] H_BP     = 12'd2;
    localparam [11:0] V_ACTIVE = 12'd4;
    localparam [11:0] V_FP     = 12'd1;
    localparam [11:0] V_SYNC   = 12'd1;
    localparam [11:0] V_BP     = 12'd1;

    localparam integer H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam integer V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;

    reg         clk = 0;
    reg         rst = 1;
    wire [11:0] x, y;
    wire        hsync, vsync, de, frame_tick;

    reg     counting = 0;
    integer de_count = 0;
    integer hs_count = 0;
    integer vs_count = 0;
    integer ft_count = 0;
    integer errors   = 0;
    integer cycles   = 0;

    video_timing #(
        .H_ACTIVE (H_ACTIVE), .H_FP (H_FP), .H_SYNC (H_SYNC), .H_BP (H_BP),
        .V_ACTIVE (V_ACTIVE), .V_FP (V_FP), .V_SYNC (V_SYNC), .V_BP (V_BP)
    ) dut (
        .clk (clk), .rst (rst), .x (x), .y (y),
        .hsync (hsync), .vsync (vsync), .de (de), .frame_tick (frame_tick)
    );

    always #5 clk = ~clk;

    // Sample in the middle of the cycle, only while counting.
    always @(negedge clk) begin
        if (counting) begin
            cycles = cycles + 1;
            if (de)        de_count = de_count + 1;
            if (hsync)     hs_count = hs_count + 1;
            if (vsync)     vs_count = vs_count + 1;
            if (frame_tick) ft_count = ft_count + 1;
            if (x >= H_TOTAL || y >= V_TOTAL) begin
                $display("FAIL: counter out of range x=%0d y=%0d", x, y);
                errors = errors + 1;
            end
        end
    end

    initial begin
        repeat (2) @(posedge clk);
        rst = 0;

        // Start counting at the first frame boundary after reset.
        @(negedge clk);
        while (!frame_tick) @(negedge clk);
        cycles = 0;
        de_count = 0;
        hs_count = 0;
        vs_count = 0;
        ft_count = 0;
        counting = 1;

        repeat (2 * H_TOTAL * V_TOTAL) @(negedge clk);
        counting = 0;
        @(negedge clk);

        if (de_count != 2 * H_ACTIVE * V_ACTIVE) begin
            $display("FAIL: de_count=%0d expected %0d", de_count, 2 * H_ACTIVE * V_ACTIVE);
            errors = errors + 1;
        end
        if (hs_count != 2 * V_TOTAL * H_SYNC) begin
            $display("FAIL: hs_count=%0d expected %0d", hs_count, 2 * V_TOTAL * H_SYNC);
            errors = errors + 1;
        end
        if (vs_count != 2 * H_TOTAL * V_SYNC) begin
            $display("FAIL: vs_count=%0d expected %0d", vs_count, 2 * H_TOTAL * V_SYNC);
            errors = errors + 1;
        end
        if (ft_count != 2) begin
            $display("FAIL: frame_tick count=%0d expected 2", ft_count);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: video_timing (%0d cycles)", cycles);
        else
            $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
