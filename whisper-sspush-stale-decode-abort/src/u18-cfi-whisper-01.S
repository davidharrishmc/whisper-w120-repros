// verify v5 repro (adopted from the u18 walk probe w18-ss-stale-decode.S, unchanged body).
// u18-cfi Whisper walk probe: an SS instruction whose decode-cache entry was filled in M-mode (xSSE=0, a MOP)
// and that then faults in S-mode (xSSE=1) on an H hart.
// Spec: priv/cfi.adoc:151-166 xSSE is that of the current privilege mode (M: 0, S: menvcfg.SSE), so the same
//   sspush x5 is a MOP in M and a shadow-stack push in S; priv/cfi.adoc:220-221 "shadow stack instructions ...
//   raise a store/AMO access-fault exception" when satp.MODE is Bare.
//   hypervisor.adoc (trap value of mtinst/htinst): for sspush there is no transformed form, so mtinst must be 0
//   (ledger u18-cfi-0235, rulings isa#1935/#2477).
// Whisper a5554a17: Hart.hpp:1029-1033 sets DecodedInst::shadowStack_ at decode time from the current mode; the
//   decode cache (Hart.cpp:6474-6478) is not invalidated on a privilege change; createTrapInst (Hart.cpp:3616)
//   tests di->isSspush(), which reads the stale flag, and falls into assert(false) at Hart.cpp:3640.
// Expected: control (sub executed only in S): cause 7, mtinst 0. Stale case (same sub first run in M as a MOP,
//   then in S): cause 7, mtinst 0, ssp unchanged.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'U', 'Zicfiss', 'Zimop']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define SSE_B 0x8
#define SSPUSH_X5 .word 0xCE504073
#if __riscv_xlen == 64
  #define MPV_B (1 << 39)
  #define MPV_CLR LI(x9, MPV_B); csrc mstatus, x9
#else
  #define MPV_CLR LI(x9, (1 << 7)); csrc 0x310, x9
#endif
#define SETPP(_PP) LI(x9, 0x1800); csrc mstatus, x9; LI(x9, (_PP) << 11); csrs mstatus, x9
#define RUN_S(_N, ...) SETPP(1); MPV_CLR; LA(x9, 71f); csrw mepc, x9; AI_ALLOW(_N); \
  mret; 71: __VA_ARGS__; RVTEST_TSBI_GOTO_MMODE; AI_OUTCOME
#define CAUSE(_C, _MSG) SA_SOFT(x14, _C, _MSG ": xcause (-1 none)")
#define TINST(_V, _MSG) AI_LOG(x15, TRAPLOG_TINST); SA_SOFT(x15, _V, _MSG ": mtinst")

RVTEST_BEGIN
  .option norvc
  csrw medeleg, x0
  csrw satp, x0
  LI(x6, SSE_B)
  csrs menvcfg, x6
  LA(x6, ssbuf_top)
  csrw ssp, x6
  li x5, 0x55

  // 1. control: sub_a is executed only in S-mode.
  RUN_S(1, jal x1, sub_a)
  CAUSE(7, "control S sspush satp Bare")
  TINST(0, "control S sspush satp Bare")
  csrr x7, ssp
  LA(x6, ssbuf_top)
  sub x7, x7, x6
  SA_SOFT(x7, 0, "control: ssp unchanged")

  // 2. stale case: sub_b is executed first in M-mode (sspush is a MOP there), then in S-mode.
  li x8, 0
  jal x1, sub_b
  csrr x7, ssp
  LA(x6, ssbuf_top)
  sub x7, x7, x6
  SA_SOFT(x7, 0, "M: sspush is a MOP, ssp unchanged")
  RUN_S(1, jal x1, sub_b)
  CAUSE(7, "stale-decode S sspush satp Bare")
  TINST(0, "stale-decode S sspush satp Bare")
  csrr x7, ssp
  LA(x6, ssbuf_top)
  sub x7, x7, x6
  SA_SOFT(x7, 0, "stale-decode: ssp unchanged")
  SA_SOFT_END
  j done

  .p2align 2
sub_a:
  SSPUSH_X5
  jalr x0, 0(x1)
sub_b:
  SSPUSH_X5
  jalr x0, 0(x1)
done:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 4
ssbuf: .fill 64, 1, 0
ssbuf_top: .fill 64, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
