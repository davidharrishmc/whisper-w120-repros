// Ssdbltrp: a trap into S/HS-mode while sstatus.SDT = 1 is delivered into M-mode as a double trap (mcause 16,
// mtval2 = the unexpected trap's cause). Every other register gets "the same information that the unexpected trap
// would have written if it was taken into M-mode" (supervisor.adoc norm:sstatus_sdt_trap).
// x31: bit n set = check n failed (0 = pass).
//  1: CTR (mctrctl.M = sctrctl.S = 1): an S-mode illegal instruction + ecall makes as many CTR records when it is
//     escalated as a double trap as when it traps straight into M-mode (the trap into M is recorded).
//  2: mcause = 16 for that double trap.
//  3: mtval2 = 2 (illegal instruction).
//  4: the M-mode handler's lw is little-endian (mstatus.MBE = 0, SBE = 1).
//  5: minstret does not count in the M-mode handler (minstretcfg.MINH = 1, SINH = 0; Smcntrpmf).
//  6: tcontrol.MPTE = old MTE = 1 and tcontrol.MTE = 0 (Sdtrig trap into M-mode; skipped without tcontrol).
//  7: an HLV.W load access fault in HS-mode escalated as a double trap sets mstatus.GVA = 1.
//  8: ... and writes mtinst (the same value as the same fault taken straight into M-mode, or 0), not leaving the
//     stale value 0x7777.
//  9: a landing-pad software-check exception (Zicfilp, ELP = 1) escalated as a double trap sets mstatus.MPELP = 1
//     and clears ELP. If ELP stays 1, the M-mode handler's first instruction takes a landing-pad fault with
//     MDT = 1, an unexpected trap: the RNMI handler (nmi_vec 0x80000800) then fails check 9.
// 10: (control for 7) the same HLV.W fault taken straight into M-mode sets mstatus.GVA = 1.
#include "exit.h"
#define MCTRCTL 0x34e
#define SCTRSTATUS 0x14f
#define SCTRCLR .word 0x10400073
#define TCONTROL 0x7a5
#define MTINST 0x34a
#define MTVAL2 0x34b
#define HEDELEG 0x602
// Bits of the upper half of mstatus (mstatush on RV32).
#define SBE 4
#define GVA 6
#define MPV 7
#define MPELP 9
#define MDT 10
#if __riscv_xlen == 64
#define MSH_SET(b) li t0, 1 << (b); slli t0, t0, 32; csrs mstatus, t0
#define MSH_CLR(b) li t0, 1 << (b); slli t0, t0, 32; csrc mstatus, t0
#define MSH_READ(r) csrr r, mstatus; srli r, r, 32
#define DTE_ON  li t0, 1 << 27; slli t0, t0, 32; csrs menvcfg, t0
#define MINH_ON  li t0, 1 << 30; slli t0, t0, 32; csrs 0x322, t0
#define MINH_OFF li t0, 1 << 30; slli t0, t0, 32; csrc 0x322, t0
#define MS_RESTORE csrw mstatus, s1
#else
#define MSH_SET(b) li t0, 1 << (b); csrs 0x310, t0
#define MSH_CLR(b) li t0, 1 << (b); csrc 0x310, t0
#define MSH_READ(r) csrr r, 0x310
#define DTE_ON  li t0, 1 << 27; csrs 0x31a, t0
#define MINH_ON  li t0, 1 << 30; csrs 0x722, t0
#define MINH_OFF li t0, 1 << 30; csrc 0x722, t0
#define MS_RESTORE csrw mstatus, s1; csrw 0x310, a6
#endif
#define SDT_ON  li t0, 1 << 24; csrs mstatus, t0
#define SDT_OFF li t0, 1 << 24; csrc mstatus, t0
// mret to S/HS-mode at lab; the code there ends with an ecall, which returns to M-mode at ret.
#define ENTER_S(lab, ret) la a0, ret; la t0, lab; csrw mepc, t0; li t0, 0x1800; csrc mstatus, t0; \
  li t0, 0x0800; csrs mstatus, t0; MSH_CLR(MPV); mret

  .section .text.init
  .globl _start
_start:
  li x31, 0; li s11, 0
  la s4, le_word                       // read by the M-mode handler
  la t0, mhandler; csrw mtvec, t0
  MSH_CLR(MDT)                         // Smdbltrp resets MDT to 1
  csrsi 0x744, 8                       // mnstatus.NMIE = 1 (Smrnmi resets it to 0)
  // PMP: [0, noacc) RWX, [noacc, noacc + 0x1000) no access for S/U, the rest RWX.
  la t1, noacc; srli t0, t1, 2; csrw pmpaddr0, t0
  li t2, 0x1000; add t1, t1, t2; srli t0, t1, 2; csrw pmpaddr1, t0
  li t0, -1; csrw pmpaddr2, t0
  li t0, 0x0f080f; csrw pmpcfg0, t0
  csrw medeleg, zero; csrw mideleg, zero; csrw HEDELEG, zero
  la t0, shandler; csrw stvec, t0
  csrw satp, zero; csrw vsatp, zero; csrw hgatp, zero
  DTE_ON                               // menvcfg.DTE = 1: sstatus.SDT is writable
  li gp, -1; csrr gp, TCONTROL         // gp = -1 if tcontrol is not implemented

  // 1: CTR records, illegal instruction straight to M (s8) and escalated as a double trap (s9).
  li t0, 6; csrw MCTRCTL, t0           // mctrctl.M = S = 1
  csrw SCTRSTATUS, zero
  SCTRCLR
  ENTER_S(s_illegal, lab1)
lab1:
  csrr s8, SCTRSTATUS
  andi s8, s8, 0xff
  csrw SCTRSTATUS, zero
  SCTRCLR
  SDT_ON
  li t0, 4; csrw medeleg, t0           // illegal instruction -> S
  ENTER_S(s_illegal, lab2)
lab2:
  csrr s9, SCTRSTATUS
  andi s9, s9, 0xff
  csrw MCTRCTL, zero
  csrw medeleg, zero
  SDT_OFF
  sub t1, s8, s9
  CHECKC(1, t1, 0)

  // 2-6: the same double trap, with SBE = 1, minstretcfg.MINH = 1, tcontrol.MTE = MPTE = 1.
  SDT_ON
  li t0, 4; csrw medeleg, t0
  MSH_SET(SBE)
  MINH_ON
  li t0, 0x88; csrw TCONTROL, t0       // MPTE = 1 (MRET sets MTE = MPTE = 1)
  li a2, 0; li a3, 0; li s7, 0; li a7, -1; li a5, -1
  li s11, 1                            // handler records the M-mode trap state
  ENTER_S(s_illegal, b1)
b1:
  csrw medeleg, zero
  SDT_OFF
  MSH_CLR(SBE)
  MINH_OFF
  csrw TCONTROL, zero
  CHECKC(2, a2, 16)
  CHECKC(3, a3, 2)
  CHECKC(4, s7, 0x11223344)
  CHECKC(5, a7, 0)
  li t1, -1; beq gp, t1, 6f            // no tcontrol: skip check 6
  andi t1, a5, 0x88
  CHECKC(6, t1, 0x80)
6:

  // 7, 8: HLV.W from HS-mode to a PMP no-access address: load access fault (cause 5), delegated to HS, SDT = 1.
  // The double trap runs first, right after a trap into M-mode (the ecall from S-mode above) wrote GVA = 0.
  la s10, noacc
  li t0, 1 << 5; csrw medeleg, t0
  SDT_ON
  li t0, 0x7777; csrw MTINST, t0
  li a6, 0; li a4, 0x7777
  li s11, 1
  ENTER_S(hs_hlv, d1)
d1:
  csrw medeleg, zero
  SDT_OFF
  srli t1, a6, GVA; andi t1, t1, 1
  CHECKC(7, t1, 1)
  mv s6, a4                            // mtinst from the double trap
  // Control: the same fault taken straight into M-mode.
  li s11, 1
  ENTER_S(hs_hlv, d2)
d2:
  srli t1, a6, GVA; andi t1, t1, 1
  CHECKC(10, t1, 1)
  beqz s6, 8f                          // 0 is a legal mtinst
  sub t1, s6, a4
  CHECKC(8, t1, 0)
8:
  // 9: landing-pad fault (software check, cause 18) in S-mode with menvcfg.LPE = 1, delegated to S, SDT = 1.
  li t0, 4; csrs menvcfg, t0           // menvcfg.LPE = 1
  li t0, 1 << 18; csrw medeleg, t0
  SDT_ON
  li a6, 0
  li s11, 1
  ENTER_S(s_lpad, c1)
c1:
  csrw medeleg, zero
  SDT_OFF
  li t0, 4; csrc menvcfg, t0
  srli t1, a6, MPELP; andi t1, t1, 1
  CHECKC(9, t1, 1)

done:
  EXIT

s_illegal:
  .word 0
  ecall
s_lpad:
  la t1, s_nolp
  jr t1                                // indirect jump through x6 (not x1/x5/x7): ELP = 1
s_nolp:
  nop                                  // not a landing pad: software-check exception, mepc = s_nolp
  ecall
hs_hlv:
  hlv.w t1, (s10)
  ecall

  .align 2
shandler:                              // not reached: every trap into S here is a double trap
  li x31, 0x400
  j done

  .align 2
mhandler:
  lw s3, 0(s4)                         // first: data endianness on handler entry
  MSH_CLR(MDT)                         // the trap set MDT; returns to M-mode must not leave it set
  csrr t3, mcause
  addi t4, t3, -8; bltz t4, 1f; addi t4, t3, -11; bgez t4, 1f
  li t0, 0x1800; csrs mstatus, t0; MSH_CLR(MPV); csrw mepc, a0; mret   // ecall: back to M-mode at a0
1: bnez s11, 2f
  csrr t4, mepc; addi t4, t4, 4; csrw mepc, t4; mret                    // skip the instruction
2: mv s7, s3                           // record the trap state, then skip the instruction
  csrr t1, minstret
  nop
  nop
  csrr t2, minstret
  sub a7, t2, t1
  csrr s1, mstatus
  MSH_READ(a6)
  csrr s5, mepc
  csrr a2, mcause
  li s11, 0                            // a missing CSR below traps to the skip path above
  csrr a3, MTVAL2
  csrr a4, MTINST
  csrr a5, TCONTROL
  MS_RESTORE                           // in case one of them trapped
  MSH_CLR(MPELP)                       // MRET would otherwise set ELP again
  addi s5, s5, 4; csrw mepc, s5; mret

  .org 0x800
nmi_handler:                           // RNMI: only reached through an unexpected trap in check 9
  li t5, 1 << 9; or x31, x31, t5
  j done

  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
  .data
  .align 3
le_word: .word 0x11223344
  .align 12
noacc: .space 0x1000
