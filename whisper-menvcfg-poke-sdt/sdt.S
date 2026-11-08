// Poking menvcfg/henvcfg must apply the same DTE rules as writing them (machine.adoc, hypervisor.adoc):
// with menvcfg.DTE = 1, mstatus.SDT and henvcfg.DTE are writable and readable, and with henvcfg.DTE = 1,
// vsstatus.SDT is. Whisper's snapshot restore pokes every CSR, so run.sh restores a snapshot taken in an
// M-mode nop sled after the test has set menvcfg.DTE, henvcfg.DTE and mstatus.SDT, then the test checks:
//   check 1: csrr mstatus shows SDT = 1 (set before the snapshot)
//   check 2: csrr henvcfg shows DTE = 1 (set before the snapshot)
//   check 3: csrc then csrs sstatus.SDT: sstatus shows SDT = 1
//   check 4: csrs vsstatus.SDT: vsstatus shows SDT = 1
// x31 = bitmask of failed checks. tohost = (x31 << 1) | 1. No trap is taken.
#include "exit.h"
#define SDT (1 << 24)
#if __riscv_xlen == 64
#define DTE_SET     li t0, 1; slli t0, t0, 59; csrs menvcfg, t0; csrs henvcfg, t0
#define HDTE_GET(r) csrr r, henvcfg; srli r, r, 59; andi r, r, 1
#else
#define DTE_SET     li t0, 1 << 27; csrs menvcfgh, t0; csrs henvcfgh, t0
#define HDTE_GET(r) csrr r, henvcfgh; srli r, r, 27; andi r, r, 1
#endif

  .option norelax
  .section .text.init
  .globl _start
_start:
  li x31, 0
  la t0, mtrap; csrw mtvec, t0
  DTE_SET                              // menvcfg.DTE = henvcfg.DTE = 1
  li t0, SDT; csrs mstatus, t0         // mstatus.SDT = 1
  .rept 64                             // run.sh saves the snapshot in this sled
  nop
  .endr
  .globl check
check:
  li t1, SDT
  csrr t0, mstatus; and t0, t0, t1; CHECKC(1, t0, SDT)
  HDTE_GET(t0); CHECKC(2, t0, 1)
  csrc sstatus, t1; csrs sstatus, t1; csrr t0, sstatus; and t0, t0, t1; CHECKC(3, t0, SDT)
  csrs vsstatus, t1; csrr t0, vsstatus; and t0, t0, t1; CHECKC(4, t0, SDT)
  j done
  .align 2
mtrap:                                 // no trap is expected
  li t0, 1 << 7; or x31, x31, t0
done:
  EXIT

  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
