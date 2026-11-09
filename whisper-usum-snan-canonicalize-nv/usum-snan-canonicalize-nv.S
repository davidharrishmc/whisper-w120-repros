// vfredusum.vs and vfwredusum.vs with no active element and a signaling-NaN scalar (vs1[0]).
// Legal outcomes (vector-common.adoc, vfredusum: a masked-off input is either the additive identity, so the sNaN
// goes through an addition, or the other input is copied): the scalar copied unchanged with fflags = 0, or the
// canonical NaN with fflags.NV set. Whisper master fa18e475 with "fp_usum_nan_canonicalize" enabled and
// "tt_fp_usum_tree_reduction" disabled returns the canonical NaN with fflags = 0.
// Built with the riscv-arch-test framework (tests_ai, sa.h self-checks); M-mode, RV64.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'V', 'D']
# MARCH: rv${XLEN}gcv_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

// ok (x7) = 1 if (x8 == SNAN and x9 == 0) or (x8 == QNAN and x9 has NV); clobbers x10, x11
#define USUM_CHECK(_SNAN, _QNAN, _MSG)                      \
  li x7, 0                                                 ;\
  LI(x10, _SNAN)                                           ;\
  bne x8, x10, 1f                                          ;\
  bnez x9, 1f                                              ;\
  li x7, 1                                                 ;\
1:                                                         ;\
  LI(x10, _QNAN)                                           ;\
  bne x8, x10, 2f                                          ;\
  andi x11, x9, 0x10                                       ;\
  beqz x11, 2f                                             ;\
  li x7, 1                                                 ;\
2:                                                         ;\
  SA_CHECK(x7, 1, _MSG)

RVTEST_BEGIN
  li x7, 0x6600
  csrs mstatus, x7              // FS = VS = Dirty

  // 1. vfredusum.vs, SEW = 32
  vsetivli x0, 4, e32, m1, tu, mu
  vmv.v.i v0, 0                 // no active element
  vmv.v.i v16, 0                // vs2 elements (all masked off)
  LI(x7, 0x7fa00000)            // binary32 signaling NaN
  vmv.s.x v24, x7               // vs1[0]
  csrwi fflags, 0
  vfredusum.vs v8, v16, v24, v0.t
  csrr x9, fflags
  vmv.x.s x8, v8
  slli x8, x8, 32
  srli x8, x8, 32
  USUM_CHECK(0x7fa00000, 0x7fc00000, "vfredusum.vs e32, no active element, sNaN scalar: 0x7fa00000 with no flags, or 0x7fc00000 with NV")

  // 2. vfredusum.vs, SEW = 64
  vsetivli x0, 2, e64, m1, tu, mu
  vmv.v.i v16, 0
  LI(x7, 0x7ff4000000000000)    // binary64 signaling NaN
  vmv.s.x v24, x7
  csrwi fflags, 0
  vfredusum.vs v8, v16, v24, v0.t
  csrr x9, fflags
  vmv.x.s x8, v8
  USUM_CHECK(0x7ff4000000000000, 0x7ff8000000000000, "vfredusum.vs e64, no active element, sNaN scalar: 0x7ff4000000000000 with no flags, or 0x7ff8000000000000 with NV")

  // 3. vfwredusum.vs, SEW = 32 (2*SEW = 64 scalar)
  vsetivli x0, 2, e64, m1, tu, mu
  LI(x7, 0x7ff4000000000000)
  vmv.s.x v24, x7               // vs1[0] (2*SEW wide)
  vsetivli x0, 4, e32, m1, tu, mu
  vmv.v.i v16, 0
  csrwi fflags, 0
  vfwredusum.vs v8, v16, v24, v0.t
  csrr x9, fflags
  vsetivli x0, 2, e64, m1, tu, mu
  vmv.x.s x8, v8
  USUM_CHECK(0x7ff4000000000000, 0x7ff8000000000000, "vfwredusum.vs e32, no active element, sNaN scalar: 0x7ff4000000000000 with no flags, or 0x7ff8000000000000 with NV")
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
