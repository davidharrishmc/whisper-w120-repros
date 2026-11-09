// vsm3me.vv with a vs1 register group that is not aligned to LMUL: a reserved encoding
// (vector-common.adoc: an LMUL=2 group named by an odd register, or an LMUL=4 group named by a register that is
// not a multiple of 4, is reserved; zvk.adoc: all V constraints apply to the vector crypto instructions).
// On a hart with Ssstrict it must raise an illegal-instruction exception, as Whisper does for a misaligned vd or
// vs2. Whisper master fa18e475 executes it.
// Built with the riscv-arch-test framework (tests_ai, sa.h self-checks); M-mode, RV64.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'V', 'Zvksh']
# MARCH: rv${XLEN}gcv_zvksh_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  li x7, 0x600
  csrs mstatus, x7              // mstatus.VS = Dirty

  // LMUL = 2
  li x8, 8
  vsetvli x7, x8, e32, m2, tu, mu
  SA_CHECK(x7, 8, "setup: vl = 8 at e32 m2")
  SA_TRY(1)
  vsm3me.vv v8, v16, v24
  SA_TRAPS(0, -1, "vsm3me.vv v8, v16, v24 at LMUL=2 (aligned control) executes")
  SA_TRY(1)
  .word 0x830ca477              // vsm3me.vv v8, v16, v25
  SA_TRAPS(1, 2, "vsm3me.vv v8, v16, v25 at LMUL=2 (vs1 not aligned) raises illegal-instruction")
  SA_TRY(1)
  .word 0x82dc2477              // vsm3me.vv v8, v13, v24
  SA_TRAPS(1, 2, "vsm3me.vv v8, v13, v24 at LMUL=2 (vs2 not aligned, control) raises illegal-instruction")

  // LMUL = 4
  vsetvli x7, x8, e32, m4, tu, mu
  SA_CHECK(x7, 8, "setup: vl = 8 at e32 m4")
  SA_TRY(1)
  vsm3me.vv v8, v16, v24
  SA_TRAPS(0, -1, "vsm3me.vv v8, v16, v24 at LMUL=4 (aligned control) executes")
  SA_TRY(1)
  .word 0x83012477              // vsm3me.vv v8, v16, v2
  SA_TRAPS(1, 2, "vsm3me.vv v8, v16, v2 at LMUL=4 (vs1 not aligned) raises illegal-instruction")
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
