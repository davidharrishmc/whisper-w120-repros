// verify v15a, u31-aia-b-T-02 (Whisper): an ithreshold write changes the APLIC's interrupt signal to the hart.
// Spec: AIA AdvPLIC.adoc:1102-1111 (ithreshold: "When ithreshold is a nonzero value P, interrupt sources with
//   priority numbers P and higher do not contribute to signaling interrupts to the hart, as though those sources were
//   not enabled"); :1113-1120 (topi); :1165-1170 "When domaincfg.IE = 1 and interrupt delivery is enabled
//   (idelivery = 1), the interrupt signal is asserted whenever either register iforce or topi is not zero" (so it is
//   de-asserted when both are zero); :1154-1157 the M-level signal is mip.MEIP; :1161-1162 "Each interrupt signal may
//   be arbitrarily delayed": every check is repeated after a 2000-iteration delay loop.
// Whisper boot state (rvmodel_macros.h): M domain direct mode, IE = 1, source 1 Edge1 -> hart 0, IE[1] = 1,
//   idelivery 1, ithreshold 0, iforce 0. Only source 1 targets the M-level IDC.
// A (mask): source 1 IPRIO 3 pending (MEIP = 1); ithreshold := 3: topi = 0, MEIP must become 0.
// B (unmask): ithreshold := 1, then source 1 pending: topi = 0, MEIP = 0; ithreshold := 0: topi = 0x10003, MEIP must
//   become 1 (otherwise the interrupt is lost).
// Source: tests/u31-aia-b/u31-aia-b-idc.S (u31-aia-b-0117 0127).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Zicsr']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define MB 0x0C000000
#define WR(_A, _V) LI(x6, _A); LI(x7, _V); sw x7, 0(x6)
#define RD(_R, _A) LI(x6, _A); lw _R, 0(x6)
#define MEIP(_R) csrr _R, mip; srli _R, _R, 11; andi _R, _R, 1
#define DELAY li x9, 2000; 1: addi x9, x9, -1; bnez x9, 1b

RVTEST_BEGIN
#ifdef ADDR_SETIPNUM
  csrci mstatus, 8
  csrw mie, x0
  // ---- A: mask a pending source with ithreshold
  WR(ADDR_CLRIPNUM, 1)
  WR(ADDR_TARGET1, 3)                // hart 0, IPRIO 3
  WR(ADDR_SETIPNUM, 1)
  MEIP(x8)
  SA_SOFT(x8, 1, "T02A control: source 1 (IPRIO 3) pending: MEIP = 1")
  WR(ADDR_ITHRESH0, 3)
  RD(x8, MB+0x4018)
  SA_SOFT(x8, 0, "T02A control: ithreshold = 3: topi = 0")
  MEIP(x8)
  SA_SOFT(x8, 0, "T02A: ithreshold = 3 masks the only pending source: MEIP = 0 (AdvPLIC.adoc:1108-1111, :1165-1170)")
  DELAY
  MEIP(x8)
  SA_SOFT(x8, 0, "T02A: ... still MEIP = 1 after a 2000-iteration delay loop")
  // ---- B: unmask a pending source with ithreshold
  WR(ADDR_CLRIPNUM, 1)
  WR(ADDR_ITHRESH0, 1)
  WR(ADDR_SETIPNUM, 1)
  RD(x8, MB+0x4018)
  SA_SOFT(x8, 0, "T02B control: ithreshold = 1, source 1 pending: topi = 0")
  MEIP(x8)
  SA_SOFT(x8, 0, "T02B control: ithreshold = 1, source 1 pending: MEIP = 0")
  WR(ADDR_ITHRESH0, 0)
  RD(x8, MB+0x4018)
  SA_SOFT(x8, 0x10003, "T02B control: ithreshold = 0: topi = source 1, IPRIO 3")
  MEIP(x8)
  SA_SOFT(x8, 1, "T02B: ithreshold := 0 unmasks pending source 1: MEIP = 1 (AdvPLIC.adoc:1165-1170)")
  DELAY
  MEIP(x8)
  SA_SOFT(x8, 1, "T02B: ... MEIP = 1 after a 2000-iteration delay loop (else the interrupt is lost)")
  // restore the boot state
  WR(ADDR_CLRIPNUM, 1)
  WR(ADDR_ITHRESH0, 0)
  WR(ADDR_TARGET1, 1)
#endif
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
