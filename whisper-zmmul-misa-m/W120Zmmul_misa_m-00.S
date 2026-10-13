///////////////////////////////////////////
// W120Zmmul/W120Zmmul_misa_m-00.S
//
// Clear misa.M (if writable) on a hart with Zmmul. The multiply instructions
// stay available (Zmmul); divide and remainder trap until misa.M is set again.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Zmmul']
# # # no param constraints
# MARCH: rv${XLEN}im_zicsr
##### END_TEST_CONFIG #####

// Define the size of the signature region
#define SIGUPD_COUNT 8

// Extra defines (if needed) to enable trap handlers, fpu, vector, etc.
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 8

// Include framework macros
#include "riscv_arch_test.h"

// Set up test environment and declare main entry point
RVTEST_BEGIN

/////////////////////////////////
// mul with misa.M cleared: Zmmul keeps it
/////////////////////////////////

  csrr x9, misa               # save misa
  LI(x10, 0x1000)             # misa.M
  csrc misa, x10              # clear misa.M if it is writable
  csrr x13, misa
  and x13, x13, x10
W120Zmmul_misa_m_cleared:
  RVTEST_SIGUPD(x2, x5, x4, x13, W120Zmmul_misa_m_cleared, W120Zmmul_misa_m_cleared_str)

  LI(x14, 7)
  LI(x15, -6)
  LI(x8, 0xBAD)
W120Zmmul_mul:
  mul x8, x14, x15
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Zmmul_mul, W120Zmmul_mul_str)

  LI(x8, 0xBAD)
W120Zmmul_mulhsu:
  mulhsu x8, x15, x14
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Zmmul_mulhsu, W120Zmmul_mulhsu_str)

  LI(x8, 0xBAD)
W120Zmmul_div:
  div x8, x15, x14
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Zmmul_div, W120Zmmul_div_str)

  csrw misa, x9               # restore misa

  LI(x8, 0xBAD)
W120Zmmul_mul_restored:
  mul x8, x14, x15
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Zmmul_mul_restored, W120Zmmul_mul_restored_str)

// Instantiate trap handlers and other epilog code, call RVMODEL_HALT at end of test
RVTEST_CODE_END

// Create scratch data sections and label for test data
RVTEST_DATA_BEGIN

// Testcase strings
W120Zmmul_misa_m_cleared_str: .string "\"test: 1; misa.M after csrc\""
W120Zmmul_mul_str: .string "\"test: 2; mul with misa.M clear\""
W120Zmmul_mulhsu_str: .string "\"test: 3; mulhsu with misa.M clear\""
W120Zmmul_div_str: .string "\"test: 4; div with misa.M clear\""
W120Zmmul_mul_restored_str: .string "\"test: 5; mul after misa restored\""

// End of test data section and model specific data
RVTEST_DATA_END

// Signature region for self-checking
RVTEST_SIG_SETUP
