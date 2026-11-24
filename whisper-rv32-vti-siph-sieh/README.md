# RV32: hvictl.VTI = 1 does not trap VS-mode siph/sieh

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

On RV32 with hvictl.VTI = 1 (IID 9, IPRIO 0) and mstateen0/hstateen0 all ones, VS-mode `csrr siph` and
`csrr sieh` complete. `csrr sip` and `csrr sie` correctly raise virtual-instruction.

## Correct behavior

With VTI = 1, VS-mode accesses to sip and sie, and on RV32 siph and sieh, raise virtual-instruction (22).

```
RV32, hvictl = VTI | IID 9, VS-mode
  csrr siph, csrr sieh    Expected: virtual instruction (22)   Observed: no trap
  csrr sip,  csrr sie     Expected: 22                         Observed: 22
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv32: `u30-aia-a-T-04.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u30-aia-a-T-04.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv32
SA-MISMATCH: T-04: RV32 VS csrr siph with hvictl.VTI=1: virtual instruction (VSLevel.adoc:385-387) expect=0x00001316 got=0x000000ff
SA-MISMATCH: T-04: RV32 VS csrr sieh with hvictl.VTI=1: virtual instruction (VSLevel.adoc:385-387) expect=0x00001316 got=0x000000ff
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-04.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
