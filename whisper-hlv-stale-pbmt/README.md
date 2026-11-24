# With hgatp = Bare, HLV/HSV use the PBMT of the HS-mode instruction fetch

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

HS-mode runs with satp = Sv39 (an identity gigapage over the image whose leaf PBMT is NC or IO) and hgatp =
Bare. `hlv.d` through vsatp = Sv39, whose VS leaf needs a hardware A-bit update (menvcfg.ADUE = henvcfg.ADUE = 1), takes
a load access fault (cause 5) and leaves A clear (cases C3 NC, C4 IO). With code PBMT = 0 it completes and sets A (C2).
A misaligned `hlv.w` with vsatp = Bare also faults with cause 5 when the code page is IO (C1) and completes when it is
PMA (C0).

## Correct behavior

HLV/HSV are translated by vsatp and hgatp, never by the HS satp, so the PBMT of the page that holds the HLV
instruction plays no part. With hgatp = Bare the PMAs are the intermediate attributes; with VS PBMT = 0 the access and
the VS A-bit update are main-memory accesses and succeed.

```
hgatp = Bare, vsatp = Sv39, VS leaf A = 0, ADUE = 1, hlv.d from HS code on a satp page with PBMT = NC / IO
  Expected: hlv.d completes, VS leaf A = 1
  Observed: load access fault (cause 5), A not set
Misaligned hlv.w, vsatp = Bare, HS code page PBMT = IO
  Expected: completes (or address-misaligned, cause 4)   Observed: cause 5
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: `u28-hyp-b-whisper-01.whisper-rv64-max.elf` with `whisper-rv64-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `u28-hyp-b-whisper-01.whisper-rv64-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64
SA-MISMATCH: C1 code PBMT=IO, misaligned hlv.w: no trap or misaligned (xcause, -1 = none) expect=0xffffffffffffffff got=0x0000000000000005
SA-MISMATCH: C1 code PBMT=IO, misaligned hlv.w: value expect=0x0000000033445566 got=0x0000000000000000
SA-MISMATCH: C3 code PBMT=NC: hlv.d needing a VS A-bit update: no trap (xcause, -1 = none) expect=0xffffffffffffffff got=0x0000000000000005
SA-MISMATCH: C3 code PBMT=NC: value expect=0x1122334455667788 got=0x0000000000000000
SA-MISMATCH: C3 code PBMT=NC: VS leaf A bit set expect=0x0000000000000001 got=0x0000000000000000
SA-MISMATCH: C4 code PBMT=IO: hlv.d needing a VS A-bit update: no trap (xcause, -1 = none) expect=0xffffffffffffffff got=0x0000000000000005
SA-MISMATCH: C4 code PBMT=IO: value expect=0x1122334455667788 got=0x0000000000000000
SA-MISMATCH: C4 code PBMT=IO: VS leaf A bit set expect=0x0000000000000001 got=0x0000000000000000
RVCP-SUMMARY: TEST FAILED - Test File "u28-hyp-b-whisper-01.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
