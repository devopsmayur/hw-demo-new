# PWM Subsystem Register Map (rev 1)

APB3, 32-bit registers, byte offsets from the subsystem base address.
Source of truth for `rtl/apb_pwm_regs.sv` and `sw/include/pwm_regs.h`.

| Offset | Name     | Bits  | Field  | Access | Reset  | Description                                          |
|--------|----------|-------|--------|--------|--------|------------------------------------------------------|
| 0x00   | CTRL     | 0     | EN     | RW (L) | 0      | Enable PWM legs                                      |
|        |          | 1     | LOCK   | W1S    | 0      | Lock safety configuration until reset (SR-REG-003)   |
| 0x04   | DEADTIME | 9:0   | DT     | RW (L) | 40     | Dead time in sys_clk cycles (0..1023, 5 ns / LSB)    |
| 0x08   | STATUS   | 0     | FAULT  | W1C    | 0      | Safety trip occurred (set wins over clear)           |
| 0x0C   | ID       | 31:0  | ID     | RO     | 0x50574D01 | IP identification, "PWM" rev 1                   |

Access: RW = read/write, (L) = read-only while CTRL.LOCK = 1 (write returns PSLVERR),
W1S = write 1 to set, W1C = write 1 to clear, RO = read-only.
