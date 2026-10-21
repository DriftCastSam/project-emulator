// Self-checking testbench for the DDR -> frame store copy engine.
// Models a 64-bit AXI read slave that returns a deterministic pixel pattern
// and checks every write into the frame store.

`timescale 1ns/1ps

module tb_fb_dma;

    localparam [31:0] BASE = 32'h1000_0000;
    localparam integer PIXELS = 61440;

    reg         clk = 0;
    reg         rst = 1;
    reg         start = 0;
    reg  [31:0] src_addr = BASE;
    wire        busy, done, error;

    wire        fb_we;
    wire [16:0] fb_waddr;
    wire [15:0] fb_wdata;

    // AXI master wires.
    wire [31:0] araddr;
    wire [7:0]  arlen;
    wire [2:0]  arsize;
    wire [1:0]  arburst;
    wire        arlock;
    wire [3:0]  arcache;
    wire [2:0]  arprot;
    wire [3:0]  arqos;
    wire        arvalid;
    reg         arready = 0;
    wire [5:0]  arid;

    reg  [63:0] rdata = 0;
    reg  [1:0]  rresp = 0;
    reg         rlast = 0;
    reg         rvalid = 0;
    wire        rready;
    reg  [5:0]  rid = 0;

    // Write channels are tied off by the DUT.
    wire [31:0] awaddr;
    wire [7:0]  awlen;
    wire [2:0]  awsize;
    wire [1:0]  awburst;
    wire        awlock;
    wire [3:0]  awcache;
    wire [2:0]  awprot;
    wire [3:0]  awqos;
    wire        awvalid;
    reg         awready = 0;
    wire [5:0]  awid;

    wire [63:0] wdata;
    wire [7:0]  wstrb;
    wire        wlast;
    wire        wvalid;
    reg         wready = 0;
    wire [5:0]  wid;

    reg  [1:0]  bresp = 0;
    reg         bvalid = 0;
    wire        bready;
    reg  [5:0]  bid = 0;

    integer errors = 0;
    integer writes = 0;
    reg [15:0] exp_pixel = 0;

    always #5 clk = ~clk;

    fb_dma dut (
        .clk (clk),
        .rst (rst),
        .start (start),
        .src_addr (src_addr),
        .bank (1'b0),
        .busy (busy),
        .done (done),
        .error (error),
        .fb_we (fb_we),
        .fb_waddr (fb_waddr),
        .fb_wdata (fb_wdata),
        .m_axi_araddr (araddr), .m_axi_arlen (arlen), .m_axi_arsize (arsize),
        .m_axi_arburst (arburst), .m_axi_arlock (arlock), .m_axi_arcache (arcache),
        .m_axi_arprot (arprot), .m_axi_arqos (arqos), .m_axi_arvalid (arvalid),
        .m_axi_arready (arready), .m_axi_arid (arid),
        .m_axi_rdata (rdata), .m_axi_rresp (rresp), .m_axi_rlast (rlast),
        .m_axi_rvalid (rvalid), .m_axi_rready (rready), .m_axi_rid (rid),
        .m_axi_awaddr (awaddr), .m_axi_awlen (awlen), .m_axi_awsize (awsize),
        .m_axi_awburst (awburst), .m_axi_awlock (awlock), .m_axi_awcache (awcache),
        .m_axi_awprot (awprot), .m_axi_awqos (awqos), .m_axi_awvalid (awvalid),
        .m_axi_awready (awready), .m_axi_awid (awid),
        .m_axi_wdata (wdata), .m_axi_wstrb (wstrb), .m_axi_wlast (wlast),
        .m_axi_wvalid (wvalid), .m_axi_wready (wready), .m_axi_wid (wid),
        .m_axi_bresp (bresp), .m_axi_bvalid (bvalid), .m_axi_bready (bready),
        .m_axi_bid (bid)
    );

    // ------------------------------------------------------------------ slave
    function [63:0] beat_data(input [31:0] addr);
        reg [31:0] p;
        begin
            p = (addr - BASE) >> 1;
            beat_data = {p[15:0] + 16'd3, p[15:0] + 16'd2,
                         p[15:0] + 16'd1, p[15:0]};
        end
    endfunction

    reg [31:0] cur_addr;
    reg [4:0]  beat;
    reg        active = 0;

    always @(posedge clk) begin
        if (rst) begin
            arready <= 0;
            active  <= 0;
            rvalid  <= 0;
        end else begin
            arready <= 1;

            if (arvalid && arready) begin
                cur_addr <= araddr;
                beat     <= 0;
                active   <= 1;
                rvalid   <= 0;
            end else if (active) begin
                // Generate one beat only when the master is ready, so no beat
                // is left pending across a burst boundary.
                if (!rvalid && rready) begin
                    rdata  <= beat_data(cur_addr + {24'd0, beat, 3'd0});
                    rlast  <= (beat == 5'd15);
                    rvalid <= 1;
                end else if (rvalid && rready) begin
                    rvalid <= 0;
                    beat   <= beat + 5'd1;
                    if (beat == 5'd15)
                        active <= 0;
                end
            end
        end
    end

    // ----------------------------------------------------------------- checks
    always @(posedge clk) begin
        if (fb_we) begin
            if (fb_waddr !== {1'b0, exp_pixel}) begin
                $display("FAIL: write %0d address %0h expected %0h",
                         writes, fb_waddr, {1'b0, exp_pixel});
                errors = errors + 1;
            end
            if (fb_wdata !== exp_pixel) begin
                $display("FAIL: write %0d data %0h expected %0h",
                         writes, fb_wdata, exp_pixel);
                errors = errors + 1;
            end
            writes     = writes + 1;
            exp_pixel  = exp_pixel + 16'd1;
        end
    end

    initial begin
        repeat (3) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        wait (done === 1'b1);
        repeat (5) @(posedge clk);

        if (writes != PIXELS) begin
            $display("FAIL: %0d writes, expected %0d", writes, PIXELS);
            errors = errors + 1;
        end
        if (busy !== 1'b0) begin
            $display("FAIL: busy still high");
            errors = errors + 1;
        end
        if (error !== 1'b0) begin
            $display("FAIL: error flag set");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: fb_dma (%0d pixels)", writes);
        else
            $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #5000000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
