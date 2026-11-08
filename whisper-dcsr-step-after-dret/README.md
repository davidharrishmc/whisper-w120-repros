# Whisper: with dcsr.step, dret re-enters Debug Mode without executing an instruction

Sdext.adoc (Single Step): with `dcsr.step` set, "the hart will only execute a single instruction and then
enter Debug Mode"; "If dcsr.step is set when a hart resumes then it will single step"; and "If control is
transferred to a trap handler while executing the instruction, then Debug Mode is re-entered immediately
after the PC is changed to the trap handler".

Whisper calls `evaluateDebugStep` after every instruction, and it enters Debug Mode (cause 4) whenever
`dcsr.step` is set and the hart is not in Debug Mode. When the debug program resumes with `dret` (Whisper's
`debug_park_loop` mode), the `dret` itself leaves Debug Mode, so the hart re-enters Debug Mode right after
it, with `dpc` at the `dret` target and no instruction executed. Every later resume does the same, so the
hart never advances while `dcsr.step` is set. (Resuming through the test bench, interactive mode or server
mode without a park loop calls `exitDebugMode` before the step and works.)

`step.S` enters Debug Mode with `ebreak` (`whisper-rv*.json` sets the `dcsr` reset value for `ebreakm` and
`debug_park_loop`; the `dcsr` masks are Whisper's defaults), sets `dcsr.step` and resumes at `step_a`. It
single-steps `step_a` (addi), `step_b` (addi) and `step_c` (ecall, which traps to M-mode). After each halt
it checks `dpc` and `dcsr.cause`; after the third it checks mcause/mepc, clears `dcsr.step` and resumes, and
`mhandler` checks that each addi executed exactly once.

x31 = bitmask of failed checks: 1/2/3 `dpc` != `step_b`/`step_c`/`mhandler` at halt 1/2/3, 4 `dcsr.cause`
!= 4 at some halt, 5 mcause != 11 or mepc != `step_c` at halt 3, 6 a0 != 2, 7 more than 3 halts (the test
stops at 6), 8 `mhandler` reached after a number of halts other than 3. tohost = (x31 << 1) | 1.

Expected: x31 = 0.

Whisper master 6b8cce1a (`master.out`): x31 = 0x2e on RV64 and RV32; every halt has `dpc` = `step_a`, so
the three halts happen without executing anything (the addis then run once each after `dcsr.step` is
cleared):

```
rv64: x31 = 0x2e
  FAIL check 1: halt 1: dpc != step_b (the dret was counted as the stepped instruction)
  FAIL check 2: halt 2: dpc != step_c
  FAIL check 3: halt 3: dpc != mhandler (ecall trap)
  FAIL check 5: halt 3: mcause != 11 or mepc != step_c
rv32: x31 = 0x2e
  FAIL check 1: halt 1: dpc != step_b (the dret was counted as the stepped instruction)
  FAIL check 2: halt 2: dpc != step_c
  FAIL check 3: halt 3: dpc != mhandler (ecall trap)
  FAIL check 5: halt 3: mcause != 11 or mepc != step_c
```

With the step halt skipped for the instruction that started in Debug Mode (`fixed.out`), both pass.

Run: `./run.sh [path/to/whisper]` (prints the failed checks; exit status 0 = pass). Rebuild: `./build.sh`.

Other simulators: Spike, Sail and QEMU have no Debug Mode that a bare-metal program can enter, so the test
cannot run on them. Imperas, stock ImperasDV Y-2026.09 library
(`IMPERAS_VLNV=/cad/imperas/IMPERAS_DV/lib/Linux64/ImperasLib`), `debug_mode=vector`,
`debug_address=0x80000800`, `dexc_address=0x80000900`, `dcsr_ebreak_mask=0x3f`, `rnmi_version=0.4`, passes on
RV64: it halts with `dpc` = `step_b`, `step_c` and `mhandler`.
