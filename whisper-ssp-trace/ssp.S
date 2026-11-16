// S-mode with menvcfg.SSE = 1 and Sv39: VA 0x80000000 is an identity RWX gigapage for code and data,
// and VA 0x40000000 maps the same memory as a shadow-stack (W-only) gigapage. csrw ssp, then
// sspush x1 (ssp -= 8) and sspopchk x1 (ssp += 8). The program checks the ssp values (checks 1 and 2); run.sh checks that the
// trace reports the ssp write of each instruction.
#include "common.h"
  .section .text.init
  .globl _start
_start:
  la t0, handler; csrw mtvec, t0
  li t0, -1; csrw pmpaddr0, t0               // PMP: all memory RWX for S-mode
  li t0, 0x1f; csrw pmpcfg0, t0
  li t0, 8; csrs menvcfg, t0                 // menvcfg.SSE = 1
  la t0, root                                // Sv39 root table: entry 2 = identity RWX gigapage
  li t1, 0x80000000; srli t1, t1, 2          // PPN(0x80000000) << 10
  ori t2, t1, 0xcf; sd t2, 16(t0)            // V R W X A D
  ori t2, t1, 0xc5; sd t2, 8(t0)             // entry 1: V W A D = shadow-stack page
  srli t0, t0, 12; li t1, 8; slli t1, t1, 60; or t0, t0, t1
  csrw satp, t0; sfence.vma
  li t0, 0x1800; csrc mstatus, t0
  li t0, 0x0800; csrs mstatus, t0            // MPP = S
  la t0, smode; csrw mepc, t0
  mret
smode:
  la t0, sstack_top; li t1, 0x40000000; sub t0, t0, t1; csrw ssp, t0   // shadow-stack VA
  li ra, 0x1234
  .globl push
push:
  sspush ra
  csrr t1, ssp; addi t0, t0, -8; bne t1, t0, fail1
  .globl pop
pop:
  sspopchk ra
  csrr t1, ssp; addi t0, t0, 8; bne t1, t0, fail2
  ecall
fail1: li a0, 1; ecall
fail2: li a0, 2; ecall
handler:                                     // ecall from S: a0 = 0 pass, else failing check
  csrr t0, mcause; li t1, 9; beq t0, t1, 1f
  TEST_FAIL(3)
1: bnez a0, 2f
  TEST_PASS
2: j report
TEST_END
  .data
  .balign 4096
root: .space 4096
  .balign 64
sstack: .space 64
sstack_top:
