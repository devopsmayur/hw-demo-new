// -----------------------------------------------------------------------------
// cdc_sync.sv
//
// Project-standard single-bit synchronizer. ALL asynchronous single-bit inputs
// (pins, other clock domains) must pass through this cell - see
// docs/RTL_DESIGN_RULES.md, rule R-CDC-01.
//
// STAGES >= 2 is mandatory (MTBF). Use STAGES = 3 for clocks > 250 MHz.
// The synthesis flow maps sync_q to the library's metastability-hardened
// flops via the ASYNC_REG attribute.
// -----------------------------------------------------------------------------
module cdc_sync #(
  parameter int unsigned STAGES    = 2,
  parameter logic        RESET_VAL = 1'b0
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic d_i,
  output logic q_o
);

  (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] sync_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) sync_q <= {STAGES{RESET_VAL}};
    else         sync_q <= {sync_q[STAGES-2:0], d_i};
  end

  assign q_o = sync_q[STAGES-1];

`ifndef SYNTHESIS
  initial begin
    if (STAGES < 2) $fatal(1, "cdc_sync: STAGES must be >= 2 (R-CDC-01)");
  end
`endif

endmodule
