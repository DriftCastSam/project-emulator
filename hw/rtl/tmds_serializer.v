// 10:1 DDR serializer for one TMDS lane.
// Uses a master/slave OSERDESE2 pair, the same structure as Digilent's
// rgb2dvi reference for 7-series parts.
//
// Not simulated by Verilator: these are Xilinx primitives. The encoder above
// the serializer is what the unit tests cover; Vivado covers this file during
// synthesis and implementation.

`default_nettype none

module tmds_serializer (
    input  wire       pixel_clk,   // 1x, drives CLKDIV
    input  wire       serial_clk,  // 5x, drives CLK
    input  wire       rst,
    input  wire [9:0] data,        // data[0] is transmitted first
    output wire       tmds_p,
    output wire       tmds_n
);

    wire cascade1, cascade2;
    wire serial;

    OSERDESE2 #(
        .DATA_RATE_OQ   ("DDR"),
        .DATA_RATE_TQ   ("SDR"),
        .DATA_WIDTH     (10),
        .TRISTATE_WIDTH (1),
        .TBYTE_CTL      ("FALSE"),
        .TBYTE_SRC      ("FALSE"),
        .SERDES_MODE    ("MASTER")
    ) master (
        .OFB       (),
        .OQ        (serial),
        .SHIFTOUT1 (),
        .SHIFTOUT2 (),
        .TBYTEOUT  (),
        .TFB       (),
        .TQ        (),
        .CLK       (serial_clk),
        .CLKDIV    (pixel_clk),
        .D1        (data[0]),
        .D2        (data[1]),
        .D3        (data[2]),
        .D4        (data[3]),
        .D5        (data[4]),
        .D6        (data[5]),
        .D7        (data[6]),
        .D8        (data[7]),
        .OCE       (1'b1),
        .RST       (rst),
        .SHIFTIN1  (cascade1),
        .SHIFTIN2  (cascade2),
        .T1        (1'b0),
        .T2        (1'b0),
        .T3        (1'b0),
        .T4        (1'b0),
        .TBYTEIN   (1'b0),
        .TCE       (1'b0)
    );

    OSERDESE2 #(
        .DATA_RATE_OQ   ("DDR"),
        .DATA_RATE_TQ   ("SDR"),
        .DATA_WIDTH     (10),
        .TRISTATE_WIDTH (1),
        .TBYTE_CTL      ("FALSE"),
        .TBYTE_SRC      ("FALSE"),
        .SERDES_MODE    ("SLAVE")
    ) slave (
        .OFB       (),
        .OQ        (),
        .SHIFTOUT1 (cascade1),
        .SHIFTOUT2 (cascade2),
        .TBYTEOUT  (),
        .TFB       (),
        .TQ        (),
        .CLK       (serial_clk),
        .CLKDIV    (pixel_clk),
        .D1        (1'b0),
        .D2        (1'b0),
        .D3        (data[8]),
        .D4        (data[9]),
        .D5        (1'b0),
        .D6        (1'b0),
        .D7        (1'b0),
        .D8        (1'b0),
        .OCE       (1'b1),
        .RST       (rst),
        .SHIFTIN1  (1'b0),
        .SHIFTIN2  (1'b0),
        .T1        (1'b0),
        .T2        (1'b0),
        .T3        (1'b0),
        .T4        (1'b0),
        .TBYTEIN   (1'b0),
        .TCE       (1'b0)
    );

    OBUFDS #(
        .IOSTANDARD ("TMDS_33")
    ) output_buffer (
        .O  (tmds_p),
        .OB (tmds_n),
        .I  (serial)
    );

endmodule

`default_nettype wire
