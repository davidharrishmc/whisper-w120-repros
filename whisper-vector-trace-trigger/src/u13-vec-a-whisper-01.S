// verify v5: action=2 (trace) load-address trigger on vector SEGMENT loads (vlseg2e32.v, vlseg2e32ff.v, vluxseg2ei32.v)
// must not change execution (Sdtrig.adoc:147-149); extra sites of u33-debug-b-whisper-02 (vector-ls.cpp:2030, :2666).
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Sdtrig', 'V']
# MARCH: rv${XLEN}iv_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"
// ------------------------------------------------------------------ common u33 helpers
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
// soft check against two legal values
#define SA_SOFT2(_R, _E1, _E2, _MSG)                        \
    LI(x4, _E1)                                            ;\
    beq  x4, _R, 99f                                       ;\
    SA_SOFT(_R, _E2, _MSG)                                 ;\
99:
#define XL      __riscv_xlen
#define TT(n)   ((n) << (XL - 4))
#define MC6     TT(6)
#define ICNT    TT(3)
#define ITRG    TT(4)
#define ETRG    TT(5)
#define LD_     1
#define ST_     2
#define EX_     4
#define U_      (1 << 3)
#define S_      (1 << 4)
#define M_      (1 << 6)
#define VU_     (1 << 23)
#define VS_     (1 << 24)
#define SEL     (1 << 21)
#define SIZE(n) ((n) << 16)
#define ACT(n)  ((n) << 12)
#define MATCH(n) ((n) << 7)
#define CHAIN   (1 << 11)
// icount
#define IC(c)   (ICNT | ((c) << 10))
#define IC_M    (1 << 9)
#define IC_S    (1 << 7)
#define IC_U    (1 << 6)
#define IC_PEND (1 << 8)
#define IC_HIT  (1 << 24)
// itrigger/etrigger
#define IE_M    (1 << 9)
#define IE_S    (1 << 7)
#define IE_U    (1 << 6)
#define IE_HIT  (1 << (XL - 6))

// select trigger _I, disable, tdata2 = register _R2, tdata1 = constant _T1; x8 = tdata1 read back, x9 = tdata1 written
#define ARM_R(_I, _R2, _T1)                                 \
    li   x9, _I                                            ;\
    csrw tselect, x9                                       ;\
    csrw tdata1, x0                                        ;\
    csrw tdata2, _R2                                       ;\
    LI(x9, _T1)                                            ;\
    csrw tdata1, x9                                        ;\
    csrr x8, tdata1
#define ARM_L(_I, _LBL, _T1)  LA(x7, _LBL); ARM_R(_I, x7, _T1)
#define ARM_C(_I, _V, _T1)    LI(x7, _V); ARM_R(_I, x7, _T1)
#define DISARM_ALL                                          \
    li x9, 3                                               ;\
1:  csrw tselect, x9                                       ;\
    csrw tdata1, x0                                        ;\
    addi x9, x9, -1                                        ;\
    bgez x9, 1b                                            ;\
    csrw tselect, x0
// x7 = mcontrol6 {hit1,hit0} of trigger _I
#define GET_HIT6(_I)                                        \
    li   x9, _I                                            ;\
    csrw tselect, x9                                       ;\
    csrr x7, tdata1                                        ;\
    srli x9, x7, 24                                        ;\
    andi x9, x9, 2                                         ;\
    srli x7, x7, 22                                        ;\
    andi x7, x7, 1                                         ;\
    or   x7, x7, x9
// skip to _L (with an INFO line) unless the configuration read back exactly (x8 == x9)
#define NEED_RET(_L, _MSG)                                  \
    beq  x8, x9, 77f                                       ;\
    SA_INFO(x8, "not retained, case skipped: " _MSG)       ;\
    j    _L                                                ;\
77:
// x7 = last logged mepc - label, x6 = last logged mtval
#define EPC_REL(_LBL)                                       \
    AI_LOG(x7, TRAPLOG_EPC)                                ;\
    LA(x6, _LBL)                                           ;\
    sub  x7, x7, x6                                        ;\
    AI_LOG(x6, TRAPLOG_TVAL)
// x6 = 0 if x6 (a tval) is 0 or equals label _LBL (+_OFF); else x6 - addr
#define TVAL_0_OR(_LBL, _OFF)                               \
    beqz x6, 78f                                           ;\
    LA(x9, _LBL)                                           ;\
    addi x9, x9, _OFF                                      ;\
    sub  x6, x6, x9                                        ;\
78:
// set tcontrol.mte = 1 when tcontrol exists (probe in a trap window)
#define MTE_ON                                              \
    SA_TRY(1)                                              ;\
    csrsi 0x7a5, 8                                         ;\
    AI_OUTCOME
// ------------------------------------------------------------------

RVTEST_BEGIN
  .option norvc
  csrci mstatus, 8
  csrw mie, x0
  csrw mip, x0
  DISARM_ALL
  MTE_ON
  li x9, (1 << 9)                // mstatus.VS = Initial
  csrs mstatus, x9

  // ============ A: vlseg2e32.v (vectorLoadSeg), action=2 load trigger on segment 2 field 0
  LA(x6, vsrc)
  addi x7, x6, 16
  ARM_R(0, x7, MC6 | M_ | LD_ | ACT(2))
  NEED_RET(a_end, "A mcontrol6 load action=2")
  vsetivli x0, 4, e32, m1, tu, mu
  vmv.v.i v2, 0
  vmv.v.i v3, 0
  csrw vstart, x0
  LA(x6, vsrc)
  SA_TRY(2)
a_i: vlseg2e32.v v2, (x6)
  nop
  AI_OUTCOME
  SA_SOFT(x13, 0, "A vlseg2e32.v: action=2 trigger takes no trap")
  csrr x7, vstart
  SA_SOFT(x7, 0, "A vlseg2e32.v completed: vstart = 0")
  csrw vstart, x0
  LA(x6, vdst)
  vse32.v v2, (x6)
  lw x7, 8(x6)
  SA_SOFT(x7, 0x55, "A segment 2 field 0 loaded (v2[2])")
  lw x7, 12(x6)
  SA_SOFT(x7, 0x77, "A segment 3 field 0 loaded (v2[3])")
  vse32.v v3, (x6)
  lw x7, 8(x6)
  SA_SOFT(x7, 0x66, "A segment 2 field 1 loaded (v3[2])")
a_end:
  DISARM_ALL

  // ============ B: vlseg2e32ff.v (vectorLoadSeg, faultFirst), same trigger
  LA(x6, vsrc)
  addi x7, x6, 16
  ARM_R(0, x7, MC6 | M_ | LD_ | ACT(2))
  NEED_RET(b_end, "B mcontrol6 load action=2")
  vsetivli x0, 4, e32, m1, tu, mu
  vmv.v.i v2, 0
  vmv.v.i v3, 0
  csrw vstart, x0
  LA(x6, vsrc)
  SA_TRY(2)
b_i: vlseg2e32ff.v v2, (x6)
  nop
  AI_OUTCOME
  SA_SOFT(x13, 0, "B vlseg2e32ff.v: action=2 trigger takes no trap")
  csrr x7, vstart
  SA_SOFT(x7, 0, "B vlseg2e32ff.v: vstart = 0")
  csrr x7, vl
  li x9, 4
  beq x7, x9, 1f
  SA_INFO(x7, "B vlseg2e32ff.v trimmed vl without a fault (legal, vector-common ff rule); segment check skipped")
  j b_end
1:
  csrw vstart, x0
  LA(x6, vdst)
  vse32.v v2, (x6)
  lw x7, 12(x6)
  SA_SOFT(x7, 0x77, "B segment 3 field 0 loaded")
b_end:
  DISARM_ALL

  // ============ C: vluxseg2ei32.v (vectorLoadSegIndexed), same trigger
  LA(x6, vidx)
  vsetivli x0, 4, e32, m1, tu, mu
  vle32.v v8, (x6)
  LA(x6, vsrc)
  addi x7, x6, 16
  ARM_R(0, x7, MC6 | M_ | LD_ | ACT(2))
  NEED_RET(c_end, "C mcontrol6 load action=2")
  vmv.v.i v2, 0
  vmv.v.i v3, 0
  csrw vstart, x0
  LA(x6, vsrc)
  SA_TRY(2)
c_i: vluxseg2ei32.v v2, (x6), v8
  nop
  AI_OUTCOME
  SA_SOFT(x13, 0, "C vluxseg2ei32.v: action=2 trigger takes no trap")
  csrr x7, vstart
  SA_SOFT(x7, 0, "C vluxseg2ei32.v completed: vstart = 0")
  csrw vstart, x0
  LA(x6, vdst)
  vse32.v v2, (x6)
  lw x7, 12(x6)
  SA_SOFT(x7, 0x77, "C segment 3 field 0 loaded")
c_end:
  DISARM_ALL
  csrw vstart, x0
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.align 4
vsrc: .word 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88
vidx: .word 0, 8, 16, 24
vdst: .word 0, 0, 0, 0

sa_data: .dword 0
sa_data2: .dword 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
