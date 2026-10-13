///////////////////////////////////////////
// W120UCustom/W120UCustom_nos-00.S
//
// tenstorrent/whisper#120 item 32: on a hart with U but without S, mstateen0
// controls U-mode access to state (smstateen.adoc). With mstateen0.C=0, a U-mode
// access to a custom CSR (0x800) must raise an illegal-instruction exception.
// On harts with no custom CSR at 0x800 the access traps anyway.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'U', 'Smstateen']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr_zifencei_smstateen
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 4
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 20

#include "riscv_arch_test.h"

RVTEST_BEGIN

main:
  csrci mstateen0, 1            // mstateen0.C = 0
  RVTEST_TSBI_GOTO_UMODE

W120UCustom_csrr_0x800_umode:
  csrr x8, 0x800                // must trap: mstateen0.C = 0
  RVTEST_TSBI_GOTO_MMODE

RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END

RVTEST_SIG_SETUP
