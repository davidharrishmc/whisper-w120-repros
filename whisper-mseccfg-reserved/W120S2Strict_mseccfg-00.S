///////////////////////////////////////////
// W120S2Strict/W120S2Strict_mseccfg-00.S
//
// whisper#120 item 19: mseccfg/mseccfgh are reserved unless an extension that adds a field to
// mseccfg (Smepmp, Zkr, Zicfilp, Smmpm) is implemented (machine.adoc norm:mseccfg_presence).
// On an Ssstrict hart each access raises an illegal-instruction exception
// (ssstrict.adoc norm:Ssstrict_unimplemented_opcodes_csr_exception): x13 keeps 0x55 and the
// trap is recorded in the trap signature.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Ssstrict']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr_zifencei
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 8

#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 40

#include "riscv_arch_test.h"

RVTEST_BEGIN

main:

  LI(x13, 0x55)
W120S2Strict_mseccfg_r:
  csrr x13, mseccfg
  RVTEST_SIGUPD(x2, x5, x4, x13, W120S2Strict_mseccfg_r, W120S2Strict_mseccfg_r_str)

  LI(x13, 0x55)
W120S2Strict_mseccfg_w:
  csrrw x13, mseccfg, x0
  RVTEST_SIGUPD(x2, x5, x4, x13, W120S2Strict_mseccfg_w, W120S2Strict_mseccfg_w_str)

  LI(x13, 0x55)
  LI(x9, -1)
W120S2Strict_mseccfg_s:
  csrrs x13, mseccfg, x9
  RVTEST_SIGUPD(x2, x5, x4, x13, W120S2Strict_mseccfg_s, W120S2Strict_mseccfg_s_str)

#if __riscv_xlen == 32
  LI(x13, 0x55)
W120S2Strict_mseccfgh_r:
  csrr x13, mseccfgh
  RVTEST_SIGUPD(x2, x5, x4, x13, W120S2Strict_mseccfgh_r, W120S2Strict_mseccfgh_r_str)

  LI(x13, 0x55)
W120S2Strict_mseccfgh_w:
  csrrw x13, mseccfgh, x0
  RVTEST_SIGUPD(x2, x5, x4, x13, W120S2Strict_mseccfgh_w, W120S2Strict_mseccfgh_w_str)
#endif

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120S2Strict_mseccfg_r_str: .string "\"test: 1; cg: W120S2Strict; cp: mseccfg; bin: csrr mseccfg\""
W120S2Strict_mseccfg_w_str: .string "\"test: 2; cg: W120S2Strict; cp: mseccfg; bin: csrrw mseccfg\""
W120S2Strict_mseccfg_s_str: .string "\"test: 3; cg: W120S2Strict; cp: mseccfg; bin: csrrs mseccfg\""
W120S2Strict_mseccfgh_r_str: .string "\"test: 4; cg: W120S2Strict; cp: mseccfg; bin: csrr mseccfgh\""
W120S2Strict_mseccfgh_w_str: .string "\"test: 5; cg: W120S2Strict; cp: mseccfg; bin: csrrw mseccfgh\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
