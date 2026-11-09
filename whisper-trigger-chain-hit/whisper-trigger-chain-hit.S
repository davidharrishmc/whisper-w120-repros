// Reproducer: the first trigger of an mcontrol6 chain gets hit0 set when it matches but the chain does not
// fire.
// Spec (tinfo.version = 1): riscv-debug-spec xml/hwbp_registers.xml mcontrol6.hit0 (norm:Sdtrig_mcontrol6_hit0)
//   "The TM updates this field when the trigger fires"; value 0 "The trigger did not fire". mcontrol6.chain
//   "The action on all but the final trigger is ignored. The action on that final trigger will be taken if and
//   only if all the triggers in the chain match at the same time"; (norm:Sdtrig_mcontrol6_chain) "A chain of
//   triggers must only fire if every trigger in the chain was matched by the same instruction."
// Case: chain {trigger 0: U execute at A, chain=1; trigger 1: U execute at B}. Executing A (not B) fires
//   nothing, so hit1:hit0 of both triggers stay 0.
// Control: chain {trigger 0: U execute at C, chain=1; trigger 1: U execute at C}. Executing C fires the chain
//   (breakpoint, mcause 3) and sets hit0 of trigger 1. Whether trigger 0, whose action is ignored, also counts
//   as firing is not settled by the text (Whisper and Spike set its hit0, Sail does not), so either is accepted.
// Whisper: Triggers::updateChainHitBit sets hit on each leading trigger of a chain whose local hit is set,
//   before it knows whether the whole chain matched.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'U', 'Sdtrig']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define MC6 (6 << (__riscv_xlen - 4))
#define TD1A (MC6 | (1 << 11) | (1 << 3) | (1 << 2))   /* chain=1 u=1 execute */
#define TD1B (MC6 | (1 << 3) | (1 << 2))               /* u=1 execute */
#define HITS ((1 << 25) | (1 << 22))

// trigger 1 = TD1B at _B, trigger 0 = TD1A at _A; x7 = trigger 0's tdata1 as read back
#define SET_CHAIN(_A, _B)      \
  li x6, 1                    ;\
  csrw tselect, x6            ;\
  csrw tdata1, x0             ;\
  LA(x6, _B)                  ;\
  csrw tdata2, x6             ;\
  LI(x6, TD1B)                ;\
  csrw tdata1, x6             ;\
  csrw tselect, x0            ;\
  csrw tdata1, x0             ;\
  LA(x6, _A)                  ;\
  csrw tdata2, x6             ;\
  LI(x6, TD1A)                ;\
  csrw tdata1, x6             ;\
  csrr x7, tdata1

// x7 = hit1|hit0 bits of trigger _N
#define GET_HITS(_N)           \
  li x6, _N                   ;\
  csrw tselect, x6            ;\
  csrr x7, tdata1             ;\
  LI(x5, HITS)                ;\
  and x7, x7, x5

RVTEST_BEGIN
  .option norvc
  li x5, 8
  csrc medeleg, x5            // breakpoints trap to M
  li x6, 1
  csrw tselect, x6
  csrr x7, tselect
  bne x7, x6, sa_skip         // fewer than 2 triggers

  // case: only the first trigger of the chain matches
  SET_CHAIN(sa_a, sa_b)
  LI(x6, TD1A)
  bne x7, x6, sa_skip         // chain not supported
  SA_TRY(1)
  RVTEST_TSBI_GOTO_UMODE
sa_a:
  nop                         // matches trigger 0 only
  nop
  RVTEST_TSBI_GOTO_MMODE
  SA_TRAPS(0, -1, "case: only the first trigger matches: no breakpoint")
  GET_HITS(0)
  SA_CHECK(x7, 0, "case: chain did not fire: hit1|hit0 of trigger 0")
  GET_HITS(1)
  SA_CHECK(x7, 0, "case: chain did not fire: hit1|hit0 of trigger 1")

  // control: both triggers of the chain match the same instruction
  SET_CHAIN(sa_c, sa_c)
  SA_TRY(1)
  RVTEST_TSBI_GOTO_UMODE
sa_c:
  nop                         // matches both triggers: the chain fires
  nop
  RVTEST_TSBI_GOTO_MMODE
  SA_TRAPS(1, 3, "control: both triggers match: breakpoint")
  GET_HITS(1)
  SA_CHECK(x7, 1 << 22, "control: chain fired: hit1|hit0 of trigger 1 (hit0 = 1)")
  GET_HITS(0)                 // non-final member of a chain that fired: 0 or hit0 = 1 (see above)
  SA_CHECK2(x7, 0, 1 << 22, "control: chain fired: hit1|hit0 of trigger 0 (0 or hit0 = 1)")

sa_skip:
  li x6, 1
  csrw tselect, x6
  csrw tdata1, x0
  csrw tselect, x0
  csrw tdata1, x0
  j sa_end
sa_b:
  nop
sa_end:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
