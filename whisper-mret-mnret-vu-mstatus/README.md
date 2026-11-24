# MRET and MNRET to VU-mode with vsstatus.SDT = 1 write mstatus back unchanged (regression in d62c6aae)

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

With H, Smdbltrp and Ssdbltrp (menvcfg.DTE = henvcfg.DTE = 1), an MNRET to VU-mode (mnstatus.MNPP = U, MNPV = 1)
executed while mstatus.MDT = 1, sstatus.SDT = 1 and vsstatus.SDT = 1 clears vsstatus.SDT but writes mstatus back
unchanged: MDT and SDT stay 1. MRET to VU-mode (MPP = U, MPV = 1, MPIE = 1) with vsstatus.SDT = 1 loses every mstatus
update: MPV stays 1, MIE stays 0, MDT and SDT stay 1. The next trap from VU-mode is then a double trap; on the stock ACT
configuration (no nmi_vec) Whisper stops with "Core entered critical-error state due to an unexpected trap". With
vsstatus.SDT = 0 both instructions are correct.

## Correct behavior

MNRET to a mode other than M clears MDT; to U, VS or VU it also clears sstatus.SDT; to VU it also clears
vsstatus.SDT (machine.adoc:517-519). MRET does the same for MDT/SDT (machine.adoc:511-515) and, as always, sets
MIE = MPIE, MPIE = 1, MPV = 0, MPP = U (machine.adoc:406-410, hypervisor.adoc:2932-2936).

```
Case A, MNRET to VU, mstatus before = 0x8000040a01007e00 (MDT = 1, SDT = 1), vsstatus.SDT = 1
  Expected: mstatus.MDT = 0, sstatus.SDT = 0, vsstatus.SDT = 0
  Observed: mstatus = 0x8000040a01007e00 (unchanged), vsstatus.SDT = 0
Case D, MRET to VU, mstatus before = 0x8000048a01006680 (MPV = 1, MPP = U, MPIE = 1, MDT = 1, SDT = 1)
  Expected: MPV = 0, MIE = 1, MPIE = 1, MDT = 0, SDT = 0
  Observed: mstatus = 0x8000048a01006680 (unchanged)
Control C, MNRET to VU with vsstatus.SDT = 0: mstatus = 0x8000000a00007e00 (correct)
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64, stock ACT config whisper-rv64-max: `u22-smmisc-T-B4.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv64, ACT config + nmi_vec/nmi_exception_vec (rr-u22-smmisc-w64): `u22-smmisc-T-B4.rr-u22-smmisc-w64.elf` with `rr-u22-smmisc-w64.json`
- rv32, ACT config + nmi vectors (rr-u22-smmisc-w32): `u22-smmisc-T-B4.rr-u22-smmisc-w32.elf` with `rr-u22-smmisc-w32.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u22-smmisc-T-B4.whisper-rv64-max.elf` (+ `.objdump`)
- `u22-smmisc-T-B4.rr-u22-smmisc-w64.elf` (+ `.objdump`)
- `u22-smmisc-T-B4.rr-u22-smmisc-w32.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `rr-u22-smmisc-w64.json`: whisper.json used for the run
- `rr-u22-smmisc-w32.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64, stock ACT config whisper-rv64-max
Error: Failed stop: Hart 0: Core entered critical-error state due to an unexpected trap
=== rv64, ACT config + nmi_vec/nmi_exception_vec (rr-u22-smmisc-w64)
SA-MISMATCH: T-B4 A MNRET to VU (vsstatus.SDT = 1): ecall from VU is not an unexpected trap (RNMI handler not entered) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-B4 A MNRET to VU (vsstatus.SDT = 1): [if the RNMI handler was entered] mstatus.MDT recorded there expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-B4 A MNRET to VU (vsstatus.SDT = 1): [if the RNMI handler was entered] sstatus.SDT recorded there expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-B4 D MRET to VU (vsstatus.SDT = 1): ecall from VU is not an unexpected trap (RNMI handler not entered) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-B4 D MRET to VU (vsstatus.SDT = 1): [if the RNMI handler was entered] mstatus.MDT recorded there expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: T-B4 D MRET to VU (vsstatus.SDT = 1): [if the RNMI handler was entered] sstatus.SDT recorded there expect=0x0000000000000000 got=0x0000000000000001
RVCP-SUMMARY: TEST FAILED - Test File "u22-smmisc-T-B4.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32, ACT config + nmi vectors (rr-u22-smmisc-w32)
SA-MISMATCH: T-B4 A MNRET to VU (vsstatus.SDT = 1): ecall from VU is not an unexpected trap (RNMI handler not entered) expect=0x00000000 got=0x00000001
SA-MISMATCH: T-B4 A MNRET to VU (vsstatus.SDT = 1): [if the RNMI handler was entered] mstatus.MDT recorded there expect=0x00000000 got=0x00000001
SA-MISMATCH: T-B4 A MNRET to VU (vsstatus.SDT = 1): [if the RNMI handler was entered] sstatus.SDT recorded there expect=0x00000000 got=0x00000001
SA-MISMATCH: T-B4 D MRET to VU (vsstatus.SDT = 1): ecall from VU is not an unexpected trap (RNMI handler not entered) expect=0x00000000 got=0x00000001
SA-MISMATCH: T-B4 D MRET to VU (vsstatus.SDT = 1): [if the RNMI handler was entered] mstatus.MDT recorded there expect=0x00000000 got=0x00000001
SA-MISMATCH: T-B4 D MRET to VU (vsstatus.SDT = 1): [if the RNMI handler was entered] sstatus.SDT recorded there expect=0x00000000 got=0x00000001
RVCP-SUMMARY: TEST FAILED - Test File "u22-smmisc-T-B4.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
