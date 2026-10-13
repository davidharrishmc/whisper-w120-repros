///////////////////////////////////////////
// W120S2Nou/W120S2Nou_nou-00.S
//
// whisper#120 item 18: without U-mode, menvcfg and menvcfgh do not exist and mcounteren should not
// exist (machine.adoc norm:menvcfg_menvcfgh_no_u_mode, norm:mcounteren_presence).
// Each access is expected to raise an illegal-instruction exception, as Spike and Sail do
// (x13 keeps 0x55; the trap is recorded).
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr_zifencei
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 7

#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 56

#include "riscv_arch_test.h"

RVTEST_BEGIN

main:

  LI(x13, 0x55)
W120S2Nou_nou_mcounteren:
  csrr x13, mcounteren
  RVTEST_SIGUPD(x2, x5, x4, x13, W120S2Nou_nou_mcounteren, W120S2Nou_nou_mcounteren_str)

  LI(x13, 0x55)
W120S2Nou_nou_menvcfg:
  csrr x13, menvcfg
  RVTEST_SIGUPD(x2, x5, x4, x13, W120S2Nou_nou_menvcfg, W120S2Nou_nou_menvcfg_str)

#if __riscv_xlen == 32
  LI(x13, 0x55)
W120S2Nou_nou_menvcfgh:
  csrr x13, menvcfgh
  RVTEST_SIGUPD(x2, x5, x4, x13, W120S2Nou_nou_menvcfgh, W120S2Nou_nou_menvcfgh_str)
#endif

  LI(x13, 0x55)
W120S2Nou_nou_mcounteren_w:
  csrrw x13, mcounteren, x0
  RVTEST_SIGUPD(x2, x5, x4, x13, W120S2Nou_nou_mcounteren_w, W120S2Nou_nou_mcounteren_w_str)

  LI(x13, 0x55)
W120S2Nou_nou_menvcfg_w:
  csrrw x13, menvcfg, x0
  RVTEST_SIGUPD(x2, x5, x4, x13, W120S2Nou_nou_menvcfg_w, W120S2Nou_nou_menvcfg_w_str)

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120S2Nou_nou_mcounteren_str: .string "\"test: 1; cg: W120S2Nou; cp: nou; bin: mcounteren\""
W120S2Nou_nou_menvcfg_str: .string "\"test: 2; cg: W120S2Nou; cp: nou; bin: menvcfg\""
W120S2Nou_nou_menvcfgh_str: .string "\"test: 3; cg: W120S2Nou; cp: nou; bin: menvcfgh\""
W120S2Nou_nou_mcounteren_w_str: .string "\"test: 4; cg: W120S2Nou; cp: nou; bin: mcounteren_w\""
W120S2Nou_nou_menvcfg_w_str: .string "\"test: 5; cg: W120S2Nou; cp: nou; bin: menvcfg_w\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
