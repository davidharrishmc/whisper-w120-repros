// medeleg3.S: with the tcontrol reentrancy option, medeleg[3] is hard-wired to 0
// (Sdtrig.adoc:192: "tcontrol.mte and tcontrol.mpte in tcontrol is implemented. medeleg[3] is
// hard-wired to 0."). Runs both checks and writes 1 to tohost when both pass, or
// (failmask << 1) | 1 (bit N-1 of failmask = check N):
//   check 1: medeleg reads back with bit 3 clear after writing all ones.
//   check 2: with that write in place, ebreak in S-mode traps to M (not to S).
#include "common.h"

  .section .text.init, "ax"
  .globl _start
_start:
  SETUP_M
  la t0, strap
  csrw stvec, t0
  li s0, 0                    // failure mask

check1:
  li t0, -1
  csrw medeleg, t0
  csrr t1, medeleg
  andi t1, t1, 1 << 3
  beqz t1, check2
  ori s0, s0, 1

check2:
  GOTO_S smode

smode:
  ebreak
  j smode

strap:                        // breakpoint delegated to S: check 2 failed
  ori s0, s0, 2

trap:                         // M-mode handler, or fall-through from strap
  li a0, 1
  beqz s0, 2f
  slli a0, s0, 1
  ori a0, a0, 1
2:
  EXIT

  TOHOST
