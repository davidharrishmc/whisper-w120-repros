// mcycle/minstret must count when not inhibited and must stop when mcountinhibit.CY/IR = 1.
// Whisper gets both right with --logfile, but its fast run loops (no --logfile) do not:
//  - with an M-mode-only hart (simpleRunNoLimit) mcycle/minstret never advance -> failure 1 or 2;
//  - otherwise (simpleRunWithLimit) a write to mcountinhibit never takes effect -> failure 3 or 4.
#include "common.h"
  .section .text.init
  .globl _start
_start:
  csrw mcountinhibit, zero
  nop
  // 1, 2: counters advance while not inhibited
  csrr t0, minstret
  csrr t1, mcycle
  .rept 32
  nop
  .endr
  csrr t2, minstret
  csrr t3, mcycle
  li t4, 32
  sub t2, t2, t0
  bgeu t2, t4, 1f
  TEST_FAIL(1)      // minstret advanced by less than 32
1:bne t3, t1, 2f
  TEST_FAIL(2)      // mcycle did not advance (its rate is implementation-defined, so only check it moved)
2:
  // 3, 4: counters hold while inhibited (mcountinhibit.CY = IR = 1)
  li t0, 5
  csrw mcountinhibit, t0
  csrr t5, mcountinhibit
  beq t5, t0, 5f
  TEST_PASS         // mcountinhibit.CY/IR not writable on this hart: checks 3 and 4 do not apply
5:csrr t0, minstret
  csrr t1, mcycle
  .rept 32
  nop
  .endr
  csrr t2, minstret
  csrr t3, mcycle
  beq t2, t0, 3f
  TEST_FAIL(3)      // minstret advanced while inhibited
3:beq t3, t1, 4f
  TEST_FAIL(4)      // mcycle advanced while inhibited
4:TEST_PASS
TEST_END
