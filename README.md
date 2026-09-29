# E-Drive Inverter Control Subsystem (demo RTL)

Fictional, self-contained RTL subsystem modelled on the PWM / safety peripheral
of an automotive traction-inverter microcontroller. Built to demonstrate
CodeRabbit reviews on hardware design repositories.

```
                 adc_clk (80 MHz)          sys_clk (200 MHz)
 sigma-delta  ┌──────────────┐        ┌──────────────────┐     ┌───────────────┐
 ADC ────────►│  async_fifo  │───────►│  ocp_safety_fsm  │────►│ pwm_deadtime  │──► hs/ls gate
 decimator    └──────────────┘        │  OCP + DESAT     │ ASC │  x3 legs      │    commands
                                      └──────────────────┘     └───────────────┘
 gate driver DESAT pin (async) ───────────────┘                        ▲
                                                                       │ dead times
 CPU ── APB ──► apb_pwm_regs ──────────────────────────────────────────┘
                   ▲   config SRAM ── ecc_secded_39_32
                   └── gate-driver SPI ── crc8_sae_j1850 (VHDL)
```

| Path | Content |
|------|---------|
| `rtl/*.sv` | SystemVerilog RTL (linted by Verilator in CodeRabbit) |
| `rtl/vhdl/*.vhd` | Legacy VHDL blocks |
| `sw/include/` | Firmware register definitions (C) |
| `docs/RTL_DESIGN_RULES.md` | Team design rules, applied by CodeRabbit as review guidelines |
| `docs/register_map.md` | Register map (source of truth) |
| `.coderabbit.yaml` | CodeRabbit configuration |

Safety target: ISO 26262 ASIL-D. Key requirement SR-PWM-001: the high-side and
low-side switch of a leg are never commanded on at the same time.

Local lint: `verilator --lint-only -Wall rtl/<file>.sv`
