// PPU video memories: 8 KiB pattern table (CHR RAM) and 2 KiB nametable RAM
// with the mirroring a mapper selects. The PS writes through simple ports, the
// renderer reads with one cycle of latency. Both write ports and both read
// ports are independent so each memory infers a simple dual-port block RAM.
//
// mirror: 0 vertical, 1 horizontal, 2 one-screen upper, 3 one-screen lower.
// Four-screen cartridges need 4 KiB of nametable RAM and are not supported.

`timescale 1ns/1ps

module ppu_mem (
    input  wire        clk,
    input  wire [1:0]  mirror,

    input  wire        chr_we,
    input  wire [12:0] chr_waddr,
    input  wire [7:0]  chr_wdata,
    input  wire [12:0] chr_raddr,
    output reg  [7:0]  chr_rdata,

    input  wire        nt_we,
    input  wire [11:0] nt_waddr,    // $2000-$2FFF offset, mirrored on write
    input  wire [7:0]  nt_wdata,
    input  wire [11:0] nt_raddr,    // mirrored on read
    output reg  [7:0]  nt_rdata
);

    reg [7:0] chr [0:8191];
    reg [7:0] ciram [0:2047];

    function [10:0] nt_map(input [11:0] a, input [1:0] m);
        case (m)
            2'd0:    nt_map = a[10:0];              // vertical: A11 ignored
            2'd1:    nt_map = {a[11], a[9:0]};      // horizontal: A10 ignored
            2'd2:    nt_map = {1'b1, a[9:0]};
            default: nt_map = {1'b0, a[9:0]};
        endcase
    endfunction

    always @(posedge clk) begin
        if (chr_we) chr[chr_waddr] <= chr_wdata;
        chr_rdata <= chr[chr_raddr];
    end

    wire [10:0] ci_waddr = nt_map(nt_waddr, mirror);
    wire [10:0] ci_raddr = nt_map(nt_raddr, mirror);

    always @(posedge clk) begin
        if (nt_we) ciram[ci_waddr] <= nt_wdata;
        nt_rdata <= ciram[ci_raddr];
    end

endmodule
