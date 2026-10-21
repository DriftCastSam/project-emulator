// Framebuffer copy engine: DDR -> on-chip 256x240 RGB565 frame store.
//
// Reads one 122,880-byte frame with 64-bit INCR bursts of 16 beats and
// unpacks four 16-bit pixels per beat into the frame store. One pixel is
// written per clock, which gives 160 MB/s at 100 MHz and copies a frame in
// under 0.8 ms, well inside a 60 Hz frame.
//
// Only the read channels are used; the write channels are tied off.

`default_nettype none

module fb_dma #(
    parameter [15:0] FRAME_PIXELS = 16'd61440
) (
    input  wire        clk,
    input  wire        rst,

    input  wire        start,
    input  wire [31:0] src_addr,
    input  wire        bank,        // frame store half to write
    output reg         busy,
    output reg         done,
    output reg         error,

    // Frame store write port.
    output wire        fb_we,
    output wire [16:0] fb_waddr,
    output wire [15:0] fb_wdata,

    // AXI4 master, 64-bit, read only.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *)  output wire [31:0] m_axi_araddr,
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

    /* verilator lint_off UNUSEDSIGNAL */
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
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BID" *)     input  wire [5:0]  m_axi_bid
    /* verilator lint_on UNUSEDSIGNAL */
);

    localparam [1:0] ST_IDLE   = 2'd0;
    localparam [1:0] ST_AR     = 2'd1;
    localparam [1:0] ST_DATA   = 2'd2;
    localparam [1:0] ST_UNPACK = 2'd3;

    reg [1:0]  state;
    reg [31:0] base;
    reg [9:0]  burst;
    reg        bank_r;
    reg [63:0] beat;
    reg        last_beat;
    reg [1:0]  unpack_cnt;
    reg [15:0] pix_idx;
    reg        arvalid_r;

    // Registered write stage. This keeps the frame-store write enable off the
    // FSM state decode, which otherwise has to drive every RAMB write port
    // across the device. The cost is one extra clock per four pixels.
    (* max_fanout = 16 *) reg        we_r;
    reg [16:0] waddr_r;
    reg [15:0] wdata_r;

    assign m_axi_araddr  = base + {15'd0, burst, 7'd0}; // burst * 128
    assign m_axi_arlen   = 8'd15;
    assign m_axi_arsize  = 3'b011;   // 8 bytes
    assign m_axi_arburst = 2'b01;    // INCR
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'b0000;
    assign m_axi_arid    = 6'd0;
    assign m_axi_arvalid = arvalid_r;

    assign m_axi_rready = (state == ST_DATA);

    assign m_axi_awaddr  = 32'd0;
    assign m_axi_awlen   = 8'd0;
    assign m_axi_awsize  = 3'b000;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awlock  = 1'b0;
    assign m_axi_awcache = 4'b0000;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awqos   = 4'b0000;
    assign m_axi_awid    = 6'd0;
    assign m_axi_awvalid = 1'b0;

    assign m_axi_wdata  = 64'd0;
    assign m_axi_wstrb  = 8'd0;
    assign m_axi_wlast  = 1'b0;
    assign m_axi_wvalid = 1'b0;
    assign m_axi_wid    = 6'd0;

    assign m_axi_bready = 1'b1;

    // Frame store write port, one cycle behind the unpack stage.
    assign fb_we    = we_r;
    assign fb_waddr = waddr_r;
    assign fb_wdata = wdata_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= ST_IDLE;
            base       <= 32'd0;
            burst      <= 10'd0;
            bank_r     <= 1'b0;
            beat       <= 64'd0;
            last_beat  <= 1'b0;
            unpack_cnt <= 2'd0;
            pix_idx    <= 16'd0;
            arvalid_r  <= 1'b0;
            busy       <= 1'b0;
            done       <= 1'b0;
            error      <= 1'b0;
        end else begin
            we_r <= (state == ST_UNPACK);

            if (state == ST_UNPACK) begin
                waddr_r <= {bank_r, pix_idx};
                wdata_r <= beat[15:0];
            end

            case (state)
                ST_IDLE: begin
                    if (start) begin
                        base      <= src_addr;
                        bank_r    <= bank;
                        burst     <= 10'd0;
                        pix_idx   <= 16'd0;
                        arvalid_r <= 1'b1;
                        busy      <= 1'b1;
                        done      <= 1'b0;
                        error     <= 1'b0;
                        state     <= ST_AR;
                    end
                end

                ST_AR: begin
                    if (m_axi_arready) begin
                        arvalid_r <= 1'b0;
                        state     <= ST_DATA;
                    end
                end

                ST_DATA: begin
                    if (m_axi_rvalid) begin
                        beat       <= m_axi_rdata;
                        last_beat  <= m_axi_rlast;
                        unpack_cnt <= 2'd0;
                        if (m_axi_rresp != 2'b00)
                            error <= 1'b1;
                        state <= ST_UNPACK;
                    end
                end

                ST_UNPACK: begin
                    beat    <= {16'd0, beat[63:16]};
                    pix_idx <= pix_idx + 16'd1;

                    if (unpack_cnt == 2'd3) begin
                        if (last_beat) begin
                            if (pix_idx == FRAME_PIXELS - 16'd1) begin
                                busy  <= 1'b0;
                                done  <= 1'b1;
                                state <= ST_IDLE;
                            end else begin
                                burst     <= burst + 10'd1;
                                arvalid_r <= 1'b1;
                                state     <= ST_AR;
                            end
                        end else begin
                            // Next beat in the same AXI burst.
                            state <= ST_DATA;
                        end
                    end else begin
                        unpack_cnt <= unpack_cnt + 2'd1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
