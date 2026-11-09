# Whisper: with misa.H cleared, SRET with a stale hstatus.SPV = 1 stops Whisper on an assertion

With H disabled, `hstatus` and the virtualization mode do not exist (machine.adoc norm:misa_extensions_disabling),
so an SRET returns to the mode in `sstatus.SPP` with V = 0. Whisper's `execSret` uses the `hstatus.SPV` value
cached before H was cleared, then tries to clear it with a CSR write of `hstatus`, which fails, and the failure path
is an assertion.

`whisper-misa-h-sret-spv.S` runs in M-mode with its own trap handler (and checks nothing if `misa.H` is
read-only): it sets `hstatus.SPV` = 1 and `sstatus.SPP` = S, clears `misa.H`, executes `sret` to an `ecall` and
checks that the ecall comes from S-mode (mcause 9).

Run: `./run.sh path/to/whisper` (exit status 0 = pass). It runs `whisper-misa-h-sret-spv-rv64.elf` with
`whisper-rv64.json` and `whisper-misa-h-sret-spv-rv32.elf` with `whisper-rv32.json`. The configurations are riscv-arch-test's `config/whisper/whisper-rv64-max/whisper.json` and `whisper-rv32-max/whisper.json`
with `misa` mask and poke mask 0x3410af (A, B, C, D, F, H, M, S, U and V writable; riscv-arch-test makes only C
writable, mask 0x4).

Whisper master fa18e475:

```
FAIL whisper-misa-h-sret-spv-rv64.elf (no test result; last lines of output:)
    whisper: Hart.cpp:12844: void WdRiscv::Hart<URV>::execSret(const WdRiscv::DecodedInst*) [with URV_ = long unsigned int]: Assertion `0 && "Error: Assertion failed"' failed.
FAIL whisper-misa-h-sret-spv-rv32.elf (no test result; last lines of output:)
    whisper: Hart.cpp:12844: void WdRiscv::Hart<URV>::execSret(const WdRiscv::DecodedInst*) [with URV_ = unsigned int]: Assertion `0 && "Error: Assertion failed"' failed.
```

With the fix, both pass.

The ELFs were built with the riscv-arch-test act4 framework (riscv/riscv-arch-test#3162, commit 205129dbd8, for
the whisper-rv64-max configuration with the writable misa above, and for whisper-rv32-max); `sa.h` has the `SA_CHECK` macro. Rebuilding needs that framework.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09), with the same test built for each: Spike and Sail pass (both make `misa.H` writable). Imperas (stock configuration, where `misa.H` is writable) fails differently: the SRET enters VS-mode and the ecall has mcause 10.
