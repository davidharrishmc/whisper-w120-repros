///////////////////////////////////////////
// W120Mstatus/W120Mstatus_xl-00.S
//
// tenstorrent/whisper#120 item 23: when MXLEN=64, mstatus.SXL is read-only zero if S-mode
// is not supported and mstatus.UXL is read-only zero if U-mode is not supported
// (machine.adoc norm:mstatus_sxl_acc_mxlen64, norm:mstatus_uxl_acc_mxlen64).
// The test records mstatus[35:32] after reset, after writing all ones and after
// writing zeros to those bits.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 6
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 4

#include "riscv_arch_test.h"

RVTEST_BEGIN

#if __riscv_xlen == 64
  csrr x9, mstatus                 // Save mstatus

W120Mstatus_xl_read:
  csrr x8, mstatus
  srli x8, x8, 32
  andi x8, x8, 0xf                 // UXL (33:32) and SXL (35:34)
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Mstatus_xl_read, W120Mstatus_xl_read_str)

  LI(x13, 0xf00000000)
W120Mstatus_xl_set:
  csrs mstatus, x13
  csrr x8, mstatus
  srli x8, x8, 32
  andi x8, x8, 0xf
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Mstatus_xl_set, W120Mstatus_xl_set_str)

W120Mstatus_xl_clear:
  csrc mstatus, x13
  csrr x8, mstatus
  srli x8, x8, 32
  andi x8, x8, 0xf
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Mstatus_xl_clear, W120Mstatus_xl_clear_str)

  csrw mstatus, x9                 // Restore mstatus
#endif

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Mstatus_xl_read_str:  .string "\"test: 1; cg: W120Mstatus; cp: xl; bin: reset\""
W120Mstatus_xl_set_str:   .string "\"test: 2; cg: W120Mstatus; cp: xl; bin: set\""
W120Mstatus_xl_clear_str: .string "\"test: 3; cg: W120Mstatus; cp: xl; bin: clear\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
