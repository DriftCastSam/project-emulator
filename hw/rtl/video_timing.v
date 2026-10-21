// CEA-861 style video timing generator.
// Defaults to 1280x720p60 with a 74.25 MHz pixel clock.

`timescale 1ns/1ps

`default_nettype none

module video_timing #(
    parameter [11:0] H_ACTIVE = 12'd1280,
    parameter [11:0] H_FP     = 12'd110,
    parameter [11:0] H_SYNC   = 12'd40,
    parameter [11:0] H_BP     = 12'd220,
    parameter [11:0] V_ACTIVE = 12'd720,
    parameter [11:0] V_FP     = 12'd5,
    parameter [11:0] V_SYNC   = 12'd5,
    parameter [11:0] V_BP     = 12'd20
) (
    input  wire       clk,
    input  wire       rst,
    output reg  [11:0] x,
    output reg  [11:0] y,
    output wire       hsync,
    output wire       vsync,
    output wire       de,
    output wire       frame_tick
);

    localparam [11:0] H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam [11:0] V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;

    wire h_last = (x == H_TOTAL - 1);
    wire v_last = (y == V_TOTAL - 1);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x <= 12'd0;
            y <= 12'd0;
        end else if (h_last) begin
            x <= 12'd0;
            y <= v_last ? 12'd0 : y + 12'd1;
        end else begin
            x <= x + 12'd1;
        end
    end

    // Positive sync polarity for 720p.
    assign hsync = (x >= H_ACTIVE + H_FP) && (x < H_ACTIVE + H_FP + H_SYNC);
    assign vsync = (y >= V_ACTIVE + V_FP) && (y < V_ACTIVE + V_FP + V_SYNC);
    assign de    = (x < H_ACTIVE) && (y < V_ACTIVE);

    assign frame_tick = (x == 12'd0) && (y == 12'd0);

endmodule

`default_nettype wire
