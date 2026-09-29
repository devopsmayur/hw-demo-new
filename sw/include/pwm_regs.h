/*
 * pwm_regs.h - register interface of the E-Drive PWM subsystem.
 * Must match docs/register_map.md and rtl/apb_pwm_regs.sv (rule R-REG-04).
 */
#ifndef PWM_REGS_H
#define PWM_REGS_H

#include <stdint.h>

#define PWM_BASE_ADDR           0xF0030000u   /* demo address */

#define PWM_CTRL_OFFSET         0x00u
#define PWM_DT_RISE_OFFSET      0x04u
#define PWM_STATUS_OFFSET       0x08u
#define PWM_ID_OFFSET           0x0Cu
#define PWM_DT_FALL_OFFSET      0x10u
#define PWM_OC_THRESH_OFFSET    0x18u

#define PWM_CTRL_EN             (1u << 0)
#define PWM_CTRL_LOCK           (1u << 1)

#define PWM_DEADTIME_MASK       0x3FFu
#define PWM_OC_THRESH_MASK      0xFFFu

#define PWM_STATUS_FAULT        (1u << 0)     /* W1C */
#define PWM_STATUS_ECC_SBE      (1u << 1)     /* W1C */
#define PWM_STATUS_ECC_DBE      (1u << 2)     /* W1C */
#define PWM_STATUS_TRIP_SRC_POS 3u
#define PWM_STATUS_TRIP_SRC_MSK (0x3u << PWM_STATUS_TRIP_SRC_POS)

#define PWM_ID_VALUE            0x50574D01u

#define PWM_REG(off)  (*(volatile uint32_t *)(PWM_BASE_ADDR + (off)))

/* Clear the safety-trip flag, keep the other status bits untouched. */
static inline void pwm_clear_fault(void)
{
    PWM_REG(PWM_STATUS_OFFSET) |= PWM_STATUS_FAULT;
}

static inline void pwm_set_deadtime(uint32_t rise_cycles, uint32_t fall_cycles)
{
    PWM_REG(PWM_DT_RISE_OFFSET) = rise_cycles & PWM_DEADTIME_MASK;
    PWM_REG(PWM_DT_FALL_OFFSET) = fall_cycles & PWM_DEADTIME_MASK;
}

static inline void pwm_set_oc_threshold(uint32_t lsb)
{
    PWM_REG(PWM_OC_THRESH_OFFSET) = lsb & PWM_OC_THRESH_MASK;
}

static inline uint32_t pwm_trip_source(void)
{
    return (PWM_REG(PWM_STATUS_OFFSET) & PWM_STATUS_TRIP_SRC_MSK)
           >> PWM_STATUS_TRIP_SRC_POS;
}

#endif /* PWM_REGS_H */
