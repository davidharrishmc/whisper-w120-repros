// verify v15a, u31-aia-b-T-06 (Whisper): when the M-level IMSIC file's eidelivery returns to 0x40000000 while the APLIC
// M domain asserts its interrupt, mip.MEIP must again show the APLIC's signal.
// Spec: AIA IMSIC.adoc:441 "When eidelivery is 0x40000000, the interrupt file functions the same as though eidelivery
//   is 0, and the PLIC or APLIC replaces the interrupt file in supplying pending external interrupts at this
//   privilege level."; AdvPLIC.adoc:1150-1157 (direct mode: the APLIC supplies the external interrupt signals when
//   the IMSIC files' eidelivery = 0x40000000; machine level: mip.MEIP); :1165-1170 (asserted while topi != 0);
//   :1161-1162 "arbitrarily delayed": checked again after a delay loop.
// Whisper -max boot: M file eidelivery = 0x40000000; APLIC M domain direct, IE = 1, source 1 Edge1 -> hart 0,
//   IE[1] = 1, idelivery 1. The M file has nothing pending.
// Steps: setipnum 1 (MEIP = 1, control); mireg eidelivery := 1 (the file supplies MEIP; it is empty: INFO);
//   eidelivery := 0x40000000 (topi still 0x10001): MEIP must be 1.
// Source: tests/u31-aia-b/u31-aia-b-bypass.S (u31-aia-b-0124 0030).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Zicsr', 'Smaia']
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
#define SA_INFO(_R, _MSG) LI(x4, 0x5a5a5a5a); beq x4, _R, 96f; SA_SOFT(_R, 0x5a5a5a5a, "INFO " _MSG); LA(x4, sa_soft_count); LREG x5, 0(x4); addi x5, x5, -1; SREG x5, 0(x4); 96:

RVTEST_BEGIN
#if defined(ADDR_SETIPNUM) && defined(IMSIC_M_FILE)
  csrci mstatus, 8
  csrw mie, x0
  li x7, 0x70
  csrw 0x350, x7                     // miselect = eidelivery
  csrr x8, 0x351
  SA_SOFT(x8, 0x40000000, "T06 control: M file eidelivery = 0x40000000 (boot)")
  WR(ADDR_CLRIPNUM, 1)
  WR(ADDR_SETIPNUM, 1)
  RD(x8, MB+0x4018)
  SA_SOFT(x8, 0x10001, "T06 control: APLIC topi = source 1, IPRIO 1")
  MEIP(x8)
  SA_SOFT(x8, 1, "T06 control: eidelivery = 0x40000000, APLIC asserts: MEIP = 1")
  li x7, 1
  csrw 0x351, x7                     // eidelivery := 1 (the file supplies MEIP)
  MEIP(x8)
  SA_INFO(x8, "T06: eidelivery = 1, M file empty: MEIP (0 expected)")
  LI(x7, 0x40000000)
  csrw 0x351, x7                     // back to APLIC delivery
  csrr x8, 0x351
  SA_SOFT(x8, 0x40000000, "T06 control: eidelivery reads 0x40000000 again")
  RD(x8, MB+0x4018)
  SA_SOFT(x8, 0x10001, "T06 control: APLIC topi still 0x10001")
  MEIP(x8)
  SA_SOFT(x8, 1, "T06: eidelivery back to 0x40000000 with the APLIC asserting: MEIP = 1 (IMSIC.adoc:441)")
  DELAY
  MEIP(x8)
  SA_SOFT(x8, 1, "T06: ... MEIP = 1 after a delay loop")
  WR(ADDR_CLRIPNUM, 1)
  csrw 0x350, x0
#endif
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
