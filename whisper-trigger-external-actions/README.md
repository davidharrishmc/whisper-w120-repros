# Whisper: tdata1.action keeps the reserved values 6 and 7 and rejects the external-trigger actions 8 and 9

Configuration dependent: the defect shows when the external-trigger actions are enabled, which is Whisper's
default (no `trigger_actions` in the json) or a `trigger_actions` list with `"external0"` and
`"external1"`. `whisper-rv64-ext.json` and `whisper-rv32-ext.json` are the riscv-arch-test
`whisper-rv64-max` and `whisper-rv32-max` configurations with those two names added to `trigger_actions`
(the riscv-arch-test configurations list only raisebreak, enterdebug, starttrace, stoptrace and emittrace, which
hides the defect).

- `whisper-trigger-action-reserved.S`: writes mcontrol6 and icount with action 6 and 7 (reserved) and checks
  that the action does not read back as written. This holds for any hart.
- `whisper-trigger-action-external.S`: writes mcontrol6 and icount with action 8 and 9 (external trigger
  output 0 and 1) and checks that they read back. This holds for a hart that supports those actions, as the
  configuration says.

Both run in M-mode with `mstatus.MIE` = 0 and clear tdata1 after each write.

Expected: 6 and 7 are not kept; 8 and 9 are kept. Whisper master (fa18e475, `master.out`), RV64 and RV32:
6 and 7 are kept, 8 and 9 are replaced (action reads 0):

```
SA-MISMATCH: mcontrol6 action=6 (reserved) is not kept expect=0x0000000000000001 got=0x0000000000000000
SA-MISMATCH: mcontrol6 action=8 (external trigger output 0): action read back expect=0x0000000000000008 got=0x0000000000000000
```

`fixed.out` is the output with the fix.

## Run

`./run.sh path/to/whisper` (prints PASS or FAIL per ELF and overall; exit status 0 = pass).

## Build

Self-checking programs built with the riscv-arch-test framework (`act`) from riscv-arch-test PR #3162 (commit
205129dbd8, which adds the `tests_ai/common` helpers; `ai_macros.h` and `sa.h` are included here) for the
riscv-arch-test Whisper configuration named below; the `whisper*.json` files are the configurations they run with.
A test prints `RVCP-SUMMARY: TEST PASSED` or `TEST FAILED`; a failed check prints `RVCP: Test Info: <check>` and
the bad value, and soft checks print `SA-MISMATCH: <check> expect=... got=...` and fail the test at the end. Configurations: `whisper-rv64-max`, `whisper-rv32-max` (run with the `-ext` json files).
