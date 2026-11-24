# RV32: vsiph (and VS-mode siph) raise illegal-instruction while vsiselect is 0x40-0x5F

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

On RV32 with H and Ssaia, after M-mode writes vsiselect = 0x40, HS-mode `csrr vsiph` (0x254) and VS-mode
`csrr siph` (0x154, which accesses vsiph) raise illegal-instruction. With Smcdeleg enabled, M-mode `csrr vsiph` traps too.
The same accesses with vsiselect = 0x30, and `csrr vsieh` with vsiselect = 0x40, do not trap.

## Correct behavior

The Smcdeleg rule for vsiselect 0x40-0x5F covers only sireg*/vsireg*. vsiph and siph are AIA high-half CSRs,
not indirect aliases, and their accessibility does not depend on vsiselect: none of these accesses traps.

```
vsiselect = 0x40, mstateen0h/hstateen0h with SE0, CSRIND, AIA, IMSIC set, hvictl.VTI = 0
  HS csrr vsiph    Expected: no trap   Observed: illegal instruction (2)
  VS csrr siph     Expected: no trap   Observed: illegal instruction (2)
  M  csrr vsiph    Expected: no trap   Observed: illegal instruction (2) (Smcdeleg enabled)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv32, stock ACT config: `u22-smmisc-whisper-01.whisper-rv32-max.elf` with `whisper-rv32-max.json`
- rv32, ACT config + smcdeleg/smcsrind (rr-u22-smmisc-w32): `u22-smmisc-whisper-01.rr-u22-smmisc-w32.elf` with `rr-u22-smmisc-w32.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u22-smmisc-whisper-01.whisper-rv32-max.elf` (+ `.objdump`)
- `u22-smmisc-whisper-01.rr-u22-smmisc-w32.elf` (+ `.objdump`)
- `whisper-rv32-max.json`: whisper.json used for the run
- `rr-u22-smmisc-w32.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv32, stock ACT config
SA-MISMATCH: vsiselect=0x40: HS csrr vsiph (0x254) -> no trap (vsiph is not a vsireg alias) expect=0xffffffff got=0x00000002
SA-MISMATCH: vsiselect=0x40: VS csrr siph (0x154 -> vsiph) -> no trap expect=0xffffffff got=0x00000002
RVCP-SUMMARY: TEST FAILED - Test File "u22-smmisc-whisper-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32, ACT config + smcdeleg/smcsrind (rr-u22-smmisc-w32)
SA-MISMATCH: vsiselect=0x40: HS csrr vsiph (0x254) -> no trap (vsiph is not a vsireg alias) expect=0xffffffff got=0x00000002
SA-MISMATCH: vsiselect=0x40: VS csrr siph (0x154 -> vsiph) -> no trap expect=0xffffffff got=0x00000002
SA-MISMATCH: vsiselect=0x40: M csrr vsiph -> no trap expect=0xffffffff got=0x00000002
RVCP-SUMMARY: TEST FAILED - Test File "u22-smmisc-whisper-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
