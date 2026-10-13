///////////////////////////////////////////
// W120Zicfiss/W120Zicfiss_mop-00.S
//
// With shadow stacks active (menvcfg.SSE=1, S-mode), only mop.r.28 (sspopchk, ssrdp) and mop.rr.7 (sspush)
// are shadow-stack instructions; every other mop.r.N / mop.rr.N keeps its Zimop behavior and writes 0 to rd
// (unpriv cfi.adoc, zimop.adoc). ssrdp (mop.r.28) is the positive control and must return ssp.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'S', 'Zimop', 'Zicfiss']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr_zifencei_zaamo_zimop_zicfiss
##### END_TEST_CONFIG #####

// Define the size of the signature region
#define SIGUPD_COUNT 6

// Extra defines (if needed) to enable trap handlers, fpu, vector, etc.
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 30

// Include framework macros
#include "riscv_arch_test.h"

// Set up test environment and declare main entry point
RVTEST_BEGIN

  LI(x8, MENVCFG_SSE)
  csrs menvcfg, x8
  LI(x8, 0x80001000)
  csrw ssp, x8                   // ssp = 0x80001000 (never dereferenced below)
  RVTEST_TSBI_GOTO_SMODE         // shadow stacks are now active (S-mode, menvcfg.SSE=1)

  LI(x10, 0xBAD)
W120Zicfiss_ssrdp:
  mop.r.28 x10, x0               // ssrdp x10: positive control, x10 = ssp
  RVTEST_SIGUPD(x2, x5, x4, x10, W120Zicfiss_ssrdp, W120Zicfiss_ssrdp_str)

  LI(x10, 0xBAD)
W120Zicfiss_mop_r_0:
  mop.r.0 x10, x0                // Zimop: x10 = 0 (not ssp)
  RVTEST_SIGUPD(x2, x5, x4, x10, W120Zicfiss_mop_r_0, W120Zicfiss_mop_r_0_str)

  LI(x10, 0xBAD)
W120Zicfiss_mop_r_27:
  mop.r.27 x10, x0               // Zimop: x10 = 0 (not ssp)
  RVTEST_SIGUPD(x2, x5, x4, x10, W120Zicfiss_mop_r_27, W120Zicfiss_mop_r_27_str)

W120Zicfiss_mop_r_0_x1:
  mop.r.0 x0, x1                 // Zimop: no effect (not sspopchk: no shadow stack load, no trap)
  csrr x10, ssp
  RVTEST_SIGUPD(x2, x5, x4, x10, W120Zicfiss_mop_r_0_x1, W120Zicfiss_mop_r_0_x1_str)

W120Zicfiss_mop_rr_0:
  mop.rr.0 x0, x0, x1            // Zimop: no effect (not sspush: no shadow stack store, no trap)
  csrr x10, ssp
  RVTEST_SIGUPD(x2, x5, x4, x10, W120Zicfiss_mop_rr_0, W120Zicfiss_mop_rr_0_str)

W120Zicfiss_mop_rr_3:
  mop.rr.3 x0, x0, x5            // Zimop: no effect (not sspush)
  csrr x10, ssp
  RVTEST_SIGUPD(x2, x5, x4, x10, W120Zicfiss_mop_rr_3, W120Zicfiss_mop_rr_3_str)

// Instantiate trap handlers and other epilog code, call RVMODEL_HALT at end of test
RVTEST_CODE_END

// Create scratch data sections and label for test data
RVTEST_DATA_BEGIN

// Testcase strings
W120Zicfiss_ssrdp_str: .string "mop.r.28 (ssrdp)"
W120Zicfiss_mop_r_0_str: .string "mop.r.0 rd!=0, rs1=x0"
W120Zicfiss_mop_r_27_str: .string "mop.r.27 rd!=0, rs1=x0"
W120Zicfiss_mop_r_0_x1_str: .string "mop.r.0 rd=x0, rs1=x1"
W120Zicfiss_mop_rr_0_str: .string "mop.rr.0 rd=x0, rs1=x0, rs2=x1"
W120Zicfiss_mop_rr_3_str: .string "mop.rr.3 rd=x0, rs1=x0, rs2=x5"

RVTEST_DATA_END

RVTEST_SIG_SETUP
