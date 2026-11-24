# M-level APLIC delivery is kept in mip itself: M-level APLIC transitions (assert or claim) latch the APLIC S-level signal into mip.SEIP/mvip[9], and IMSIC M-file accesses (eithreshold, mtopei, eidelivery) clear the APLIC MEIP

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

The M-level APLIC interrupt is stored in mip itself. Two consequences:
(1) mvien = mvip = 0, mie = 0. The APLIC S domain asserts SEI (mip.SEIP = 1, mvip[9] = 0: correct). When the APLIC M
domain then asserts MEI, mvip[9] (the software-writable SEIP bit) becomes 1. After both APLIC sources clear, mip.SEIP
stays 1: a supervisor external interrupt that software never wrote, until software clears it. The same happens on
an M-level deassertion: with the S domain asserting and an M source pending, a claimi read in the M domain (MEIP 1 -> 0)
sets mvip[9], and after the S domain's own claim mip.SEIP stays 1 (with interrupts enabled, an endless SEI storm).
(2) With the M-level IMSIC file at eidelivery = 0x40000000 (APLIC supplies MEI) and an APLIC M-level interrupt pending
(mip.MEIP = 1), `csrw mireg` of the M file's eithreshold (same value) clears mip.MEIP; so does `csrrw x8, mtopei, x0`
(a claim with the file empty). So does a round trip of eidelivery itself: with the APLIC asserting (topi = 0x10001),
writing eidelivery = 1 (the empty file now supplies MEIP: MEIP = 0, correct) and then 0x40000000 again leaves MEIP = 0.
The APLIC still asserts the interrupt; it stays lost until the APLIC source changes.

## Correct behavior

(1) SEIP is the OR of the software-writable bit and the interrupt controller's signal, and the controller's
signal never changes the software-writable bit. (2) With eidelivery = 0x40000000 the APLIC supplies MEIP; accesses to
the M file's registers do not change it.

```
(1) APLIC S source asserted, then APLIC M source asserted, then both cleared
  Expected: mvip[9] = 0 throughout; mip.SEIP = 0 at the end
  Observed: mvip[9] = 1 after the M source; mip.SEIP = 1 at the end
(2) APLIC M source pending (MEIP = 1), M file eidelivery = 0x40000000
  csrw mireg (eithreshold, same value)   Expected: MEIP = 1   Observed: MEIP = 0
  csrrw x8, mtopei, x0                   Expected: MEIP = 1   Observed: MEIP = 0
  eidelivery 0x40000000 -> 1 -> 0x40000000 Expected: MEIP = 1   Observed: MEIP = 0
(1') S source asserted, M source pending; M claimi; then S claimi
  Expected: mvip[9] = 0; mip.SEIP = 0 at the end   Observed: mvip[9] = 1; mip.SEIP = 1
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64 phantom SEIP (03): `u30-aia-a-whisper-03.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv64 lost MEIP (08): `u30-aia-a-whisper-08.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32 phantom SEIP (03): `u30-aia-a-whisper-03.whisper-rv32-max.elf` with `whisper-rv32-max.json`
- rv32 lost MEIP (08): `u30-aia-a-whisper-08.whisper-rv32-max.elf` with `whisper-rv32-max.json`
- rv64 phantom SEIP on an M claim (T-04): `u31-aia-b-T-04.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv64 lost MEIP on eidelivery 1 -> 0x40000000 (T-06): `u31-aia-b-T-06.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32 phantom SEIP on an M claim (T-04): `u31-aia-b-T-04.whisper-rv32-max.elf` with `whisper-rv32-max.json`
- rv32 lost MEIP on eidelivery 1 -> 0x40000000 (T-06): `u31-aia-b-T-06.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u30-aia-a-whisper-03.whisper-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-whisper-08.whisper-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-whisper-03.whisper-rv32-max.elf` (+ `.objdump`)
- `u30-aia-a-whisper-08.whisper-rv32-max.elf` (+ `.objdump`)
- `u31-aia-b-T-04.whisper-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-06.whisper-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-04.whisper-rv32-max.elf` (+ `.objdump`)
- `u31-aia-b-T-06.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64 phantom SEIP (03)
SA-MISMATCH: W03: after the APLIC asserts MEI, mvip[9] (B) is still 0 (machine.adoc:1438-1443) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: W03: after both APLIC sources clear, mip.SEIP = B|E = 0 expect=0x0000000000000000 got=0x0000000000000001
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-whisper-03.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv64 lost MEIP (08)
SA-MISMATCH: W08: eidelivery=0x40000000: csrw mireg (eithreshold, same value) leaves the APLIC's MEIP = 1 (IMSIC.adoc:441) expect=0x0000000000000001 got=0x0000000000000000
SA-MISMATCH: W08: csrrw mtopei (claim, file empty) leaves the APLIC's MEIP = 1 expect=0x0000000000000001 got=0x0000000000000000
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-whisper-08.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 phantom SEIP (03)
SA-MISMATCH: W03: after the APLIC asserts MEI, mvip[9] (B) is still 0 (machine.adoc:1438-1443) expect=0x00000000 got=0x00000001
SA-MISMATCH: W03: after both APLIC sources clear, mip.SEIP = B|E = 0 expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-whisper-03.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 lost MEIP (08)
SA-MISMATCH: W08: eidelivery=0x40000000: csrw mireg (eithreshold, same value) leaves the APLIC's MEIP = 1 (IMSIC.adoc:441) expect=0x00000001 got=0x00000000
SA-MISMATCH: W08: csrrw mtopei (claim, file empty) leaves the APLIC's MEIP = 1 expect=0x00000001 got=0x00000000
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-whisper-08.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv64 phantom SEIP on an M claim (T-04)
SA-MISMATCH: T04: after the M claim while S asserts: mvip[9] (software SEIP) = 0 (machine.adoc:1436-1456) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T04: after the S claim: mip.SEIP = B|E = 0 (software never wrote B) expect=0x0000000000000000 got=0x0000000000000001
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-04.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv64 lost MEIP on eidelivery 1 -> 0x40000000 (T-06)
SA-MISMATCH: INFO T06: eidelivery = 1, M file empty: MEIP (0 expected) expect=0x000000005a5a5a5a got=0x0000000000000000
SA-MISMATCH: T06: eidelivery back to 0x40000000 with the APLIC asserting: MEIP = 1 (IMSIC.adoc:441) expect=0x0000000000000001 got=0x0000000000000000
SA-MISMATCH: T06: ... MEIP = 1 after a delay loop expect=0x0000000000000001 got=0x0000000000000000
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-06.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 phantom SEIP on an M claim (T-04)
SA-MISMATCH: T04: after the M claim while S asserts: mvip[9] (software SEIP) = 0 (machine.adoc:1436-1456) expect=0x00000000 got=0x00000001
SA-MISMATCH: T04: after the S claim: mip.SEIP = B|E = 0 (software never wrote B) expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-04.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 lost MEIP on eidelivery 1 -> 0x40000000 (T-06)
SA-MISMATCH: INFO T06: eidelivery = 1, M file empty: MEIP (0 expected) expect=0x5a5a5a5a got=0x00000000
SA-MISMATCH: T06: eidelivery back to 0x40000000 with the APLIC asserting: MEIP = 1 (IMSIC.adoc:441) expect=0x00000001 got=0x00000000
SA-MISMATCH: T06: ... MEIP = 1 after a delay loop expect=0x00000001 got=0x00000000
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-06.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
