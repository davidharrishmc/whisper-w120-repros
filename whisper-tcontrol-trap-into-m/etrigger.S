// etrigger.S: an exception raised in S-mode and taken into M-mode must not fire an etrigger
// when the tcontrol reentrancy option is used (Sdtrig.adoc:192: tcontrol.mte/mpte are
// implemented; Sdtrig.adoc:210-211: "Both options prevent etrigger and itrigger from having any
// effect on exceptions and interrupts that are handled in M-mode"). Taking the trap into M sets
// mpte = mte and mte = 0, and the etrigger would fire just before the first instruction of the
// M-mode handler.
// Trigger 0: etrigger, s=1, action=0, tdata2 = 1 << 2 (illegal instruction). medeleg = 0.
// Writes 1 to tohost if the M-mode handler sees mcause 2 (the illegal instruction), else
// (mcause << 1) | 1 (mcause 3 = the etrigger's breakpoint).
#include "common.h"

  .section .text.init, "ax"
  .globl _start
_start:
  SETUP_M
  csrw TSELECT, zero
  csrw TDATA1, zero
  li t0, 1 << 2               // illegal-instruction exception
  csrw TDATA2, t0
  li t0, (5 << 60) | (1 << 7) // type = etrigger, s = 1, action = 0 (breakpoint)
  csrw TDATA1, t0
  GOTO_S smode

smode:
  .word 0                     // illegal instruction, taken into M (medeleg[2] = 0)
  j smode

trap:
  csrr t0, mcause
  li t1, 2
  li a0, 1
  beq t0, t1, 2f
  slli a0, t0, 1
  ori a0, a0, 1
2:
  EXIT

  TOHOST
