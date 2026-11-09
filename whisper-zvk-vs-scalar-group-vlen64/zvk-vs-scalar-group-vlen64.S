// VLEN = 64: the scalar element group (vs2) of a vector crypto .vs instruction is a 2-register group
// (zvk.adoc: EMUL = ceil(EGW / VLEN)), so naming it with an odd register is a reserved encoding (and v7 also
// overlaps the vd group v8-v9). On a hart with Ssstrict it must raise an illegal-instruction exception.
// Whisper master fa18e475 with "bytes_per_vec": 8 crashes (SIGSEGV) on the first such instruction.
// The test does nothing (and passes) when VLEN != 64.
// Built with the riscv-arch-test framework (tests_ai, sa.h self-checks); M-mode, RV64.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'V', 'Zvkned', 'Zvksed']
# MARCH: rv${XLEN}gcv_zvkned_zvksed_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  li x7, 0x600
  csrs mstatus, x7              // mstatus.VS = Dirty
  csrr x9, vlenb
  li x8, 8
  bne x9, x8, 1f                // only meaningful at VLEN = 64
  li x8, 4
  vsetvli x7, x8, e32, m2, tu, mu   // LMUL*VLEN = 128 = EGW: one element group in v8-v9
  SA_CHECK(x7, 4, "setup: vl = 4 at e32 m2")

  SA_TRY(1)
  vaesz.vs v8, v6               // scalar group v6-v7: legal
  SA_TRAPS(0, -1, "vaesz.vs v8, v6 at VLEN=64 (aligned scalar group, control) executes")
  SA_TRY(1)
  vaesdf.vs v8, v7              // scalar group v7-v8: odd register, overlaps vd
  SA_TRAPS(1, 2, "vaesdf.vs v8, v7 at VLEN=64 (scalar group named by an odd register) raises illegal-instruction")
  SA_TRY(1)
  vaesz.vs v8, v5               // scalar group v5-v6: odd register
  SA_TRAPS(1, 2, "vaesz.vs v8, v5 at VLEN=64 (scalar group named by an odd register) raises illegal-instruction")
  SA_TRY(1)
  vsm4r.vs v8, v3               // scalar group v3-v4: odd register
  SA_TRAPS(1, 2, "vsm4r.vs v8, v3 at VLEN=64 (scalar group named by an odd register) raises illegal-instruction")
1:
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
