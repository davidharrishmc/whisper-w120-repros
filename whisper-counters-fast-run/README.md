# Whisper: without --logfile, mcountinhibit is ignored and (M-only harts) mcycle/minstret do not count

`counters.S` (RV64, M-mode) checks that `minstret` and `mcycle` advance over 32 `nop`s while not inhibited
(checks 1 and 2), then sets `mcountinhibit` = 5 (CY, IR) and checks that neither advances over 32 more
`nop`s (checks 3 and 4; skipped if `mcountinhibit` does not read back 5). On failure it prints `FAIL n` on the
HTIF console and writes `(n << 1) | 1` to `tohost`.

The hart has no Zicntr (the `mcycle`/`minstret` CSRs exist without it), so Whisper runs the fast loops
`simpleRunNoLimit` (`whisper-m.json`, M-only) or `simpleRunWithLimit` (`whisper-mu.json`, M and U) unless a
trace file is given. Expected: PASS in all four runs. Whisper master (d62c6aae, `master.out`):

```
FAIL  whisper-m.json  : FAIL 1
PASS  whisper-m.json --logfile LOG
FAIL  whisper-mu.json  : FAIL 3
PASS  whisper-mu.json --logfile LOG
FAIL
```

`fixed.out` is the output with the fix.

## Run

`./run.sh path/to/whisper` (prints PASS or FAIL per run and overall; exit status 0 = pass).

The same ELF runs on Spike (`spike --isa=rv64i_zicsr --priv=m counters.elf`), Sail
(`sail_riscv_sim --config <sail.json> counters.elf`), QEMU (`qemu-system-riscv64 -machine spike -bios none
-kernel counters.elf -nographic`); the exit status is the failing check (0 = pass).

## Build

`./build.sh` (riscv64-unknown-elf-gcc; `common.h` is the HTIF pass/fail harness, `link.ld` places the code at
0x80000000).
