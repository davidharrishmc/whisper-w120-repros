///////////////////////////////////////////
// W120H/W120H_svinval_absent-00.S
//
// On a hart with H and Ssstrict but without Svinval, sinval.vma, sfence.w.inval and sfence.inval.ir are
// unimplemented opcodes, so Ssstrict requires an illegal-instruction exception (priv ssstrict.adoc). They are
// not HS-qualified (not valid in HS-mode), so the virtual-instruction exception does not apply in VU-mode or
// VS-mode (priv hypervisor.adoc, norm:H_cause_virtual_instruction).
// sfence.vma in VU-mode is the positive control for the virtual-instruction exception.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'H', 'Ssstrict']
# # # no param constraints
# MARCH: rv${XLEN}ih_zicsr_zifencei_svinval
##### END_TEST_CONFIG #####

// Define the size of the signature region
#define SIGUPD_COUNT 1

// Extra defines (if needed) to enable trap handlers, fpu, vector, etc.
#define BOOT_TO_SMODE
#define TRAP_SIGUPD_COUNT 60

// Include framework macros
#include "riscv_arch_test.h"

// Set up test environment and declare main entry point
RVTEST_BEGIN

#ifndef SVINVAL_SUPPORTED
  RVTEST_TSBI_GOTO_VUMODE
W120H_vu_sfence_vma:
  sfence.vma x0, x0              // positive control: virtual-instruction exception
W120H_vu_sinval_vma:
  sinval.vma x0, x0              // illegal instruction
W120H_vu_sfence_w_inval:
  sfence.w.inval                 // illegal instruction
W120H_vu_sfence_inval_ir:
  sfence.inval.ir                // illegal instruction
  RVTEST_TSBI_GOTO_VSMODE
W120H_vs_sinval_vma:
  sinval.vma x0, x0              // illegal instruction
W120H_vs_sfence_w_inval:
  sfence.w.inval                 // illegal instruction
W120H_vs_sfence_inval_ir:
  sfence.inval.ir                // illegal instruction
  RVTEST_TSBI_GOTO_SMODE
#endif
  LI(x10, 1)
W120H_done:
  RVTEST_SIGUPD(x2, x5, x4, x10, W120H_done, W120H_done_str)

// Instantiate trap handlers and other epilog code, call RVMODEL_HALT at end of test
RVTEST_CODE_END

// Create scratch data sections and label for test data
RVTEST_DATA_BEGIN

// Testcase strings
W120H_done_str: .string "done"

RVTEST_DATA_END

RVTEST_SIG_SETUP
