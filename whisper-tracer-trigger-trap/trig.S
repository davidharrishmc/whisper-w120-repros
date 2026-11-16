// An execute-address breakpoint trigger (mcontrol6, action 0, u = 1) on `target`. M-mode drops to
// U-mode at `target`; the trigger fires before `target` executes, and the M-mode handler checks
// mcause = 3 (breakpoint) (check 1) and mepc = target (check 2).
#include "common.h"
  .section .text.init
  .globl _start
_start:
  la t0, handler; csrw mtvec, t0
  li t0, -1; csrw pmpaddr0, t0               // PMP: all memory RWX in U-mode
  li t0, 0x1f; csrw pmpcfg0, t0
  csrw tselect, zero
  csrw tdata1, zero
  la t0, target; csrw tdata2, t0
  li t0, 6; slli t0, t0, 60; ori t0, t0, 0xc  // mcontrol6: type 6, u = 1, execute = 1
  csrw tdata1, t0
  li t0, 0x1800; csrc mstatus, t0             // MPP = U
  la t0, target; csrw mepc, t0
  mret
target:
  addi a1, a1, 1                              // never executes
  TEST_FAIL(3)
handler:
  csrw tdata1, zero
  csrr t0, mcause; li t1, 3; beq t0, t1, 1f
  TEST_FAIL(1)
1: csrr t0, mepc; la t1, target; beq t0, t1, 2f
  TEST_FAIL(2)
2: TEST_PASS
TEST_END
