# Whisper: sspopchk in VS-mode skips the G-stage write-permission check when the G-stage translation is cached

`whisper-sspopchk-gstage-tlb.S` runs in VS-mode with `henvcfg.SSE` = 1, an Sv39 VS-stage that maps shadow-stack
pages, and an Sv39x4 G-stage:

- control: `sspopchk x1` through a G-stage leaf with R = W = 1: no trap;
- case 1: `sspopchk x1` through a G-stage leaf with R = 1, W = 0, no earlier access to the page: store/AMO
  guest-page fault (cause 23);
- case 2: an ordinary `ld` from a second such page (legal: loads may read shadow-stack pages), then
  `sspopchk x1` from it: store/AMO guest-page fault (cause 23).

Expected: control no trap; cases 1 and 2 cause 23. Whisper master (fa18e475, `master.out`): case 1 23, case 2
no trap:

```
FAIL  whisper-sspopchk-gstage-tlb.elf
      RVCP: Test Info: case 2: VS sspopchk, G-stage R only, after ld from the same page: number of traps
      RVCP: Bad Value:      0x0000000000000000
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
