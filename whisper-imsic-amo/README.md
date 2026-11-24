# AMOs to IMSIC and APLIC registers are performed (seteipnum, APLIC setipnum, domaincfg, clrie) instead of faulting or being ignored

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

`amoor.w` (and `amoswap.w`) of 7 to the M-level interrupt file's seteipnum_le completes without a fault and
sets eip0 bit 7: the AMO acts as a 32-bit store. 8/16-bit, 64-bit and misaligned stores are handled correctly.
The APLIC behaves the same: `amoswap.w`/`amoor.w`/`amoadd.w` of 1 to setipnum set IP[1], `amoor.w` 0x100 to domaincfg
(IE = 0) sets IE, and `amoor.w` 2 to clrie[0] clears IE[1]; no trap is taken, and each AMO acts as a read-modify-write
of the register.

## Correct behavior

Only naturally aligned 32-bit simple reads and writes are supported; an AMO should fault, and must otherwise
be ignored, in both the IMSIC and the APLIC. Legal outcomes: store/AMO access fault, or completion with the device
registers unchanged.

```
amoor.w x?, 7, (seteipnum_le of the M file); then poll eip0 200 times
  Expected: store/AMO access fault (7), or no trap and eip0 bit 7 = 0
  Observed: no trap, eip0 bit 7 = 1 (same for amoswap.w)
Control: sw 7 to seteipnum_le sets eip0 bit 7 (correct)
APLIC (M domain): amoor.w 0x100 -> domaincfg (IE = 0); amoswap/amoor/amoadd.w 1 -> setipnum; amoor.w 2 -> clrie[0]
  Expected: access fault (7), or no trap with domaincfg.IE = 0, IP[1] = 0, IE[1] = 1
  Observed: no trap; domaincfg.IE = 1, IP[1] = 1 after each AMO, IE[1] = 0
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: `u30-aia-a-T-06.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32: `u30-aia-a-T-06.whisper-rv32-max.elf` with `whisper-rv32-max.json`
- rv64 APLIC (u31 T-01): `u31-aia-b-T-01.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32 APLIC (u31 T-01): `u31-aia-b-T-01.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u30-aia-a-T-06.whisper-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-T-06.whisper-rv32-max.elf` (+ `.objdump`)
- `u31-aia-b-T-01.whisper-rv64-max.elf` (+ `.objdump`)
- `u31-aia-b-T-01.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64
SA-MISMATCH: T-06: amoor.w 7 to seteipnum_le does not set eip0 bit 7 (IMSIC.adoc:202-206 must ignore) expect=0x0000000000000000 got=0x0000000000000080
SA-MISMATCH: T-06: amoswap.w 7 to seteipnum_le does not set eip0 bit 7 (IMSIC.adoc:202-206 must ignore) expect=0x0000000000000000 got=0x0000000000000080
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-06.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32
SA-MISMATCH: T-06: amoor.w 7 to seteipnum_le does not set eip0 bit 7 (IMSIC.adoc:202-206 must ignore) expect=0x00000000 got=0x00000080
SA-MISMATCH: T-06: amoswap.w 7 to seteipnum_le does not set eip0 bit 7 (IMSIC.adoc:202-206 must ignore) expect=0x00000000 got=0x00000080
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-T-06.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv64 APLIC (u31 T-01)
SA-MISMATCH: T01: amoor.w 0x100 to domaincfg must not set IE (AdvPLIC.adoc:364-368: fault or ignore) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T01: amoswap.w 1 to setipnum must not set IP[1] expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T01: amoor.w 1 to setipnum must not set IP[1] expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T01: amoadd.w 1 to setipnum must not set IP[1] expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T01: amoor.w 2 to clrie[0] must not clear IE[1] expect=0x0000000000000001 got=0x0000000000000000
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 APLIC (u31 T-01)
SA-MISMATCH: T01: amoor.w 0x100 to domaincfg must not set IE (AdvPLIC.adoc:364-368: fault or ignore) expect=0x00000000 got=0x00000001
SA-MISMATCH: T01: amoswap.w 1 to setipnum must not set IP[1] expect=0x00000000 got=0x00000001
SA-MISMATCH: T01: amoor.w 1 to setipnum must not set IP[1] expect=0x00000000 got=0x00000001
SA-MISMATCH: T01: amoadd.w 1 to setipnum must not set IP[1] expect=0x00000000 got=0x00000001
SA-MISMATCH: T01: amoor.w 2 to clrie[0] must not clear IE[1] expect=0x00000001 got=0x00000000
RVCP-SUMMARY: TEST FAILED - Test File "u31-aia-b-T-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
