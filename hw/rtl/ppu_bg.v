// PPU background renderer, phase 5a.
//
// Renders one 256-pixel scanline of background from the loopy V register as it
// stands at the start of the line, before the two prefetch tiles. Nametable and
// pattern reads go through synchronous memory ports (one cycle of latency), so
// the address is held for one wait cycle before the data is captured.
//
// Output is one 4-bit background palette index per pixel: 0 for a transparent
// pixel, {attr, pattern} otherwise. Masking, palette lookup and colour live in
// ppu_render. This block is not dot-accurate: a tile takes 9 fetch cycles plus 8
// pixel cycles, far inside the 5000 cycles available per line at 74.25 MHz.
//
// Loopy V layout: [14:12] fine Y, [11:10] nametable, [9:5] coarse Y, [4:0] coarse X.

`timescale 1ns/1ps

module ppu_bg (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,       // pulse; latches v, fine_x and bg_tbl
    input  wire [14:0] v,
    input  wire [2:0]  fine_x,
    input  wire        bg_tbl,      // PPUCTRL bit 4: pattern table at $0000 / $1000

    output reg  [12:0] chr_addr,    // pattern table read, 1 cycle latency
    input  wire [7:0]  chr_data,
    output reg  [11:0] nt_addr,     // nametable space $2000-$2FFF, 1 cycle latency
    input  wire [7:0]  nt_data,

    output reg         busy,
    output reg         px_valid,
    output reg  [7:0]  px_x,
    output reg  [3:0]  px_val,
    output reg         done         // pulse on the cycle after the last pixel
);

    reg [14:0] v_r;
    reg [2:0]  fx_r;
    reg        tbl_r;

    reg [5:0]  tile;                // 0..32, 33 tiles cover 256 pixels at any fine X
    reg [3:0]  ph;
    reg [2:0]  j;

    reg [7:0]  nt_byte, at_byte, lo, hi;
    reg [1:0]  attr;

    // Address of tile `tile`: coarse X advances and carries into the nametable
    // select bit, exactly like repeated h_scroll in the real PPU.
    wire [5:0] cx_sum = {1'b0, v_r[4:0]} + tile;
    wire [4:0] cx_t   = cx_sum[4:0];
    wire [1:0] nt_t   = {v_r[11], v_r[10] ^ cx_sum[5]};
    wire [4:0] cy     = v_r[9:5];
    wire [2:0] fy     = v_r[14:12];

    wire [1:0] at_sel = {cy[1], cx_t[1]};
    wire [1:0] at_pair = (at_sel == 2'd0) ? at_byte[1:0] :
                         (at_sel == 2'd1) ? at_byte[3:2] :
                         (at_sel == 2'd2) ? at_byte[5:4] : at_byte[7:6];

    // Position of this pixel in the unscrolled 264-pixel strip, and its place
    // on screen once fine X has been subtracted.
    wire [8:0] strip = {tile, j};
    wire [8:0] x_off = strip - {6'b0, fx_r};
    wire       in_view = (strip >= {6'b0, fx_r}) && (x_off < 9'd256);
    wire [1:0] px = {hi[3'd7 - j], lo[3'd7 - j]};

    always @(posedge clk) begin
        px_valid <= 1'b0;
        done     <= 1'b0;

        if (rst) begin
            busy <= 1'b0;
            ph   <= 4'd0;
        end else if (start && !busy) begin
            v_r   <= v;
            fx_r  <= fine_x;
            tbl_r <= bg_tbl;
            tile  <= 6'd0;
            ph    <= 4'd0;
            busy  <= 1'b1;
        end else if (busy) begin
            case (ph)
                4'd0: begin nt_addr <= {nt_t, cy, cx_t}; ph <= 4'd1; end
                4'd1: ph <= 4'd2;
                4'd2: begin
                    nt_byte <= nt_data;
                    nt_addr <= {nt_t, 4'b1111, cy[4:2], cx_t[4:2]};
                    ph      <= 4'd3;
                end
                4'd3: ph <= 4'd4;
                4'd4: begin
                    at_byte  <= nt_data;
                    chr_addr <= {tbl_r, nt_byte, 1'b0, fy};
                    ph       <= 4'd5;
                end
                4'd5: ph <= 4'd6;
                4'd6: begin
                    lo       <= chr_data;
                    chr_addr <= {tbl_r, nt_byte, 1'b1, fy};
                    ph       <= 4'd7;
                end
                4'd7: ph <= 4'd8;
                4'd8: begin
                    hi   <= chr_data;
                    attr <= at_pair;
                    j    <= 3'd0;
                    ph   <= 4'd9;
                end
                4'd9: begin
                    if (in_view) begin
                        px_valid <= 1'b1;
                        px_x     <= x_off[7:0];
                        px_val   <= (px == 2'b00) ? 4'd0 : {attr, px};
                    end
                    if (j == 3'd7) begin
                        if (tile == 6'd32) begin
                            busy <= 1'b0;
                            done <= 1'b1;
                        end else begin
                            tile <= tile + 6'd1;
                            ph   <= 4'd0;
                        end
                    end
                    j <= j + 3'd1;
                end
                default: ph <= 4'd0;
            endcase
        end
    end

endmodule
