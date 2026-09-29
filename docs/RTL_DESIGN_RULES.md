# RTL & HW/SW Interface Design Rules — E-Drive Inverter Subsystem

Applies to everything under `rtl/` and `sw/`. Target: ISO 26262 ASIL-D.
CodeRabbit loads this file as review guidelines (see `.coderabbit.yaml`).
Reviewers should cite the rule ID when flagging a violation.

## Clock- and reset-domain crossing

**R-CDC-01** Every asynchronous single-bit input (pad, other clock domain) goes through `rtl/cdc_sync.sv` with `STAGES >= 2` before it is used in any logic. Latency is not an accepted reason to skip synchronization; two flops at 200 MHz cost 10 ns.

**R-CDC-02** Multi-bit values never cross a clock domain through flop synchronizers unless at most one bit can change per source-clock cycle (Gray code). Use Gray-coded FIFO pointers or a req/ack handshake with a stable data bus.

**R-RST-01** Resets assert asynchronously and de-assert synchronously, per clock domain.

## State machines

**R-FSM-01** Every FSM `case` has a `default` branch that returns to a documented safe state. Unused encodings must be recoverable (single-event upsets are a considered fault model, ISO 26262-5 Annex D).

**R-FSM-02** Every signal assigned in an `always_comb` block has a default assignment at the top of the block. Latches are not permitted in this subsystem.

## Arithmetic

**R-ARITH-01** Signedness is declared explicitly. Corner cases of two's-complement arithmetic (most negative value, overflow, saturation) are handled and commented.

**R-ARITH-02** No implicit width truncation. Counters and datapaths cover the full range of the register that configures them.

## Power stage (gate commands)

**R-PWM-01** No path — reset, enable, fault, safe state (ASC / OFF), test mode — may drive the high-side and low-side command of one leg active in the same cycle (SR-PWM-001). Safe-state transitions go through the dead-time logic.

**R-PWM-02** Safety assertions (`a_*`) may not be removed, disabled or weakened (for example by extending `disable iff`) without an approved safety-case change. Assertions are evidence in the FMEDA.

## Register interface

**R-REG-01** Every safety-relevant configuration register is covered by `CTRL.LOCK` (SR-REG-003).

**R-REG-02** Write-1-to-clear status bits: a hardware set event in the same cycle as a software clear must never be lost (set wins, per bit). A write clears only the bits written as 1.

**R-REG-03** Reset values of safety parameters are fail-safe: protection is active from reset with a conservative setting, never disabled until software configures it.

**R-REG-04** Any change to the register map updates `docs/register_map.md` **and** `sw/include/pwm_regs.h` in the same pull request.

## Memories

**R-MEM-01** ECC decoders satisfy SR-MEM-002: an uncorrectable error is never reported as corrected and never produces "corrected" data.

## VHDL

**R-VHDL-01** VHDL-2008. Combinational processes use `process (all)`. Only `ieee.numeric_std` for arithmetic.

**R-VHDL-02** CRC and checksum implementations state their full parameter set (polynomial, init, final XOR, reflection) and are verified against the standard's check value.

## Firmware (sw/)

**R-SW-01** Firmware never uses read-modify-write (`|=`, `&=`) on registers that contain W1C bits.
