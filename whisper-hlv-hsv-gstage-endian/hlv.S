// HLV/HSV data endianness and G-stage page-table endianness.
//  hypervisor.adoc norm:hlsv_priv: HLV/HSV make "an explicit memory access with an effective privilege mode of VS or
//  VU ... VU when hstatus.SPVP=0, and VS when hstatus.SPVP=1", so the data endianness is hstatus.VSBE (SPVP=1,
//  norm:hstatus_vsbe_op) or vsstatus.UBE (SPVP=0, the VS-level sstatus.UBE, norm:sstatus_ube_endianness_op).
//  machine.adoc norm:mstatus_sbe_implicit: "For implicit accesses to supervisor-level memory management data
//  structures, such as page tables, endianness is always controlled by SBE." G-stage page tables are HS-level
//  structures; VSBE covers only VS-level ones (norm:hstatus_vsbe_implicit).
// le_word holds 0x11223344 in little-endian byte order. MBE = 0 throughout. satp = vsatp = 0.
//  1: M, VSBE=1, SPVP=1:          hlv.w -> 0x44332211
//  2: M, VSBE=0, UBE=1, SPVP=1:   hlv.w -> 0x11223344
//  3: M, VSBE=0, UBE=1, SPVP=0:   hlv.w -> 0x44332211
//  4: M, VSBE=1, UBE=0, SPVP=0:   hlv.w -> 0x11223344
//  5: M, VSBE=1, SPVP=1:          hsv.w 0x11223344, then M lw -> 0x44332211
//  6: M, UBE=1, SPVP=0:           hsv.w 0x11223344, then M lw -> 0x44332211
//  7: M lw right after check 1's hlv.w -> 0x11223344 (M-mode endianness restored)
//  8: HS, SBE=1, VSBE=0, SPVP=1:  hlv.w -> 0x11223344
//  9: HS, SBE=1, VSBE=0: hlv.w of a PMP no-access page traps to M; M handler lw -> 0x11223344
// 10: ... mcause = 5
// 11: hgatp Sv39x4/Sv32x4 with a big-endian identity leaf PTE, SBE=1, VSBE=0: M hlv.w SPVP=1 -> 0x11223344, no trap
// 12: hgatp with a little-endian leaf PTE, SBE=0, VSBE=1: M hlv.w SPVP=1 -> 0x44332211, no trap
// 13: as 11, but VS-mode lw (fetch and load both through the G-stage) -> 0x11223344
// 14: set if hstatus.VSBE, vsstatus.UBE or mstatus.SBE is read-only (checks that need it are skipped)
// x31 = bitmask of failed checks; tohost = (x31 << 1) | 1 (QEMU build: sifive test finisher, exit code = x31).
#include "exit.h"
#define VSBE 0x20
#define SPVP 0x100
#define UBE  0x40
#if __riscv_xlen == 64
#define SBE_ON   li t0, 1; slli t0, t0, 36; csrs mstatus, t0
#define SBE_OFF  li t0, 1; slli t0, t0, 36; csrc mstatus, t0
#define SBE_GET(r) csrr r, mstatus; srli r, r, 36; andi r, r, 1
#define SET_MPV  li t0, 1; slli t0, t0, 39; csrs mstatus, t0
#define MDT_OFF  li t0, 1; slli t0, t0, 42; csrc mstatus, t0
#define CLR_MPV  li t0, 1; slli t0, t0, 39; csrc mstatus, t0
#define HGATP_ON(root) la t0, root; srli t0, t0, 12; li t1, 8; slli t1, t1, 60; or t0, t0, t1; csrw hgatp, t0
#define PTE_SZ   8
#define LEAF_IX  2                      // GPA 0x80000000 >> 30 (1 GiB leaf at the Sv39x4 root)
#define STORE_PTE sd
#else
#define SBE_ON   li t0, 0x10; csrs mstatush, t0
#define SBE_OFF  li t0, 0x10; csrc mstatush, t0
#define SBE_GET(r) csrr r, mstatush; srli r, r, 4; andi r, r, 1
#define SET_MPV  li t0, 0x80; csrs mstatush, t0
#define MDT_OFF  li t0, 1 << 10; csrc mstatush, t0
#define CLR_MPV  li t0, 0x80; csrc mstatush, t0
#define HGATP_ON(root) la t0, root; srli t0, t0, 12; li t1, 1; slli t1, t1, 31; or t0, t0, t1; csrw hgatp, t0
#define PTE_SZ   4
#define LEAF_IX  0x200                  // GPA 0x80000000 >> 22 (4 MiB leaf at the Sv32x4 root)
#define STORE_PTE sw
#endif
#define LEAF_LE  0x200000df             // PPN 0x80000, D A U X W R V
#if __riscv_xlen == 64
#define LEAF_BE  0xdf00002000000000
#else
#define LEAF_BE  0xdf000020
#endif
#define HFENCE   .word 0x62000073       // hfence.gvma x0, x0
#define NEED(r, lab) beqz r, lab

  .option norelax
  .section .text.init
  .globl _start
_start:
  li x31, 0; li s2, 0; li s6, 0
  la s4, le_word
  la s5, scratch
  MDT_OFF                              // Smdbltrp resets MDT to 1: allow traps into M-mode
  // PMP: [0, bad_page) RWX, [bad_page, bad_page + 4 KiB) no access (S/U/VS/VU), rest RWX.
  la t0, bad_page; srli t0, t0, 2; csrw pmpaddr0, t0
  la t0, bad_page; li t1, 0x1000; add t0, t0, t1; srli t0, t0, 2; csrw pmpaddr1, t0
  li t0, -1; csrw pmpaddr2, t0
  li t0, 0x1f080f; csrw pmpcfg0, t0
  la t0, mhandler; csrw mtvec, t0
  csrsi 0x744, 8                       // Smrnmi: mnstatus.NMIE = 1 (resets to 0); skipped if illegal
  csrw medeleg, zero; csrw mideleg, zero; csrw hedeleg, zero; csrw hideleg, zero
  csrw satp, zero; csrw vsatp, zero; csrw hgatp, zero
  // Which endianness bits are writable: s7 = VSBE, s8 = vsstatus.UBE, s9 = SBE.
  li t0, VSBE; csrs hstatus, t0; csrr s7, hstatus; csrc hstatus, t0; andi s7, s7, VSBE
  li t0, UBE; csrs vsstatus, t0; csrr s8, vsstatus; csrc vsstatus, t0; andi s8, s8, UBE
  SBE_ON; SBE_GET(s9); SBE_OFF
  snez s7, s7; snez s8, s8
  and t0, s7, s8; and t0, t0, s9; bnez t0, 1f
  li t0, 1 << 14; or x31, x31, t0
1:
  // 1, 7
  NEED(s7, 6f)
  li t0, VSBE | SPVP; csrs hstatus, t0
  hlv.w t1, (s4)
  lw t2, 0(s4)
  li t0, VSBE | SPVP; csrc hstatus, t0
  CHECKC(1, t1, 0x44332211)
  CHECKC(7, t2, 0x11223344)
6:
  // 2
  NEED(s8, 6f)
  li t0, SPVP; csrs hstatus, t0
  li t0, UBE; csrs vsstatus, t0
  hlv.w t1, (s4)
  li t0, UBE; csrc vsstatus, t0
  li t0, SPVP; csrc hstatus, t0
  CHECKC(2, t1, 0x11223344)
6:
  // 3
  NEED(s8, 6f)
  li t0, UBE; csrs vsstatus, t0
  hlv.w t1, (s4)
  li t0, UBE; csrc vsstatus, t0
  CHECKC(3, t1, 0x44332211)
6:
  // 4
  NEED(s7, 6f)
  li t0, VSBE; csrs hstatus, t0
  hlv.w t1, (s4)
  li t0, VSBE; csrc hstatus, t0
  CHECKC(4, t1, 0x11223344)
6:
  // 5
  NEED(s7, 6f)
  li t2, 0x11223344
  li t0, VSBE | SPVP; csrs hstatus, t0
  hsv.w t2, (s5)
  li t0, VSBE | SPVP; csrc hstatus, t0
  lw t1, 0(s5)
  CHECKC(5, t1, 0x44332211)
6:
  // 6
  NEED(s8, 6f)
  sw zero, 0(s5)
  li t2, 0x11223344
  li t0, UBE; csrs vsstatus, t0
  hsv.w t2, (s5)
  li t0, UBE; csrc vsstatus, t0
  lw t1, 0(s5)
  CHECKC(6, t1, 0x44332211)
6:
  // 8
  NEED(s9, 6f)
  SBE_ON
  li t0, SPVP; csrs hstatus, t0
  li s10, 0
  la a0, after8; la a1, hs_hlv; jal enter_hs
after8:
  SBE_OFF
  CHECKC(8, s10, 0x11223344)
6:
  // 9, 10
  NEED(s9, 6f)
  SBE_ON
  li s2, 0; li s3, 0
  la a0, after9; la a1, hs_hlv_fault; jal enter_hs
after9:
  SBE_OFF
  li t0, SPVP; csrc hstatus, t0
  CHECKC(9, s3, 0x11223344)
  CHECKC(10, s2, 5)
6:
  // 11: G-stage with a big-endian leaf PTE, SBE=1, VSBE=0
  NEED(s9, 6f)
  la t0, groot; li t1, LEAF_IX * PTE_SZ; add t0, t0, t1; li t1, LEAF_BE; STORE_PTE t1, 0(t0)
  SBE_ON
  HGATP_ON(groot); HFENCE
  li s2, 0; li t1, 0
  li t0, SPVP; csrs hstatus, t0
  hlv.w t1, (s4)
  li t0, SPVP; csrc hstatus, t0
  csrw hgatp, zero; HFENCE
  SBE_OFF
  CHECKC(11, t1, 0x11223344)
  CHECKC(11, s2, 0)
6:
  // 12: G-stage with a little-endian leaf PTE, SBE=0, VSBE=1
  NEED(s7, 6f)
  la t0, groot; li t1, LEAF_IX * PTE_SZ; add t0, t0, t1; li t1, LEAF_LE; STORE_PTE t1, 0(t0)
  HGATP_ON(groot); HFENCE
  li s2, 0; li t1, 0
  li t0, VSBE | SPVP; csrs hstatus, t0
  hlv.w t1, (s4)
  li t0, VSBE | SPVP; csrc hstatus, t0
  csrw hgatp, zero; HFENCE
  CHECKC(12, t1, 0x44332211)
  CHECKC(12, s2, 0)
6:
  // 13: VS-mode lw through a big-endian G-stage leaf PTE, SBE=1, VSBE=0
  NEED(s9, 6f)
  la t0, groot; li t1, LEAF_IX * PTE_SZ; add t0, t0, t1; li t1, LEAF_BE; STORE_PTE t1, 0(t0)
  SBE_ON
  HGATP_ON(groot); HFENCE
  li s2, 0; li s10, 0; li s6, 1
  la a0, after13; la a1, vs_lw; jal enter_vs
after13:
  li s6, 0
  csrw hgatp, zero; HFENCE
  SBE_OFF
  CHECKC(13, s10, 0x11223344)
  CHECKC(13, s2, 0)
6:
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

hs_hlv:
  hlv.w s10, (s4)
  ecall
hs_hlv_fault:
  la t0, bad_page
  hlv.w t1, (t0)
  ecall
vs_lw:
  lw s10, 0(s4)
  ecall

  .align 2
mhandler:
  csrr t3, mcause
  addi t4, t3, -8; bltz t4, 1f; addi t4, t3, -11; bgez t4, 1f
2: li t0, 0x1800; csrs mstatus, t0      // ecall: return to M at a0
  CLR_MPV
  csrw mepc, a0
  mret
1: mv s2, t3                            // other trap: record mcause and the M-mode view of le_word
  lw s3, 0(s4)
  bnez s6, 2b                           // s6 = 1: return to M at a0
  csrr t4, mepc; addi t4, t4, 4; csrw mepc, t4
  mret

  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
  .data
  .align 3
le_word: .word 0x11223344
scratch: .word 0
  .align 14
groot: .space 0x4000                    // G-stage root table (16 KiB)
bad_page: .space 0x1000
