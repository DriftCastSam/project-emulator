// Bring-up pattern: 8 colour bars, a moving box, and a grey ramp.
// Everything is generated from the pixel coordinates, so it is trivial to
// prove that the timing generator, the encoders, and the pins all agree.

`timescale 1ns/1ps

`default_nettype none

module test_pattern (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_tick,
    input  wire [11:0] x,
    input  wire [11:0] y,
    input  wire        enable,
    input  wire        animate,
    output reg  [23:0] rgb
);

    localparam [11:0] BOX_W     = 12'd64;
    localparam [11:0] BOX_H     = 12'd64;
    localparam [11:0] BOX_MAX_X = 12'd1216;
    localparam [11:0] BOX_Y     = 12'd328;

    reg [11:0] box_x;

    wire [11:0] box_next = box_x + 12'd4;

    always @(posedge clk or posedge rst) begin
        if (rst)
            box_x <= 12'd0;
        else if (frame_tick && animate)
            box_x <= (box_next >= BOX_MAX_X) ? 12'd0 : box_next;
    end

    // 1280 / 8 = 160 pixels per bar.
    reg [23:0] bar_colour;
    always @(*) begin
        if      (x < 12'd160) bar_colour = 24'hFFFFFF; // white
        else if (x < 12'd320) bar_colour = 24'hFFFF00; // yellow
        else if (x < 12'd480) bar_colour = 24'h00FFFF; // cyan
        else if (x < 12'd640) bar_colour = 24'h00FF00; // green
        else if (x < 12'd800) bar_colour = 24'hFF00FF; // magenta
        else if (x < 12'd960) bar_colour = 24'hFF0000; // red
        else if (x < 12'd1120) bar_colour = 24'h0000FF; // blue
        else                   bar_colour = 24'h000000; // black
    end

    wire [11:0] box_right  = box_x + BOX_W;
    wire [11:0] box_bottom = BOX_Y + BOX_H;

    wire in_box = (x >= box_x) && (x < box_right) &&
                  (y >= BOX_Y) && (y < box_bottom);

    wire in_ramp = (y >= 720 - 24);

    always @(*) begin
        if (!enable)
            rgb = 24'h000000;
        else if (in_box)
            rgb = 24'hFFFFFF;
        else if (in_ramp)
            rgb = {x[9:2], x[9:2], x[9:2]};
        else
            rgb = bar_colour;
    end

endmodule

`default_nettype wire
