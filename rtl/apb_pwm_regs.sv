// -----------------------------------------------------------------------------
// apb_pwm_regs.sv
//
// APB3 register interface of the traction-inverter PWM subsystem.
// Register map: docs/register_map.md (must be kept in sync with this file).
//
// Safety configuration lock (SR-REG-003):
//   Once CTRL.LOCK is written to 1 it can only be cleared by reset. While
//   locked, every safety-relevant configuration register is read-only and a
//   write attempt returns PSLVERR. This protects the power stage against
//   runaway or corrupted software (freedom from interference, ISO 26262-6).
// -----------------------------------------------------------------------------
module apb_pwm_regs #(
  parameter int unsigned DT_W  = 10,
  parameter int unsigned ADC_W = 12
) (
  input  logic                    pclk_i,
  input  logic                    presetn_i,
  // APB3 slave
  input  logic                    psel_i,
  input  logic                    penable_i,
  input  logic                    pwrite_i,
  input  logic [7:0]              paddr_i,
  input  logic [31:0]             pwdata_i,
  output logic [31:0]             prdata_o,
  output logic                    pready_o,
  output logic                    pslverr_o,
  // to / from PWM core and safety logic
  output logic                    pwm_en_o,
  output logic [DT_W-1:0]         dt_rise_o,
  output logic [DT_W-1:0]         dt_fall_o,
  output logic signed [ADC_W-1:0] oc_thresh_o,
  input  logic                    fault_set_i,   // 1-cycle pulse, safety FSM
  input  logic                    ecc_sbe_i,     // 1-cycle pulse, ECC
  input  logic                    ecc_dbe_i,     // 1-cycle pulse, ECC
  input  logic [1:0]              trip_src_i,
  output logic                    fault_clr_o    // 1-cycle pulse when SW clears fault
);

  localparam logic [7:0] ADDR_CTRL      = 8'h00;
  localparam logic [7:0] ADDR_DT_RISE   = 8'h04;
  localparam logic [7:0] ADDR_STATUS    = 8'h08;
  localparam logic [7:0] ADDR_ID        = 8'h0C;
  localparam logic [7:0] ADDR_DT_FALL   = 8'h10;
  localparam logic [7:0] ADDR_OC_THRESH = 8'h14;

  localparam logic [31:0] IP_ID = 32'h5057_4D02;  // "PWM", rev 2

  logic                    en_q;
  logic                    lock_q;
  logic [DT_W-1:0]         dt_rise_q;
  logic [DT_W-1:0]         dt_fall_q;
  logic signed [ADC_W-1:0] oc_thresh_q;
  logic [2:0]              status_q;     // {ECC_DBE, ECC_SBE, FAULT}, W1C
  logic [2:0]              status_set;

  logic wr_en;
  logic rd_en;
  logic wr_locked_err;
  logic clr_req;

  assign wr_en = psel_i & penable_i &  pwrite_i;
  assign rd_en = psel_i & penable_i & ~pwrite_i;

  // Write to a lockable register while locked -> ignored + PSLVERR
  assign wr_locked_err = wr_en & lock_q &
                         ((paddr_i == ADDR_CTRL) | (paddr_i == ADDR_DT_RISE));

  assign status_set = {ecc_dbe_i, ecc_sbe_i, fault_set_i};
  assign clr_req    = wr_en & (paddr_i == ADDR_STATUS) & pwdata_i[0];

  always_ff @(posedge pclk_i or negedge presetn_i) begin
    if (!presetn_i) begin
      en_q        <= 1'b0;
      lock_q      <= 1'b0;
      dt_rise_q   <= DT_W'(40);      // 200 ns @ 200 MHz, safe default
      dt_fall_q   <= DT_W'(40);
      oc_thresh_q <= 12'h7FF;        // max; SW programs the real limit at init
      status_q    <= '0;
    end else begin
      if (wr_en && !wr_locked_err) begin
        unique case (paddr_i)
          ADDR_CTRL: begin
            en_q   <= pwdata_i[0];
            lock_q <= lock_q | pwdata_i[1];   // sticky until reset
          end
          ADDR_DT_RISE:   dt_rise_q   <= pwdata_i[DT_W-1:0];
          ADDR_DT_FALL:   dt_fall_q   <= pwdata_i[DT_W-1:0];
          ADDR_OC_THRESH: oc_thresh_q <= pwdata_i[ADC_W-1:0];
          default: ;
        endcase
      end
      // STATUS: write-1-to-clear, otherwise accumulate new events
      if (wr_en && (paddr_i == ADDR_STATUS))
        status_q <= status_q & ~pwdata_i[2:0];
      else
        status_q <= status_q | status_set;
    end
  end

  always_comb begin
    prdata_o = '0;
    if (rd_en) begin
      unique case (paddr_i)
        ADDR_CTRL:      prdata_o = {30'd0, lock_q, en_q};
        ADDR_DT_RISE:   prdata_o = {{(32-DT_W){1'b0}}, dt_rise_q};
        ADDR_DT_FALL:   prdata_o = {{(32-DT_W){1'b0}}, dt_fall_q};
        ADDR_OC_THRESH: prdata_o = oc_thresh_q;
        ADDR_STATUS:    prdata_o = {26'd0, trip_src_i, 1'b0, status_q};
        ADDR_ID:        prdata_o = IP_ID;
        default:        prdata_o = '0;
      endcase
    end
  end

  assign pready_o    = 1'b1;
  assign pslverr_o   = wr_locked_err;
  assign pwm_en_o    = en_q;
  assign dt_rise_o   = dt_rise_q;
  assign dt_fall_o   = dt_fall_q;
  assign oc_thresh_o = oc_thresh_q;
  assign fault_clr_o = clr_req & ~fault_set_i;

  // Upper write-data bits are reserved (write-ignored)
  logic unused_pwdata;
  assign unused_pwdata = ^pwdata_i[31:ADC_W];

endmodule
