#include "common.h"
  .section .text.init
  .globl _start
_start:
  la t0, trap; csrw mtvec, t0
  li t0, 1 << 42; csrc mstatus, t0                  // clear MDT
#ifndef NO_SMRNMI
  csrsi 0x744, 8                                    // mnstatus.NMIE = 1 (else MPRV is ignored)
#endif
  li t0, -1; csrw pmpaddr0, t0; li t0, 0x1f; csrw pmpcfg0, t0
  MKPTE(t0, l1, 1);  la t1, sroot; sd t0, 8(t1)
  MKPTE(t0, l0, 1);  la t1, l1;    sd t0, 0(t1)
  MKPTE(t0, pgA, 0xc7); la t1, l0; sd t0, 0(t1)     // non-global S leaf
  la t0, sroot; srli t0, t0, 12; li t1, (8 << 60) | (1 << 44); or t0, t0, t1
  csrw satp, t0                                     // Sv39, ASID 1
  sfence.vma x0, x0
  li t0, 3 << 11; csrc mstatus, t0
  li t0, (1 << 17) | (1 << 11); csrs mstatus, t0    // MPRV=1, MPP=S
  li a0, 0x40000000
  lw a1, 0(a0)
  li t2, 0x11111111; beq a1, t2, 1f; FAIL(1)
1:
  li t0, 1 << 17; csrc mstatus, t0                  // MPRV=0 for the PTE store
  MKPTE(t0, pgB, 0xc7); la t1, l0; sd t0, 0(t1)
  li t0, 1 << 17; csrs mstatus, t0
  li t3, 1 | (1 << 20)
  sfence.vma x0, t3                                 // ASID 1 with bit 20 set
  lw a1, 0(a0)
  li t2, 0x22222222; beq a1, t2, 1f; FAIL(2)
1:
  PASS
#include "tail.S"
  .data
  .align 12
sroot: .fill 4096, 1, 0
l1: .fill 4096, 1, 0
l0: .fill 4096, 1, 0
pgA: .word 0x11111111
  .fill 4092, 1, 0
pgB: .word 0x22222222
  .fill 4092, 1, 0
