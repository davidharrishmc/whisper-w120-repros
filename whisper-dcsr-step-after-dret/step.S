// dcsr.step (Sdext.adoc, Single Step): "If dcsr.step is set when a hart resumes then it will single step";
// with step set "the hart will only execute a single instruction and then enter Debug Mode", and "If control
// is transferred to a trap handler while executing the instruction, then Debug Mode is re-entered
// immediately after the PC is changed to the trap handler".
// The test enters Debug Mode with ebreak (dcsr.ebreakm resets to 1; debug_park_loop = park), sets dcsr.step
// and resumes with dret at step_a. It then single-steps step_a (addi), step_b (addi) and step_c (ecall, which
// traps to M-mode): each dret must execute one instruction, so the halts must have dpc = step_b, step_c and
// mhandler (with mcause 11, mepc = step_c), each with dcsr.cause = 4 (step). After the third halt the test
// clears dcsr.step and resumes; mhandler then checks that each addi executed exactly once.
// x31 = bitmask of failed checks: 1/2/3 dpc wrong at halt 1/2/3, 4 dcsr.cause != 4 at some halt,
// 5 mcause != 11 or mepc != step_c at halt 3, 6 a0 != 2 in mhandler, 7 more than 3 halts (stopped at 6),
// 8 mhandler reached with dcsr.step still expected. tohost = (x31 << 1) | 1.
#include "exit.h"
#define DCSR 0x7b0
#define DPC  0x7b1
#define DRET .word 0x7b200073
#if __riscv_xlen == 64
#define MDT_CLR  li t0, 1; slli t0, t0, 42; csrc mstatus, t0
#else
#define MDT_CLR  li t0, 1 << 10; csrc mstatush, t0
#endif

  .option norelax
  .section .text.init
  .globl _start
_start:
  li x31, 0
  li t0, -1; csrw pmpaddr0, t0; li t0, 0x0f; csrw pmpcfg0, t0
  la t0, mhandler; csrw mtvec, t0
  MDT_CLR                              // mstatus.MDT = 0 (Smdbltrp) and
  li t0, 8; csrs 0x744, t0             // mnstatus.NMIE = 1 (Smrnmi), so the ecall is an ordinary trap
  li a0, 0                             // incremented by step_a and step_b
  li s1, 0                             // number of step halts
  la s0, debug_start
  ebreak                               // dcsr.ebreakm = 1: enter Debug Mode at park
  j done

debug_start:                           // Debug Mode
  csrr t0, DCSR; ori t0, t0, 4; csrw DCSR, t0   // dcsr.step = 1
  la t0, step_a; csrw DPC, t0
  la s0, after_halt
  DRET

  .globl step_a
step_a: addi a0, a0, 1
  .globl step_b
step_b: addi a0, a0, 1
  .globl step_c
step_c: ecall
  j done

after_halt:                            // Debug Mode, after each step halt
  addi s1, s1, 1
  csrr t0, DCSR; srli t0, t0, 6; andi t0, t0, 7
  li t1, 4; beq t0, t1, 1f; li t5, 1 << 4; or x31, x31, t5; 1:
  csrr t0, DPC
  li t1, 1; bne s1, t1, 2f
  la t1, step_b; beq t0, t1, resume; li t5, 1 << 1; or x31, x31, t5; j resume
2:li t1, 2; bne s1, t1, 3f
  la t1, step_c; beq t0, t1, resume; li t5, 1 << 2; or x31, x31, t5; j resume
3:li t1, 3; bne s1, t1, 4f
  la t1, mhandler; beq t0, t1, 5f; li t5, 1 << 3; or x31, x31, t5; 5:
  csrr t0, mcause; li t1, 11; bne t0, t1, 6f
  csrr t0, mepc; la t1, step_c; beq t0, t1, 7f
6:li t5, 1 << 5; or x31, x31, t5
7:csrr t0, DCSR; andi t0, t0, ~4; csrw DCSR, t0   // dcsr.step = 0: run mhandler normally
  j resume
4:li t1, 6; blt s1, t1, resume
  li t5, 1 << 7; or x31, x31, t5       // too many halts: stop here
  j done
resume:
  DRET

  .align 2
  .globl mhandler
mhandler:
  li t1, 3; beq s1, t1, 1f; li t5, 1 << 8; or x31, x31, t5; 1:
  li t1, 2; beq a0, t1, done; li t5, 1 << 6; or x31, x31, t5
done:
  EXIT

  .org 0x800
park:                                  // Debug Mode entry (debug_park_loop)
  jr s0
  .org 0x900
debug_trap:                            // exception in Debug Mode (debug_trap_address)
  li t0, 1 << 27; or x31, x31, t0
  j done

  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
