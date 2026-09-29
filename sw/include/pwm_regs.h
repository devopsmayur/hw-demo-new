/*
 * pwm_regs.h - register interface of the E-Drive PWM subsystem.
 * Must match docs/register_map.md and rtl/apb_pwm_regs.sv (rule R-REG-04).
 */
#ifndef PWM_REGS_H
#define PWM_REGS_H

#include <stdint.h>

#define PWM_BASE_ADDR           0xF0030000u   /* demo address */

#define PWM_CTRL_OFFSET         0x00u
#define PWM_DEADTIME_OFFSET     0x04u
#define PWM_STATUS_OFFSET       0x08u
#define PWM_ID_OFFSET           0x0Cu

#define PWM_CTRL_EN             (1u << 0)
#define PWM_CTRL_LOCK           (1u << 1)

#define PWM_DEADTIME_MASK       0x3FFu

#define PWM_STATUS_FAULT        (1u << 0)     /* W1C */

#define PWM_ID_VALUE            0x50574D01u

#define PWM_REG(off)  (*(volatile uint32_t *)(PWM_BASE_ADDR + (off)))

/* STATUS is W1C: write only the bit to clear, never read-modify-write. */
static inline void pwm_clear_fault(void)
{
    PWM_REG(PWM_STATUS_OFFSET) = PWM_STATUS_FAULT;
}

static inline void pwm_set_deadtime(uint32_t cycles)
{
    PWM_REG(PWM_DEADTIME_OFFSET) = cycles & PWM_DEADTIME_MASK;
}

#endif /* PWM_REGS_H */
