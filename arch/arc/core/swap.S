/*
 * Copyright (c) 2014-2015 Wind River Systems, Inc.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * @file
 * @brief Thread context switching
 *
 * This module implements the routines necessary for thread context switching
 * on ARCv2 CPUs.
 *
 * See isr_wrapper.S for details.
 */

#include <kernel_structs.h>
#include <offsets_short.h>
#include <toolchain.h>
#include <arch/cpu.h>
#include <v2/irq.h>
#include <swap_macros.h>

GTEXT(__swap)
GDATA(_k_neg_eagain)
GDATA(_kernel)

/**
 *
 * @brief Initiate a cooperative context switch
 *
 * The __swap() routine is invoked by various kernel services to effect
 * a cooperative context switch.  Prior to invoking __swap(), the caller
 * disables interrupts via irq_lock() and the return 'key' is passed as a
 * parameter to __swap(). The key is in fact the value stored in the register
 * operand of a CLRI instruction.
 *
 * It stores the intlock key parameter into current->intlock_key.

 * Given that __swap() is called to effect a cooperative context switch,
 * the caller-saved integer registers are saved on the stack by the function
 * call preamble to __swap(). This creates a custom stack frame that will be
 * popped when returning from __swap(), but is not suitable for handling a
 * return from an exception. Thus, the fact that the thread is pending because
 * of a cooperative call to __swap() has to be recorded via the _CAUSE_COOP code
 * in the relinquish_cause of the thread's k_thread structure. The
 * _IrqExit()/_FirqExit() code will take care of doing the right thing to
 * restore the thread status.
 *
 * When __swap() is invoked, we know the decision to perform a context switch or
 * not has already been taken and a context switch must happen.
 *
 * @return may contain a return value setup by a call to
 * _set_thread_return_value()
 *
 * C function prototype:
 *
 * unsigned int __swap (unsigned int key);
 *
 */

SECTION_FUNC(TEXT, __swap)

	/* interrupts are locked, interrupt key is in r0 */

	mov r1, _kernel
	ld_s r2, [r1, _kernel_offset_to_current]

	/* save intlock key */
	st_s r0, [r2, _thread_offset_to_intlock_key]
	st _CAUSE_COOP, [r2, _thread_offset_to_relinquish_cause]

	/*
         * Carve space for the return value. Setting it to a defafult of
         * -EAGAIN eliminates the need for the timeout code to set it.
         * If another value is ever needed, it can be modified with
         * _set_thread_return_value().
         */
	ld r3, [_k_neg_eagain]
	st_s r3, [r2, _thread_offset_to_return_value]

	/*
	 * Save status32 and blink on the stack before the callee-saved registers.
	 * This is the same layout as the start of an IRQ stack frame.
	 */
	lr r3, [_ARC_V2_STATUS32]
	push_s r3
#ifdef CONFIG_ARC_STACK_CHECKING
	/* disable stack checking during swap */
	bclr r3, r3, _ARC_V2_STATUS32_SC_BIT
	kflag r3
#endif
	push_s blink

	_save_callee_saved_regs

	/* get the cached thread to run */
	ld_s r2, [r1, _kernel_offset_to_ready_q_cache]

	/* entering here, r2 contains the new current thread */
#ifdef CONFIG_ARC_STACK_CHECKING
	/* Use stack top and base registers from restored context */
	ld r3, [r2, _thread_offset_to_stack_base]
	sr r3, [_ARC_V2_KSTACK_BASE]
	ld r3, [r2, _thread_offset_to_stack_top]
	sr r3, [_ARC_V2_KSTACK_TOP]
#endif
	/* XXX - can be moved to delay slot of _CAUSE_RIRQ ? */
	st_s r2, [r1, _kernel_offset_to_current]

	_load_callee_saved_regs

	ld_s r3, [r2, _thread_offset_to_relinquish_cause]

	breq r3, _CAUSE_RIRQ, _swap_return_from_rirq
	nop
	breq r3, _CAUSE_FIRQ, _swap_return_from_firq
	nop

	/* fall through to _swap_return_from_coop */

.balign 4
_swap_return_from_coop:

	ld_s r1, [r2, _thread_offset_to_intlock_key]
	st  0, [r2, _thread_offset_to_intlock_key]
	ld_s r0, [r2, _thread_offset_to_return_value]

	lr ilink, [_ARC_V2_STATUS32]
	bbit1 ilink, _ARC_V2_STATUS32_AE_BIT, _return_from_exc

	pop_s blink /* pc into blink */
	pop_s r3    /* status32 into r3 */
	kflag r3    /* write status32 */

	j_s.d [blink] /* always execute delay slot */
	seti r1       /* delay slot */


.balign 4
_swap_return_from_rirq:
_swap_return_from_firq:

	lr r3, [_ARC_V2_STATUS32]
	bbit1 r3, _ARC_V2_STATUS32_AE_BIT, _return_from_exc_irq

	/* pretend interrupt happened to use rtie instruction */
	lr r3, [_ARC_V2_AUX_IRQ_ACT]
	brne r3,0,_swap_already_in_irq

	or r3,r3,(1<<(CONFIG_NUM_IRQ_PRIO_LEVELS-1)) /* use lowest */
	sr r3, [_ARC_V2_AUX_IRQ_ACT]

_swap_already_in_irq:
	rtie

.balign 4
_return_from_exc_irq:
	_pop_irq_stack_frame
	sub_s sp, sp, 8

_return_from_exc:

	/* put the return address to eret */
	ld ilink, [sp] /* pc into ilink */
	sr ilink, [_ARC_V2_ERET]

	/* put status32 into estatus */
	ld ilink, [sp, 4] /* status32 into ilink */
	sr ilink, [_ARC_V2_ERSTATUS]
	add_s sp, sp, 8
	rtie
