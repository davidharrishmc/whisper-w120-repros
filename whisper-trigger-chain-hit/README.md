# Whisper: mcontrol6 hit bits are set on a chain that matched only partly

The configuration's tinfo is 0x1008078, so `tinfo.version` = 1 (the ratified Sdtrig 1.0 triggers).
`whisper-trigger-chain-hit.S` runs in M-mode, clears `medeleg[3]` and arms two mcontrol6 execute-address
triggers enabled in U-mode, trigger 0 with chain = 1:

- case: trigger 0 at A, trigger 1 at B; U-mode executes A but not B. Nothing must fire, and hit1:hit0 of both
  triggers must stay 0.
- control: both triggers at C; U-mode executes C. The chain fires (breakpoint, mcause 3), and hit0 of trigger 1
  must be 1. Trigger 0's hit0 may be 0 or 1: whether a non-final chain member, whose action is ignored, counts
  as firing is not settled by the spec text (Whisper and Spike set it, Sail does not).

Expected: case no breakpoint and no hit bits; control breakpoint with trigger 1's hit0 set. Whisper master
(fa18e475, `master.out`): in the case, trigger 0 has hit0 = 1 although nothing fired:

```
FAIL  whisper-trigger-chain-hit.elf
      RVCP: Test Info: case: chain did not fire: hit1|hit0 of trigger 0
      RVCP: Bad Value:      0x0000000000400000
```

`fixed.out` is the output with the fix.

## Run

`./run.sh path/to/whisper` (prints PASS or FAIL; exit status 0 = pass).

## Build

Self-checking programs built with the riscv-arch-test framework (`act`) from riscv-arch-test PR #3162 (commit
205129dbd8, which adds the `tests_ai/common` helpers; `ai_macros.h` and `sa.h` are included here) for the
riscv-arch-test Whisper configuration named below; the `whisper*.json` files are the configurations they run with.
A test prints `RVCP-SUMMARY: TEST PASSED` or `TEST FAILED`; a failed check prints `RVCP: Test Info: <check>` and
the bad value, and soft checks print `SA-MISMATCH: <check> expect=... got=...` and fail the test at the end. Configuration: `whisper-rv64-max`.
