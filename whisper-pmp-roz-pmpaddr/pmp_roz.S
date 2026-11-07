// A PMP entry whose pmpaddr is read-only zero is still an implemented entry: its address is 0 and its pmpcfg
// byte decides whether and how it matches (machine.adoc). Whisper skips such entries.
//
// x31 = bitmask of failed checks:
//  bit 1: reference: pmp8cfg = 0 (OFF); M-mode lw from address 0 does not trap (else check 2 cannot run).
//  bit 2: pmpaddr8 = 0, pmp8cfg = 0x98 (L=1, A=NAPOT, RWX=0): the entry covers [0, 8) (G <= 1) or
//         [0, 2^(G+2)) (G >= 2) and is locked, so an M-mode lw from address 0 raises a load access fault
//         (mcause 5).
//  bit 3: pmp0cfg-pmp7cfg = 0 (OFF); with mstatus.MPRV=1, MPP=S, a lw from RAM matches no entry. At least one
//         entry is implemented, so the S-mode access fails: load access fault (mcause 5).
//  bit 8: unexpected trap (s10 = mcause).
#include "exit.h"

  .section .text.init
  .globl _start
_start:
  li x31, 0
  li s10, 0
  li s8, 0
  la t0, mtrap; csrw mtvec, t0
#if __riscv_xlen == 64
  li t0, 1; slli t0, t0, 42; csrc mstatus, t0     // mstatus.MDT = 0 (Smdbltrp)
#else
  li t0, 1 << 10; csrc 0x310, t0                   // mstatush.MDT = 0 (Smdbltrp)
#endif
  li s8, 1                                         // tolerate illegal-instruction where Smrnmi is absent
  li t0, 8; csrs 0x744, t0                         // mnstatus.NMIE = 1 (Smrnmi): M-mode traps are not fatal
  li s8, 0
  csrw pmpcfg0, zero                               // entries 0-7 OFF
#if __riscv_xlen == 32
  csrw pmpcfg1, zero
#endif
  csrw pmpcfg2, zero                               // entry 8 OFF
  csrw pmpaddr8, zero                              // a no-op where pmpaddr8 is read-only zero

  // Check 1 (reference): no PMP entry on, M-mode load from 0.
  li s9, 0
  li t1, 0
  lw t2, 0(t1)
  beqz s9, 1f; li t5, 1 << 1; or x31, x31, t5; 1:

  // Check 2: locked NAPOT entry 8 with no permissions at address 0.
  li t0, 0x98
  csrw pmpcfg2, t0
  li s9, 0
  li t1, 0
  lw t2, 0(t1)
  li t4, 5; beq s9, t4, 1f; li t5, 1 << 2; or x31, x31, t5; 1:

  // Check 3: S-mode (MPRV) load from RAM, no entry matches.
  li t0, 0x1800; csrc mstatus, t0
  li t0, 0x0800; csrs mstatus, t0                  // MPP = S
  li t0, 1 << 17
  li s9, 0
  la t1, data
  csrs mstatus, t0                                 // MPRV = 1
  lw t2, 0(t1)
  csrc mstatus, t0                                 // MPRV = 0
  li t4, 5; beq s9, t4, 1f; li t5, 1 << 3; or x31, x31, t5; 1:

done:
  EXIT

  .align 4
mtrap:
  csrr s9, mcause
  li t1, 5; beq s9, t1, 1f                        // load access fault: expected by checks 2 and 3
  bnez s8, 1f                                      // mnstatus write without Smrnmi
  mv s10, s9
  li t1, 1 << 8; or x31, x31, t1
1:
  li t1, 1 << 17; csrc mstatus, t1                // MPRV = 0
  csrr t1, mepc; addi t1, t1, 4; csrw mepc, t1
  mret

  .data
  .align 3
data: .dword 0x1234

  .section .tohost,"aw"
  .globl tohost
  .align 3
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
