// verify v5 repro u04-atomics-whisper-01 (a): RV64 amocas.q / RV32 amocas.d with a store-ADDRESS trigger on the
// upper half. The pair CAS is one atomic access (zacas.adoc "atomically loads ... stores the 128-bit value",
// rvwmo.adoc:69-74 single-copy atomic, single memory operation), so the only legal outcomes are
// {no trap, both halves written} or {breakpoint, memory unchanged}; never a half-written pair or an abort.
// u04-atomics Whisper walk probe: amocas.q (RV64) / amocas.d (RV32) are written as two stores, each of
// which evaluates store triggers again. A trigger that matches only the second half fires after the first
// half has been written (partial update; amocas.q also asserts ok0 == ok1).
// Legal outcomes for each case: {no trap, both halves written} or {breakpoint, memory unchanged}.
##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Sdtrig', 'Zacas']
# MARCH: rv${XLEN}ia_zacas_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

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
#define ST_     2
#define M_      (1 << 6)
#define SEL     (1 << 21)
#define SIZE(n) ((n) << 16)

#define ARM_R(_R2, _T1)                                     \
    csrw tselect, x0                                       ;\
    csrw tdata1, x0                                        ;\
    csrw tdata2, _R2                                       ;\
    LI(x9, _T1)                                            ;\
    csrw tdata1, x9                                        ;\
    csrr x8, tdata1
#define DISARM  csrw tselect, x0; csrw tdata1, x0

#if XL == 64
#define OLD0 0x1111111111111111
#define OLD1 0x2222222222222222
#define NEW0 0xAAAAAAAAAAAAAAAA
#define NEW1 0xBBBBBBBBBBBBBBBB
#define W    8
#define CAS  amocas.q x16, x18, (x20)
#else
#define OLD0 0x11111111
#define OLD1 0x22222222
#define NEW0 0xAAAAAAAA
#define NEW1 0xBBBBBBBB
#define W    4
#define CAS  amocas.d x16, x18, (x20)
#endif

// set memory {OLD0, OLD1}, rd pair = {OLD0, OLD1} (compare succeeds), rs2 pair = {NEW0, NEW1}
#define SETUP                                               \
    LA(x20, sa_q)                                          ;\
    LI(x16, OLD0)                                          ;\
    LI(x17, OLD1)                                          ;\
    SREG x16, 0(x20)                                       ;\
    SREG x17, W(x20)                                       ;\
    LI(x18, NEW0)                                          ;\
    LI(x19, NEW1)
// x6 = (mem lo == NEW0) xor (mem hi == NEW1): 1 means partial update
#define PARTIAL                                             \
    LA(x20, sa_q)                                          ;\
    LREG x6, 0(x20)                                        ;\
    LI(x9, NEW0)                                           ;\
    xor  x6, x6, x9                                        ;\
    seqz x6, x6                                            ;\
    LREG x7, W(x20)                                        ;\
    LI(x9, NEW1)                                           ;\
    xor  x7, x7, x9                                        ;\
    seqz x7, x7                                            ;\
    xor  x6, x6, x7

#define RUN                                                 \
    SA_TRY(2)                                              ;\
    csrsi mstatus, 8                                       ;\
    CAS                                                    ;\
    csrci mstatus, 8                                       ;\
    AI_OUTCOME                                             ;\
    DISARM

RVTEST_BEGIN
  .option norvc
  csrci mstatus, 8
  csrw mie, x0
  csrw mip, x0

  // ---- control: no trigger, compare succeeds -> both halves written
  SETUP
  RUN
  SA_SOFT(x13, 0, "C control: number of traps")
  PARTIAL
  SA_SOFT(x6, 0, "C control: partial update")
  SA_SOFT(x7, 1, "C control: high half written")

  // ---- A0: store-address trigger, size = 0 (any), tdata2 = A+W (a non-lowest compare value: matching is optional)
  SETUP
  addi x7, x20, W
  ARM_R(x7, MC6 | M_ | ST_)
  SA_INFO(x8, "A0 tdata1 read back")
  RUN
  SA_INFO(x13, "A0 number of traps")
  PARTIAL
  SA_SOFT(x6, 0, "A0 size=0 store-address trigger at A+W: partial update (1 = only one half written)")

  // ---- A: store-address trigger, size = one half (RV64 size 5, RV32 size 3), tdata2 = A+W
  SETUP
  addi x7, x20, W
#if XL == 64
  ARM_R(x7, MC6 | M_ | ST_ | SIZE(5))
#else
  ARM_R(x7, MC6 | M_ | ST_ | SIZE(3))
#endif
  SA_INFO(x8, "A tdata1 read back")
  RUN
  SA_INFO(x13, "A number of traps")
  PARTIAL
  SA_SOFT(x6, 0, "A size=half store-address trigger at A+W: partial update (1 = only one half written)")

  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
.align 4
sa_q: .dword 0, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
