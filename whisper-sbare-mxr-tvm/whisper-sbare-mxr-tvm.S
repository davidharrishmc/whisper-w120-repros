// With S-mode and only Bare address translation (satp.MODE read-only 0), mstatus.MXR and mstatus.TVM must be
// read-only 0 (ISA manual main branch, riscv-isa-manual PR #2978):
//   machine.adoc norm:mstatus_mxr_rdonly0_no_smode "mxr is read-only 0 if S-mode is not supported or if
//     satp[mode] is read-only 0; otherwise, it must be writable."
//   machine.adoc norm:mstatus_tvm_acc "tvm is read-only 0 when S-mode is not supported or if satp[mode] is
//     read-only 0; otherwise, it must be writable."
// The test sets MXR and TVM with csrs and reads them back, then (with TVM written 1) runs `csrr satp` in S-mode:
// TVM is read-only 0, so the access must not raise an illegal-instruction exception (ecall cause 9 comes first).
// On a hart whose satp.MODE is writable the test checks nothing and passes.
// RV64 only (the Bare-only configurations used are RV64).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
#if __riscv_xlen == 64
  LI(x9, 0x8000000000000000)    // satp.MODE = Sv39
  csrw satp, x9
  csrr x7, satp
  csrw satp, x0
  bnez x7, t_end              // satp.MODE writable: not a Bare-only hart, nothing to check

  // 1. MXR
  LI(x9, 1 << 19)
  csrs mstatus, x9
  csrr x7, mstatus
  csrc mstatus, x9
  srli x7, x7, 19
  andi x7, x7, 1
  SA_SOFT(x7, 0, "mstatus.MXR after csrs (read-only 0 with a Bare-only satp)")

  // 2. TVM
  LI(x9, 1 << 20)
  csrs mstatus, x9
  csrr x7, mstatus
  srli x7, x7, 20
  andi x7, x7, 1
  SA_SOFT(x7, 0, "mstatus.TVM after csrs (read-only 0 with a Bare-only satp)")

  // 3. With TVM written 1, an S-mode read of satp executes (then ecall, cause 9).
  csrw mie, x0
  csrw medeleg, x0
  csrw mideleg, x0
  LA(x4, t_save)
  csrr x7, mtvec
  sd x7, 0(x4)
  csrr x7, mscratch
  sd x7, 8(x4)
  LA(x7, t_area)
  csrw mscratch, x7
  LA(x7, t_mtrap)
  csrw mtvec, x7
  LA(x4, t_area)
  li x7, -1
  sd x7, 8(x4)                  // first mcause (-1 = none)
  LA(x7, t_back)
  sd x7, 16(x4)                 // resume point
  li x8, 0x1800
  csrc mstatus, x8
  li x8, 0x0800                 // MPP = S
  csrs mstatus, x8
  LA(x7, t_smode)
  csrw mepc, x7
  mret
t_smode:
  csrr x7, satp                 // illegal only if TVM = 1
  ecall
t_back:
  LA(x4, t_save)
  ld x7, 0(x4)
  csrw mtvec, x7
  ld x7, 8(x4)
  csrw mscratch, x7
  LI(x9, 1 << 20)
  csrc mstatus, x9
  LA(x4, t_area)
  ld x7, 8(x4)
  SA_SOFT(x7, 9, "first trap after S-mode csrr satp with TVM written 1 (9 = the ecall; 2 = csrr satp was illegal)")
  SA_SOFT_END
t_end:
  j t_done

.balign 4
t_mtrap:                      // record the first mcause, resume at t_back in M-mode
  csrrw x13, mscratch, x13
  sd x14, 0(x13)
  ld x14, 8(x13)
  bgez x14, 1f
  csrr x14, mcause
  sd x14, 8(x13)
1:
  ld x14, 16(x13)
  csrw mepc, x14
  li x14, 0x1800
  csrs mstatus, x14             // MPP = M
  ld x14, 0(x13)
  csrrw x13, mscratch, x13
  mret
t_done:
#endif
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.align 3
t_area: .fill 4, 8, 0
t_save: .fill 2, 8, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
