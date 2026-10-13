///////////////////////////////////////////
// W120Csrexist/W120Csrexist_scountovf-00.S
//
// whisper#120 item 18: a configuration that disables mcounteren on a hart with U-mode (and S-mode
// and Sscofpmf) is accepted, and an S-mode read of scountovf then hits an assertion.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U', 'Sscofpmf']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 3

#define BOOT_TO_SMODE
#define TRAP_SIGUPD_COUNT 16

#include "riscv_arch_test.h"

RVTEST_BEGIN

main:

  LI(x13, 0x55)
W120Csrexist_scountovf_smode:
  csrr x13, scountovf
  RVTEST_SIGUPD(x2, x5, x4, x13, W120Csrexist_scountovf_smode, W120Csrexist_scountovf_smode_str)

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Csrexist_scountovf_smode_str: .string "\"test: 1; cg: W120Csrexist; cp: scountovf; bin: S-mode read\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
