// Background scanline renderer: ppu_bg + ppu_mem + ppu_pal.
//
// The caller pulses line_start once per visible scanline with the line state
// (loopy V before the prefetch, fine X, PPUCTRL/PPUMASK bits). Pixels stream
// out as out_valid/out_x/out_rgb, two cycles after ppu_bg produces them, and
// line_done pulses after the last one. The PS writes the memories through the
// chr_/nt_/pal_ write ports.

`timescale 1ns/1ps

module ppu_render (
    input  wire        clk,
    input  wire        rst,

    // memory write ports (PS side)
    input  wire [1:0]  mirror,
    input  wire        chr_we,
    input  wire [12:0] chr_waddr,
    input  wire [7:0]  chr_wdata,
    input  wire        nt_we,
    input  wire [11:0] nt_waddr,
    input  wire [7:0]  nt_wdata,
    input  wire        pal_we,
    input  wire [4:0]  pal_waddr,
    input  wire [5:0]  pal_wdata,

    // line state
    input  wire        line_start,
    input  wire [14:0] v,
    input  wire [2:0]  fine_x,
    input  wire        bg_tbl,      // PPUCTRL[4]
    input  wire        bg_en,       // PPUMASK[3]
    input  wire        bg_left,     // PPUMASK[1]
    input  wire        gray,        // PPUMASK[0]

    // pixel stream
    output wire        busy,
    output reg         out_valid,
    output reg  [7:0]  out_x,
    output wire [15:0] out_rgb,
    output wire        line_done
);

    wire [12:0] chr_raddr;
    wire [7:0]  chr_rdata;
    wire [11:0] nt_raddr;
    wire [7:0]  nt_rdata;

    wire       bg_done;
    wire       px_valid;
    wire [7:0] px_x;
    wire [3:0] px_val;

    ppu_mem mem (
        .clk (clk), .mirror (mirror),
        .chr_we (chr_we), .chr_waddr (chr_waddr), .chr_wdata (chr_wdata),
        .chr_raddr (chr_raddr), .chr_rdata (chr_rdata),
        .nt_we (nt_we), .nt_waddr (nt_waddr), .nt_wdata (nt_wdata),
        .nt_raddr (nt_raddr), .nt_rdata (nt_rdata)
    );

    ppu_bg bg (
        .clk (clk), .rst (rst), .start (line_start),
        .v (v), .fine_x (fine_x), .bg_tbl (bg_tbl),
        .chr_addr (chr_raddr), .chr_data (chr_rdata),
        .nt_addr (nt_raddr), .nt_data (nt_rdata),
        .busy (busy), .px_valid (px_valid), .px_x (px_x), .px_val (px_val),
        .done (bg_done)
    );

    // Disabled background, or the left 8 pixels when clipped, show the backdrop.
    wire show = bg_en && (px_x >= 8'd8 || bg_left);
    wire [4:0] pal_idx = show ? {1'b0, px_val} : 5'd0;

    ppu_pal pal (
        .clk (clk),
        .we (pal_we), .waddr (pal_waddr), .wdata (pal_wdata),
        .idx (pal_idx), .gray (gray), .rgb (out_rgb)
    );

    // The palette adds one cycle; delay valid, x and done to match.
    reg done_d;
    always @(posedge clk) begin
        out_valid <= px_valid;
        out_x     <= px_x;
        done_d    <= bg_done;
    end
    assign line_done = done_d;

endmodule
