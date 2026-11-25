// mtime-wrap (bare metal, RV64, M-mode, interrupts disabled): mip.MTIP after mtime wraps past 2^64 to below mtimecmp.
// CLINT at 0x2000000 (mtimecmp 0x2004000, mtime 0x200bff8). Failure n: "FAIL n" on the HTIF console.
#include "common.h"
#define MTIMECMP 0x2004000
#define MTIME    0x200bff8
  .section .text.init
  .globl _start
_start:
  csrw mie, zero
  csrci mstatus, 8          // MIE = 0: no interrupt can be taken
  li s0, MTIME
  li s1, MTIMECMP
  li s2, -0x80
  sd s2, 0(s1)              // mtimecmp = 2^64 - 0x80
  li t2, -0x100
  sd t2, 0(s0)              // mtime = 2^64 - 0x100
  li t3, 100000
1:csrr t5, mip
  andi t5, t5, 0x80
  bnez t5, 2f
  addi t3, t3, -1
  bnez t3, 1b
  TEST_FAIL(1)              // control: MTIP = 1 once mtime reaches mtimecmp
2:li t3, 100000
6:ld t4, 0(s0)
  bltu t4, s2, 3f
  addi t3, t3, -1
  bnez t3, 6b
  TEST_FAIL(2)              // control: mtime wraps to a value below mtimecmp
3:li t3, 100000             // poll mip (reads only)
4:csrr t5, mip
  andi t5, t5, 0x80
  beqz t5, 5f
  addi t3, t3, -1
  bnez t3, 4b
  TEST_FAIL(3)              // mtime < mtimecmp, but 100,000 reads of mip all have MTIP = 1
5:ld t4, 0(s0)
  bltu t4, s2, 7f
  TEST_FAIL(4)              // control: mtime is still below mtimecmp
7:TEST_PASS
TEST_END
