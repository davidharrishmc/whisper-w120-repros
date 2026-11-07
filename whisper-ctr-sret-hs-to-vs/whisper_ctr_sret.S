// Whisper: CTR recording of an sret from HS-mode into VS-mode decides whether the HS (source) mode is enabled from
// vsctrctl.S instead of sctrctl.S (smctr.adoc, "Virtualization Mode Transitions": mctrctl.M, sctrctl.S and
// vsctrctl.{S,U} determine whether the source and target modes are enabled; ctr_trapret_de / ctr_trapret_ed).
//  check 1: sctrctl.S = 0 (HS disabled), vsctrctl.S = 1 (VS enabled): the sret HS->VS is a trap return from a
//           disabled mode and is not recorded (norm:ctr_trapret_de); the VS ecall to M (mctrctl = M = 0) is an
//           external trap with MTE = STE = 0 and is not recorded either. Expected sctrstatus.WRPTR = 0.
//  check 2: sctrctl.S = 1, vsctrctl.S = 0: the sret HS->VS is a trap return from an enabled to a disabled mode and is
//           recorded with ctrtarget.PC = 0 (norm:ctr_trapret_ed). Expected WRPTR = 1 ...
//  check 3: ... and logical entry 0 has ctrsource = the sret's pc | V.
#include "common.h"
  .section .text.init
  .globl _start
_start:
  SETUP
  // case 1
  csrw MCTRCTL, zero        // M = S = U = 0 (sctrctl is a view of mctrctl)
  csrwi VSCTRCTL, 2         // vsctrctl.S = 1
  csrw SCTRSTATUS, zero
  SCTRCLR
  ENTER(1, 0, hs_code, after1)
after1:
  csrw VSCTRCTL, zero
  csrr t1, SCTRSTATUS
  andi t1, t1, 0xff
  CHECKC(1, t1, 0)          // Whisper: 1 (the sret was recorded)
  // case 2
  csrwi MCTRCTL, 2          // sctrctl.S = 1
  csrw VSCTRCTL, zero
  csrw SCTRSTATUS, zero
  SCTRCLR
  ENTER(1, 0, hs_code, after2)
after2:
  csrw MCTRCTL, zero
  csrr t1, SCTRSTATUS
  andi t1, t1, 0xff
  CHECKC(2, t1, 1)          // Whisper: 0
  li t0, 0x200
  csrw SISELECT, t0
  csrr t1, SIREG
  la t2, sret_pc
  ori t2, t2, 1
  sub t1, t1, t2
  CHECKC(3, t1, 0)
done:
  EXIT

hs_code:                    // HS-mode: sret into VS-mode at vs_code
  la t0, vs_code
  csrw sepc, t0
  li t0, 0x100
  csrs sstatus, t0          // SPP = S
  li t0, 0x80
  csrs 0x600, t0            // hstatus.SPV = 1
sret_pc:
  sret
vs_code:
  ecall                     // VS -> M (not delegated)
HANDLER
  .section .tohost, "aw"
  .align 3
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0
