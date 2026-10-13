///////////////////////////////////////////
// W120Imsic/W120Imsic_bit58-00.S
//
// tenstorrent/whisper#120 item 33: mstateen0.IMSIC (bit 58) and hstateen0.IMSIC
// control access to IMSIC state. On a hart without an IMSIC the bits are read-only
// zero (smstateen.adoc). Set them and check that they read back as zero.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Smstateen']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr_zifencei_smstateen
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 4
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 20

#include "riscv_arch_test.h"

RVTEST_BEGIN

main:
#if __riscv_xlen == 64
  LI(x15, 0x0400000000000000)   // bit 58
  csrs mstateen0, x15
  csrr x14, mstateen0
  and x14, x14, x15
#else
  LI(x15, 0x04000000)           // bit 26 of mstateen0h = bit 58
  csrs mstateen0h, x15
  csrr x14, mstateen0h
  and x14, x14, x15
#endif
W120Imsic_mstateen0_bit58:
  RVTEST_SIGUPD(x2, x5, x4, x14, W120Imsic_mstateen0_bit58, W120Imsic_mstateen0_bit58_str)

#ifdef H_SUPPORTED
#if __riscv_xlen == 64
  csrs hstateen0, x15
  csrr x14, hstateen0
  and x14, x14, x15
#else
  csrs hstateen0h, x15
  csrr x14, hstateen0h
  and x14, x14, x15
#endif
W120Imsic_hstateen0_bit58:
  RVTEST_SIGUPD(x2, x5, x4, x14, W120Imsic_hstateen0_bit58, W120Imsic_hstateen0_bit58_str)
#endif

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Imsic_mstateen0_bit58_str: .string "\"test: 1; cg: W120Imsic; cp: mstateen0_imsic; bin: set_bit_58\""
W120Imsic_hstateen0_bit58_str: .string "\"test: 2; cg: W120Imsic; cp: hstateen0_imsic; bin: set_bit_58\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
