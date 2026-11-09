# Whisper: clearing misa.S leaves misa.H set

The hypervisor extension turns S-mode into HS-mode, so it depends on S. A `misa` write that disables S while
leaving H enabled must disable both (machine.adoc norm:misa_extensions_dependencies). Whisper's `misa`
legalization clears S without U, D without F and V without F or D, but not H without S.

`whisper-misa-h-without-s.S` runs in M-mode (and checks nothing if `misa.H` is 0):

1. `csrc misa, S` (if S is writable): `misa.S` and `misa.H` must read 0;
2. after restoring `misa`, `csrc misa, U` (if U is writable): `misa.U`, `misa.S` and `misa.H` must read 0.

Each failed check prints an `SA-MISMATCH` line.

Run: `./run.sh path/to/whisper` (exit status 0 = pass). It runs `whisper-misa-h-without-s-rv64.elf` with
`whisper-rv64.json` and `whisper-misa-h-without-s-rv32.elf` with `whisper-rv32.json`. The configurations are riscv-arch-test's `config/whisper/whisper-rv64-max/whisper.json` and `whisper-rv32-max/whisper.json`
with `misa` mask and poke mask 0x3410af (A, B, C, D, F, H, M, S, U and V writable; riscv-arch-test makes only C
writable, mask 0x4).

Whisper master fa18e475:

```
FAIL whisper-misa-h-without-s-rv64.elf
  SA-MISMATCH: 1: misa.H after csrc misa, S (H depends on S) expect=0x0000000000000000 got=0x0000000000000001
  SA-MISMATCH: 2: misa.H after csrc misa, U (H depends on S) expect=0x0000000000000000 got=0x0000000000000001
  RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
FAIL whisper-misa-h-without-s-rv32.elf
  SA-MISMATCH: 1: misa.H after csrc misa, S (H depends on S) expect=0x00000000 got=0x00000001
  SA-MISMATCH: 2: misa.H after csrc misa, U (H depends on S) expect=0x00000000 got=0x00000001
  RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
```

With the fix, both pass.

The ELFs were built with the riscv-arch-test act4 framework (riscv/riscv-arch-test#3162, commit 205129dbd8, for
the whisper-rv64-max configuration with the writable misa above, and for whisper-rv32-max); `sa.h` has the `SA_SOFT` check macros. Rebuilding needs
that framework.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09), with the same test built for each: Sail (S, U and H writable in `misa` by default) and Imperas with `misa_Extensions_mask=0x3410af` pass. Spike and the stock Imperas configuration do not make `misa.S` and `misa.U` writable, so the test checks nothing there.
