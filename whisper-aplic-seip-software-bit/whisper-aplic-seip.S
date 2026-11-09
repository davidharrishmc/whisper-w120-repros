// mip.SEIP reads as the logical OR of the software-writable bit (B) and the supervisor external interrupt signal
// from the interrupt controller (E). Software writes of mip change only B.
//   machine.adoc norm:intr_sei_op "Supervisor-level external interrupts are made pending based on the logical-OR
//     of the software-writable seip bit and the signal from the external interrupt controller."
//   norm:mip_seip_wrcsr "the signal from the interrupt controller is not used to calculate the value written to
//     seip". NOTE: "If csrrw t0,mip,t1 is executed, then t0[9] is written with B || E, and B is simply written
//     with t1[9]. In neither case does B depend upon E."
// E is driven with RVMODEL_SET_SEXT_INT / RVMODEL_CLR_SEXT_INT (on Whisper: APLIC supervisor domain, source 2,
// direct delivery). Checks (M-mode, all interrupts disabled):
//   1. B=0, E=1:                         SEIP = 1
//   2. csrw mip, x0 with E=1:            SEIP = 1 (B=0, E still 1)
//   3. csrrc mip, SEIP with E=1, B=1:    SEIP = 1
//   4. S-level IMSIC file access (eidelivery rewritten with its value 0x40000000) with E=1: SEIP = 1
//   5. csrrs mip, SEIP (B=1), then E=0:  SEIP = 1 (B)
//   6. csrrc mip, SEIP (B=0), E=0:       SEIP = 0
// Without RVMODEL_SET_SEXT_INT (no way to drive E) the test checks nothing.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define READ_SEIP(_R) csrr _R, mip ; srli _R, _R, 9 ; andi _R, _R, 1

RVTEST_BEGIN
  csrci mstatus, 0xa           // MIE = SIE = 0
  csrw mie, x0
  li x6, 0x200
  csrc mip, x6                 // B = 0
#if defined(RVMODEL_SET_SEXT_INT)
  RVMODEL_SET_SEXT_INT(x10, x11)   // E = 1
  li x15, 2000
1: READ_SEIP(x7)
  bnez x7, 2f
  addi x15, x15, -1
  bnez x15, 1b
2:
  SA_SOFT(x7, 1, "1: B=0, E=1: mip.SEIP")
  csrw mip, x0                 // B = 0; E stays 1
  READ_SEIP(x7)
  SA_SOFT(x7, 1, "2: after csrw mip, x0 with E=1: mip.SEIP")
  csrs mip, x6                 // B = 1
  csrc mip, x6                 // B = 0; E stays 1
  READ_SEIP(x7)
  SA_SOFT(x7, 1, "3: after csrs/csrc mip.SEIP with E=1: mip.SEIP")
#if defined(IMSIC_S_FILE)
  li x8, 0x70                  // eidelivery of the S-level IMSIC file
  csrw siselect, x8
  csrr x8, sireg
  csrw sireg, x8               // same value
  READ_SEIP(x7)
  SA_SOFT(x7, 1, "4: after an S-level IMSIC file access with E=1: mip.SEIP")
#endif
  csrs mip, x6                 // B = 1
  RVMODEL_CLR_SEXT_INT(x10, x11)   // E = 0
  li x15, 200
1: addi x15, x15, -1
  bnez x15, 1b
  READ_SEIP(x7)
  SA_SOFT(x7, 1, "5: B=1 set by csrs, then E=0: mip.SEIP")
  csrc mip, x6                 // B = 0
  READ_SEIP(x7)
  SA_SOFT(x7, 0, "6: B=0, E=0: mip.SEIP")
#endif
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
