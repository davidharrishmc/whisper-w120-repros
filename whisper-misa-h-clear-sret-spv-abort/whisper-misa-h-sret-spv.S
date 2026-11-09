// With misa.H cleared, the hypervisor CSRs (hstatus included) revert to their behavior on a hart without H, so an
// M-mode SRET returns to the mode in sstatus.SPP with V = 0, whatever hstatus.SPV held before H was disabled.
//   machine.adoc norm:misa_extensions_disabling "When a standard extension is disabled by clearing its bit in
//     misa, the instructions and CSRs defined or modified by the extension revert to their defined or reserved
//     behaviors as if the extension is not implemented."
//   machine.adoc norm:mstatus_xret_op: xRET changes the privilege mode to the value y held in xPP.
// Sequence (M-mode): hstatus.SPV = 1 (H on); sstatus.SPP = S; clear misa.H; sepc = target; sret; target: ecall.
// Expected: the ecall comes from S-mode (mcause 9). Skipped when misa.H is read-only.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U', 'H']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####
#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"
// own M-mode trap handler: records mcause, resumes at t_resume in M-mode
#define SETUP_HANDLER \
    csrw mie, x0 ; csrw mideleg, x0 ; csrw medeleg, x0 ;\
    LA(x4, t_save) ; csrr x7, mtvec ; SREG x7, 0(x4) ; csrr x7, mscratch ; SREG x7, REGWIDTH(x4) ;\
    LA(x7, t_area) ; csrw mscratch, x7 ; LA(x7, t_mtrap) ; csrw mtvec, x7 ;\
    LA(x4, t_area) ; li x7, -1 ; SREG x7, REGWIDTH(x4)
#define RESTORE_HANDLER \
    LA(x4, t_save) ; LREG x7, 0(x4) ; csrw mtvec, x7 ; LREG x7, REGWIDTH(x4) ; csrw mscratch, x7
#define SET_RESUME(_L) LA(x7, _L) ; LA(x4, t_area) ; SREG x7, 2*REGWIDTH(x4)
#define LD_CAUSE(_R) LA(x4, t_area) ; LREG _R, REGWIDTH(x4)
#define MPP_SET(_V) li x8, 0x1800 ; csrc mstatus, x8 ; li x8, (_V) << 11 ; csrs mstatus, x8
// x11 = 1 if misa bit _B can be cleared
#define WRITABLE(_B) LI(x8, 1 << (_B)) ; csrc misa, x8 ; csrr x11, misa ; csrs misa, x8 ; srli x11, x11, _B ; andi x11, x11, 1 ; xori x11, x11, 1
RVTEST_BEGIN
  csrr x9, misa
  SETUP_HANDLER
  WRITABLE(7)
  li x6, 9
  beqz x11, t_out
  li x8, 0x80
  csrs 0x600, x8                       // hstatus.SPV = 1 (H on)
  li x8, 0x100
  csrs mstatus, x8                     // SPP = S
  li x8, 0x80
  csrc misa, x8                        // H off
  SET_RESUME(t_back)
  LA(x7, t_target)
  csrw sepc, x7
  sret
t_target:
  ecall
t_back:
  LD_CAUSE(x6)
  li x8, 0x80
  csrs misa, x8
  csrw 0x600, x0

t_out:
  csrw misa, x9
  RESTORE_HANDLER
  MPP_SET(3)
  SA_CHECK(x6, 9, "mcause of the ecall after an M-mode SRET with SPP=S, misa.H cleared, stale hstatus.SPV=1 (9 = S-mode)")
  j t_end
.balign 4
t_mtrap:
  csrrw x13, mscratch, x13
  SREG x14, 0(x13)
  csrr x14, mcause
  SREG x14, REGWIDTH(x13)
  LREG x14, 2*REGWIDTH(x13)
  csrw mepc, x14
  li x14, 0x1800
  csrs mstatus, x14
  LREG x14, 0(x13)
  csrrw x13, mscratch, x13
  mret
t_end:
RVTEST_CODE_END
RVTEST_DATA_BEGIN
.align 3
t_area: .fill 4, 8, 0
t_save: .fill 2, 8, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
