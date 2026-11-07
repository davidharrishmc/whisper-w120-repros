// Smcdeleg/Ssccfg: a write through sireg* to a delegated counter CSR must act like a direct
// write of the aliased CSR (smcdeleg.adoc: "the register state associated with counter i can
// be read or written via sireg*, while siselect holds 0x40+i").
//
// x31 = bitmask of failed checks:
//  bit 1: S-mode sireg  (siselect 0x42 = instret) := 1000, then read back through sireg: the same
//         value as check 6 reads after a direct write (1000).
//  bit 2: S-mode sireg2 (RV64) / sireg5 (RV32) (siselect 0x43) sets hpmevent3.OF: scountovf = 0x8.
//  bit 3: S-mode sireg2 (RV64) / sireg5 (RV32) (siselect 0x42) sets instretcfg.SINH: instret
//         does not advance over the next 11 S-mode instructions (delta 0).
//  bit 4: reference for bit 2: M-mode csrw mhpmevent3(h) sets OF: scountovf = 0x8.
//  bit 5: reference for bit 3: M-mode csrw minstretcfg(h) sets SINH: delta 0.
//  bit 6: reference for bit 1: M-mode csrw minstret := 1000, then csrr minstret: 1000.
//  bit 8: unexpected trap (s10 = last mcause).
#include "exit.h"

#define CSR_SISELECT   0x150
#define CSR_SIREG      0x151
#define CSR_SIREG2     0x152
#define CSR_SIREG5     0x156
#define CSR_SCOUNTOVF  0xda0
#define CSR_MENVCFG    0x30a
#define CSR_MENVCFGH   0x31a
#define CSR_MSTATEEN0  0x30c
#define CSR_MSTATEEN0H 0x31c
#define CSR_MINSTRETCFG  0x322
#define CSR_MINSTRETCFGH 0x722

#if __riscv_xlen == 64
#define SIREG_CFG  CSR_SIREG2      // hpmevent3 / instretcfg (all 64 bits)
#define OF_BIT     (1 << 63)
#define SINH_BIT   (1 << 61)
#define MHPMEVENT3_CFG  mhpmevent3
#define MINSTRETCFG_HI  CSR_MINSTRETCFG
#else
#define SIREG_CFG  CSR_SIREG5      // hpmevent3h / instretcfgh (bits 63:32)
#define OF_BIT     (1 << 31)
#define SINH_BIT   (1 << 29)
#define MHPMEVENT3_CFG  mhpmevent3h
#define MINSTRETCFG_HI  CSR_MINSTRETCFGH
#endif

// Enter S-mode at label; return to M-mode at label2 with ecall.
.macro TO_S label
  li t0, 0x1800; csrc mstatus, t0
  li t0, 0x0800; csrs mstatus, t0
  la t0, \label; csrw mepc, t0
  mret
.endm
.macro BACK_TO_M label
  la s11, \label
  ecall
.endm

  .section .text.init
  .globl _start
_start:
  li x31, 0
  li s10, 0
  la t0, mtrap; csrw mtvec, t0
#if __riscv_xlen == 64
  li t0, 1; slli t0, t0, 42; csrc mstatus, t0                   // mstatus.MDT = 0 (Smdbltrp)
#else
  li t0, 1 << 10; csrc 0x310, t0                                 // mstatush.MDT = 0 (Smdbltrp)
#endif
  li t0, -1; csrw pmpaddr0, t0; li t0, 0x1f; csrw pmpcfg0, t0    // S-mode may access everything
  li t0, -1; csrw CSR_MSTATEEN0, t0                              // siselect/sireg* from S (CSRIND)
#if __riscv_xlen == 64
  li t0, 1; slli t0, t0, 60; csrs CSR_MENVCFG, t0                // menvcfg.CDE
#else
  csrw CSR_MSTATEEN0H, t0
  li t0, 1 << 28; csrs CSR_MENVCFGH, t0                          // menvcfgh.CDE
#endif
  li t0, -1; csrw mcounteren, t0                                 // delegate all counters
  csrw mcountinhibit, zero
  csrw mhpmevent3, zero
  csrw CSR_MINSTRETCFG, zero
#if __riscv_xlen == 32
  csrw mhpmevent3h, zero
  csrw CSR_MINSTRETCFGH, zero
#endif

  // Check 6 (reference): direct write of minstret.
  li t0, 1000
  csrw minstret, t0
  csrr s6, minstret
  CHECKC(6, s6, 1000)

  // Check 1: instret := 1000 through sireg reads back like the direct write.
  TO_S s1
s1:
  li t0, 0x42; csrw CSR_SISELECT, t0
  li t0, 1000
  csrw CSR_SIREG, t0
  csrr a1, CSR_SIREG
  BACK_TO_M m1
m1:
  beq a1, s6, 9f; li t5, 1 << 1; or x31, x31, t5; 9:

  // Check 2: hpmevent3.OF := 1 through sireg2/sireg5.
  TO_S s2
s2:
  li t0, 0x43; csrw CSR_SISELECT, t0
  li t0, OF_BIT
  csrw SIREG_CFG, t0
  csrr a2, CSR_SCOUNTOVF
  BACK_TO_M m2
m2:
  CHECKC(2, a2, 8)

  // Check 4 (reference): direct write of mhpmevent3(h).OF.
  csrw MHPMEVENT3_CFG, zero
  li t0, OF_BIT; csrw MHPMEVENT3_CFG, t0
  csrr a4, CSR_SCOUNTOVF
  csrw MHPMEVENT3_CFG, zero
  CHECKC(4, a4, 8)

  // Check 3: instretcfg.SINH := 1 through sireg2/sireg5.
  TO_S s3
s3:
  li t0, 0x42; csrw CSR_SISELECT, t0
  li t0, SINH_BIT
  csrw SIREG_CFG, t0
  rdinstret s2
  nop; nop; nop; nop; nop; nop; nop; nop; nop; nop
  rdinstret s3
  sub a3, s3, s2
  BACK_TO_M m3
m3:
  csrw MINSTRETCFG_HI, zero
  CHECKC(3, a3, 0)

  // Check 5 (reference): direct write of minstretcfg(h).SINH.
  li t0, SINH_BIT; csrw MINSTRETCFG_HI, t0
  TO_S s5
s5:
  rdinstret s2
  nop; nop; nop; nop; nop; nop; nop; nop; nop; nop
  rdinstret s3
  sub a5, s3, s2
  BACK_TO_M m5
m5:
  csrw MINSTRETCFG_HI, zero
  CHECKC(5, a5, 0)

done:
  EXIT

  .align 4
mtrap:
  csrr t1, mcause
  li t2, 9; beq t1, t2, 1f            // ecall from S: continue in M-mode at s11
  mv s10, t1
  li t2, 1 << 8; or x31, x31, t2
  csrr t1, mepc; addi t1, t1, 4; csrw mepc, t1
  mret
1:
#if __riscv_xlen == 64
  li t1, 1; slli t1, t1, 42; csrc mstatus, t1   // MDT = 0 so a later M-mode trap is not a double trap
#else
  li t1, 1 << 10; csrc 0x310, t1
#endif
  jr s11

  .section .tohost,"aw"
  .globl tohost
  .align 3
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
