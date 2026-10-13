///////////////////////////////////////////
// W120Envcfg/W120Envcfg_cbo-00.S
//
// tenstorrent/whisper#120 item 25: CBIE and CBCFE are read-only zero without Zicbom, and
// CBZE is read-only zero without Zicboz, in menvcfg, senvcfg and henvcfg
// (machine.adoc norm:menvcfg_cbze_rdonly0/cbcfe_rdonly0/cbie_rdonly0; supervisor.adoc
// and hypervisor.adoc say the same for senvcfg and henvcfg). The test sets bits 7:4 of
// each implemented envcfg CSR and records the value read back.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'U']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 8
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 4

#include "riscv_arch_test.h"

RVTEST_BEGIN

  li x13, 0xf0                     // CBZE (7), CBCFE (6), CBIE (5:4)

W120Envcfg_menvcfg_cbo:
  csrs menvcfg, x13
  csrr x8, menvcfg
  and x8, x8, x13
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Envcfg_menvcfg_cbo, W120Envcfg_menvcfg_cbo_str)

#ifdef S_SUPPORTED
W120Envcfg_senvcfg_cbo:
  csrs senvcfg, x13
  csrr x8, senvcfg
  and x8, x8, x13
  csrc senvcfg, x13
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Envcfg_senvcfg_cbo, W120Envcfg_senvcfg_cbo_str)
#endif

#ifdef H_SUPPORTED
W120Envcfg_henvcfg_cbo:
  csrs henvcfg, x13
  csrr x8, henvcfg
  and x8, x8, x13
  csrc henvcfg, x13
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Envcfg_henvcfg_cbo, W120Envcfg_henvcfg_cbo_str)
#endif

  csrc menvcfg, x13

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Envcfg_menvcfg_cbo_str: .string "\"test: 1; cg: W120Envcfg; cp: cbo; bin: menvcfg\""
W120Envcfg_senvcfg_cbo_str: .string "\"test: 2; cg: W120Envcfg; cp: cbo; bin: senvcfg\""
W120Envcfg_henvcfg_cbo_str: .string "\"test: 3; cg: W120Envcfg; cp: cbo; bin: henvcfg\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
