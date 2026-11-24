// verify v15a, u32-debug-a-T-03 (Whisper): with dcsr.stopcount = 1, instret must not advance in Debug Mode, nor on
// the EBREAK that enters Debug Mode.
// Bare test (tests/u32-debug-a/bare/dm.h harness, Whisper build -DWHISPER -DUART=0x10000000), run with the dcsr
// reset preset act/config/whisper/rr-u32-debug-a-w/whisper-rv{64,32}-ebmall.json (ebreakm = 1, stopcount = 0 at
// reset): Whisper in a batch run keeps executing after the EBREAK in Debug Mode, so the code there plays the debugger.
// Run: work/verify-v15a/wb.sh u32-debug-a-T-03 64|32 [a5554a17|2646725] [log|fast].
// Spec: debug core_registers (specs/debug/xml/core_registers.xml:205-216) dcsr.stopcount "1 (freeze): Don't
//   increment any hart-local counters while in Debug Mode or on ebreak instructions that cause entry into Debug
//   Mode. These counters include the instret CSR."; Sdext.adoc:47 "If stopcount is 1 then counters are stopped."
// Checks: (1) stopcount reads back 1 after csrs (so not hardwired 0); (2) in Debug Mode, csrr minstret; nop; nop;
//   csrr minstret differ by 0; (3) M-mode csrr minstret (A); EBREAK entering Debug Mode with stopcount = 1; first
//   Debug Mode csrr minstret (B): B - A = 1 (only the csrr A retired outside Debug Mode).
#include "dm.h"
main:
  // ---- first entry: set stopcount (debugger action), measure inside Debug Mode
  ebreak
  li t0, D_STOPCOUNT
  csrs DCSR, t0
  csrr s3, DCSR
  csrr s4, minstret
  nop
  nop
  csrr s5, minstret
  la t0, back1
  csrw DPC, t0
  DRET
back1:
  CHKM(s3, D_STOPCOUNT, D_STOPCOUNT, "T03 control: dcsr.stopcount reads 1 after csrs")
  sub s0, s5, s4
  CHK(s0, 0, "T03: stopcount=1: csrr minstret; nop; nop; csrr minstret in Debug Mode differ by 0")
  // ---- second entry with stopcount = 1 already set: the entering EBREAK must not count
  csrr s6, minstret
  ebreak
  csrr s7, minstret
  la t0, back2
  csrw DPC, t0
  DRET
back2:
  sub s0, s7, s6
  CHK(s0, 1, "T03: stopcount=1: M csrr minstret (A); ebreak -> Debug Mode; csrr minstret (B): B - A = 1")
  TEST_END
  .section .rodata
s_name: .asciz "u32-debug-a-T-03"
