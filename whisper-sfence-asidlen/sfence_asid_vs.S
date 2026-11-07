// V=1 variant: sfence.vma executed in VS-mode must ignore rs2 bits above vsatp's ASID field.
// hgatp = Bare, vsatp = Sv39 ASID 1. The loads and the fence run in VS-mode (code mapped by a global identity
// gigapage); M-mode retargets the leaf in between. RS2 is the fence's rs2.
#include "common.h"
#ifndef RS2
#define RS2 1
#endif
  .section .text.init
  .globl _start
_start:
  la t0, trap; csrw mtvec, t0
  li t0, 1 << 42; csrc mstatus, t0                  // clear MDT
#ifndef NO_SMRNMI
  csrsi 0x744, 8                                    // mnstatus.NMIE = 1 (else MPRV is ignored)
#endif
  li t0, -1; csrw pmpaddr0, t0; li t0, 0x1f; csrw pmpcfg0, t0
  csrw hgatp, zero; csrw medeleg, zero
  MKPTE(t0, l1, 1);  la t1, sroot; sd t0, 8(t1)
  li t0, (0x80000000 >> 12) << 10 | 0xef; sd t0, 16(t1)   // global RWX identity gigapage for code
  MKPTE(t0, l0, 1);  la t1, l1;    sd t0, 0(t1)
  MKPTE(t0, pgA, 0xc7); la t1, l0; sd t0, 8(t1)     // non-global leaf
  la t0, sroot; srli t0, t0, 12; li t1, (8 << 60) | (1 << 44); or t0, t0, t1
  csrw vsatp, t0                                    // Sv39, ASID 1
  li a0, 0x40001000                                 // VPN 0x40001: no direct-mapped TLB index clash with the code page
  li t3, RS2
  la s0, back1
  la t0, vs1; j to_vs
vs1:
  lw a1, 0(a0)                                      // VS: caches the translation of page A
  ecall
back1:
  li t2, 0x11111111; beq a1, t2, 1f; FAIL(1)
1:
  MKPTE(t0, pgB, 0xc7); la t1, l0; sd t0, 8(t1)     // M: retarget the leaf to page B
  la s0, back2
  la t0, vs2; j to_vs
vs2:
  sfence.vma x0, t3                                 // VS: fence ASID 1 (plus the ignored rs2 bits)
  lw a1, 0(a0)
  ecall
back2:
  li t2, 0x22222222; beq a1, t2, 1f; FAIL(2)
1:
  PASS
to_vs:                                              // mret to VS-mode at t0
  csrw mepc, t0
  li t1, 3 << 11; csrc mstatus, t1
  li t1, (1 << 39) | (1 << 11); csrs mstatus, t1    // MPV=1, MPP=S
  mret
  .align 2
trap:
  csrr t5, mcause
  li t4, 10; bne t5, t4, 1f                         // ecall from VS: continue at s0 in M-mode
  jr s0
1:
  li t6, (99 << 1) | 1
write_tohost:
  li t0, 1 << 17; csrc mstatus, t0
#ifdef QEMU
  // QEMU virt: sifive test finisher; 0x5555 = pass, (n << 16) | 0x3333 = exit status n.
  li t0, 0x100000; srli t1, t6, 1; bnez t1, 2f
  li t1, 0x5555; sw t1, 0(t0)
1: j 1b
2: slli t1, t1, 16; li t2, 0x3333; or t1, t1, t2; sw t1, 0(t0)
1: j 1b
#else
  la t0, tohost
  sd t6, 0(t0)
1: j 1b
#endif
  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
  .data
  .align 12
sroot: .fill 4096, 1, 0
l1: .fill 4096, 1, 0
l0: .fill 4096, 1, 0
pgA: .word 0x11111111
  .fill 4092, 1, 0
pgB: .word 0x22222222
  .fill 4092, 1, 0
