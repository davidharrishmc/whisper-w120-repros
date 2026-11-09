# Whisper: a sized NAPOT trigger compares tdata2 bits above the access size

`whisper-napot-trigger-size.S` runs in M-mode with `mstatus.MIE` = 1 (M-mode breakpoints need it in this
configuration) and arms trigger 0 as an mcontrol6 trigger with select = 1, size = 3 (32 bits), match = 1 (NAPOT),
m = 1:

- load data (load = 1): tdata2 = 0x7 (control A) and 0xffffffff00000007 (case): `lw` of 0x00000003 must take a
  breakpoint in both, because only the low 32 bits of tdata2 take part and its NAPOT range is 0x0-0xf. Control B:
  `lw` of 0x13 must not.
- execute opcode (execute = 1): tdata2 = 0x000f8f97 (control C) and 0xffffffff000f8f97 (case):
  `addi x31, x31, 0` (0x000f8f93) must take a breakpoint in both.

Expected: breakpoints in both cases. Whisper master (fa18e475, `master.out`): the controls pass, but neither
case fires:

```
FAIL  whisper-napot-trigger-size.elf
      SA-MISMATCH: load case: tdata2=0xffffffff00000007, lw of 3: xcause (3 = breakpoint) expect=0x0000000000000003 got=0xffffffffffffffff
      SA-MISMATCH: execute case: tdata2=0xffffffff000f8f97, addi x31,x31,0: xcause (3 = breakpoint) expect=0x0000000000000003 got=0xffffffffffffffff
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
