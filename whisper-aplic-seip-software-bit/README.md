# Whisper: the APLIC's supervisor external interrupt is written into the software-writable mip.SEIP bit

`mip.SEIP` reads as the OR of a software-writable bit (B) and the supervisor external interrupt signal from the
interrupt controller (E), and CSR writes of `mip` change only B (machine.adoc norm:intr_sei_op, norm:mip_seip_rdcsr,
norm:mip_seip_wrcsr). Whisper's APLIC direct-delivery callback sets and clears bit 9 of `mip`, i.e. B, so a CSR
write of `mip` loses a real external interrupt, and the APLIC deasserting clears a bit software set.

`whisper-aplic-seip.S` runs in M-mode with interrupts disabled. It raises the interrupt with
`RVMODEL_SET_SEXT_INT` (APLIC supervisor domain, source 2, direct delivery, as riscv-arch-test's whisper
configurations set it up) and checks `mip.SEIP`:

1. B = 0, E = 1: SEIP = 1
2. after `csrw mip, x0` (E still 1): SEIP = 1
3. after `csrs mip, SEIP` and `csrc mip, SEIP`: SEIP = 1
4. after rewriting the S-level IMSIC file's `eidelivery` (0x40000000) through `siselect`/`sireg`: SEIP = 1
5. after `csrs mip, SEIP` (B = 1) and `RVMODEL_CLR_SEXT_INT` (E = 0): SEIP = 1
6. after `csrc mip, SEIP`: SEIP = 0

Each failed check prints an `SA-MISMATCH` line; the test passes when all six hold.

Run: `./run.sh path/to/whisper` (exit status 0 = pass). It runs `whisper-aplic-seip-rv64.elf` with
`whisper-rv64.json` and `whisper-aplic-seip-rv32.elf` with `whisper-rv32.json`, which are riscv-arch-test's
`config/whisper/whisper-rv64-max/whisper.json` and `whisper-rv32-max/whisper.json`, unchanged.

Whisper master fa18e475:

```
FAIL whisper-aplic-seip-rv64.elf
  SA-MISMATCH: 2: after csrw mip, x0 with E=1: mip.SEIP expect=0x0000000000000001 got=0x0000000000000000
  SA-MISMATCH: 3: after csrs/csrc mip.SEIP with E=1: mip.SEIP expect=0x0000000000000001 got=0x0000000000000000
  SA-MISMATCH: 4: after an S-level IMSIC file access with E=1: mip.SEIP expect=0x0000000000000001 got=0x0000000000000000
  SA-MISMATCH: 5: B=1 set by csrs, then E=0: mip.SEIP expect=0x0000000000000001 got=0x0000000000000000
  RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
FAIL whisper-aplic-seip-rv32.elf
  SA-MISMATCH: 2: after csrw mip, x0 with E=1: mip.SEIP expect=0x00000001 got=0x00000000
  SA-MISMATCH: 3: after csrs/csrc mip.SEIP with E=1: mip.SEIP expect=0x00000001 got=0x00000000
  SA-MISMATCH: 4: after an S-level IMSIC file access with E=1: mip.SEIP expect=0x00000001 got=0x00000000
  SA-MISMATCH: 5: B=1 set by csrs, then E=0: mip.SEIP expect=0x00000001 got=0x00000000
  RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
```

With the fix, both pass.

The ELFs were built with the riscv-arch-test act4 framework (riscv/riscv-arch-test#3162, commit 205129dbd8, for
the whisper-rv64-max and whisper-rv32-max configurations); `sa.h` has the `SA_SOFT` check macros. Rebuilding needs
that framework.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09), with the same test built for each: Sail passes on RV64 and RV32. riscv-arch-test's Spike and Imperas configurations have no way to raise a supervisor external interrupt (`RVMODEL_SET_SEXT_INT` is not defined), so the test checks nothing there.
