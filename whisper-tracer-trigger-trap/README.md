# Whisper: a --tracerlib extension gets no record for a trap taken by a trigger unless --logfile is given

`trig.S` (RV64, M-mode then U-mode) sets an execute-address breakpoint trigger (mcontrol6, action 0,
`u` = 1) on `target`, then drops to U-mode at `target` with `mret`. The trigger fires before `target`
executes; the M-mode handler checks mcause = 3 (check 1) and mepc = `target` (check 2). On failure it
prints `FAIL n` on the HTIF console and writes `(n << 1) | 1` to `tohost`.

`pctrace.cpp` is a minimal tracer extension: it writes `<pc> RET` or `<pc> TRAP` for every record it
receives. `run.sh` runs the program with the extension, without and with `--logfile`, and checks that the
extension received a TRAP record at `target`.

Expected: PASS in both runs. Whisper master (d62c6aae, `master.out`): the program passes both times, but
without `--logfile` the extension's records go from the `mret` (0x80000058) straight to the handler
(0x80000068); there is no record at `target` (0x8000005c):

```
FAIL  trig.elf  : tracer got no TRAP record at target (000000008000005c); records: ... 80000058 RET 80000068 RET ...
PASS  trig.elf --logfile LOG
FAIL
```

`fixed.out` is the output with the fix ([tenstorrent/whisper#368](https://github.com/tenstorrent/whisper/pull/368)). Issue: [tenstorrent/whisper#367](https://github.com/tenstorrent/whisper/issues/367).

## Run

`./build.sh path/to/whisper-source` (once), then `./run.sh path/to/whisper` (prints PASS or FAIL per run
and overall; exit status 0 = pass). `pctrace.so` must be built against the same Whisper source as the
binary.

The program alone also runs on Spike (`spike --isa=rv64i_zicsr trig.elf`) and Sail
(`sail_riscv_sim --config <sail.json with Sdtrig> trig.elf`); exit status 0 = pass.

## Build

`./build.sh path/to/whisper-source` (riscv64-unknown-elf-gcc for `trig.elf`, g++ for `pctrace.so`;
`common.h` is the HTIF pass/fail harness, `link.ld` places the code at 0x80000000).
