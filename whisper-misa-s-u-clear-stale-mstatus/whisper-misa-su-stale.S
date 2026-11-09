// Clearing misa.S (or misa.U) at run time must make mstatus behave as on a hart without S-mode (or U-mode).
//   machine.adoc norm:misa_extensions_disabling "When a standard extension is disabled by clearing its bit in
//     misa, the instructions and CSRs defined or modified by the extension revert to their defined or reserved
//     behaviors as if the extension is not implemented."
//   norm:mstatus_sie_spie_rdonly0 "If supervisor mode is not implemented, then sie and spie are read-only 0"
//   norm:mstatus_mxr_rdonly0_no_smode / norm:mstatus_sum_rdonly0 / norm:mstatus_tvm_acc / norm:mstatus_tsr_acc:
//     MXR, SUM, TVM and TSR are read-only 0 when S-mode is not supported
//   norm:mstatus_mprv_rdonly0_no_umode: MPRV is read-only 0 if U-mode is not supported
//   norm:mstatus_tw_acc: TW is read-only 0 when there are no modes less privileged than M
//   norm:mstatus_xpp_warl: MPP can hold only M and implemented lower modes
//   norm:mstatus_xret_op: MRET changes the privilege mode to MPP and sets MPP to the least-privileged supported mode
// Part S (misa.S writable): set SIE, SPIE, SUM, MXR, TVM, TSR; clear misa.S (and misa.H, which depends on S); the
//   fields must read 0, and stay 0 when written again.
// Part U (misa.U writable): set TW, MPP = U; clear misa.U (and S, H); TW must read 0 and MPP must read M (the only
//   mode); with no mstatus write in between, MRET must stay in M-mode (the next csrr mstatus does not trap; the ecall
//   has cause 11) and leave MPP = M; MPRV must stay 0 when written 1.
// Each part is skipped when its misa bit is read-only.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define FIELD(_D, _R, _SH, _MASK) srli _D, _R, _SH ; andi _D, _D, _MASK
#define MPP_SET(_V) li x8, 0x1800 ; csrc mstatus, x8 ; li x8, (_V) << 11 ; csrs mstatus, x8
// x11 = 1 if misa bit _B can be cleared
#define WRITABLE(_B) LI(x8, 1 << (_B)) ; csrc misa, x8 ; csrr x11, misa ; csrs misa, x8 ; srli x11, x11, _B ; andi x11, x11, 1 ; xori x11, x11, 1
#define SBITS ((1 << 1) | (1 << 5) | (1 << 18) | (1 << 19) | (1 << 20) | (1 << 22))   // SIE SPIE SUM MXR TVM TSR

RVTEST_BEGIN
  csrr x9, misa
  csrw mie, x0
  csrw mideleg, x0
  csrw medeleg, x0
  csrw satp, x0
  LA(x4, t_save)
  csrr x7, mtvec
  SREG x7, 0(x4)
  csrr x7, mscratch
  SREG x7, REGWIDTH(x4)
  LA(x7, t_area)
  csrw mscratch, x7
  LA(x7, t_mtrap)
  csrw mtvec, x7

  //================================================================ part S
  WRITABLE(18)
  beqz x11, t_skip_s
  LI(x8, SBITS)
  csrs mstatus, x8
  LI(x8, (1 << 18) | (1 << 7))
  csrc misa, x8                        // S and H off
  csrr x10, misa
  FIELD(x7, x10, 18, 1)
  SA_SOFT(x7, 0, "S: misa.S after csrc")
  csrr x10, mstatus
  FIELD(x7, x10, 1, 1)
  SA_SOFT(x7, 0, "S: mstatus.SIE once misa.S is cleared")
  FIELD(x7, x10, 5, 1)
  SA_SOFT(x7, 0, "S: mstatus.SPIE once misa.S is cleared")
  FIELD(x7, x10, 18, 1)
  SA_SOFT(x7, 0, "S: mstatus.SUM once misa.S is cleared")
  FIELD(x7, x10, 19, 1)
  SA_SOFT(x7, 0, "S: mstatus.MXR once misa.S is cleared")
  FIELD(x7, x10, 20, 1)
  SA_SOFT(x7, 0, "S: mstatus.TVM once misa.S is cleared")
  FIELD(x7, x10, 22, 1)
  SA_SOFT(x7, 0, "S: mstatus.TSR once misa.S is cleared")
  LI(x8, SBITS)
  csrs mstatus, x8                     // write them again with S off
  csrr x10, mstatus
  and x7, x10, x8
  SA_SOFT(x7, 0, "S: mstatus SIE/SPIE/SUM/MXR/TVM/TSR after csrs with misa.S cleared")
  csrc mstatus, x8
  LI(x8, (1 << 18) | (1 << 7))
  and x8, x8, x9
  csrs misa, x8                        // S and H back on
  LI(x8, SBITS)
  csrc mstatus, x8
t_skip_s:

  //================================================================ part U
  WRITABLE(20)
  beqz x11, t_skip_u
  LI(x8, 1 << 21)
  csrs mstatus, x8                     // TW
  MPP_SET(0)                           // MPP = U
  LI(x8, (1 << 20) | (1 << 18) | (1 << 7))
  csrc misa, x8                        // U, S and H off; no mstatus write from here to the MRET
  csrr x10, mstatus
  csrr x12, misa
  FIELD(x7, x12, 20, 1)
  SA_SOFT(x7, 0, "U: misa.U after csrc")
  FIELD(x7, x10, 21, 1)
  SA_SOFT(x7, 0, "U: mstatus.TW once misa.U is cleared")
  FIELD(x7, x10, 11, 3)
  SA_SOFT(x7, 3, "U: mstatus.MPP (written U before misa.U was cleared): M is the only legal value")
  LA(x4, t_area)
  li x7, -1
  SREG x7, REGWIDTH(x4)                // first mcause (-1 = none)
  LA(x7, t_back)
  SREG x7, 2*REGWIDTH(x4)
  LA(x7, t_target)
  csrw mepc, x7
  mret
t_target:
  csrr x10, mstatus                    // traps unless still in M-mode
  ecall
t_back:
  LA(x4, t_area)
  LREG x7, REGWIDTH(x4)
  SA_SOFT(x7, 11, "U: first trap after MRET with misa.U cleared (11 = the M-mode ecall; 2 = csrr mstatus ran in U-mode)")
  FIELD(x7, x10, 11, 3)
  SA_SOFT(x7, 3, "U: mstatus.MPP after that MRET (least-privileged supported mode = M)")
  LI(x8, 1 << 17)
  csrs mstatus, x8                     // MPRV with U disabled (MPP = M here)
  csrr x10, mstatus
  csrc mstatus, x8
  FIELD(x7, x10, 17, 1)
  SA_SOFT(x7, 0, "U: mstatus.MPRV after csrs with misa.U cleared")
  LI(x8, (1 << 20) | (1 << 18) | (1 << 7))
  and x8, x8, x9
  csrs misa, x8                        // U, S and H back on
  LI(x8, 1 << 21)
  csrc mstatus, x8
t_skip_u:

  csrw misa, x9
  LA(x4, t_save)
  LREG x7, 0(x4)
  csrw mtvec, x7
  LREG x7, REGWIDTH(x4)
  csrw mscratch, x7
  MPP_SET(3)
  SA_SOFT_END
  j t_done

.balign 4
t_mtrap:                             // record the first mcause, resume at the saved point in M-mode
  csrrw x13, mscratch, x13
  SREG x14, 0(x13)
  LREG x14, REGWIDTH(x13)
  bgez x14, 1f
  csrr x14, mcause
  SREG x14, REGWIDTH(x13)
1:
  LREG x14, 2*REGWIDTH(x13)
  csrw mepc, x14
  li x14, 0x1800
  csrs mstatus, x14                    // MPP = M
  LREG x14, 0(x13)
  csrrw x13, mscratch, x13
  mret
t_done:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.align 3
t_area: .fill 4, 8, 0
t_save: .fill 2, 8, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
