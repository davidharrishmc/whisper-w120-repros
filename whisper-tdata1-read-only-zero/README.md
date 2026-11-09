# Whisper: read-only-zero tdata1 fields keep the ones written to them

The configuration's tinfo is 0x1008078 (`tinfo.version` = 1: the ratified Sdtrig 1.0 layouts).
`whisper-tdata1-read-only-zero.S` runs in M-mode with `mstatus.MIE` = 0. For each trigger type it writes
tdata1 with every data bit set except action, chain (and icount pending), reads it back, and checks that the
fields that the debug spec's tdata1 layout for that type defines as "0" read 0:

| type | RV64 zero fields | RV32 zero fields |
|---|---|---|
| mcontrol (2) | 52:23, 5 | 5 |
| icount (3) | 58:27 | - |
| itrigger (4) | 57:13, 8 | 25:13, 8 |
| etrigger (5) | 57:13, 10, 8 | 25:13, 10, 8 |
| mcontrol6 (6) | 58:27, 20:19 | 20:19 |
| tmexttrigger (7) | 57:23 | 25:23 |

A type that the configuration does not support (tdata1 type does not stick) is skipped: the riscv-arch-test
configurations used here support icount, itrigger, etrigger and mcontrol6.

Expected: every zero field reads 0. Whisper master (fa18e475, `master.out`): RV64 mcontrol6 keeps bits 20:19
and 58, icount keeps bit 58, itrigger keeps 24:13 and 8, etrigger keeps 24:13, 10 and 8 (the bits that the
per-trigger configuration mask 0xfc00000001ffffff lets through); RV32 (mask 0xfdffffff) mcontrol6 keeps 20:19,
itrigger keeps 24:13 and 8, etrigger keeps 24:13, 10 and 8. For example:

```
SA-MISMATCH: mcontrol6 (v1): bits 20:19 alone read 0 expect=0x0000000000000000 got=0x0000000000180000
SA-MISMATCH: icount: bit 58 alone reads 0 expect=0x0000000000000000 got=0x0400000000000000
SA-MISMATCH: etrigger: bits 57:13, 10 and 8 read 0 expect=0x0000000000000000 got=0x0000000001ffe500
```

`fixed.out` is the output with the fix.

## Run

`./run.sh path/to/whisper` (prints PASS or FAIL per ELF and overall; exit status 0 = pass). It runs
`whisper-tdata1-read-only-zero_rv64.elf` with `whisper-rv64.json` and `_rv32.elf` with `whisper-rv32.json`.

## Build

Self-checking programs built with the riscv-arch-test framework (`act`) from riscv-arch-test PR #3162 (commit
205129dbd8, which adds the `tests_ai/common` helpers; `ai_macros.h` and `sa.h` are included here) for the
riscv-arch-test Whisper configuration named below; the `whisper*.json` files are the configurations they run with.
A test prints `RVCP-SUMMARY: TEST PASSED` or `TEST FAILED`; a failed check prints `RVCP: Test Info: <check>` and
the bad value, and soft checks print `SA-MISMATCH: <check> expect=... got=...` and fail the test at the end. Configurations: `whisper-rv64-max`, `whisper-rv32-max`.
