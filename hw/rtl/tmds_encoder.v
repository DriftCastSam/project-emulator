// TMDS 8b/10b encoder, DVI 1.0 section 3.2.
// Three-stage pipeline: minimise transitions, balance DC, register output.
// The output for a pixel appears three pixel clocks after its inputs.

`timescale 1ns/1ps

`default_nettype none

module tmds_encoder (
    input  wire       clk,
    input  wire       rst,
    input  wire       de,      // data enable: 1 = pixel, 0 = control period
    input  wire       c0,      // control bit 0 (hsync on the blue lane)
    input  wire       c1,      // control bit 1 (vsync on the blue lane)
    input  wire [7:0] d,       // pixel component
    output reg  [9:0] q        // encoded symbol, LSB transmitted first
);

    // ---------------------------------------------------------------- stage 1
    function [3:0] popcount8;
        input [7:0] v;
        integer i;
        begin
            popcount8 = 4'd0;
            for (i = 0; i < 8; i = i + 1)
                popcount8 = popcount8 + {3'b000, v[i]};
        end
    endfunction

    reg [7:0] d1;
    reg       de1, c01, c11;
    reg [3:0] n1d1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            d1   <= 8'h00;
            de1  <= 1'b0;
            c01  <= 1'b0;
            c11  <= 1'b0;
            n1d1 <= 4'd0;
        end else begin
            d1   <= d;
            de1  <= de;
            c01  <= c0;
            c11  <= c1;
            n1d1 <= popcount8(d);
        end
    end

    // Two candidate encodings, pick the one with fewer transitions.
    reg [8:0] qm_xor;
    reg [8:0] qm_xnor;
    integer k;

    always @(*) begin
        qm_xor[0]  = d1[0];
        qm_xnor[0] = d1[0];
        for (k = 1; k < 8; k = k + 1) begin
            qm_xor[k]  = qm_xor[k-1]  ^  d1[k];
            qm_xnor[k] = qm_xnor[k-1] ~^ d1[k];
        end
        qm_xor[8]  = 1'b1;
        qm_xnor[8] = 1'b0;
    end

    wire [8:0] qm1 = (n1d1 > 4 || (n1d1 == 4 && d1[0] == 1'b0)) ? qm_xnor : qm_xor;
    wire [3:0] n1qm1 = popcount8(qm1[7:0]);

    // ---------------------------------------------------------------- stage 2
    reg [8:0] qm2;
    reg [3:0] n1qm2, n0qm2;
    reg       de2, c02, c12;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            qm2   <= 9'd0;
            n1qm2 <= 4'd0;
            n0qm2 <= 4'd8;
            de2   <= 1'b0;
            c02   <= 1'b0;
            c12   <= 1'b0;
        end else begin
            qm2   <= qm1;
            n1qm2 <= n1qm1;
            n0qm2 <= 4'd8 - n1qm1;
            de2   <= de1;
            c02   <= c01;
            c12   <= c11;
        end
    end

    // ---------------------------------------------------------------- stage 3
    localparam [9:0] TOKEN_00 = 10'b1101010100;
    localparam [9:0] TOKEN_01 = 10'b0010101011;
    localparam [9:0] TOKEN_10 = 10'b0101010100;
    localparam [9:0] TOKEN_11 = 10'b1010101011;

    reg signed [4:0] cnt;      // running DC balance, -8 .. +8
    reg signed [4:0] cnt_next;
    reg [9:0] qout_next;

    wire signed [4:0] dc_bias = $signed({1'b0, n0qm2}) - $signed({1'b0, n1qm2});
    wire balanced     = (cnt == 5'sd0) || (n1qm2 == 4'd4);
    wire not_balanced = (cnt > 5'sd0 && n1qm2 > 4'd4) ||
                        (cnt < 5'sd0 && n1qm2 < 4'd4);

    always @(*) begin
        if (!de2) begin
            case ({c12, c02})
                2'b00:   qout_next = TOKEN_00;
                2'b01:   qout_next = TOKEN_01;
                2'b10:   qout_next = TOKEN_10;
                default: qout_next = TOKEN_11;
            endcase
            cnt_next = 5'sd0;
        end else if (balanced) begin
            if (qm2[8] == 1'b0) begin
                qout_next = {1'b1, 1'b0, ~qm2[7:0]};
                cnt_next  = cnt + dc_bias;
            end else begin
                qout_next = {1'b0, 1'b1, qm2[7:0]};
                cnt_next  = cnt - dc_bias;
            end
        end else if (not_balanced) begin
            qout_next = {1'b1, qm2[8], ~qm2[7:0]};
            cnt_next  = cnt + (qm2[8] ? 5'sd2 : 5'sd0) + dc_bias;
        end else begin
            qout_next = {1'b0, qm2[8], qm2[7:0]};
            cnt_next  = cnt - (qm2[8] ? 5'sd0 : 5'sd2) - dc_bias;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 5'sd0;
            q   <= 10'd0;
        end else begin
            cnt <= cnt_next;
            q   <= qout_next;
        end
    end

endmodule

`default_nettype wire
