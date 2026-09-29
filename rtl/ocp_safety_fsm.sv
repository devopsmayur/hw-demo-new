// -----------------------------------------------------------------------------
// ocp_safety_fsm.sv
//
// Over-current protection (OCP) and gate-driver DESAT supervision for the
// traction inverter. Drives the power stage into a safe state:
//
//   phase over-current -> ASC (active short circuit, all low sides on)
//   DESAT from driver  -> OFF (all gates off, freewheel through diodes)
//
// After a trip the FSM stays in the safe state until software clears the
// fault (STATUS.FAULT W1C) AND de-asserts CTRL.EN (no automatic restart,
// SR-SAF-007).
//
// Phase currents are signed two's complement ADC codes (full scale = +/-2048
// LSB = +/-1000 A). oc_thresh_i is the |I| trip level in the same units.
// -----------------------------------------------------------------------------
module ocp_safety_fsm #(
  parameter int unsigned ADC_W = 12
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    arm_i,         // CTRL.EN
  // phase current samples (from ADC CDC FIFO)
  input  logic                    i_valid_i,
  input  logic signed [ADC_W-1:0] i_u_i,
  input  logic signed [ADC_W-1:0] i_v_i,
  input  logic signed [ADC_W-1:0] i_w_i,
  // signed so it compares directly with the signed ADC samples
  input  logic signed [ADC_W-1:0] oc_thresh_i,
  // gate-driver DESAT fault pin: active low, open drain, from the pad ring
  input  logic                    desat_ni,
  input  logic                    fault_clr_i,   // SW W1C pulse
  output logic                    pwm_en_o,      // gates allowed to switch
  output logic                    asc_req_o,     // active short circuit
  output logic                    fault_set_o,   // 1-cycle pulse to STATUS
  output logic [1:0]              trip_src_o     // 01 = OC, 10 = DESAT
);

  typedef enum logic [2:0] {
    ST_IDLE  = 3'b000,   // gates off, waiting for arm
    ST_RUN   = 3'b001,   // normal switching
    ST_ASC   = 3'b010,   // over-current -> active short circuit
    ST_OFF   = 3'b011,   // DESAT -> all gates off
    ST_REARM = 3'b100    // fault cleared, wait for CTRL.EN = 0
  } state_e;

  localparam logic [1:0] TRIP_NONE  = 2'b00;
  localparam logic [1:0] TRIP_OC    = 2'b01;
  localparam logic [1:0] TRIP_DESAT = 2'b10;

  state_e     state_q, state_d;
  logic [1:0] trip_src_q, trip_src_d;

  // ---------------------------------------------------------------------------
  // Fault detection
  // ---------------------------------------------------------------------------

  // DESAT must be handled within 1 us (driver datasheet), so it goes straight
  // into the next-state logic - no time for a synchronizer here.
  logic desat_fault;
  assign desat_fault = ~desat_ni;

  function automatic logic signed [ADC_W-1:0] iabs(
    input logic signed [ADC_W-1:0] x
  );
    return x[ADC_W-1] ? -x : x;
  endfunction

  logic oc_trip;
  assign oc_trip = i_valid_i &&
                   ((iabs(i_u_i) > oc_thresh_i) ||
                    (iabs(i_v_i) > oc_thresh_i) ||
                    (iabs(i_w_i) > oc_thresh_i));

  // ---------------------------------------------------------------------------
  // Safety state machine
  // ---------------------------------------------------------------------------
  always_comb begin
    state_d = state_q;
    case (state_q)
      ST_IDLE: begin
        if (arm_i) state_d = ST_RUN;
      end
      ST_RUN: begin
        if (desat_fault)  state_d = ST_OFF;
        else if (oc_trip) state_d = ST_ASC;
        else if (!arm_i)  state_d = ST_IDLE;
      end
      ST_ASC: begin
        // a DESAT while in ASC means a low-side switch is failing -> OFF
        if (desat_fault)      state_d = ST_OFF;
        else if (fault_clr_i) state_d = ST_REARM;
      end
      ST_OFF: begin
        if (fault_clr_i) state_d = ST_REARM;
      end
      ST_REARM: begin
        if (!arm_i) state_d = ST_IDLE;
      end
    endcase
  end

  // Trip source capture (reported in STATUS.TRIP_SRC)
  always_comb begin
    if (state_q == ST_RUN && desat_fault)
      trip_src_d = TRIP_DESAT;
    else if (state_q == ST_RUN && oc_trip)
      trip_src_d = TRIP_OC;
    else if (state_q == ST_REARM && !arm_i)
      trip_src_d = TRIP_NONE;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q    <= ST_IDLE;
      trip_src_q <= TRIP_NONE;
    end else begin
      state_q    <= state_d;
      trip_src_q <= trip_src_d;
    end
  end

  assign pwm_en_o    = (state_q == ST_RUN);
  assign asc_req_o   = (state_q == ST_ASC);
  assign fault_set_o = (state_q == ST_RUN) &&
                       ((state_d == ST_ASC) || (state_d == ST_OFF));
  assign trip_src_o  = trip_src_q;

endmodule
