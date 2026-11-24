// verify v1: an action=2 (trace) load-address trigger on a vector-load element must not change execution
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Sdtrig', 'V']
# MARCH: rv${XLEN}iv_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"
// INFO line: printed like a mismatch but not counted as a failure
#define SA_INFO(_R, _MSG)                                   \
    .option push                                           ;\
    .option norvc                                          ;\
    LA(x5, sa_soft_args)                                   ;\
    SREG x0, 0(x5)                                         ;\
    SREG _R, REGWIDTH(x5)                                  ;\
    LA(x4, 97f)                                            ;\
    SREG x4, 2*REGWIDTH(x5)                                ;\
    jal  x5, sa_soft_report                                ;\
    LA(x4, sa_soft_count)                                  ;\
    LREG x5, 0(x4)                                         ;\
    addi x5, x5, -1                                        ;\
    SREG x5, 0(x4)                                         ;\
    .pushsection .data                                     ;\
97: .string "INFO " _MSG                                   ;\
    .popsection                                            ;\
    .option pop
#define XL      __riscv_xlen
#define TT(n)   ((n) << (XL - 4))
#define MC6     TT(6)
#define LD_     1
#define EX_     4
#define M_      (1 << 6)
#define SIZE(n) ((n) << 16)
#define ACT(n)  ((n) << 12)
#define DISARM_ALL                                          \
    li x9, 3                                               ;\
1:  csrw tselect, x9                                       ;\
    csrw tdata1, x0                                        ;\
    addi x9, x9, -1                                        ;\
    bgez x9, 1b                                            ;\
    csrw tselect, x0

RVTEST_BEGIN
  .option norvc
  csrci mstatus, 8
  csrw mie, x0
  DISARM_ALL
  li x9, (1 << 9)                 // mstatus.VS = Initial
  csrs mstatus, x9
  // Trigger 0: mcontrol6 load address == &vsrc[2], m=1, action=2 (trace on); MIE stays 0.
  LA(x6, vsrc)
  addi x7, x6, 8
  li x9, 0
  csrw tselect, x9
  csrw tdata1, x0
  csrw tdata2, x7
  LI(x9, MC6 | M_ | LD_ | ACT(2))
  csrw tdata1, x9
  csrr x8, tdata1
  beq x8, x9, b_armed
  SA_INFO(x8, "02 mcontrol6 load action=2 not retained (WARL legalized): case skipped")
  j b_end
b_armed:
  // B2: vle32.v, element 2 matches the action=2 trigger
  vsetivli x0, 4, e32, m1, ta, ma
  vmv.v.i v1, 0
  LA(x6, vsrc)
  SA_TRY(2)
  vle32.v v1, (x6)
  nop
  AI_OUTCOME
  csrr x7, vstart
  SA_SOFT(x13, 0, "02 Sdtrig.adoc:147-149 action-2 triggers don't affect execution: vle32.v takes no trap")
  SA_SOFT(x7, 0, "02 Sdtrig.adoc:147-149 vle32.v completes: vstart = 0 afterwards")
  LA(x6, vdst)
  vse32.v v1, (x6)
  lw x7, 8(x6)
  SA_SOFT(x7, 0x33, "02 vle32.v element 2 (the matching one) loaded")
  lw x7, 12(x6)
  SA_SOFT(x7, 0x44, "02 vle32.v element 3 loaded")
  csrw vstart, x0
  // B1 control: scalar lw of the same address with the same trigger
  LA(x6, vsrc)
  SA_TRY(2)
  lw x11, 8(x6)
  nop
  AI_OUTCOME
  SA_SOFT(x13, 0, "02 control: scalar lw with the action=2 trigger takes no trap")
  SA_SOFT(x11, 0x33, "02 control: scalar lw loaded value")
  // hit0 of trigger 0 (informational: did the trigger fire at all?)
  csrw tselect, x0
  csrr x7, tdata1
  srli x7, x7, 22
  andi x7, x7, 1
  SA_INFO(x7, "02 trigger 0 hit0 after both loads")
b_end:
  DISARM_ALL
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.align 4
vsrc: .word 0x11, 0x22, 0x33, 0x44
vdst: .word 0, 0, 0, 0
sa_data: .dword 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
