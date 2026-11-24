# VS-mode can access vsip/vsie while hvictl.VTI = 1, and on RV32 vsiph/vsieh always, instead of raising virtual-instruction

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

vsip, vsie and (RV32) vsiph, vsieh are hypervisor/VS CSRs, but VS-mode can read and write them directly in two
cases. (1) With hvictl.VTI = 1 (IID 9, IPRIO 0), VS-mode `csrr vsip` (0x244), `csrr vsie` (0x204), `csrw vsie` and, on
RV32, `csrr vsiph` (0x254) and `csrr vsieh` (0x214) complete; the write reaches vsie. With VTI = 0, `csrr vsip` raises
virtual-instruction correctly. (2) On RV32, VS-mode `csrr vsiph` / `csrr vsieh` also complete when hvictl has never been
written, with mstateen0/hstateen0 all ones; they trap only when a stateen AIA bit blocks them.

## Correct behavior

A VS-mode access to a hypervisor or VS CSR raises virtual-instruction (22) whatever hvictl holds; VTI only
adds traps (for sip/sie, siph/sieh).

```
hvictl = VTI | IID 9, VS-mode:
  csrr vsip / csrr vsie / csrw vsie       Expected: virtual instruction (22)   Observed: no trap
  RV32 csrr vsiph / csrr vsieh            Expected: 22                         Observed: no trap
RV32, hvictl never written, mstateen0/h = hstateen0/h = ~0, VS-mode:
  csrr vsiph / csrr vsieh                 Expected: 22                         Observed: no trap
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64 vsip/vsie with VTI = 1: `u30-aia-a-whisper-01.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32 vsip/vsie/vsiph/vsieh with VTI = 1: `u30-aia-a-whisper-01.whisper-rv32-max.elf` with `whisper-rv32-max.json`
- rv32 vsiph/vsieh before any hvictl write: `u23-smstateen-T-06.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u30-aia-a-whisper-01.whisper-rv64-max.elf` (+ `.objdump`)
- `u30-aia-a-whisper-01.whisper-rv32-max.elf` (+ `.objdump`)
- `u23-smstateen-T-06.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64 vsip/vsie with VTI = 1
SA-MISMATCH: W01: VS csrr vsip (0x244) with hvictl.VTI=1: virtual instruction expect=0x0000000000001316 got=0x00000000000000ff
SA-MISMATCH: W01: VS csrr vsie (0x204) with hvictl.VTI=1: virtual instruction expect=0x0000000000001316 got=0x00000000000000ff
SA-MISMATCH: W01: VS csrw vsie (0x204) with hvictl.VTI=1: virtual instruction expect=0x0000000000001316 got=0x00000000000000ff
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-whisper-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 vsip/vsie/vsiph/vsieh with VTI = 1
SA-MISMATCH: W01: VS csrr vsip (0x244) with hvictl.VTI=1: virtual instruction expect=0x00001316 got=0x000000ff
SA-MISMATCH: W01: VS csrr vsie (0x204) with hvictl.VTI=1: virtual instruction expect=0x00001316 got=0x000000ff
SA-MISMATCH: W01: VS csrw vsie (0x204) with hvictl.VTI=1: virtual instruction expect=0x00001316 got=0x000000ff
SA-MISMATCH: W01: RV32 VS csrr vsiph (0x254) with hvictl.VTI=1: virtual instruction expect=0x00001316 got=0x000000ff
SA-MISMATCH: W01: RV32 VS csrr vsieh (0x214) with hvictl.VTI=1: virtual instruction expect=0x00001316 got=0x000000ff
RVCP-SUMMARY: TEST FAILED - Test File "u30-aia-a-whisper-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32 vsiph/vsieh before any hvictl write
SA-MISMATCH: A1 VS csrr vsiph, mstateen0 = ~0: 22 expect=0x00000016 got=0xffffffff
SA-MISMATCH: A2 VS csrr vsieh, mstateen0 = ~0: 22 expect=0x00000016 got=0xffffffff
SA-MISMATCH: B1 VS csrr vsiph, mstateen0.CSRIND = 0, AIA = 1: 22 expect=0x00000016 got=0xffffffff
SA-MISMATCH: B2 VS csrr vsieh, mstateen0.CSRIND = 0, AIA = 1: 22 expect=0x00000016 got=0xffffffff
RVCP-SUMMARY: TEST FAILED - Test File "u23-smstateen-T-06.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
