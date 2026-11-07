// Ssdbltrp: "When the SDT bit is set to 1 by an explicit CSR write, the SIE (Supervisor Interrupt Enable) bit is
// cleared to 0. This clearing occurs regardless of the value written, if any, to the SIE bit by the same write.
// The SIE bit can only be set to 1 by an explicit CSR write if the SDT bit is being set to 0 by the same write or
// is already 0." (supervisor.adoc norm:sstatus_sdt_sstatus_sie_overwrite). vsstatus is the VS-level sstatus, so
// the rule applies to writes of vsstatus and to VS-mode writes of sstatus. menvcfg.DTE = henvcfg.DTE = 1.
//  1: M-mode  csrs vsstatus, SDT|SIE                    -> vsstatus.SIE = 0
//  2: M-mode  vsstatus = SDT; csrs vsstatus, SIE         -> vsstatus.SIE = 0 (SDT already 1)
//  3: M-mode  vsstatus = SDT; csrw vsstatus, SIE         -> vsstatus.SIE = 1 (SDT set to 0 by the same write)
//  4: HS-mode csrs vsstatus, SDT|SIE                    -> vsstatus.SIE = 0
//  5: VS-mode csrs sstatus, SDT|SIE (writes vsstatus)   -> vsstatus.SIE = 0
//  6: VS-mode, vsstatus = SDT: csrs sstatus, SIE         -> vsstatus.SIE = 0
//  7: M-mode  csrs sstatus, SDT|SIE (control, HS level)  -> sstatus.SIE = 0
//  8: vsstatus.SDT = 1 after check 5 (the write took effect)
// x31 = bitmask of failed checks; tohost = (x31 << 1) | 1 (QEMU build: sifive test finisher, exit code = x31).
#include "exit.h"
#define SDT 0x01000000
#define SIE 0x2
#if __riscv_xlen == 64
#define DTE_ON  li t0, 1; slli t0, t0, 59; csrs menvcfg, t0; csrs henvcfg, t0
#define SET_MPV li t0, 1; slli t0, t0, 39; csrs mstatus, t0
#define CLR_MPV li t0, 1; slli t0, t0, 39; csrc mstatus, t0
#else
#define DTE_ON  li t0, 1 << 27; csrs menvcfgh, t0; csrs henvcfgh, t0
#define SET_MPV li t0, 0x80; csrs mstatush, t0
#define CLR_MPV li t0, 0x80; csrc mstatush, t0
#endif
#define SIE_OF(n, csr) csrr t1, csr; andi t1, t1, SIE; srli t1, t1, 1; mv s##n, t1

  .option norelax
  .section .text.init
  .globl _start
_start:
  li x31, 0
  li t0, -1; csrw pmpaddr0, t0; li t0, 0x0f; csrw pmpcfg0, t0
  la t0, mhandler; csrw mtvec, t0
  csrw medeleg, zero; csrw mideleg, zero; csrw hedeleg, zero; csrw hideleg, zero
  csrw satp, zero; csrw vsatp, zero; csrw hgatp, zero
  DTE_ON

  // 1
  csrw vsstatus, zero
  li t0, SDT | SIE; csrs vsstatus, t0
  csrr t1, vsstatus; andi t1, t1, SIE
  CHECKC(1, t1, 0)
  // 2
  li t0, SDT; csrw vsstatus, t0
  li t0, SIE; csrs vsstatus, t0
  csrr t1, vsstatus; andi t1, t1, SIE
  CHECKC(2, t1, 0)
  // 3
  li t0, SDT; csrw vsstatus, t0
  li t0, SIE; csrw vsstatus, t0
  csrr t1, vsstatus; andi t1, t1, SIE
  CHECKC(3, t1, SIE)
  // 4
  csrw vsstatus, zero
  la a0, after4; la a1, hs_set_vsstatus; jal enter_hs
after4:
  csrr t1, vsstatus; andi t1, t1, SIE
  CHECKC(4, t1, 0)
  // 5, 8
  csrw vsstatus, zero
  la a0, after5; la a1, vs_set_sdt_sie; jal enter_vs
after5:
  csrr t2, vsstatus
  andi t1, t2, SIE
  CHECKC(5, t1, 0)
  li t0, SDT; and t1, t2, t0
  CHECKC(8, t1, SDT)
  // 6
  li t0, SDT; csrw vsstatus, t0
  la a0, after6; la a1, vs_set_sie; jal enter_vs
after6:
  csrr t1, vsstatus; andi t1, t1, SIE
  CHECKC(6, t1, 0)
  // 7
  li t0, SDT | SIE; csrc sstatus, t0
  li t0, SDT | SIE; csrs sstatus, t0
  csrr t1, sstatus; andi t1, t1, SIE
  CHECKC(7, t1, 0)
  li t0, SDT | SIE; csrc sstatus, t0
done:
  EXIT

enter_vs:                              // mret to VS-mode at a1; the code there ecalls back to M at a0
  csrw mepc, a1
  li t0, 0x1800; csrc mstatus, t0; li t0, 0x0800; csrs mstatus, t0
  SET_MPV
  mret
enter_hs:                              // mret to HS-mode at a1
  csrw mepc, a1
  li t0, 0x1800; csrc mstatus, t0; li t0, 0x0800; csrs mstatus, t0
  CLR_MPV
  mret

hs_set_vsstatus:
  li t0, SDT | SIE; csrs vsstatus, t0
  ecall
vs_set_sdt_sie:
  li t0, SDT | SIE; csrs sstatus, t0
  ecall
vs_set_sie:
  li t0, SIE; csrs sstatus, t0
  ecall

  .align 2
mhandler:                              // ecall (cause 8-10): back to M at a0; anything else fails (bit 30)
  csrr t3, mcause
  addi t4, t3, -8; bltz t4, 1f; addi t4, t3, -11; bgez t4, 1f
  li t0, 0x1800; csrs mstatus, t0
  CLR_MPV
  csrw mepc, a0
  mret
1: li t0, 1 << 30; or x31, x31, t0
  j done

  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
