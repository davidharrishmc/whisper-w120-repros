# APLIC: the Guest Index field of a supervisor-level domain's target[i] is writable on harts without H

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

On harts with S-mode but no H, an S-level APLIC domain in MSI delivery mode (domaincfg = 0x80000004) with
source 2 delegated and active (Edge1): `sw 0x5003` (Hart Index 0, Guest Index 5, EIID 3) to the S domain's target[2]
reads back 0x5003. The control with H (GEILEN 63/31) correctly holds Guest Index 5.

## Correct behavior

Without H, Guest Index of a supervisor-level domain is read-only zero: target[2] reads 0x3.

```
S-without-H config (misa.H = 0, GEILEN 0); S domain MSI mode; sw 0x5003 -> S target[2]
  Expected: 0x00000003      Observed: 0x00005003
Control, config with H: 0x5003 read back (correct)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64, S without H (whisper-rv64-noh = whisper-rv64-max minus H): `u31-aia-b-T-07b.noh.rv64.elf` with `whisper-rv64-noh.json`
- rv32, S without H (whisper-rv32-noh): `u31-aia-b-T-07b.noh.rv32.elf` with `whisper-rv32-noh.json`
- rv64, control with H (whisper-rv64-h = whisper-rv64-max, GEILEN 63): Guest Index 5 held: `u31-aia-b-T-07b.h.rv64.elf` with `whisper-rv64-h.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u31-aia-b-T-07b.noh.rv64.elf` (+ `.objdump`)
- `u31-aia-b-T-07b.noh.rv32.elf` (+ `.objdump`)
- `u31-aia-b-T-07b.h.rv64.elf` (+ `.objdump`)
- `whisper-rv64-noh.json`: whisper.json used for the run
- `whisper-rv32-noh.json`: whisper.json used for the run
- `whisper-rv64-h.json`: whisper.json used for the run
- `src/`: test source (bare: build with `riscv64-unknown-elf-gcc -nostdlib -nostartfiles -march=rv64gch_zicsr_zifencei_zicfilp_zawrs_zicond -mabi=lp64 -DHAS_S -DHAS_U [-DEXPECT_H] -DUART=0x10000000 -DWHISPER -Isrc -T src/link.ld (RV32: -march=rv32gch_zicsr_zifencei_zicfilp_zawrs -mabi=ilp32); the test prints FAIL lines on the UART`)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64, S without H (whisper-rv64-noh = whisper-rv64-max minus H)
FAIL: T07b: harts without H: S target[2] Guest Index read-only zero (AdvPLIC.adoc:948-951) exp=0x0000000000000003 got=0x0000000000005003
u31-aia-b-T-07b: checks=4 failures=1 RESULT=FAIL
Error: Failed stop: Hart 0: write to to-host
tohost = 0x0000000000000003
=== rv32, S without H (whisper-rv32-noh)
FAIL: T07b: harts without H: S target[2] Guest Index read-only zero (AdvPLIC.adoc:948-951) exp=0x00000003 got=0x00005003
u31-aia-b-T-07b: checks=4 failures=1 RESULT=FAIL
Error: Failed stop: Hart 0: write to to-host
tohost = 0x00000003
=== rv64, control with H (whisper-rv64-h = whisper-rv64-max, GEILEN 63): Guest Index 5 held
u31-aia-b-T-07b: checks=4 failures=0 RESULT=PASS
Successful stop: Hart 0: write to to-host
tohost = 0x0000000000000001
```
