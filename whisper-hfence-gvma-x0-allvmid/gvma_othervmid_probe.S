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
  MKPTE(t0, l1, 1);  la t1, groot; sd t0, 8(t1)     // root[1] -> l1 (GPA 0x40000000)
  MKPTE(t0, l0, 1);  la t1, l1;    sd t0, 0(t1)
  MKPTE(t0, pgA, 0xdf); la t1, l0; sd t0, 0(t1)
  csrw 0x280, x0                                    // vsatp = Bare
  la t0, groot; srli t0, t0, 12; li t1, (8 << 60) | (1 << 44); or s1, t0, t1   // hgatp VMID 1
  la t0, groot; srli t0, t0, 12; li t1, (8 << 60) | (2 << 44); or s2, t0, t1   // hgatp VMID 2
  csrw 0x680, s1
  HFENCE_GVMA(0, 0)
  li a0, 0x40000000
  HLV_W(11, 10)
  li t2, 0x11111111; beq a1, t2, 1f; FAIL(1)
1:
  csrw 0x680, s2                                    // switch to VMID 2
  MKPTE(t0, pgB, 0xdf); la t1, l0; sd t0, 0(t1)     // retarget GPA 0x40000000 -> pgB
  li a3, 2; HFENCE_GVMA(0, 13)                      // VMID 2 only (probe: VMID 1 entries may survive)
  csrw 0x680, s1                                    // back to VMID 1
  HLV_W(11, 10)
  li t2, 0x22222222; beq a1, t2, 1f; FAIL(2)
1:
  PASS
#include "tail.S"
  .data
  .align 14
groot: .fill 16384, 1, 0
  .align 12
l1: .fill 4096, 1, 0
l0: .fill 4096, 1, 0
pgA: .word 0x11111111
  .fill 4092, 1, 0
pgB: .word 0x22222222
  .fill 4092, 1, 0
