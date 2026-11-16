# Whisper: the trace does not report the ssp write of sspush and sspopchk

`ssp.S` (RV64, S-mode, `menvcfg.SSE` = 1, Sv39) maps the code with an identity RWX gigapage and the same
memory at VA 0x40000000 as a shadow-stack (W-only) gigapage. It writes `ssp`, executes `sspush ra`
(`ssp` -= 8) and `sspopchk ra` (`ssp` += 8), and checks `ssp` after each (checks 1 and 2). On failure it
prints `FAIL n` on the HTIF console and writes `(n << 1) | 1` to `tohost`.

`run.sh` runs the program with `--logfile` and checks that the log reports the `ssp` write (CSR 0x011) on
the `sspush` and on the `sspopchk`.

Expected: PASS. Whisper master (d62c6aae, `master.out`): the `ssp` values are right, but the log has no
`ssp` line for either instruction:

```
PASS  program (ssp values)
FAIL  log reports no ssp write on push (00000000800000a4):
        #42 0  S 00000000800000a4 ce104073 m 0000000040003038 0000000000001234 sspush    x1 [0x40003038:0x80003038]
FAIL  log reports no ssp write on pop (00000000800000b4):
        #46 0  S 00000000800000b4 cdc0c073 r 0000000000000000 0000000000000000 sspopchk x1 [0x40003038:0x80003038]
FAIL
```

`fixed.out` is the output with the fix.

## Run

`./run.sh path/to/whisper` (prints PASS or FAIL per check and overall; exit status 0 = pass).

The same ELF runs on Spike (`spike --isa=rv64ima_zicsr_zimop_zicfiss -l --log-commits ssp.elf`, which logs
`c17_ssp` on both instructions) and Sail (`sail_riscv_sim --config <sail.json with Zicfiss> ssp.elf`).

## Build

`./build.sh` (riscv64-unknown-elf-gcc; `common.h` is the HTIF pass/fail harness, `link.ld` places the code at
0x80000000).
