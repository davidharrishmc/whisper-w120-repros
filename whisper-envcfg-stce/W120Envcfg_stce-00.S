///////////////////////////////////////////
// W120Envcfg/W120Envcfg_stce-00.S
//
// tenstorrent/whisper#120 item 24: "When the Sstc extension is not implemented, STCE is
// read-only zero" (machine.adoc norm:menvcfg_stce_rdonly0); with H, henvcfg.STCE is
// read-only zero when menvcfg.STCE is 0. The test sets STCE (menvcfg bit 63, menvcfgh
// bit 31 on RV32) in menvcfg and, with H, in henvcfg, and records the value read back.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'U']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 6
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 4

#include "riscv_arch_test.h"

RVTEST_BEGIN

#if __riscv_xlen == 64
  #define ENVCFG_HI(csr) csr
  LI(x13, 0x8000000000000000)
#else
  #define ENVCFG_HI(csr) csr##h
  LI(x13, 0x80000000)
#endif

W120Envcfg_menvcfg_stce:
  csrs ENVCFG_HI(menvcfg), x13
  csrr x8, ENVCFG_HI(menvcfg)
  and x8, x8, x13
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Envcfg_menvcfg_stce, W120Envcfg_menvcfg_stce_str)

#ifdef H_SUPPORTED
W120Envcfg_henvcfg_stce:
  csrs ENVCFG_HI(henvcfg), x13
  csrr x8, ENVCFG_HI(henvcfg)
  and x8, x8, x13
  csrc ENVCFG_HI(henvcfg), x13
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Envcfg_henvcfg_stce, W120Envcfg_henvcfg_stce_str)
#endif

  csrc ENVCFG_HI(menvcfg), x13

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Envcfg_menvcfg_stce_str: .string "\"test: 1; cg: W120Envcfg; cp: stce; bin: menvcfg\""
W120Envcfg_henvcfg_stce_str: .string "\"test: 2; cg: W120Envcfg; cp: stce; bin: henvcfg\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
