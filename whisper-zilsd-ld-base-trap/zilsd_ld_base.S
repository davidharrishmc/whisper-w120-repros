// RV32 Zilsd: an ld whose second word faults must leave the base register (rs1) unchanged
// (zilsd.adoc norm:Zilsd_ld_resume_trap). M-mode, bare. PMP: [0, P+0x1000) RWX, [P+0x1000, P+0x2000)
// locked with no access, rest RWX, so a word load at P+0xffc succeeds and one at P+0x1000 faults.
// x31 = 0 pass, else the failing check:
//  1: control, ld x12, 0(x10) with the second word faulting: x10 unchanged
//  2: ... load access fault (mcause 5)
//  3: ld x10, 0(x10) with the second word faulting: x10 (rd = rs1) unchanged
//  4: ... load access fault (mcause 5)
//  5: ld x10, 0(x10) with both words accessible: x10/x11 = 0x55667788/0x11223344 (sanity)
//  6, 7: (built with -DZCLSD; run before 3) the same as 3, 4 for Zclsd c.ld x10, 0(x10)
#include "exit.h"
  .section .text.init
  .globl _start
_start:
  li x31, 0; li s2, 0
#ifndef NO_SMRNMI
  csrsi 0x744, 8                       // mnstatus.NMIE = 1 (Smrnmi resets it to 0)
#endif
  li t0, 0x400; csrc 0x310, t0          // mstatush.MDT = 0 (Smdbltrp sets it at reset)
  la t0, mhandler; csrw mtvec, t0
  la t1, zl_page
  li t2, 0x1000; add t1, t1, t2
  srli t0, t1, 2; csrw pmpaddr0, t0
  add t1, t1, t2
  srli t0, t1, 2; csrw pmpaddr1, t0
  li t0, -1; csrw pmpaddr2, t0
  li t0, 0x0f880f; csrw pmpcfg0, t0
  // 1, 2: rd != rs1
  la x10, zl_page
  li t2, 0xffc; add x10, x10, t2
  mv s6, x10
  li s2, 0
  .word 0x00053603                     // ld x12, 0(x10)
  sub t1, x10, s6
  CHECK(1, t1, 0)
  CHECK(2, s2, 5)
#ifdef ZCLSD
  // 6, 7: Zclsd c.ld x10, 0(x10) with the second word faulting: x10 unchanged, mcause 5
  la x10, zl_page
  li t2, 0xffc; add x10, x10, t2
  li s2, 0
  .half 0x6108                         // c.ld x10, 0(x10)
  .half 0x0001                         // c.nop (the handler resumes at mepc + 4)
  sub t1, x10, s6
  CHECK(6, t1, 0)
  CHECK(7, s2, 5)
#endif
  // 3, 4: rd = rs1
  li s2, 0
  .word 0x00053503                     // ld x10, 0(x10)
  sub t1, x10, s6
  CHECK(3, t1, 0)
  CHECK(4, s2, 5)
  // 5: no fault
  la x10, zl_data
  .word 0x00053503                     // ld x10, 0(x10)
  CHECK(5, x10, 0x55667788)
  CHECK(5, x11, 0x11223344)
done:
  EXIT

  .align 2
mhandler:
  csrr s2, mcause
  csrr t4, mepc; addi t4, t4, 4; csrw mepc, t4
  mret

  .section .tohost, "aw"
  .align 6
  .globl tohost
tohost: .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0

  .data
  .align 3
zl_data: .word 0x55667788, 0x11223344
  .align 12
zl_page: .fill 1024, 4, 0xdeadbeef
