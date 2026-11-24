# APLIC: a write to ithreshold does not update the interrupt signal to the hart (masked source keeps MEIP = 1; unmasking a pending source never raises MEIP)

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

In an M-level APLIC domain in direct-delivery mode (domaincfg.IE = 1, idelivery = 1, iforce = 0), writing
ithreshold changes topi but not the interrupt signal to the hart. (A) Source 1 (IPRIO 3) pending, MEIP = 1; ithreshold
:= 3: topi correctly reads 0, but mip.MEIP stays 1, also after a 2000-iteration delay loop. (B) The reverse, which loses
an interrupt: ithreshold = 1, source 1 made pending (MEIP = 0, topi = 0, correct); ithreshold := 0: topi correctly reads
0x00010003, but MEIP stays 0, also after the delay loop. With MEIE/MIE set the interrupt is not taken until some other
APLIC register write or a claimi read re-evaluates the signal.

## Correct behavior

With IE = idelivery = 1 and iforce = 0, the interrupt signal equals (topi != 0): MEIP = 0 in case A and
MEIP = 1 in case B (after at most a finite delay).

```
(A) source 1 IPRIO 3 pending, MEIP = 1; ithreshold := 3
  Expected: topi = 0, MEIP = 0      Observed: topi = 0, MEIP = 1 (also after 2000 iterations)
(B) ithreshold = 1, source 1 pending (MEIP = 0); ithreshold := 0
  Expected: topi = 0x00010003, MEIP = 1      Observed: topi = 0x00010003, MEIP = 0 (also after 2000 iterations)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: `u31-aia-b-T-02.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32: `u31-aia-b-T-02.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u31-aia-b-T-02.whisper-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-02.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64
SA-MISMATCH: T02A: ithreshold = 3 masks the only pending source: MEIP = 0 (AdvPLIC.adoc:1108-1111, :1165-1170) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T02A: ... still MEIP = 1 after a 2000-iteration delay loop expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T02B: ithreshold := 0 unmasks pending source 1: MEIP = 1 (AdvPLIC.adoc:1165-1170) expect=0x0000000000000001 got=0x0000000000000000
SA-MISMATCH: T02B: ... MEIP = 1 after a 2000-iteration delay loop (else the interrupt is lost) expect=0x0000000000000001 got=0x0000000000000000
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-02.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32
SA-MISMATCH: T02A: ithreshold = 3 masks the only pending source: MEIP = 0 (AdvPLIC.adoc:1108-1111, :1165-1170) expect=0x00000000 got=0x00000001
SA-MISMATCH: T02A: ... still MEIP = 1 after a 2000-iteration delay loop expect=0x00000000 got=0x00000001
SA-MISMATCH: T02B: ithreshold := 0 unmasks pending source 1: MEIP = 1 (AdvPLIC.adoc:1165-1170) expect=0x00000001 got=0x00000000
SA-MISMATCH: T02B: ... MEIP = 1 after a 2000-iteration delay loop (else the interrupt is lost) expect=0x00000001 got=0x00000000
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-02.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
