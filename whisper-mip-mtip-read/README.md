# Whisper: with interrupts disabled, mip.MTIP is not updated when mtime passes mtimecmp (without --logfile)

`mtip.S` (RV64, M-mode, `mstatus.MIE` = 0, `mie` = 0) sets `mtimecmp` = `mtime` + 16 through the CLINT at
0x2000000, spins for 100,000 iterations, checks that `mtime` >= `mtimecmp` (check 1), then reads `mip` up to
100,000 times and checks that MTIP (bit 7) becomes 1 (check 2). On failure it prints `FAIL n` on the HTIF console and writes
`(n << 1) | 1` to `tohost`.

Expected: PASS in both runs. Whisper master (d62c6aae, `master.out`):

```
FAIL  mtip.elf  : FAIL 2
PASS  mtip.elf --logfile LOG
FAIL
```

`fixed.out` is the output with the fix.

## Run

`./run.sh path/to/whisper` (prints PASS or FAIL per run and overall; exit status 0 = pass).

The same ELF runs on Spike (`spike --isa=rv64i_zicsr --priv=m mtip.elf`), Sail
(`sail_riscv_sim --config <sail.json> mtip.elf`, CLINT at 0x2000000) and QEMU (`qemu-system-riscv64
-machine spike -bios none -kernel mtip.elf -nographic`); the exit status is the failing check (0 = pass).

## Build

`./build.sh` (riscv64-unknown-elf-gcc; `common.h` is the HTIF pass/fail harness, `link.ld` places the code at
0x80000000).
