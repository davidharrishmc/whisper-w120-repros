// verify v15a, u31-aia-b-T-04 (Whisper): an M-domain APLIC claim (MEIP 1 -> 0) while the S domain asserts its
// interrupt must not copy the APLIC's supervisor-level signal into the software-writable SEIP bit.
// Spec: ISA priv/machine.adoc:1436-1443 (norm:intr_sei_op) SEIP is the logical-OR of the software-writable bit and
//   the external interrupt controller's signal; (norm:mip_seip_wrcsr) "the signal from the interrupt controller is not
//   used to calculate the value written to seip"; NOTE :1447-1456 "In neither case does B depend upon E"; AIA
//   MSLevel.adoc:579-581 (mvien[9] = 0: mvip[9] is the software-writable SEIP bit). AdvPLIC.adoc:1138-1142 claimi.
// Order chosen to separate this trigger from verify v12 u30-aia-a-whisper-03 (M-domain *assertion* while S asserts):
//   M source 1 pending first (S idle), then S source 2 pending, then M claim, then S claim.
// Checks: mvip[9] (B) = 0 after each step; mip.SEIP = 0 after the S claim (software never wrote B).
// Source: tests/u31-aia-b/u31-aia-b-sei.S (u31-aia-b-0125).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'Zicsr', 'Smaia', 'Ssaia']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define MB 0x0C000000
#define SB 0x0D000000
#define WR(_A, _V) LI(x6, _A); LI(x7, _V); sw x7, 0(x6)
#define RD(_R, _A) LI(x6, _A); lw _R, 0(x6)
#define MIPB(_R, _B) csrr _R, mip; srli _R, _R, _B; andi _R, _R, 1
#define MVIP9(_R) csrr _R, 0x309; srli _R, _R, 9; andi _R, _R, 1

RVTEST_BEGIN
#if defined(ADDR_SETIPNUM) && defined(ADDR_S_SETIPNUM)
  csrci mstatus, 8
  csrw mie, x0
  csrw mideleg, x0
  csrw 0x308, x0                     // mvien = 0
  csrw 0x309, x0                     // mvip = 0: B = 0
  WR(ADDR_CLRIPNUM, 1)
  WR(ADDR_S_CLRIPNUM, 2)
  MIPB(x8, 9)
  SA_SOFT(x8, 0, "T04 control: start: mip.SEIP = 0")
  // 1. M domain asserts (S idle)
  WR(ADDR_SETIPNUM, 1)
  MIPB(x8, 11)
  SA_SOFT(x8, 1, "T04 control: M source 1 pending: MEIP = 1")
  MVIP9(x8)
  SA_SOFT(x8, 0, "T04: after the M assert (S idle): mvip[9] = 0")
  // 2. S domain asserts
  WR(ADDR_S_SETIPNUM, 2)
  MIPB(x8, 9)
  SA_SOFT(x8, 1, "T04 control: S source 2 pending: mip.SEIP = 1")
  MVIP9(x8)
  SA_SOFT(x8, 0, "T04: after the S assert: mvip[9] = 0 (whisper#284 on the pin)")
  // 3. M claim while S asserts
  RD(x8, MB+0x401C)
  SA_SOFT(x8, 0x10001, "T04 control: M claimi = 0x10001")
  MIPB(x8, 11)
  SA_SOFT(x8, 0, "T04 control: after the M claim: MEIP = 0")
  MVIP9(x8)
  SA_SOFT(x8, 0, "T04: after the M claim while S asserts: mvip[9] (software SEIP) = 0 (machine.adoc:1436-1456)")
  // 4. S claim: the S domain stops asserting
  RD(x8, SB+0x401C)
  SA_SOFT(x8, 0x20001, "T04 control: S claimi = 0x20001")
  MIPB(x8, 9)
  SA_SOFT(x8, 0, "T04: after the S claim: mip.SEIP = B|E = 0 (software never wrote B)")
  csrw 0x309, x0
  li x8, 0x200
  csrc mip, x8
#endif
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
