///////////////////////////////////////////
// W120H/W120H_hlv_rv32-00.S
//
// HLV.WU and HLV.D are not valid for RV32 (priv hypervisor.adoc), so on an RV32 hart their encodings are
// unimplemented opcodes in the standard encoding space. A hart with Ssstrict must raise an illegal-instruction
// exception for them (priv ssstrict.adoc), as Whisper already does for HSV.D. Executed in HS-mode, where the
// valid HLV instructions are permitted. HLV.W is the positive control and loads normally.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'H', 'Ssstrict']
# params:
#   MXLEN: 32
# MARCH: rv32ih_zicsr_zifencei
##### END_TEST_CONFIG #####

// Define the size of the signature region
#define SIGUPD_COUNT 3

// Extra defines (if needed) to enable trap handlers, fpu, vector, etc.
#define BOOT_TO_SMODE
#define TRAP_SIGUPD_COUNT 20

// Include framework macros
#include "riscv_arch_test.h"

// Set up test environment and declare main entry point
RVTEST_BEGIN

  LA(x6, scratch)
  LI(x7, 0x12345678)
  sw x7, 0(x6)
  sw x7, 4(x6)

  LI(x10, 0xBAD)
W120H_hlv_w:
  hlv.w x10, (x6)                // positive control: x10 = 0x12345678
  RVTEST_SIGUPD(x2, x5, x4, x10, W120H_hlv_w, W120H_hlv_w_str)

  LI(x10, 0xBAD)
W120H_hlv_wu:
  .word 0x68134573               // hlv.wu x10, (x6): RV64-only, illegal instruction on RV32 + Ssstrict
  RVTEST_SIGUPD(x2, x5, x4, x10, W120H_hlv_wu, W120H_hlv_wu_str)

  LI(x10, 0xBAD)
W120H_hlv_d:
  .word 0x6c034573               // hlv.d x10, (x6): RV64-only, illegal instruction on RV32 + Ssstrict
  RVTEST_SIGUPD(x2, x5, x4, x10, W120H_hlv_d, W120H_hlv_d_str)

// Instantiate trap handlers and other epilog code, call RVMODEL_HALT at end of test
RVTEST_CODE_END

// Create scratch data sections and label for test data
RVTEST_DATA_BEGIN

// Testcase strings
W120H_hlv_w_str: .string "hlv.w"
W120H_hlv_wu_str: .string "hlv.wu (0x68134573)"
W120H_hlv_d_str: .string "hlv.d (0x6c034573)"

RVTEST_DATA_END

RVTEST_SIG_SETUP
