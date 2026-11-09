// Reproducer: a sized (size=3, 32-bit) mcontrol6 NAPOT trigger with select=1 compares tdata2 bits above bit 31,
// so it misses a 32-bit load value, or a 32-bit instruction, that is in the range given by the low 32 bits of
// tdata2.
// Spec: riscv-debug-spec xml/hwbp_registers.xml mcontrol6.match (norm:Sdtrig_mcontrol6_comparisons): "All
//   comparisons only look at the lower XLEN (in the current mode) bits of the compare values and of tdata2.
//   When select=1 and access size is N, this is further reduced, and comparisons only look at the lower N
//   bits of the compare values and of tdata2." match=1 (napot, norm:Sdtrig_mcontrol6_match_napot): "Matches
//   when the top M bits of any compare value match the top M bits of tdata2."
// Whisper: Trigger::doMatch (Triggers.cpp) applies the low-N-bit mask only to Equal/GE/LT; Match::Masked
//   compares (item & data2CompareMask_) == (tdata2 & data2CompareMask_) over all XLEN bits.
// Expected (spec):
//   load data: tdata2 = 0xffffffff00000007 (NAPOT, bits 3:0 don't care), lw of 0x00000003 -> breakpoint
//     (cause 3). Controls: tdata2 = 0x7 -> breakpoint; lw of 0x13 -> no trap.
//   execute opcode: tdata2 = 0xffffffff000f8f97 (bits 3:0 don't care), `addi x31, x31, 0` (0x000f8f93) ->
//     breakpoint. Control: tdata2 = 0x000f8f97 -> breakpoint.
// Whisper: no trap in both cases with the upper tdata2 bits set; the controls pass.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'Sdtrig']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define MC6 (6 << (__riscv_xlen - 4))
// mcontrol6: select=1 (data), size=3 (32-bit), match=1 (NAPOT), m=1, load=1
#define TD1 (MC6 | (1 << 21) | (3 << 16) | (1 << 7) | (1 << 6) | 1)
// mcontrol6: select=1 (opcode), size=3 (32-bit), match=1 (NAPOT), m=1, execute=1
#define TD1X (MC6 | (1 << 21) | (3 << 16) | (1 << 7) | (1 << 6) | 4)

// program trigger 0 with tdata2 = _T2 and tdata1 = _T1; x8 = tdata1 read back, x9 = tdata2 read back
#define SET_TRIGX(_T1, _T2)     \
  csrw tselect, x0             ;\
  csrw tdata1, x0              ;\
  LI(x7, _T2)                  ;\
  csrw tdata2, x7              ;\
  LI(x7, _T1)                  ;\
  csrw tdata1, x7              ;\
  csrr x8, tdata1              ;\
  csrr x9, tdata2
#define SET_TRIG(_T2) SET_TRIGX(TD1, _T2)

RVTEST_BEGIN
#if __riscv_xlen == 64
  csrw mie, x0
  LA(x6, sa_data)

  // control A: tdata2 = 0x7 (NAPOT 16-byte range 0..15), lw of 3 matches
  SET_TRIG(0x7)
  LI(x7, TD1)
  bne x8, x7, sa_skip         // size=3 / NAPOT data not supported: nothing to test
  csrsi mstatus, 8            // M-mode triggers with action=0 match only while MIE=1
  SA_TRY(1)
  lw x10, 0(x6)               // value 3
  AI_OUTCOME
  csrci mstatus, 8
  mv x11, x14

  // case: tdata2 = 0xffffffff00000007; only bits 31:4 take part for a 32-bit access, so lw of 3 matches
  SET_TRIG(0xffffffff00000007)
  csrsi mstatus, 8
  SA_TRY(1)
  lw x10, 0(x6)               // value 3
  AI_OUTCOME
  csrci mstatus, 8
  mv x12, x14
  mv x15, x9                  // tdata2 as read back

  // control B: same tdata2, lw of 0x13 (bit 4 set) does not match
  csrsi mstatus, 8
  SA_TRY(1)
  lw x10, 4(x6)               // value 0x13
  AI_OUTCOME
  csrci mstatus, 8
  mv x1, x14

  csrw tdata1, x0

  // execute opcode, control C: tdata2 = 0x000f8f97 (NAPOT 16-value range 0x000f8f90..0x000f8f9f)
  .option push
  .option norvc
  SET_TRIGX(TD1X, 0x000f8f97)
  LI(x7, TD1X)
  bne x8, x7, sa_skipx        // size=3 / NAPOT opcode not supported: skip the execute cases
  csrsi mstatus, 8
  SA_TRY(1)
  addi x31, x31, 0            // 0x000f8f93
  AI_OUTCOME
  csrci mstatus, 8
  mv x16, x14

  // execute opcode, case: tdata2 = 0xffffffff000f8f97; only bits 31:4 take part for a 32-bit instruction
  SET_TRIGX(TD1X, 0xffffffff000f8f97)
  csrsi mstatus, 8
  SA_TRY(1)
  addi x31, x31, 0            // 0x000f8f93
  AI_OUTCOME
  csrci mstatus, 8
  mv x17, x14
  mv x18, x9                  // tdata2 as read back
  csrw tdata1, x0
  .option pop
sa_skipx:
  // soft checks: every mismatch is printed, then SA_SOFT_END fails the test if there was one
  SA_SOFT(x11, 3, "load control A: tdata2=0x7, lw of 3: xcause")
  SA_SOFT(x1, -1, "load control B: tdata2=0xffffffff00000007, lw of 0x13: xcause (-1 = none)")
  SA_SOFT(x15, 0xffffffff00000007, "load: tdata2 read back")
  SA_SOFT(x12, 3, "load case: tdata2=0xffffffff00000007, lw of 3: xcause (3 = breakpoint)")
  LI(x7, TD1X)
  bne x8, x7, sa_skip
  SA_SOFT(x16, 3, "execute control C: tdata2=0x000f8f97, addi x31,x31,0: xcause")
  SA_SOFT(x18, 0xffffffff000f8f97, "execute: tdata2 read back")
  SA_SOFT(x17, 3, "execute case: tdata2=0xffffffff000f8f97, addi x31,x31,0: xcause (3 = breakpoint)")
sa_skip:
  SA_SOFT_END
#endif
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 3
sa_data:
  .word 0x00000003, 0x00000013
RVTEST_DATA_END
RVTEST_SIG_SETUP
