// Reproducer: tdata1.action does not accept the external-trigger actions 8 and 9 on a configuration that
// enables them ("external0", "external1" in the Whisper trigger_actions list, or Whisper's default list).
// Spec: riscv-debug-spec Sdtrig.adoc tab:action: 8-9 "Send a signal to TM external trigger output 0 or 1
//   (respectively)" (norm:Sdtrig_action8_9); norm:Sdtrig_tdata_warl.
// Whisper: Triggers.hpp `enum class TriggerAction { ..., EmitTrace, Reserved, External0, External1, ... }`
//   gives External0 = 6 and External1 = 7, so actions 8 and 9 are never supported.
// This test applies only to a hart that supports the external-trigger actions (here: the configuration).
// Check: mcontrol6 and icount written with action 8 and 9 read back 8 and 9. Every mismatch is printed
//   (SA-MISMATCH); the test fails at the end if there was one.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Sdtrig']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define TT(n) ((n) << (__riscv_xlen - 4))

// Write tdata1 = _VAL (type _T, action _A at bit _SH) and fail softly unless the action reads back as _A.
#define KEPT(_T, _VAL, _SH, _A, _MSG)      \
  csrw tdata1, x0                         ;\
  LI(x7, TT(_T) | (_VAL))                 ;\
  csrw tdata1, x7                         ;\
  csrr x8, tdata1                         ;\
  csrw tdata1, x0                         ;\
  srli x8, x8, _SH                        ;\
  andi x8, x8, 15                         ;\
  SA_SOFT(x8, _A, _MSG)

RVTEST_BEGIN
  csrci mstatus, 8            // MIE = 0
  csrw tselect, x0
  csrw tdata2, x0
  KEPT(6, (8 << 12) | (1 << 3) | 1, 12, 8, "mcontrol6 action=8 (external trigger output 0): action read back")
  KEPT(6, (9 << 12) | (1 << 3) | 1, 12, 9, "mcontrol6 action=9 (external trigger output 1): action read back")
  KEPT(3, (1 << 10) | (1 << 6) | 8, 0, 8, "icount action=8 (external trigger output 0): action read back")
  KEPT(3, (1 << 10) | (1 << 6) | 9, 0, 9, "icount action=9 (external trigger output 1): action read back")
  csrw tdata1, x0
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
