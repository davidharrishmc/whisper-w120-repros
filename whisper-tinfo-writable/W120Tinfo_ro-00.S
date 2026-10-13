///////////////////////////////////////////
// W120Tinfo/W120Tinfo_ro-00.S
//
// tenstorrent/whisper#120 item 35: every field of tinfo is read-only (Sdtrig,
// hwbp_registers.xml). Write the complement of tinfo for trigger 0 and check that
// the value read back is unchanged.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sdtrig']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr_zifencei
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 4
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 20

#include "riscv_arch_test.h"

RVTEST_BEGIN

main:
  csrw tselect, x0
  csrr x14, tinfo
  not x15, x14
  csrw tinfo, x15
  csrr x13, tinfo
  xor x14, x13, x14             // nonzero if any tinfo bit changed
W120Tinfo_write_complement:
  RVTEST_SIGUPD(x2, x5, x4, x14, W120Tinfo_write_complement, W120Tinfo_write_complement_str)

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Tinfo_write_complement_str: .string "\"test: 1; cg: W120Tinfo; cp: tinfo_read_only; bin: write_complement\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
