// Video front end: clocks, registers, frame store, scaler, TMDS output.
//
// This is the module the block design sees. It has an AXI4-Lite control port
// and an AXI4 read master (DDR -> frame store), both on the PS clock domain,
// plus a TMDS output on the pixel clock domain.
//
// Clock plan for 1280x720p60:
//   125 MHz board oscillator
//     -> MMCM1: x7.125 / 12 = 74.21875 MHz
//     -> MMCM2: x10 = 742.1875 MHz VCO, /2 = 371.09375 MHz serial
//     -> pixel = 74.21875 MHz on a global BUFG (the frame store spans clock
//        regions), serial = 371.09375 MHz on a BUFIO.

`default_nettype none

module orbit_video (
    // Board oscillator, 125 MHz.
    input  wire        clk125,

    // AXI4-Lite control.
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:M_AXI, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 100000000" *)
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

    // AXI4 read master, DDR -> frame store.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI, PROTOCOL AXI4, ADDR_WIDTH 32, DATA_WIDTH 64, ID_WIDTH 6, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, MAX_BURST_LENGTH 256, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, SUPPORTS_NARROW_BURST 0, FREQ_HZ 100000000" *)
    output wire [31:0] m_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLEN" *)   output wire [7:0]  m_axi_arlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARSIZE" *)  output wire [2:0]  m_axi_arsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARBURST" *) output wire [1:0]  m_axi_arburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLOCK" *)  output wire        m_axi_arlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARCACHE" *) output wire [3:0]  m_axi_arcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARPROT" *)  output wire [2:0]  m_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARQOS" *)   output wire [3:0]  m_axi_arqos,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *) output wire        m_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *) input  wire        m_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARID" *)    output wire [5:0]  m_axi_arid,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RDATA" *)   input  wire [63:0] m_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RRESP" *)   input  wire [1:0]  m_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RLAST" *)   input  wire        m_axi_rlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RVALID" *)  input  wire        m_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RREADY" *)  output wire        m_axi_rready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RID" *)     input  wire [5:0]  m_axi_rid,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWADDR" *)  output wire [31:0] m_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLEN" *)   output wire [7:0]  m_axi_awlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWSIZE" *)  output wire [2:0]  m_axi_awsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWBURST" *) output wire [1:0]  m_axi_awburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLOCK" *)  output wire        m_axi_awlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWCACHE" *) output wire [3:0]  m_axi_awcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWPROT" *)  output wire [2:0]  m_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWQOS" *)   output wire [3:0]  m_axi_awqos,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *) output wire        m_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *) input  wire        m_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWID" *)    output wire [5:0]  m_axi_awid,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WDATA" *)   output wire [63:0] m_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *)   output wire [7:0]  m_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WLAST" *)   output wire        m_axi_wlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WVALID" *)  output wire        m_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WREADY" *)  input  wire        m_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WID" *)     output wire [5:0]  m_axi_wid,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BRESP" *)   input  wire [1:0]  m_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BVALID" *)  input  wire        m_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BREADY" *)  output wire        m_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BID" *)     input  wire [5:0]  m_axi_bid,

    // HDMI.
    output wire        hdmi_clk_p,
    output wire        hdmi_clk_n,
    output wire [2:0]  hdmi_data_p,
    output wire [2:0]  hdmi_data_n,
    output wire        hdmi_hpd,

    output wire [1:0]  led
);

    // ------------------------------------------------------------- clocking
    wire clk125_buf;
    wire clk_pixel_ref;
    wire clk_pixel_ref_raw;
    wire clk_fb_ref_out;
    wire clk_fb_ref_in;
    wire mmcm_ref_locked;

    wire clk_serial_raw;
    wire clk_serial;
    wire clk_pixel_raw;
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
        .CLKOUT1     (clk_pixel_raw),
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

    // Global clocks. The frame store is a large RAMB array that spans clock
    // regions, so the pixel clock has to be global; a regional BUFR cannot
    // drive it. The serializer still gets its 5x clock from a BUFIO.
    BUFG u_fb_bufg (
        .I (clk_fb),
        .O (clk_fb_buf)
    );

    BUFIO u_serial_bufio (
        .O (clk_serial),
        .I (clk_serial_raw)
    );

    BUFG u_pixel_bufg (
        .I (clk_pixel_raw),
        .O (clk_pixel)
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
    reg [31:0] fb_addr;
    reg [31:0] fb_stride;
    reg [31:0] scratch;
    reg [31:0] frame_count;
    reg [15:0] swap_count;

    reg        mmcm_locked_q;
    reg        vsync_q;
    reg        display_ready_q;

    reg        awready_r, wready_r, bvalid_r;
    reg        arready_r, rvalid_r;
    reg [31:0] rdata_r;

    // DMA control.
    wire       dma_kick;
    reg        dma_pending;
    reg [31:0] dma_pending_addr;
    reg        dma_done_q;
    reg        done_toggle;

    reg        fb_bank_s;       // display bank, synchronised into this domain
    reg        swap_pending_s;

    wire       dma_busy;
    wire       dma_done;
    wire       dma_error;
    wire       fb_we;
    wire [16:0] fb_waddr;
    wire [15:0] fb_wdata;

    assign dma_kick = dma_pending && !dma_busy && !swap_pending_s;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            ctrl               <= 32'h0000_0001; // test pattern on
            fb_addr            <= 32'd0;
            fb_stride          <= 32'd512;
            scratch            <= 32'd0;
            awready_r          <= 1'b0;
            wready_r           <= 1'b0;
            bvalid_r           <= 1'b0;
            arready_r          <= 1'b0;
            rvalid_r           <= 1'b0;
            rdata_r            <= 32'd0;
            dma_pending        <= 1'b0;
            dma_pending_addr   <= 32'd0;
            dma_done_q         <= 1'b0;
            done_toggle        <= 1'b0;
            fb_bank_s          <= 1'b0;
            swap_pending_s     <= 1'b0;
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
                    4'h1: ctrl      <= s_axi_wdata;
                    4'h3: fb_addr   <= s_axi_wdata;
                    4'h4: fb_stride <= s_axi_wdata;
                    4'h5: if (s_axi_wdata[0]) begin
                              dma_pending      <= 1'b1;
                              dma_pending_addr <= fb_addr;
                          end
                    4'h7: scratch   <= s_axi_wdata;
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
                    4'h2: rdata_r <= {frame_count[15:0], 13'd0,
                                      display_ready_q, vsync_q, mmcm_locked_q};
                    4'h3: rdata_r <= fb_addr;
                    4'h4: rdata_r <= fb_stride;
                    4'h5: rdata_r <= 32'd0;
                    4'h6: rdata_r <= {swap_count, 13'd0, dma_error, dma_done, dma_busy};
                    4'h7: rdata_r <= scratch;
                    default: rdata_r <= 32'd0;
                endcase
            end

            if (rvalid_r && s_axi_rready)
                rvalid_r <= 1'b0;

            // Clear a pending request once the copy engine accepts it.
            if (dma_kick)
                dma_pending <= 1'b0;

            // One toggle per completed copy, for the pixel domain.
            dma_done_q <= dma_done;
            if (dma_done && !dma_done_q)
                done_toggle <= ~done_toggle;
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

    // Video signals are declared here because the status synchronisers read
    // vsync and the frame tick.
    wire [11:0] x, y;
    wire        hsync, vsync, de;
    wire        frame_tick;
    wire [23:0] pat_rgb;
    reg         display_ready;

    // ------------------------------------------------------- control CDC
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
    reg [2:0] swap_sync;
    reg       mmcm_locked_s;
    reg       vsync_s;
    reg       display_ready_s;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            toggle_sync     <= 3'b000;
            swap_sync       <= 3'b000;
            swap_count      <= 16'd0;
            mmcm_locked_s   <= 1'b0;
            vsync_s         <= 1'b0;
            display_ready_s <= 1'b0;
            mmcm_locked_q   <= 1'b0;
            vsync_q         <= 1'b0;
            display_ready_q <= 1'b0;
            frame_count     <= 32'd0;
        end else begin
            toggle_sync     <= {toggle_sync[1:0], frame_toggle};
            swap_sync       <= {swap_sync[1:0], swap_toggle};
            if (swap_sync[2] ^ swap_sync[1])
                swap_count <= swap_count + 16'd1;
            mmcm_locked_s   <= mmcm_locked;
            vsync_s         <= vsync;
            display_ready_s <= display_ready;
            mmcm_locked_q   <= mmcm_locked_s;
            vsync_q         <= vsync_s;
            display_ready_q <= display_ready_s;
            if (toggle_sync[2] ^ toggle_sync[1])
                frame_count <= frame_count + 32'd1;
        end
    end

    // ------------------------------------------------- frame store + swap
    // Two 120 KiB banks, one displayed, one being filled.
    reg [15:0] fb_mem [0:131071];

    always @(posedge s_axi_aclk) begin
        if (fb_we)
            fb_mem[fb_waddr] <= fb_wdata;
    end

    reg [16:0] fb_raddr;
    reg [15:0] fb_q;

    always @(posedge clk_pixel) begin
        fb_q <= fb_mem[fb_raddr];
    end

    reg        fb_bank;
    reg        swap_pending;
    reg        swap_toggle;

    // done toggle -> pixel domain
    reg [2:0] done_sync;
    always @(posedge clk_pixel or posedge rst_px) begin
        if (rst_px) begin
            done_sync    <= 3'b000;
            fb_bank      <= 1'b0;
            display_ready <= 1'b0;
            swap_pending <= 1'b0;
            swap_toggle  <= 1'b0;
        end else begin
            done_sync <= {done_sync[1:0], done_toggle};
            if (done_sync[2] ^ done_sync[1])
                swap_pending <= 1'b1;
            if (frame_tick && swap_pending) begin
                fb_bank       <= ~fb_bank;
                display_ready <= 1'b1;
                swap_pending  <= 1'b0;
                swap_toggle   <= ~swap_toggle;
            end
        end
    end

    // Display bank and pending flag -> AXI domain, so the copy engine writes
    // the bank that is not on screen.
    reg [1:0] fb_bank_cdc, swap_cdc;
    always @(posedge s_axi_aclk) begin
        fb_bank_cdc   <= {fb_bank_cdc[0], fb_bank};
        swap_cdc      <= {swap_cdc[0], swap_pending};
        fb_bank_s     <= fb_bank_cdc[1];
        swap_pending_s<= swap_cdc[1];
    end

    // ------------------------------------------------------------- video
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
        .enable     (1'b1),
        .animate    (animate),
        .rgb        (pat_rgb)
    );

    // 256x240 scaled 3x into the centre of 1280x720. The multiply by 21846
    // and shift is a divide by 3 for the 0..767 and 0..719 ranges.
    wire [11:0] sx_in      = x - 12'd256;
    wire [31:0] sx_mul     = sx_in * 32'd21846;
    wire [31:0] sy_mul     = y * 32'd21846;
    wire [7:0]  src_x      = sx_mul[23:16];
    wire [7:0]  src_y      = sy_mul[23:16];
    wire        in_window  = (x >= 12'd256) && (x < 12'd1024);

    always @(*) begin
        fb_raddr = {fb_bank, src_y, src_x};
    end

    wire [23:0] fb_rgb = {fb_q[15:11], fb_q[13:11],
                          fb_q[10:5],  fb_q[6:5],
                          fb_q[4:0],   fb_q[2:0]};

    wire show_pattern = pattern_en || !display_ready;

    reg        de_d, hs_d, vs_d, win_d, pat_d;
    reg [23:0] pat_rgb_d;

    always @(posedge clk_pixel or posedge rst_px) begin
        if (rst_px) begin
            de_d      <= 1'b0;
            hs_d      <= 1'b0;
            vs_d      <= 1'b0;
            win_d     <= 1'b0;
            pat_d     <= 1'b0;
            pat_rgb_d <= 24'd0;
        end else begin
            de_d      <= de;
            hs_d      <= hsync;
            vs_d      <= vsync;
            win_d     <= in_window;
            pat_d     <= show_pattern;
            pat_rgb_d <= pat_rgb;
        end
    end

    wire [23:0] rgb_sel = pat_d ? pat_rgb_d : fb_rgb;
    wire [23:0] rgb     = win_d ? rgb_sel : 24'h000000;

    // ------------------------------------------------------------- DMA
    fb_dma u_dma (
        .clk            (s_axi_aclk),
        .rst            (!s_axi_aresetn),
        .start          (dma_kick),
        .src_addr       (dma_pending_addr),
        .bank           (~fb_bank_s),
        .busy           (dma_busy),
        .done           (dma_done),
        .error          (dma_error),
        .fb_we          (fb_we),
        .fb_waddr       (fb_waddr),
        .fb_wdata       (fb_wdata),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_arlock   (m_axi_arlock),
        .m_axi_arcache  (m_axi_arcache),
        .m_axi_arprot   (m_axi_arprot),
        .m_axi_arqos    (m_axi_arqos),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_arid     (m_axi_arid),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready),
        .m_axi_rid      (m_axi_rid),
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (m_axi_awlen),
        .m_axi_awsize   (m_axi_awsize),
        .m_axi_awburst  (m_axi_awburst),
        .m_axi_awlock   (m_axi_awlock),
        .m_axi_awcache  (m_axi_awcache),
        .m_axi_awprot   (m_axi_awprot),
        .m_axi_awqos    (m_axi_awqos),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_awid     (m_axi_awid),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_wid      (m_axi_wid),
        .m_axi_bresp    (m_axi_bresp),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_bid      (m_axi_bid)
    );

    // ------------------------------------------------------------- TMDS
    wire [9:0] q_b, q_g, q_r;

    tmds_encoder u_enc_b (
        .clk (clk_pixel), .rst (rst_px), .de (de_d), .c0 (hs_d), .c1 (vs_d),
        .d (rgb[7:0]),  .q (q_b)
    );
    tmds_encoder u_enc_g (
        .clk (clk_pixel), .rst (rst_px), .de (de_d), .c0 (1'b0), .c1 (1'b0),
        .d (rgb[15:8]), .q (q_g)
    );
    tmds_encoder u_enc_r (
        .clk (clk_pixel), .rst (rst_px), .de (de_d), .c0 (1'b0), .c1 (1'b0),
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
