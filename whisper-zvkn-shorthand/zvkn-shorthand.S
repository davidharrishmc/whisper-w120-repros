// A hart whose isa string names the Zvkn shorthand instead of its members (Zvkned, Zvknhb, Zvkb, Zvkt;
// zvk.adoc, Zvkn) must execute the members' instructions. Whisper master fa18e475 with "zvkn" in its isa string
// (and no zvkned/zvknhb/zvkb/zvbb) raises an illegal-instruction exception for all of them.
// Built with the riscv-arch-test framework (tests_ai, sa.h self-checks); M-mode, RV64.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'V', 'Zvkned', 'Zvknhb', 'Zvkb']
# MARCH: rv${XLEN}gcv_zvkned_zvknhb_zvkb_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  li x7, 0x600
  csrs mstatus, x7              // mstatus.VS = Dirty
  vsetivli x7, 4, e32, m1, tu, mu
  SA_TRY(1)
  vaesef.vv v8, v16
  SA_TRAPS(0, -1, "vaesef.vv (Zvkned) executes")
  SA_TRY(1)
  vsha2ms.vv v8, v16, v24
  SA_TRAPS(0, -1, "vsha2ms.vv at SEW=32 (Zvknha, implied by Zvknhb) executes")
  SA_TRY(1)
  vandn.vv v8, v16, v24
  SA_TRAPS(0, -1, "vandn.vv (Zvkb) executes")
  vsetivli x7, 4, e64, m2, tu, mu
  SA_TRY(1)
  vsha2ms.vv v8, v16, v24
  SA_TRAPS(0, -1, "vsha2ms.vv at SEW=64 (Zvknhb) executes")
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
