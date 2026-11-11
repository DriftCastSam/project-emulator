// Compares the background renderer against golden frames recorded from the
// LaiNES PPU (sw/nes/test/ppu_golden.cpp). Run with +vec=<dir>.

`timescale 1ns/1ps

module tb_ppu_render;

    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;

    reg  [1:0]  mirror = 0;
    reg         chr_we = 0;
    reg  [12:0] chr_waddr = 0;
    reg  [7:0]  chr_wdata = 0;
    reg         nt_we = 0;
    reg  [11:0] nt_waddr = 0;
    reg  [7:0]  nt_wdata = 0;
    reg         pal_we = 0;
    reg  [4:0]  pal_waddr = 0;
    reg  [5:0]  pal_wdata = 0;

    reg         line_start = 0;
    reg  [14:0] v = 0;
    reg  [2:0]  fine_x = 0;
    reg         bg_tbl = 0, bg_en = 0, bg_left = 0, gray = 0;

    wire        busy, out_valid, line_done;
    wire [7:0]  out_x;
    wire [15:0] out_rgb;

    ppu_render dut (
        .clk (clk), .rst (rst),
        .mirror (mirror),
        .chr_we (chr_we), .chr_waddr (chr_waddr), .chr_wdata (chr_wdata),
        .nt_we (nt_we), .nt_waddr (nt_waddr), .nt_wdata (nt_wdata),
        .pal_we (pal_we), .pal_waddr (pal_waddr), .pal_wdata (pal_wdata),
        .line_start (line_start), .v (v), .fine_x (fine_x), .bg_tbl (bg_tbl),
        .bg_en (bg_en), .bg_left (bg_left), .gray (gray),
        .busy (busy), .out_valid (out_valid), .out_x (out_x), .out_rgb (out_rgb),
        .line_done (line_done)
    );

    reg [7:0]  chr_mem [0:8191];
    reg [7:0]  nt_mem  [0:4095];
    reg [7:0]  pal_mem [0:31];
    reg [3:0]  cfg_mem [0:0];
    reg [31:0] lines_mem [0:239];
    reg [15:0] expect_mem [0:61439];

    reg [255:0] seen;
    string dir;
    integer errors = 0;
    integer shown = 0;
    integer pixels = 0;
    integer line, i;
    integer cur_line = 0;


    // Check every pixel as it streams out.
    always @(posedge clk) begin
        if (out_valid) begin
            if (seen[out_x]) begin
                errors = errors + 1;
                if (shown < 10) begin
                    $display("line %0d x %0d: pixel emitted twice", cur_line, out_x);
                    shown = shown + 1;
                end
            end
            seen[out_x] <= 1'b1;
            pixels = pixels + 1;
            if (out_rgb !== expect_mem[cur_line * 256 + out_x]) begin
                errors = errors + 1;
                if (shown < 10) begin
                    $display("line %0d x %0d: got %04x expected %04x",
                             cur_line, out_x, out_rgb, expect_mem[cur_line * 256 + out_x]);
                    shown = shown + 1;
                end
            end
        end
    end

    initial begin
        if (!$value$plusargs("vec=%s", dir)) $fatal(1, "run with +vec=<dir>");
        $readmemh({dir, "/chr.mem"}, chr_mem);
        $readmemh({dir, "/nt.mem"}, nt_mem);
        $readmemh({dir, "/pal.mem"}, pal_mem);
        $readmemh({dir, "/cfg.mem"}, cfg_mem);
        $readmemh({dir, "/lines.mem"}, lines_mem);
        $readmemh({dir, "/expect.mem"}, expect_mem);

        repeat (4) @(posedge clk);
        rst <= 0;
        mirror <= cfg_mem[0][1:0];

        // Load the memories through the PS write ports.
        for (i = 0; i < 8192; i = i + 1) begin
            @(posedge clk);
            chr_we <= 1; chr_waddr <= i[12:0]; chr_wdata <= chr_mem[i];
        end
        @(posedge clk); chr_we <= 0;
        for (i = 0; i < 4096; i = i + 1) begin
            @(posedge clk);
            nt_we <= 1; nt_waddr <= i[11:0]; nt_wdata <= nt_mem[i];
        end
        @(posedge clk); nt_we <= 0;
        for (i = 0; i < 32; i = i + 1) begin
            @(posedge clk);
            pal_we <= 1; pal_waddr <= i[4:0]; pal_wdata <= pal_mem[i][5:0];
        end
        @(posedge clk); pal_we <= 0;
        repeat (4) @(posedge clk);

        for (line = 0; line < 240; line = line + 1) begin
            cur_line = line;
            seen = 256'b0;
            @(posedge clk);
            v       <= lines_mem[line][14:0];
            fine_x  <= lines_mem[line][17:15];
            bg_tbl  <= lines_mem[line][18];
            bg_en   <= lines_mem[line][19];
            bg_left <= lines_mem[line][20];
            gray    <= lines_mem[line][21];
            line_start <= 1;
            @(posedge clk);
            line_start <= 0;
            wait (line_done);
            @(posedge clk);
            if (seen !== {256{1'b1}}) begin
                errors = errors + 1;
                if (shown < 10) begin
                    $display("line %0d: only %0d of 256 pixels emitted", line, $countones(seen));
                    shown = shown + 1;
                end
            end
        end

        if (errors == 0)
            $display("PASS: ppu_render (%0d pixels, mirroring %0d)", pixels, cfg_mem[0]);
        else
            $fatal(1, "FAIL: ppu_render %0d errors (%s)", errors, dir);
        $finish;
    end

    initial begin
        #2000000000;
        $fatal(1, "FAIL: timeout");
    end

endmodule
