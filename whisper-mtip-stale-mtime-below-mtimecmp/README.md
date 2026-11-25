# mip.MTIP / mip.STIP stay 1 after mtime falls below mtimecmp / stimecmp (store to mtime, or mtime wrap)

Whisper reproducer, 2026-11-25. Found by a simulator spec review against riscv-isa-manual 3142f66f; failing on
Whisper master a0288feb and on a5554a17, with and without `--logfile`.

## What is wrong

Once `mip.MTIP` is 1 (`mtime` >= `mtimecmp`), Whisper keeps it at 1 when `mtime` drops below `mtimecmp` without a
write to `mtimecmp`:

- T1: a store to `mtime` sets it to 0 (it reads back 0, `mtimecmp` = 2^40). 100,000 reads of `mip` all have MTIP = 1.
- T2: `mtimecmp` = 2^64 - 0x80, `mtime` counts up to it (MTIP = 1), then wraps past 2^64 to a small value. 100,000
  reads of `mip` all have MTIP = 1.
- The same for `mip.STIP` with Sstc (`menvcfg.STCE` = 1) when `mtime` is written below `stimecmp`.

MTIP/STIP fall as soon as the program writes any CSR (for example `csrw mscratch`), stores to `mtimecmp` or stores to
`msip`: the tests show the CSR-write case as a passing check after each failing one.

## Correct behavior

MTIP is the output of the unsigned comparison `mtime` >= `mtimecmp` and STIP that of `time` >= `stimecmp`. When the
result of the comparison changes, whatever the reason, the pending bit must follow "eventually".

```
mtimecmp = 2^40, mtime = 2^40 + 0x10 (MTIP = 1), then mtime := 0
  Expected: mip.MTIP = 0 (eventually)
  Observed: mip.MTIP = 1 in 100,000 reads of mip
mtimecmp = 2^64 - 0x80, mtime := 2^64 - 0x100, wait until mtime has wrapped
  Expected: mip.MTIP = 0 (eventually)
  Observed: mip.MTIP = 1 in 100,000 reads of mip
menvcfg.STCE = 1, stimecmp = 2^40, mtime = 2^40 + 0x10 (STIP = 1), then mtime := 0
  Expected: mip.STIP = 0 (eventually)
  Observed: mip.STIP = 1 in 100,000 reads of mip
```

## How to run

```
./run.sh /path/to/whisper
```

Each case runs twice: without a trace file and with `--logfile /dev/null`. `run.sh` prints the failing checks, one
PASS/FAIL line per run and an overall PASS/FAIL (exit status 0 = pass).

Cases:
- `mtime-mtip.whisper-rv64-max.elf`, `mtime-mtip.whisper-rv32-max.elf` (with `whisper-rv64-max.json` /
  `whisper-rv32-max.json`): controls C1-C4 (MTIP follows `mtime` rising past `mtimecmp` and both directions of a
  `mtimecmp` write), T1 (store to `mtime`), T2 (wrap).
- `mtime-stip.whisper-rv64-max.elf`, `mtime-stip.whisper-rv32-max.elf`: controls C1-C2, T1 for STIP.
- `mtime-write.bare-rv64.elf`, `mtime-wrap.bare-rv64.elf` (with `bare-rv64.json`: rv64i_zicsr, CLINT at 0x2000000):
  T1 and T2 as bare-metal M-mode programs. This hart has no Sdtrig and no counters, so without `--logfile` it runs in
  Whisper's fast loop (the two max configurations always use the traced loop). `FAIL 1`/`FAIL 2` are controls
  (MTIP = 1 first; `mtime` really is below `mtimecmp`), `FAIL 3` is the bug.

Files:
- `run.sh`: runs every case on the Whisper binary given as argument.
- `*.elf` (+ `.objdump`): prebuilt tests.
- `whisper-rv64-max.json`, `whisper-rv32-max.json`, `bare-rv64.json`: the whisper.json of each run.
- `src/mtime-mtip.S`, `src/mtime-stip.S`, `src/sa.h`: test source in riscv-arch-test act4 `tests_ai` format (built by
  the ACT framework for the configuration named in the file name; self-checking, prints `SA-MISMATCH` lines).
- `src/bare/`: source of the bare-metal cases (`build.sh`, riscv64-unknown-elf-gcc; `common.h` is the HTIF pass/fail
  harness).

## Output on Whisper master a0288feb (a5554a17 is identical)

```
SA-MISMATCH: T1 MTIP = 0 after mtime is written back below mtimecmp (polled 100000 times) expect=0x0000000000000000 got=0x0000000000000080
SA-MISMATCH: T2 MTIP = 0 after mtime wraps below mtimecmp (polled 100000 times) expect=0x0000000000000000 got=0x0000000000000080
FAIL  mtime-mtip.whisper-rv64-max.elf
SA-MISMATCH: T1 MTIP = 0 after mtime is written back below mtimecmp (polled 100000 times) expect=0x0000000000000000 got=0x0000000000000080
SA-MISMATCH: T2 MTIP = 0 after mtime wraps below mtimecmp (polled 100000 times) expect=0x0000000000000000 got=0x0000000000000080
FAIL  mtime-mtip.whisper-rv64-max.elf --logfile /dev/null
SA-MISMATCH: T1 STIP = 0 after mtime is written back below stimecmp (polled 100000 times) expect=0x0000000000000000 got=0x0000000000000020
FAIL  mtime-stip.whisper-rv64-max.elf
SA-MISMATCH: T1 STIP = 0 after mtime is written back below stimecmp (polled 100000 times) expect=0x0000000000000000 got=0x0000000000000020
FAIL  mtime-stip.whisper-rv64-max.elf --logfile /dev/null
(the same four runs for rv32)
FAIL 3
FAIL  mtime-write.bare-rv64.elf
FAIL 3
FAIL  mtime-write.bare-rv64.elf --logfile /dev/null
FAIL 3
FAIL  mtime-wrap.bare-rv64.elf
FAIL 3
FAIL  mtime-wrap.bare-rv64.elf --logfile /dev/null
FAIL
```

## Other simulators

- Sail (71312d53 and 0.16) and Spike (982f078): `mtime-mtip` and `mtime-stip` pass on RV64 and RV32; Spike also
  passes the two bare-metal ELFs (`spike --isa=rv64i_zicsr --priv=m <elf>`).
- QEMU (master 6bf90d4 and 11.1.3, `virt`): passes T1 and `mtime-stip`; fails T2 (MTIP stays 1 after the wrap).
