# Writing pmpaddr(i-1) while entry i-1 is OFF does not move the lower bound of TOR entry i, even after SFENCE.VMA

Whisper reproducer, 2026-11-21. Found by a four-simulator spec review against riscv-isa-manual 3142f66f (plus
riscv-aia 9507866 and riscv-debug-spec 40e5c35); failing on Whisper master a0288feb (and on a5554a17).

## What is wrong

Entry 1 is OFF and entry 2 is TOR covering [pmpaddr1, pmpaddr2). Writing only pmpaddr1 (moving entry 2's
bottom down to A') and executing SFENCE.VMA x0, x0 leaves Whisper matching the old range: an S-mode load at A' takes a
load access fault (cause 5). pmpaddr1 reads back the new value. Rewriting pmpcfg0 with its unchanged value makes the
load succeed.

## Correct behavior

TOR entry i matches pmpaddr(i-1) <= y < pmpaddr(i) "irrespective of the value of pmpcfg(i-1)", so the write
to pmpaddr1 moves entry 2's lower bound; after the SFENCE.VMA the load at A' succeeds.

```
pmpcfg: entry 1 OFF, entry 2 TOR RWX; pmpaddr1 changed from A>>2 to A'>>2 (A' < A), sfence.vma x0, x0
  Expected: S-mode lw at A' succeeds
  Observed: load access fault, mcause = 5
```

## How to run

```
./run.sh /path/to/whisper
```

Cases:
- rv64: `v2-u21w-01-pmp-tor.whisper-rv64-max.elf` with `whisper-rv64-max.json`
- rv32: `v2-u21w-01-pmp-tor.whisper-rv32-max.elf` with `whisper-rv32-max.json`

Files:
- `run.sh`: runs every case below on the Whisper binary given as argument.
- `v2-u21w-01-pmp-tor.whisper-rv64-max.elf` (+ `.objdump`)
- `v2-u21w-01-pmp-tor.whisper-rv32-max.elf` (+ `.objdump`)
- `whisper-rv64-max.json`: whisper.json used for the run
- `whisper-rv32-max.json`: whisper.json used for the run
- `src/`: test source (riscv-arch-test act4 `tests_ai` format with `sa.h`; built by the ACT framework for the config named in the file name; self-checking, prints `SA-MISMATCH` lines on failure)

## Output on Whisper master a5554a17 (key lines)

```
=== rv64
SA-MISMATCH: after pmpaddr1 = A'>>2 and sfence.vma: S load at A' inside TOR [A',B) (number of traps) expect=0x0000000000000000 got=0x0000000000000001
SA-MISMATCH: after pmpaddr1 = A'>>2 and sfence.vma: S load at A' inside TOR [A',B) (xcause, -1 = none) expect=0xffffffffffffffff got=0x0000000000000005
RVCP-SUMMARY: TEST FAILED - Test File "v2-u21w-01-pmp-tor.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
=== rv32
SA-MISMATCH: after pmpaddr1 = A'>>2 and sfence.vma: S load at A' inside TOR [A',B) (number of traps) expect=0x00000000 got=0x00000001
SA-MISMATCH: after pmpaddr1 = A'>>2 and sfence.vma: S load at A' inside TOR [A',B) (xcause, -1 = none) expect=0xffffffff got=0x00000005
RVCP-SUMMARY: TEST FAILED - Test File "v2-u21w-01-pmp-tor.S"
RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
Error: Failed stop: Hart 0: write to to-host
```
