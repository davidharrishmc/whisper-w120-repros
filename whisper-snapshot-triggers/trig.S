// Whisper snapshots must keep the debug triggers. The test sets two mcontrol6 triggers for U-mode: trigger 0
// on executing bp_target and trigger 1 on loading data_word, both action 0 (breakpoint exception, delegated
// to S-mode), leaves tselect = 0, and enters U-mode, where it runs a nop sled (run.sh saves a snapshot there
// and restarts from it), then loads data_word and executes bp_target. The S-mode handler records each
// breakpoint (scause 3) and resumes after the load; an ecall ends the test.
//   check 1: the load trigger (trigger 1, not the one tselect selects) did not fire
//   check 2: the execute trigger (trigger 0) did not fire
//   check 3: an unexpected trap
// x31 = bitmask of failed checks. tohost = (x31 << 1) | 1.
#include "exit.h"
#define XLEN __riscv_xlen
// mcontrol6 (type 6), action 0, u, plus execute (bit 2) or load (bit 0); match equal, timing before.
#define MC6(r, bits) li r, 6; slli r, r, XLEN - 4; ori r, r, 0x8 | (bits)

  .option norelax
  .section .text.init
  .globl _start
_start:
  li x31, 0
  li t0, -1; csrw pmpaddr0, t0; li t0, 0x0f; csrw pmpcfg0, t0
  la t0, mtrap; csrw mtvec, t0
  la t0, shandler; csrw stvec, t0
  li t0, (1 << 3) | (1 << 8); csrs medeleg, t0   // breakpoint and ecall from U trap to S-mode
  csrw satp, zero
  li t0, 1; csrw tselect, t0
  MC6(t0, 0x1); csrw tdata1, t0
  la t0, data_word; csrw tdata2, t0    // trigger 1: load of data_word
  csrw tselect, zero
  MC6(t0, 0x4); csrw tdata1, t0
  la t0, bp_target; csrw tdata2, t0    // trigger 0: execute bp_target
  li s3, 0                             // bit 0: load trigger fired, bit 1: execute trigger fired
  la s2, data_word
  li t0, 0x1800; csrc mstatus, t0      // MPP = U
  la t0, u_code; csrw mepc, t0
  mret

u_code:                                // U-mode
  .rept 64                             // run.sh saves the snapshot in this sled
  nop
  .endr
  .globl ld_inst
ld_inst:
  lw t0, 0(s2)                         // trigger 1
  .globl bp_target
bp_target:
  nop                                  // trigger 0
  ecall

  .align 2
shandler:                              // S-mode
  csrr t0, scause; csrr t1, sepc
  li t2, 8; beq t0, t2, check          // ecall from U: done
  li t2, 3; bne t0, t2, unexpected
  la t2, ld_inst; bne t1, t2, 1f
  ori s3, s3, 1; addi t1, t1, 4; csrw sepc, t1; sret   // load breakpoint: resume after the load
1:la t2, bp_target; bne t1, t2, unexpected
  ori s3, s3, 2
check:
  andi t0, s3, 1; CHECKC(1, t0, 1)
  andi t0, s3, 2; CHECKC(2, t0, 2)
  j done
  .align 2
mtrap:
unexpected:
  li t0, 1 << 3; or x31, x31, t0
done:
  EXIT

  .data
  .align 3
data_word: .dword 0x1234

  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
