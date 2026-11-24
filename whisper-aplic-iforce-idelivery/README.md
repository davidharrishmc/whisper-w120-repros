# APLIC: iforce = 1 asserts the interrupt to the hart while idelivery = 0

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

In an M-level APLIC domain in direct-delivery mode with nothing pending and domaincfg.IE = 1, setting
idelivery := 0 and then iforce := 1 (reads back 1) makes mip.MEIP = 1, also after a delay loop. Controls behave:
idelivery := 1 -> MEIP = 1; iforce := 0 -> MEIP = 0; domaincfg.IE = 0 is honoured.

## Correct behavior

With idelivery = 0 the interrupt signal to the hart is held de-asserted whatever iforce holds: MEIP = 0.

```
domaincfg.IE = 1, nothing pending, idelivery := 0, iforce := 1
  Expected: MEIP = 0      Observed: MEIP = 1 (also after a delay loop)
Control: idelivery := 1 -> MEIP = 1; iforce := 0 -> MEIP = 0 (correct)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: `u31-aia-b-T-03.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32: `u31-aia-b-T-03.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u31-aia-b-T-03.whisper-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-03.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64
SA-MISMATCH: T03: idelivery = 0, iforce = 1: MEIP = 0 (AdvPLIC.adoc:1095-1097, :1165-1168) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T03: ... MEIP = 0 after a delay loop expect=0x0000000000000000 got=0x0000000000000001
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-03.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32
SA-MISMATCH: T03: idelivery = 0, iforce = 1: MEIP = 0 (AdvPLIC.adoc:1095-1097, :1165-1168) expect=0x00000000 got=0x00000001
SA-MISMATCH: T03: ... MEIP = 0 after a delay loop expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-03.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
