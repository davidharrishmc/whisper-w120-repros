///////////////////////////////////////////
// W120Csrexist/W120Csrexist_nos-00.S
//
// whisper#120 item 20: Sstc's stimecmp/stimecmph are S-level CSRs; a hart without S-mode has none.
// Spike and Sail raise an illegal-instruction exception for each access (x13 keeps 0x55; the trap is
// recorded).
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 4

#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 32

#include "riscv_arch_test.h"

RVTEST_BEGIN

main:

  LI(x13, 0x55)
W120Csrexist_nos_stimecmp:
  csrr x13, stimecmp
  RVTEST_SIGUPD(x2, x5, x4, x13, W120Csrexist_nos_stimecmp, W120Csrexist_nos_stimecmp_str)

#if __riscv_xlen == 32
  LI(x13, 0x55)
W120Csrexist_nos_stimecmph:
  csrr x13, stimecmph
  RVTEST_SIGUPD(x2, x5, x4, x13, W120Csrexist_nos_stimecmph, W120Csrexist_nos_stimecmph_str)
#endif

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Csrexist_nos_stimecmp_str: .string "\"test: 1; cg: W120Csrexist; cp: nos; bin: stimecmp\""
W120Csrexist_nos_stimecmph_str: .string "\"test: 2; cg: W120Csrexist; cp: nos; bin: stimecmph\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
