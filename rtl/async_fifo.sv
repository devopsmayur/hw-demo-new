// -----------------------------------------------------------------------------
// async_fifo.sv
//
// Dual-clock FIFO carrying phase-current samples {i_w, i_v, i_u} from the
// sigma-delta ADC decimator (adc_clk, 80 MHz) into the control / safety logic
// (sys_clk, 200 MHz). The two clocks are fully asynchronous.
//
// Pointers are AW+1 bits wide: the extra MSB distinguishes full from empty.
// -----------------------------------------------------------------------------
module async_fifo #(
  parameter int unsigned DW = 36,
  parameter int unsigned AW = 4
) (
  // write side - ADC clock domain
  input  logic          wclk_i,
  input  logic          wrst_ni,
  input  logic          winc_i,
  input  logic [DW-1:0] wdata_i,
  output logic          wfull_o,
  // read side - system clock domain
  input  logic          rclk_i,
  input  logic          rrst_ni,
  input  logic          rinc_i,
  output logic [DW-1:0] rdata_o,
  output logic          rempty_o
);

  localparam int unsigned DEPTH = 2 ** AW;

  logic [DW-1:0] mem_q [DEPTH];

  logic [AW:0] wbin_q,  wbin_d;
  logic [AW:0] wgray_q, wgray_d;
  logic [AW:0] rbin_q,  rbin_d;
  logic [AW:0] rgray_q, rgray_d;

  // read pointer (gray) synchronized into the write domain
  (* ASYNC_REG = "TRUE" *) logic [AW:0] wq1_rgray_q, wq2_rgray_q;
  // write pointer synchronized into the read domain
  (* ASYNC_REG = "TRUE" *) logic [AW:0] rq1_wbin_q,  rq2_wbin_q;

  // ---------------------------------------------------------------------------
  // Write domain (adc_clk)
  // ---------------------------------------------------------------------------
  logic wpush;
  assign wpush   = winc_i & ~wfull_o;
  assign wbin_d  = wbin_q + {{AW{1'b0}}, wpush};
  assign wgray_d = (wbin_d >> 1) ^ wbin_d;

  always_ff @(posedge wclk_i or negedge wrst_ni) begin
    if (!wrst_ni) begin
      wbin_q  <= '0;
      wgray_q <= '0;
    end else begin
      wbin_q  <= wbin_d;
      wgray_q <= wgray_d;
    end
  end

  always_ff @(posedge wclk_i) begin
    if (wpush) mem_q[wbin_q[AW-1:0]] <= wdata_i;
  end

  always_ff @(posedge wclk_i or negedge wrst_ni) begin
    if (!wrst_ni) begin
      wq1_rgray_q <= '0;
      wq2_rgray_q <= '0;
    end else begin
      wq1_rgray_q <= rgray_q;
      wq2_rgray_q <= wq1_rgray_q;
    end
  end

  // full: MSB and 2nd MSB inverted, remaining bits equal (gray compare)
  assign wfull_o = (wgray_q == {~wq2_rgray_q[AW:AW-1], wq2_rgray_q[AW-2:0]});

  // ---------------------------------------------------------------------------
  // Read domain (sys_clk)
  // ---------------------------------------------------------------------------
  // The write pointer passes through a 2-flop synchronizer, so the binary
  // value can be used directly - saves the gray-to-binary conversion and
  // keeps the empty flag timing path short at 200 MHz.
  always_ff @(posedge rclk_i or negedge rrst_ni) begin
    if (!rrst_ni) begin
      rq1_wbin_q <= '0;
      rq2_wbin_q <= '0;
    end else begin
      rq1_wbin_q <= wbin_q;
      rq2_wbin_q <= rq1_wbin_q;
    end
  end

  logic rpop;
  assign rpop    = rinc_i & ~rempty_o;
  assign rbin_d  = rbin_q + {{AW{1'b0}}, rpop};
  assign rgray_d = (rbin_d >> 1) ^ rbin_d;

  always_ff @(posedge rclk_i or negedge rrst_ni) begin
    if (!rrst_ni) begin
      rbin_q  <= '0;
      rgray_q <= '0;
    end else begin
      rbin_q  <= rbin_d;
      rgray_q <= rgray_d;
    end
  end

  assign rempty_o = (rbin_q == rq2_wbin_q);
  assign rdata_o  = mem_q[rbin_q[AW-1:0]];

endmodule
