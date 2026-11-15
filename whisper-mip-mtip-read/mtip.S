// Once mtime >= mtimecmp, mip.MTIP must read 1 "eventually, but not necessarily immediately"
// (norm:mtime_intr_mtip_visibility), whether or not the timer interrupt is enabled. With
// mstatus.MIE = 0 and mie = 0, Whisper (without --logfile) never re-evaluates MTIP, so polling
// mip never sees MTIP = 1 -> failure 2.
// CLINT at 0x2000000 (mtimecmp 0x2004000, mtime 0x200bff8).
#include "common.h"
#define MTIMECMP 0x2004000
#define MTIME    0x200bff8
  .section .text.init
  .globl _start
_start:
  csrw mie, zero
  csrci mstatus, 8          // MIE = 0: no interrupt can be taken
  li t0, MTIME
  li t1, MTIMECMP
  LREG t2, 0(t0)
  addi t2, t2, 16
  SREG t2, 0(t1)            // mtimecmp = mtime + 16
  li t3, 100000             // spin well past mtimecmp
1:addi t3, t3, -1
  bnez t3, 1b
  LREG t4, 0(t0)
  bgeu t4, t2, 2f
  TEST_FAIL(1)              // mtime did not reach mtimecmp (environment problem, not the bug)
2:li t3, 100000             // poll mip for MTIP
4:csrr t5, mip
  andi t5, t5, 0x80
  bnez t5, 3f
  addi t3, t3, -1
  bnez t3, 4b
  TEST_FAIL(2)              // mtime >= mtimecmp, but 100,000 reads of mip never see MTIP = 1
3:TEST_PASS
TEST_END
