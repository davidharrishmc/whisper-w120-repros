// verify v15a, u31-aia-b-T-03 (Whisper): iforce = 1 must not assert the interrupt while idelivery = 0.
// Spec: AIA AdvPLIC.adoc:1095-1097 "Setting iforce = 1 forces an interrupt to be asserted to the corresponding hart
//   whenever both the IE field of domaincfg is one and interrupt delivery is enabled to the hart by the idelivery
//   register."; :1165-1168 "If either domaincfg.IE = 0 or interrupt delivery to the hart is disabled by the idelivery
//   register (idelivery = 0), the interrupt signal is held de-asserted."; aia#139 (J. Hauser, 2025-09-28): iforce
//   raises the interrupt "assuming interrupt delivery is enabled both by idelivery and by domaincfg.IE".
// Whisper boot state: M domain direct mode, IE = 1, idelivery 1; nothing pending.
// Checks: idelivery := 0, iforce := 1: MEIP = 0 (also after a delay loop); controls: idelivery := 1 -> MEIP = 1,
//   iforce := 0 -> MEIP = 0.
// Source: tests/u31-aia-b/u31-aia-b-iforce.S (u31-aia-b-0114 0127).

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
  WR(ADDR_CLRIPNUM, 1)
  MEIP(x8)
  SA_SOFT(x8, 0, "T03 control: nothing pending: MEIP = 0")
  WR(ADDR_IDELIVERY0, 0)
  WR(MB+0x4004, 1)                   // iforce = 1
  RD(x8, MB+0x4004)
  SA_SOFT(x8, 1, "T03 control: iforce reads 1")
  MEIP(x8)
  SA_SOFT(x8, 0, "T03: idelivery = 0, iforce = 1: MEIP = 0 (AdvPLIC.adoc:1095-1097, :1165-1168)")
  DELAY
  MEIP(x8)
  SA_SOFT(x8, 0, "T03: ... MEIP = 0 after a delay loop")
  WR(ADDR_IDELIVERY0, 1)
  MEIP(x8)
  SA_SOFT(x8, 1, "T03 control: idelivery = 1, iforce = 1: MEIP = 1")
  WR(MB+0x4004, 0)
  MEIP(x8)
  SA_SOFT(x8, 0, "T03 control: iforce = 0: MEIP = 0")
#endif
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
