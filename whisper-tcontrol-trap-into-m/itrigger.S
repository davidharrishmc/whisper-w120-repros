// itrigger.S: an interrupt taken from S-mode into M-mode must not fire an itrigger when the
// tcontrol reentrancy option is used (Sdtrig.adoc:192; Sdtrig.adoc:210-211: "Both options
// prevent etrigger and itrigger from having any effect on exceptions and interrupts that are
// handled in M-mode").
// Trigger 0: itrigger, s=1, action=0, tdata2 = 1 << 3 (machine software interrupt).
// mie.MSIE = 1 and the CLINT msip register (0x2000000) = 1: the interrupt is taken into M as
// soon as the hart enters S-mode.
// Writes 1 to tohost if the M-mode handler sees mcause = interrupt 3, else (mcause << 1) | 1
// (mcause 3 = the itrigger's breakpoint).
#include "common.h"

  .section .text.init, "ax"
  .globl _start
_start:
  SETUP_M
  csrw TSELECT, zero
  csrw TDATA1, zero
  li t0, 1 << 3               // machine software interrupt
  csrw TDATA2, t0
  li t0, (4 << 60) | (1 << 7) // type = itrigger, s = 1, action = 0 (breakpoint)
  csrw TDATA1, t0
  li t0, 1 << 3
  csrs mie, t0                // MSIE
  li t0, 0x2000000            // CLINT msip
  li t1, 1
  sw t1, 0(t0)
  GOTO_S smode

smode:
  nop
  j smode

trap:
  csrr t0, mcause
  li t1, (1 << 63) | 3
  li a0, 1
  beq t0, t1, 2f
  slli a0, t0, 1
  ori a0, a0, 1
2:
  EXIT

  TOHOST
