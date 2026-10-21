// Video front end: clocks, registers, timing, pattern, TMDS output.
//
// This is the module the block design sees. It has an AXI4-Lite control port
// on the PS clock domain and a TMDS output on the pixel clock domain.
//
// Clock plan for 1280x720p60:
//   125 MHz board oscillator
//     -> MMCM VCO 742.1875 MHz
//     -> 371.09375 MHz serial (BUFIO), pixel = serial / 5 (BUFR)
//   The pixel clock is derived from the serial clock through a BUFR so that
//   OSERDESE2 CLK and CLKDIV stay aligned, matching the Digilent reference.

`default_nettype none

module orbit_video (
    // Board oscillator, 125 MHz.
    input  wire        clk125,

    // AXI4-Lite control.
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 100000000" *)
    input  wire        s_axi_aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 s_axi_aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire        s_axi_aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI, PROTOCOL AXI4LITE, ADDR_WIDTH 32, DATA_WIDTH 32, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 1, ID_WIDTH 0, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, FREQ_HZ 100000000" *)
    input  wire [31:0] s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) input  wire        s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) output wire        s_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)   input  wire [31:0] s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)   input  wire [3:0]  s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)  input  wire        s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)  output wire        s_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)   output wire [1:0]  s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)  output wire        s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)  input  wire        s_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)  input  wire [31:0] s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) input  wire        s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) output wire        s_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)   output wire [31:0] s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)   output wire [1:0]  s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)  output wire        s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)  input  wire        s_axi_rready,

    // HDMI.
    output wire        hdmi_clk_p,
    output wire        hdmi_clk_n,
    output wire [2:0]  hdmi_data_p,
    output wire [2:0]  hdmi_data_n,
    output wire        hdmi_hpd,

    output wire [1:0]  led
);

    // ------------------------------------------------------------- clocking
    //
    // One MMCM cannot make both 74.21875 and 371.09375 MHz from 125 MHz with
    // the 0.125 multiplier granularity, so the reference clock is generated
    // first and multiplied by 10 in a second MMCM.
    //
    //   MMCM1: 125 MHz * 7.125 / 12 = 74.21875 MHz (VCO 890.625 MHz)
    //   MMCM2: 74.21875 MHz * 10    = 742.1875 MHz VCO
    //          CLKOUT0 / 2          = 371.09375 MHz serial
    //          CLKOUT1 / 10         = 74.21875 MHz pixel
    wire clk125_buf;
    wire clk_pixel_ref;
    wire clk_pixel_ref_raw;
    wire clk_fb_ref_out;
    wire clk_fb_ref_in;
    wire mmcm_ref_locked;

    wire clk_serial_raw;
    wire clk_serial;
    wire clk_pixel;
    wire clk_fb;
    wire clk_fb_buf;
    wire mmcm_locked;

    // Buffer the board clock before the MMCM. The oscillator pin and the
    // MMCM are not guaranteed to sit in the same clock region, and a direct
    // IOB-to-MMCM route is a placement error when they do not.
    BUFG u_clk125_bufg (
        .I (clk125),
        .O (clk125_buf)
    );

    reg [2:0] rst125_sync;
    always @(posedge clk125_buf or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn)
            rst125_sync <= 3'b000;
        else
            rst125_sync <= {rst125_sync[1:0], 1'b1};
    end
    wire rst125_n = rst125_sync[2];

    MMCME2_ADV #(
        .BANDWIDTH          ("OPTIMIZED"),
        .COMPENSATION       ("ZHOLD"),
        .STARTUP_WAIT       ("FALSE"),
        .DIVCLK_DIVIDE      (1),
        .CLKFBOUT_MULT_F    (7.125),    // VCO 890.625 MHz
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (8.000),
        .REF_JITTER1        (0.010),
        .CLKOUT0_DIVIDE_F   (12.000),   // 74.21875 MHz
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000)
    ) u_mmcm_ref (
        .CLKIN1      (clk125_buf),
        .CLKIN2      (1'b0),
        .CLKINSEL    (1'b1),
        .CLKFBIN     (clk_fb_ref_in),
        .CLKFBOUT    (clk_fb_ref_out),
        .CLKFBOUTB   (),
        .CLKOUT0     (clk_pixel_ref_raw),
        .CLKOUT0B    (),
        .CLKOUT1     (),
        .CLKOUT1B    (),
        .CLKOUT2     (),
        .CLKOUT2B    (),
        .CLKOUT3     (),
        .CLKOUT3B    (),
        .CLKOUT4     (),
        .CLKOUT5     (),
        .CLKOUT6     (),
        .LOCKED      (mmcm_ref_locked),
        .PWRDWN      (1'b0),
        .RST         (~rst125_n),
        .DADDR       (7'd0),
        .DCLK        (1'b0),
        .DEN         (1'b0),
        .DI          (16'd0),
        .DO          (),
        .DRDY        (),
        .DWE         (1'b0),
        .PSCLK       (1'b0),
        .PSEN        (1'b0),
        .PSINCDEC    (1'b0),
        .PSDONE      (),
        .CLKINSTOPPED(),
        .CLKFBSTOPPED()
    );

    BUFG u_fb_ref_bufg (
        .I (clk_fb_ref_out),
        .O (clk_fb_ref_in)
    );

    BUFG u_pixel_ref_bufg (
        .I (clk_pixel_ref_raw),
        .O (clk_pixel_ref)
    );

    MMCME2_ADV #(
        .BANDWIDTH          ("OPTIMIZED"),
        .COMPENSATION       ("ZHOLD"),
        .STARTUP_WAIT       ("FALSE"),
        .DIVCLK_DIVIDE      (1),
        .CLKFBOUT_MULT_F    (10.000),   // VCO 742.1875 MHz
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (13.4737),
        .REF_JITTER1        (0.010),
        .CLKOUT0_DIVIDE_F   (2.000),    // 371.09375 MHz, 5x pixel
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .CLKOUT1_DIVIDE     (10),       // 74.21875 MHz
        .CLKOUT1_DUTY_CYCLE (0.500),
        .CLKOUT1_PHASE      (0.000)
    ) u_mmcm (
        .CLKIN1      (clk_pixel_ref),
        .CLKIN2      (1'b0),
        .CLKINSEL    (1'b1),
        .CLKFBIN     (clk_fb_buf),
        .CLKFBOUT    (clk_fb),
        .CLKFBOUTB   (),
        .CLKOUT0     (clk_serial_raw),
        .CLKOUT0B    (),
        .CLKOUT1     (),
        .CLKOUT1B    (),
        .CLKOUT2     (),
        .CLKOUT2B    (),
        .CLKOUT3     (),
        .CLKOUT3B    (),
        .CLKOUT4     (),
        .CLKOUT5     (),
        .CLKOUT6     (),
        .LOCKED      (mmcm_locked),
        .PWRDWN      (1'b0),
        .RST         (~mmcm_ref_locked),
        .DADDR       (7'd0),
        .DCLK        (1'b0),
        .DEN         (1'b0),
        .DI          (16'd0),
        .DO          (),
        .DRDY        (),
        .DWE         (1'b0),
        .PSCLK       (1'b0),
        .PSEN        (1'b0),
        .PSINCDEC    (1'b0),
        .PSDONE      (),
        .CLKINSTOPPED(),
        .CLKFBSTOPPED()
    );

    // Feedback deskew: divide by one so serial and pixel clocks see the same
    // delay through the clock network.
    BUFR #(
        .BUFR_DIVIDE ("1"),
        .SIM_DEVICE  ("7SERIES")
    ) u_fb_bufr (
        .O   (clk_fb_buf),
        .CE  (1'b1),
        .CLR (1'b0),
        .I   (clk_fb)
    );

    BUFIO u_serial_bufio (
        .O (clk_serial),
        .I (clk_serial_raw)
    );

    BUFR #(
        .BUFR_DIVIDE ("5"),
        .SIM_DEVICE  ("7SERIES")
    ) u_pixel_bufr (
        .O   (clk_pixel),
        .CE  (1'b1),
        .CLR (~mmcm_locked),
        .I   (clk_serial_raw)
    );

    // Pixel-domain reset: held until the MMCM locks, released synchronously.
    reg [2:0] rst_px_sync;
    always @(posedge clk_pixel or negedge mmcm_locked) begin
        if (!mmcm_locked)
            rst_px_sync <= 3'b000;
        else
            rst_px_sync <= {rst_px_sync[1:0], 1'b1};
    end
    wire rst_px = ~rst_px_sync[2];

    // ---------------------------------------------------------- registers
    localparam [31:0] ID_VALUE = 32'h4F524231; // "ORB1"

    reg [31:0] ctrl;
    reg [31:0] scratch;
    reg [31:0] frame_count;
    reg        mmcm_locked_q;
    reg        vsync_q;

    reg        awready_r, wready_r, bvalid_r;
    reg        arready_r, rvalid_r;
    reg [31:0] rdata_r;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            ctrl      <= 32'h0000_0003; // pattern on, animate on
            scratch   <= 32'd0;
            awready_r <= 1'b0;
            wready_r  <= 1'b0;
            bvalid_r  <= 1'b0;
            arready_r <= 1'b0;
            rvalid_r  <= 1'b0;
            rdata_r   <= 32'd0;
        end else begin
            awready_r <= 1'b0;
            wready_r  <= 1'b0;
            arready_r <= 1'b0;
            rvalid_r  <= 1'b0;

            if (s_axi_awvalid && s_axi_wvalid && !bvalid_r) begin
                awready_r <= 1'b1;
                wready_r  <= 1'b1;
                bvalid_r  <= 1'b1;
                case (s_axi_awaddr[5:2])
                    4'h1: ctrl    <= s_axi_wdata;
                    4'h2: scratch <= s_axi_wdata;
                    default: ;
                endcase
            end

            if (bvalid_r && s_axi_bready)
                bvalid_r <= 1'b0;

            if (s_axi_arvalid && !rvalid_r) begin
                arready_r <= 1'b1;
                rvalid_r  <= 1'b1;
                case (s_axi_araddr[5:2])
                    4'h0: rdata_r <= ID_VALUE;
                    4'h1: rdata_r <= ctrl;
                    4'h2: rdata_r <= scratch;
                    4'h3: rdata_r <= {frame_count[15:0], 14'd0, mmcm_locked_q, vsync_q};
                    default: rdata_r <= 32'd0;
                endcase
            end

            if (rvalid_r && s_axi_rready)
                rvalid_r <= 1'b0;
        end
    end

    assign s_axi_awready = awready_r;
    assign s_axi_wready  = wready_r;
    assign s_axi_bvalid  = bvalid_r;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_arready = arready_r;
    assign s_axi_rvalid  = rvalid_r;
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = 2'b00;

    // ------------------------------------------------------- control CDC
    // ctrl bits are static; two flops is enough.
    reg [1:0] ctrl_s0, ctrl_s1;
    reg       pattern_en;
    reg       animate;

    always @(posedge clk_pixel) begin
        ctrl_s0    <= ctrl[1:0];
        ctrl_s1    <= ctrl_s0;
        pattern_en <= ctrl_s1[0];
        animate    <= ctrl_s1[1];
    end

    // Status CDC: one toggle per frame, synchronised into the AXI domain.
    reg frame_toggle;
    always @(posedge clk_pixel or posedge rst_px) begin
        if (rst_px)
            frame_toggle <= 1'b0;
        else if (frame_tick)
            frame_toggle <= ~frame_toggle;
    end

    reg [2:0] toggle_sync;
    reg       mmcm_locked_s;
    reg       vsync_s;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            toggle_sync    <= 3'b000;
            mmcm_locked_s  <= 1'b0;
            vsync_s        <= 1'b0;
            mmcm_locked_q  <= 1'b0;
            vsync_q        <= 1'b0;
            frame_count    <= 32'd0;
        end else begin
            toggle_sync   <= {toggle_sync[1:0], frame_toggle};
            mmcm_locked_s <= mmcm_locked;
            vsync_s       <= vsync;
            mmcm_locked_q <= mmcm_locked_s;
            vsync_q       <= vsync_s;
            if (toggle_sync[2] ^ toggle_sync[1])
                frame_count <= frame_count + 32'd1;
        end
    end

    // ------------------------------------------------------------- video
    wire [11:0] x, y;
    wire        hsync, vsync, de, frame_tick;
    wire [23:0] rgb;

    video_timing u_timing (
        .clk        (clk_pixel),
        .rst        (rst_px),
        .x          (x),
        .y          (y),
        .hsync      (hsync),
        .vsync      (vsync),
        .de         (de),
        .frame_tick (frame_tick)
    );

    test_pattern u_pattern (
        .clk        (clk_pixel),
        .rst        (rst_px),
        .frame_tick (frame_tick),
        .x          (x),
        .y          (y),
        .enable     (pattern_en),
        .animate    (animate),
        .rgb        (rgb)
    );

    // ------------------------------------------------------------- TMDS
    wire [9:0] q_b, q_g, q_r;

    tmds_encoder u_enc_b (
        .clk (clk_pixel), .rst (rst_px), .de (de), .c0 (hsync), .c1 (vsync),
        .d (rgb[7:0]),  .q (q_b)
    );
    tmds_encoder u_enc_g (
        .clk (clk_pixel), .rst (rst_px), .de (de), .c0 (1'b0), .c1 (1'b0),
        .d (rgb[15:8]), .q (q_g)
    );
    tmds_encoder u_enc_r (
        .clk (clk_pixel), .rst (rst_px), .de (de), .c0 (1'b0), .c1 (1'b0),
        .d (rgb[23:16]), .q (q_r)
    );

    tmds_serializer u_ser_b (
        .pixel_clk (clk_pixel), .serial_clk (clk_serial), .rst (rst_px),
        .data (q_b), .tmds_p (hdmi_data_p[0]), .tmds_n (hdmi_data_n[0])
    );
    tmds_serializer u_ser_g (
        .pixel_clk (clk_pixel), .serial_clk (clk_serial), .rst (rst_px),
        .data (q_g), .tmds_p (hdmi_data_p[1]), .tmds_n (hdmi_data_n[1])
    );
    tmds_serializer u_ser_r (
        .pixel_clk (clk_pixel), .serial_clk (clk_serial), .rst (rst_px),
        .data (q_r), .tmds_p (hdmi_data_p[2]), .tmds_n (hdmi_data_n[2])
    );
    tmds_serializer u_ser_clk (
        .pixel_clk (clk_pixel), .serial_clk (clk_serial), .rst (rst_px),
        .data (10'b0000011111), .tmds_p (hdmi_clk_p), .tmds_n (hdmi_clk_n)
    );

    assign hdmi_hpd = 1'b1;

    assign led[0] = mmcm_locked;
    assign led[1] = frame_count[2];

endmodule

`default_nettype wire
