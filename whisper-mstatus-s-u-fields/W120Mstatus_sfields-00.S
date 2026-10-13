///////////////////////////////////////////
// W120Mstatus/W120Mstatus_sfields-00.S
//
// tenstorrent/whisper#120 item 22: mstatus fields that belong to S-mode, U-mode or the
// v registers must be read-only zero when the hart lacks them (machine.adoc):
//   SIE, SPIE, MXR, SUM, TVM, TSR: read-only 0 without S-mode
//   SUM, MXR, TVM:                 read-only 0 when satp.MODE is read-only 0 (Bare only)
//   MPRV:                          read-only 0 without U-mode
//   TW:                            read-only 0 without modes less privileged than M
//   VS:                            read-only 0 without the v registers and S-mode
//                                  (checked only on harts that have neither)
// The test sets each field with csrs and records the value read back.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 12
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 4

#include "riscv_arch_test.h"

RVTEST_BEGIN

  csrr x9, mstatus                 // Save mstatus

#define MSTATUS_FIELD_TEST(name, bits)    \
  LI(x13, bits)                          ;\
W120Mstatus_##name:                      ;\
  csrs mstatus, x13                      ;\
  csrr x8, mstatus                       ;\
  and x8, x8, x13                        ;\
  csrc mstatus, x13                      ;\
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Mstatus_##name, W120Mstatus_##name##_str)

  MSTATUS_FIELD_TEST(sie,  0x00000002)
  MSTATUS_FIELD_TEST(spie, 0x00000020)
#if !defined(S_SUPPORTED) && !defined(V_SUPPORTED)
  MSTATUS_FIELD_TEST(vs,   0x00000600)   // optional read-only zero with S but no V
#endif
  MSTATUS_FIELD_TEST(mprv, 0x00020000)
  MSTATUS_FIELD_TEST(sum,  0x00040000)
  MSTATUS_FIELD_TEST(mxr,  0x00080000)
  MSTATUS_FIELD_TEST(tvm,  0x00100000)
  MSTATUS_FIELD_TEST(tw,   0x00200000)
  MSTATUS_FIELD_TEST(tsr,  0x00400000)

  csrw mstatus, x9                 // Restore mstatus

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Mstatus_sie_str:  .string "\"test: 1; cg: W120Mstatus; cp: sfields; bin: sie\""
W120Mstatus_spie_str: .string "\"test: 2; cg: W120Mstatus; cp: sfields; bin: spie\""
W120Mstatus_vs_str:   .string "\"test: 3; cg: W120Mstatus; cp: sfields; bin: vs\""
W120Mstatus_mprv_str: .string "\"test: 4; cg: W120Mstatus; cp: sfields; bin: mprv\""
W120Mstatus_sum_str:  .string "\"test: 5; cg: W120Mstatus; cp: sfields; bin: sum\""
W120Mstatus_mxr_str:  .string "\"test: 6; cg: W120Mstatus; cp: sfields; bin: mxr\""
W120Mstatus_tvm_str:  .string "\"test: 7; cg: W120Mstatus; cp: sfields; bin: tvm\""
W120Mstatus_tw_str:   .string "\"test: 8; cg: W120Mstatus; cp: sfields; bin: tw\""
W120Mstatus_tsr_str:  .string "\"test: 9; cg: W120Mstatus; cp: sfields; bin: tsr\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
