# Whisper: sspush never matches an mcontrol6 store-data trigger

`whisper-sspush-store-data-trigger.S` runs in S-mode with Sv39 and `menvcfg.SSE` = 1. It arms trigger 0 as an
mcontrol6 store-data trigger (select = 1, store = 1, s = 1, size = any, match = equal) with tdata2 = the value in
x1, sets `sstatus.SIE` (breakpoints are delegated to S-mode in this configuration), and then:

- control: `sd x1` to an ordinary page: must take a breakpoint (scause 3);
- case: `sspush x1` with ssp pointing into a shadow-stack page: must take a breakpoint (scause 3) before the
  store, leaving ssp unchanged.

Expected: both breakpoints, ssp unchanged. Whisper master (fa18e475, `master.out`): the control takes the
breakpoint, the `sspush` does not trap and pushes:

```
FAIL  whisper-sspush-store-data-trigger.elf
      RVCP: Test Info: sspush of the tdata2 value: xcause (3 = store-data breakpoint)
      RVCP: Bad Value:      0xffffffffffffffff
```

(-1 = no trap.) `fixed.out` is the output with the fix.

## Run

`./run.sh path/to/whisper` (prints PASS or FAIL; exit status 0 = pass). It runs
`whisper --maxinst 100000000:f --config whisper.json whisper-sspush-store-data-trigger.elf`.

## Build

Self-checking programs built with the riscv-arch-test framework (`act`) from riscv-arch-test PR #3162 (commit
205129dbd8, which adds the `tests_ai/common` helpers; `ai_macros.h` and `sa.h` are included here) for the
riscv-arch-test Whisper configuration named below; the `whisper*.json` files are the configurations they run with.
A test prints `RVCP-SUMMARY: TEST PASSED` or `TEST FAILED`; a failed check prints `RVCP: Test Info: <check>` and
the bad value, and soft checks print `SA-MISMATCH: <check> expect=... got=...` and fail the test at the end. Configuration: `whisper-rv64-max`.
