# Whisper: CSR instructions do not write rd when their misa or satp write is suppressed

A CSR instruction reads the old value of the CSR into rd (zicsr.adoc norm:csrrw_op, norm:csrrs_op) even when its
CSR write has no effect. Whisper skips rd in two cases: a `misa` write that would clear C when the next instruction
is not 4-byte aligned (the write is suppressed, machine.adoc norm:misa_inc_ialign), and a `satp`/`vsatp` write with
an unsupported MODE (the write is ignored, supervisor.adoc norm:satp_mode_op_unsupported).

`whisper-csr-suppressed-rd.S` runs in M-mode and presets x7 = 0x5555 before each instruction:

1. `csrrw x7, misa, (misa without C)` at an address = 2 mod 4: `misa` must be unchanged and x7 = the old `misa`
   (the configurations make `misa.C` writable, so the write is suppressed);
2. `csrrw x7, satp, (MODE = 1, reserved on RV64)` with `satp` = 0: `satp` must stay 0 and x7 = 0 (RV64 only);
3. `csrrs x7, satp, (MODE = 1)`: x7 = 0 (RV64 only).

Each failed check prints an `SA-MISMATCH` line (the misa check prints x7 - old misa).

Run: `./run.sh path/to/whisper` (exit status 0 = pass). It runs `whisper-csr-suppressed-rd-rv64.elf` with
`whisper-rv64.json` and `whisper-csr-suppressed-rd-rv32.elf` with `whisper-rv32.json`, which are riscv-arch-test's
`config/whisper/whisper-rv64-max/whisper.json` and `whisper-rv32-max/whisper.json`, unchanged.

Whisper master fa18e475:

```
FAIL whisper-csr-suppressed-rd-rv64.elf
  SA-MISMATCH: 1: csrrw rd when the misa write is suppressed (rd - old misa) expect=0x0000000000000000 got=0x7fffffffffcc43a6
  SA-MISMATCH: 2: csrrw rd when the satp write has a reserved MODE (old satp = 0) expect=0x0000000000000000 got=0x0000000000005555
  SA-MISMATCH: 3: csrrs rd when the satp write has a reserved MODE (old satp = 0) expect=0x0000000000000000 got=0x0000000000005555
  RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
FAIL whisper-csr-suppressed-rd-rv32.elf
  SA-MISMATCH: 1: csrrw rd when the misa write is suppressed (rd - old misa) expect=0x00000000 got=0xbfcc43a6
  RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
```

With the fix, both pass.

The ELFs were built with the riscv-arch-test act4 framework (riscv/riscv-arch-test#3162, commit 205129dbd8, for
the whisper-rv64-max and whisper-rv32-max configurations); `sa.h` has the `SA_SOFT` check macros. Rebuilding needs
that framework.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09), with the same test built for each: Spike, Sail and Imperas pass on RV64 and RV32.
