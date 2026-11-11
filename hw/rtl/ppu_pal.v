// Palette RAM and colour lookup.
//
// 32 entries of 6 bits. Entries $10, $14, $18 and $1C pal_alias $00, $04, $08 and
// $0C on both read and write, as on a 2C02. Grayscale masks the colour to its
// luminance column. The result is RGB565 one cycle after idx.
//
// Emphasis bits (PPUMASK 7:5) are not implemented yet.

`timescale 1ns/1ps

module ppu_pal (
    input  wire        clk,

    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [5:0]  wdata,

    input  wire [4:0]  idx,
    input  wire        gray,
    output reg  [15:0] rgb
);

    reg [5:0] ram [0:31];

    function [4:0] pal_alias(input [4:0] a);
        pal_alias = (a[4] && a[1:0] == 2'b00) ? {1'b0, a[3:0]} : a;
    endfunction

    integer i;
    initial for (i = 0; i < 32; i = i + 1) ram[i] = 6'd0;

    wire [4:0] pal_waddr_a = pal_alias(waddr);
    wire [4:0] pal_idx_a   = pal_alias(idx);

    always @(posedge clk)
        if (we) ram[pal_waddr_a] <= wdata;

    wire [5:0]  color = ram[pal_idx_a] & (gray ? 6'h30 : 6'h3F);
    wire [15:0] rom_rgb;
    nes_pal_rom rom (.idx(color), .rgb(rom_rgb));

    always @(posedge clk) rgb <= rom_rgb;

endmodule
