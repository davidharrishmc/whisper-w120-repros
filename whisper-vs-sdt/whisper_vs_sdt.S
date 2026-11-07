// Whisper: Ssdbltrp at VS level (menvcfg.DTE = henvcfg.DTE = 1).
//  check 2: a trap into VS-mode does not set vsstatus.SDT.
//  check 4: a trap into VS-mode with vsstatus.SDT = 1 is delivered to VS-mode instead of a double trap into M (cause 16).
//  check 5: MRET to VU-mode does not clear vsstatus.SDT (machine.adoc: "if it is VU, then vsstatus.SDT is also set to 0").
#include "exit.h"
  .section .text.init
  .globl _start
_start:
  li x31, 0
  li t0, -1
  csrw pmpaddr0, t0
  li t0, 0x0f
  csrw pmpcfg0, t0          // PMP entry 0: TOR RWX over everything, so VS/VU can run
  la t0, mhandler
  csrw mtvec, t0
  la t0, vshandler
  csrw vstvec, t0
  li t0, 1
  slli t0, t0, 59
  csrs menvcfg, t0          // menvcfg.DTE
  csrs henvcfg, t0          // henvcfg.DTE
  li t0, 8
  csrs medeleg, t0          // breakpoints to HS ...
  csrs hedeleg, t0          // ... and on to VS
  csrw vsatp, zero
  csrw hgatp, zero
  li s1, 0x01000000         // SDT
  // 1-2: ebreak in VS-mode with vsstatus.SDT = 0: VS handler sees SDT = 1
  csrc vsstatus, s1
  la a0, after1
  jal enter_vs
after1:
  CHECKC(1, s2, 3)           // the VS handler ran (vscause 3)
  srli s3, s3, 24
  andi s3, s3, 1
  CHECKC(2, s3, 1)           // Whisper: vsstatus.SDT = 0 at VS handler entry
  // 3-4: ebreak in VS-mode with vsstatus.SDT = 1: double trap into M-mode, mcause 16
  csrs vsstatus, s1
  li s2, 0
  li s4, 0
  la a0, after2
  jal enter_vs
after2:
  CHECKC(4, s4, 16)          // Whisper: no double trap (the VS handler took it)
  // 5: MRET to VU-mode clears vsstatus.SDT
  csrs vsstatus, s1
  la a0, after3
  la t0, vu_code
  csrw mepc, t0
  li t0, 0x1800
  csrc mstatus, t0          // MPP = U
  li t0, 1
  slli t0, t0, 39
  csrs mstatus, t0          // MPV = 1
  mret
after3:
  csrr t1, vsstatus
  srli t1, t1, 24
  andi t1, t1, 1
  CHECKC(5, t1, 0)           // Whisper: vsstatus.SDT = 1
done:
  EXIT

enter_vs:                   // mret to VS-mode at vs_code; M handler returns to a0
  la t0, vs_code
  csrw mepc, t0
  li t0, 0x1800
  csrc mstatus, t0
  li t0, 0x800
  csrs mstatus, t0          // MPP = S
  li t0, 1
  slli t0, t0, 39
  csrs mstatus, t0          // MPV = 1
  mret
vs_code:
  ebreak
  ecall                     // cause 10 (not delegated): back to M
vu_code:
  ecall                     // cause 8 (not delegated): back to M

  .align 2
vshandler:
  csrr s2, scause           // vscause
  csrr s3, sstatus          // vsstatus
  csrr t0, sepc
  addi t0, t0, 4
  csrw sepc, t0
  sret
  .align 2
mhandler:
  csrr t0, mcause
  li t1, 16
  bne t0, t1, 1f
  mv s4, t0                 // double trap: record, skip the ebreak
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
1:                          // ecall from VS/VU: return to M-mode at a0
  li t0, 1
  slli t0, t0, 39
  csrc mstatus, t0          // MPV = 0
  li t0, 0x1800
  csrs mstatus, t0          // MPP = M
  csrw mepc, a0
  mret
  .section .tohost, "aw"
  .align 6
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
