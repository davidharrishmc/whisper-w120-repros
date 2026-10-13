///////////////////////////////////////////
// W120Zicfiss/W120Zicfiss_ssamoswap-00.S
//
// ssamoswap.w/d need Zicfiss (which depends on Zaamo), not the full A extension.
// In M-mode, the memory access of ssamoswap.w/d raises a store/AMO access-fault exception
// (priv cfi.adoc norm:ssmp_ssamoswap). On a hart with Zaamo but without Zalrsc (so no A),
// the instruction must still be decoded, so the trap handler records mcause 7, not 2.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'S', 'Zaamo', 'Zicfiss']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr_zifencei_zaamo_zimop_zicfiss
##### END_TEST_CONFIG #####

// Define the size of the signature region
#define SIGUPD_COUNT 4

// Extra defines (if needed) to enable trap handlers, fpu, vector, etc.
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 20

// Include framework macros
#include "riscv_arch_test.h"

// Set up test environment and declare main entry point
RVTEST_BEGIN

  LA(x6, scratch)
  LI(x7, 0x1234)
  SREG x7, 0(x6)
  LI(x8, 0x5678)

  LI(x9, 0xBAD)
W120Zicfiss_ssamoswap_w:
  ssamoswap.w x9, x8, (x6)
  RVTEST_SIGUPD(x2, x5, x4, x9, W120Zicfiss_ssamoswap_w, W120Zicfiss_ssamoswap_w_str)
  LREG x10, 0(x6)
  RVTEST_SIGUPD(x2, x5, x4, x10, W120Zicfiss_ssamoswap_w, W120Zicfiss_ssamoswap_w_str)

#if __riscv_xlen == 64
  LI(x9, 0xBAD)
W120Zicfiss_ssamoswap_d:
  ssamoswap.d x9, x8, (x6)
  RVTEST_SIGUPD(x2, x5, x4, x9, W120Zicfiss_ssamoswap_d, W120Zicfiss_ssamoswap_d_str)
  LREG x10, 0(x6)
  RVTEST_SIGUPD(x2, x5, x4, x10, W120Zicfiss_ssamoswap_d, W120Zicfiss_ssamoswap_d_str)
#endif

// Instantiate trap handlers and other epilog code, call RVMODEL_HALT at end of test
RVTEST_CODE_END

// Create scratch data sections and label for test data
RVTEST_DATA_BEGIN

// Testcase strings
W120Zicfiss_ssamoswap_w_str: .string "ssamoswap.w"
W120Zicfiss_ssamoswap_d_str: .string "ssamoswap.d"

RVTEST_DATA_END

RVTEST_SIG_SETUP
