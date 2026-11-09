// Reproducer: tdata1.action keeps the reserved values 6 and 7.
// Spec: riscv-debug-spec Sdtrig.adoc tab:action: 0-4 defined, 5 "Reserved for use by the trace specification"
//   (norm:Sdtrig_action5_rsv), 8-9 "Send a signal to TM external trigger output 0 or 1 (respectively)"
//   (norm:Sdtrig_action8_9), other values "Reserved for future use" (norm:Sdtrig_action_rsv: 6, 7, 10-15).
//   norm:Sdtrig_tdata_warl: "All tdata registers follow write-any-read-legal semantics."
// Whisper: Triggers.hpp `enum class TriggerAction { RaiseBreak, EnterDebug, StartTrace, StopTrace, EmitTrace,
//   Reserved, External0, External1, Limit = 15 }` gives External0 = 6 and External1 = 7, so with the
//   external-trigger actions enabled (Whisper's default, or "external0"/"external1" in trigger_actions) tdata1
//   keeps action 6 and 7.
// Check: mcontrol6 and icount written with action 6 and 7 never read back 6 or 7 (a type that does not stick
//   is skipped). Every mismatch is printed (SA-MISMATCH); the test fails at the end if there was one.

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

// Write tdata1 = _VAL (type _T, action _A at bit _SH) and fail softly if the action reads back as _A.
#define NOT_KEPT(_T, _VAL, _SH, _A, _MSG)  \
  csrw tdata1, x0                         ;\
  LI(x7, TT(_T) | (_VAL))                 ;\
  csrw tdata1, x7                         ;\
  csrr x8, tdata1                         ;\
  csrw tdata1, x0                         ;\
  srli x9, x8, __riscv_xlen - 4           ;\
  li x10, _T                              ;\
  bne x9, x10, 1f                         ;\
  srli x8, x8, _SH                        ;\
  andi x8, x8, 15                         ;\
  li x10, _A                              ;\
  sub x8, x8, x10                         ;\
  snez x8, x8                             ;\
  SA_SOFT(x8, 1, _MSG)                    ;\
1:

RVTEST_BEGIN
  csrci mstatus, 8            // MIE = 0: M-mode action-0 triggers cannot fire
  csrw tselect, x0
  csrw tdata2, x0
  // mcontrol6, u=1 load=1 (action at bits 15:12)
  NOT_KEPT(6, (6 << 12) | (1 << 3) | 1, 12, 6, "mcontrol6 action=6 (reserved) is not kept")
  NOT_KEPT(6, (7 << 12) | (1 << 3) | 1, 12, 7, "mcontrol6 action=7 (reserved) is not kept")
  // icount, u=1 count=1 (action at bits 5:0; 6 and 7 fit in the low 4 bits checked)
  NOT_KEPT(3, (1 << 10) | (1 << 6) | 6, 0, 6, "icount action=6 (reserved) is not kept")
  NOT_KEPT(3, (1 << 10) | (1 << 6) | 7, 0, 7, "icount action=7 (reserved) is not kept")
  csrw tdata1, x0
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
RVTEST_DATA_END
RVTEST_SIG_SETUP
