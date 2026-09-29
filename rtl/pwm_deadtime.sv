// -----------------------------------------------------------------------------
// pwm_deadtime.sv
//
// Complementary gate-command generator with dead-time insertion for ONE
// half-bridge leg of a 3-phase traction inverter (instantiated 3x).
//
//   pwm_ref_i   raw PWM reference from the carrier comparator (clk_i domain)
//   dt_cycles_i dead time in clk_i cycles (0..1023, 5.115 us max @ 200 MHz)
//   hs_o / ls_o high-side / low-side gate commands to the isolated gate driver
//
// Safety requirement SR-PWM-001 (ASIL-D):
//   hs_o and ls_o shall never be active in the same clock cycle, on any path
//   (reset, enable, fault, safe-state). Violation = shoot-through = destroyed
//   power module.
// -----------------------------------------------------------------------------
module pwm_deadtime #(
  parameter int unsigned DT_W = 10
) (
  input  logic            clk_i,
  input  logic            rst_ni,
  input  logic            en_i,
  input  logic            pwm_ref_i,
  input  logic [DT_W-1:0] dt_cycles_i,
  output logic            hs_o,
  output logic            ls_o
);

  logic            ref_q;
  logic [DT_W-1:0] dt_cnt_q;
  logic            hs_q;
  logic            ls_q;
  logic            ref_edge;

  assign ref_edge = pwm_ref_i ^ ref_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ref_q    <= 1'b0;
      dt_cnt_q <= '0;
      hs_q     <= 1'b0;
      ls_q     <= 1'b0;
    end else if (!en_i) begin
      // Leg disabled: both switches off, arm a full dead time for re-enable
      ref_q    <= pwm_ref_i;
      dt_cnt_q <= dt_cycles_i;
      hs_q     <= 1'b0;
      ls_q     <= 1'b0;
    end else begin
      ref_q <= pwm_ref_i;
      if (ref_edge) begin
        // Any reference edge: turn both switches off, start dead time
        hs_q     <= 1'b0;
        ls_q     <= 1'b0;
        dt_cnt_q <= dt_cycles_i;
      end else if (dt_cnt_q != '0) begin
        dt_cnt_q <= dt_cnt_q - DT_W'(1);
      end else begin
        hs_q <=  ref_q;
        ls_q <= ~ref_q;
      end
    end
  end

  assign hs_o = hs_q;
  assign ls_o = ls_q;

`ifndef SYNTHESIS
  // SR-PWM-001: never both gates on
  a_no_shoot_through : assert property (
    @(posedge clk_i) disable iff (!rst_ni) !(hs_o && ls_o)
  ) else $error("SR-PWM-001 violated: hs_o and ls_o both active");
`endif

endmodule
