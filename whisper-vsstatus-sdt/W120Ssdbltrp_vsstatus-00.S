///////////////////////////////////////////
// W120Ssdbltrp/W120Ssdbltrp_vsstatus-00.S
//
// tenstorrent/whisper#120 item 30: with Ssdbltrp and H, Ssdbltrp adds vsstatus.SDT
// (ssdbltrp.adoc norm:vsstatus_SDT); it is writable when henvcfg.DTE=1 and read-only zero
// when henvcfg.DTE=0 (hypervisor.adoc: "When henvcfg.DTE is zero ... the vsstatus.SDT bit
// is read-only zero"). The test sets menvcfg.DTE and henvcfg.DTE, sets vsstatus.SDT and
// records the value read back, then repeats with henvcfg.DTE=0.
//
// SPDX-License-Identifier: Apache-2.0
///////////////////////////////////////////

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'H', 'Ssdbltrp']
# # # no param constraints
# MARCH: rv${XLEN}i_zicsr_h
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 8
#define BOOT_TO_MMODE
#define TRAP_SIGUPD_COUNT 4

#include "riscv_arch_test.h"

RVTEST_BEGIN

#if __riscv_xlen == 64
  #define ENVCFG_HI(csr) csr
  LI(x13, 0x0800000000000000)      // DTE (bit 59)
#else
  #define ENVCFG_HI(csr) csr##h
  LI(x13, 0x08000000)              // DTE (menvcfgh/henvcfgh bit 27)
#endif
  LI(x14, 0x01000000)              // vsstatus.SDT (bit 24)

  csrs ENVCFG_HI(menvcfg), x13
  csrs ENVCFG_HI(henvcfg), x13

W120Ssdbltrp_henvcfg_dte:
  csrr x8, ENVCFG_HI(henvcfg)
  and x8, x8, x13
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Ssdbltrp_henvcfg_dte, W120Ssdbltrp_henvcfg_dte_str)

W120Ssdbltrp_vsstatus_sdt_dte1:
  csrs vsstatus, x14
  csrr x8, vsstatus
  and x8, x8, x14
  csrc vsstatus, x14
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Ssdbltrp_vsstatus_sdt_dte1, W120Ssdbltrp_vsstatus_sdt_dte1_str)

  csrc ENVCFG_HI(henvcfg), x13
W120Ssdbltrp_vsstatus_sdt_dte0:
  csrs vsstatus, x14
  csrr x8, vsstatus
  and x8, x8, x14
  csrc vsstatus, x14
  RVTEST_SIGUPD(x2, x5, x4, x8, W120Ssdbltrp_vsstatus_sdt_dte0, W120Ssdbltrp_vsstatus_sdt_dte0_str)

  csrc ENVCFG_HI(menvcfg), x13

RVTEST_CODE_END

RVTEST_DATA_BEGIN
W120Ssdbltrp_henvcfg_dte_str:        .string "\"test: 1; cg: W120Ssdbltrp; cp: vsstatus; bin: henvcfg_dte\""
W120Ssdbltrp_vsstatus_sdt_dte1_str:  .string "\"test: 2; cg: W120Ssdbltrp; cp: vsstatus; bin: sdt_dte1\""
W120Ssdbltrp_vsstatus_sdt_dte0_str:  .string "\"test: 3; cg: W120Ssdbltrp; cp: vsstatus; bin: sdt_dte0\""
RVTEST_DATA_END

RVTEST_SIG_SETUP
