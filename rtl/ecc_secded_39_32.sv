// -----------------------------------------------------------------------------
// ecc_secded_39_32.sv
//
// Extended Hamming (39,32) SEC-DED code protecting the safety configuration
// shadow SRAM (dead times, OC thresholds, calibration data).
//
// Codeword layout:
//   cw[0]      overall parity over cw[38:1]
//   cw[2^k]    Hamming parity bits, k = 0..5 (positions 1,2,4,8,16,32)
//   cw[other]  data bits d[0..31], in ascending position order
//
// Decoder outputs:
//   err_sbe_o  single-bit error detected and corrected -> data_o is valid
//   err_dbe_o  double-bit error detected, NOT correctable -> safety reaction
//
// SR-MEM-002 (ASIL-D): every double-bit error shall be signalled on err_dbe_o
// and shall never be reported as corrected.
// -----------------------------------------------------------------------------
module ecc_secded_39_32 (
  // encoder (write path)
  input  logic [31:0] wdata_i,
  output logic [38:0] wcw_o,
  // decoder (read path)
  input  logic [38:0] rcw_i,
  output logic [31:0] rdata_o,
  output logic        err_sbe_o,
  output logic        err_dbe_o
);

  function automatic logic is_pow2(input int unsigned pos);
    return (pos & (pos - 1)) == 0;
  endfunction

  function automatic logic [38:0] encode(input logic [31:0] d);
    logic [38:0] cw;
    int unsigned j;
    cw = '0;
    j  = 0;
    for (int unsigned pos = 1; pos < 39; pos++) begin
      if (!is_pow2(pos)) begin
        cw[pos] = d[j];
        j++;
      end
    end
    for (int unsigned k = 0; k < 6; k++) begin
      for (int unsigned pos = 1; pos < 39; pos++) begin
        if (!is_pow2(pos) && pos[k]) cw[1 << k] ^= cw[pos];
      end
    end
    cw[0] = ^cw[38:1];
    return cw;
  endfunction

  function automatic logic [31:0] extract(input logic [38:0] cw);
    logic [31:0] d;
    int unsigned j;
    d = '0;
    j = 0;
    for (int unsigned pos = 1; pos < 39; pos++) begin
      if (!is_pow2(pos)) begin
        d[j] = cw[pos];
        j++;
      end
    end
    return d;
  endfunction

  // ---------------------------------------------------------------------------
  // Encoder
  // ---------------------------------------------------------------------------
  assign wcw_o = encode(wdata_i);

  // ---------------------------------------------------------------------------
  // Decoder
  // ---------------------------------------------------------------------------
  logic [5:0]  syndrome;
  logic        parity_err;
  logic [38:0] cw_fixed;

  always_comb begin
    syndrome = '0;
    for (int unsigned k = 0; k < 6; k++) begin
      for (int unsigned pos = 1; pos < 39; pos++) begin
        if (pos[k]) syndrome[k] ^= rcw_i[pos];
      end
    end
    parity_err = ^rcw_i;
  end

  // A single flipped bit gives a syndrome pointing at its position (1..38).
  // Two flipped bits give a syndrome outside the valid position range.
  assign err_sbe_o = (syndrome != 6'd0) && (syndrome <= 6'd38);
  assign err_dbe_o = (syndrome > 6'd38);

  always_comb begin
    cw_fixed = rcw_i;
    if (err_sbe_o) cw_fixed[syndrome] = ~cw_fixed[syndrome];
  end

  assign rdata_o = extract(cw_fixed);

endmodule
