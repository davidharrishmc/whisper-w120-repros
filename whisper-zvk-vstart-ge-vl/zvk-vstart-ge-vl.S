// Vector crypto element-group instructions with vstart = vl (a multiple of EGS, below VLMAX).
// Each must either raise an illegal-instruction exception and leave vstart unchanged, or complete without
// updating any element and reset vstart to 0 (vector-common.adoc: "reset the vstart CSR to zero at the end of
// execution"). Whisper master fa18e475 with "trap_non_zero_vstart": false completes them and leaves vstart = 8.
// e32, LMUL = 4, vl = 8, vstart = 8: legal for every VLEN >= 128 (VLMAX >= 16) and both EGS = 4 and EGS = 8.
// Built with the riscv-arch-test framework (tests_ai, sa.h self-checks); M-mode, RV64.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'V', 'Zvkned', 'Zvkg', 'Zvknha', 'Zvksed', 'Zvksh']
# MARCH: rv${XLEN}gcv_zvkned_zvkg_zvknha_zvksed_zvksh_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// Run one instruction (the variadic arguments) with vstart = 8 = vl and check the outcome.
#define VSTART_CASE(_MSG, ...)                              \
  li x7, 8                                                 ;\
  csrw vstart, x7                                          ;\
  SA_TRY(1)                                                ;\
  __VA_ARGS__                                              ;\
  AI_OUTCOME                                               ;\
  csrr x9, vstart                                          ;\
  csrw vstart, x0                                          ;\
  beqz x13, 1f                                             ;\
  SA_CHECK(x14, 2, _MSG ": a trap must be illegal-instruction") ;\
  SA_CHECK(x9, 8, _MSG ": illegal-instruction leaves vstart unchanged") ;\
  j 2f                                                     ;\
1:                                                         ;\
  SA_CHECK(x9, 0, _MSG ": executed, so vstart must be reset to 0") ;\
2:

RVTEST_BEGIN
  li x7, 0x600
  csrs mstatus, x7              // mstatus.VS = Dirty
  li x8, 8
  vsetvli x7, x8, e32, m4, tu, mu
  SA_CHECK(x7, 8, "setup: vl = 8 at e32 m4")

  VSTART_CASE("vaesef.vv (Zvkned) vstart=vl=8", vaesef.vv v8, v16)
  VSTART_CASE("vaesz.vs (Zvkned) vstart=vl=8", vaesz.vs v8, v16)
  VSTART_CASE("vaeskf1.vi (Zvkned) vstart=vl=8", vaeskf1.vi v8, v16, 1)
  VSTART_CASE("vghsh.vv (Zvkg) vstart=vl=8", vghsh.vv v8, v16, v24)
  VSTART_CASE("vsha2ms.vv (Zvknha) vstart=vl=8", vsha2ms.vv v8, v16, v24)
  VSTART_CASE("vsm4r.vv (Zvksed) vstart=vl=8", vsm4r.vv v8, v16)
  VSTART_CASE("vsm3me.vv (Zvksh) vstart=vl=8", vsm3me.vv v8, v16, v24)
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
