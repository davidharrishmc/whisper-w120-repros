# RV32: miph and mieh are fully writable but never make an interrupt pending

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

On RV32, M-mode `csrw miph, -1` and `csrw mieh, -1` both read back 0xffffffff (nothing delegated, mvien = 0),
but mtopi reports no interrupt 32 or above, and with mstatus.MIE = 1 no interrupt trap is taken.

## Correct behavior

miph/mieh may be read-only zero (AIA allows it, and that is what the code comment intends). If they are
writable, mip[32+k] = mie[32+k] = 1 with mideleg[32+k] = 0 is a pending, enabled M-level interrupt: mtopi.IID >= 32 and,
with MIE = 1, the interrupt traps.

```
RV32: csrw miph, -1; csrw mieh, -1; mideleg/mvien = 0
  Expected: miph = mieh = 0 (read-only zero), or mtopi.IID >= 32 and an interrupt trap with cause >= 32
  Observed: miph = mieh = 0xffffffff, mtopi.IID < 32, no trap with MIE = 1
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv32: `u30-aia-a-whisper-05.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u30-aia-a-whisper-05.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv32
SA-MISMATCH: INFO W05 miph after writing -1 expect=0x00000000 got=0xffffffff
SA-MISMATCH: INFO W05 mieh after writing -1 expect=0x00000000 got=0xffffffff
SA-MISMATCH: W05: miph&mieh nonzero, nothing delegated: mtopi.IID must be >= 32 (MSLevel.adoc:428-432) expect=0x00000000 got=0x00000001
SA-MISMATCH: W05: miph&mieh nonzero, MIE=1: one interrupt trap to M expect=0x00000001 got=0x00000000
SA-MISMATCH: W05: miph&mieh nonzero, MIE=1: the trap is an interrupt with code >= 32 expect=0x00000001 got=0x00000000
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-whisper-05.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
