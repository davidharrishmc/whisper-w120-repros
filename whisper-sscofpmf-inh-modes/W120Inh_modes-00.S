///////////////////////////////////////////
// W120Inh/W120Inh_modes-00.S
//
// tenstorrent/whisper#120 item 29: Sscofpmf mhpmevent xINH bits are read-only
// zero when the associated privilege mode is not implemented (sscofpmf.adoc).
// Write MINH, SINH, UINH, VSINH, VUINH of mhpmevent3 and read them back.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sscofpmf', 'Zihpm']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr_zifencei_zihpm
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 4
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 20

#include "riscv_arch_test.h"

RVTEST_BEGIN

main:
#if __riscv_xlen == 64
  LI(x15, 0x7c00000000000000)   // MINH SINH UINH VSINH VUINH (bits 62:58)
  csrw mhpmevent3, x15
  csrr x14, mhpmevent3
  csrw mhpmevent3, x0
#else
  LI(x15, 0x7c000000)           // same bits in mhpmevent3h (bits 30:26)
  csrw mhpmevent3h, x15
  csrr x14, mhpmevent3h
  csrw mhpmevent3h, x0
#endif
  and x14, x14, x15
W120Inh_mhpmevent3_inh:
  RVTEST_SIGUPD(x2, x5, x4, x14, W120Inh_mhpmevent3_inh, W120Inh_mhpmevent3_inh_str)

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Inh_mhpmevent3_inh_str: .string "\"test: 1; cg: W120Inh; cp: mhpmevent_xinh; bin: write_all_inh\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
