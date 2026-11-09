# Whisper: clearing misa.S or misa.U leaves their mstatus fields set, and MRET enters the disabled U-mode

When software clears a writable `misa` letter, the extension behaves as if it were not implemented
(machine.adoc norm:misa_extensions_disabling). Without S-mode, `mstatus` SIE, SPIE, SUM, MXR, TVM and TSR are
read-only zero; without U-mode, MPRV is read-only zero, TW is read-only zero when M is the only mode, and MPP can only
hold M, so MRET stays in M-mode (norm:mstatus_xpp_warl, norm:mstatus_xret_op). Whisper applies these rules only to
modes missing from the isa string.

`whisper-misa-su-stale.S` runs in M-mode with its own trap handler:

- part S: set SIE, SPIE, SUM, MXR, TVM and TSR; clear `misa.S` and `misa.H` (H depends on S); check that the six
  fields read 0, then set them again and check that they still read 0;
- part U: set TW and MPP = U; clear `misa.U`, `misa.S` and `misa.H`; check TW = 0 and MPP = M; with no `mstatus`
  write in between, execute `mret` to `csrr mstatus` + `ecall` and check that the first trap is the M-mode ecall
  (mcause 11, not 2) and that MPP is M after the MRET; then set MPRV and check that it reads 0.

Each part is skipped when its `misa` bit is read-only. Each failed check prints an `SA-MISMATCH` line.

Run: `./run.sh path/to/whisper` (exit status 0 = pass). It runs `whisper-misa-su-stale-rv64.elf` with
`whisper-rv64.json` and `whisper-misa-su-stale-rv32.elf` with `whisper-rv32.json`. The configurations are riscv-arch-test's `config/whisper/whisper-rv64-max/whisper.json` and `whisper-rv32-max/whisper.json`
with `misa` mask and poke mask 0x3410af (A, B, C, D, F, H, M, S, U and V writable; riscv-arch-test makes only C
writable, mask 0x4).

Whisper master fa18e475:

```
FAIL whisper-misa-su-stale-rv64.elf
  SA-MISMATCH: S: mstatus.SIE once misa.S is cleared expect=0x0000000000000000 got=0x0000000000000001
  SA-MISMATCH: S: mstatus.SPIE once misa.S is cleared expect=0x0000000000000000 got=0x0000000000000001
  SA-MISMATCH: S: mstatus.SUM once misa.S is cleared expect=0x0000000000000000 got=0x0000000000000001
  SA-MISMATCH: S: mstatus.MXR once misa.S is cleared expect=0x0000000000000000 got=0x0000000000000001
  SA-MISMATCH: S: mstatus.TVM once misa.S is cleared expect=0x0000000000000000 got=0x0000000000000001
  SA-MISMATCH: S: mstatus.TSR once misa.S is cleared expect=0x0000000000000000 got=0x0000000000000001
  SA-MISMATCH: S: mstatus SIE/SPIE/SUM/MXR/TVM/TSR after csrs with misa.S cleared expect=0x0000000000000000 got=0x00000000005c0022
  SA-MISMATCH: U: mstatus.TW once misa.U is cleared expect=0x0000000000000000 got=0x0000000000000001
  SA-MISMATCH: U: mstatus.MPP (written U before misa.U was cleared): M is the only legal value expect=0x0000000000000003 got=0x0000000000000000
  SA-MISMATCH: U: first trap after MRET with misa.U cleared (11 = the M-mode ecall; 2 = csrr mstatus ran in U-mode) expect=0x000000000000000b got=0x0000000000000002
  SA-MISMATCH: U: mstatus.MPP after that MRET (least-privileged supported mode = M) expect=0x0000000000000003 got=0x0000000000000000
  SA-MISMATCH: U: mstatus.MPRV after csrs with misa.U cleared expect=0x0000000000000000 got=0x0000000000000001
  RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
FAIL whisper-misa-su-stale-rv32.elf
  SA-MISMATCH: S: mstatus.SIE once misa.S is cleared expect=0x00000000 got=0x00000001
  SA-MISMATCH: S: mstatus.SPIE once misa.S is cleared expect=0x00000000 got=0x00000001
  SA-MISMATCH: S: mstatus.SUM once misa.S is cleared expect=0x00000000 got=0x00000001
  SA-MISMATCH: S: mstatus.MXR once misa.S is cleared expect=0x00000000 got=0x00000001
  SA-MISMATCH: S: mstatus.TVM once misa.S is cleared expect=0x00000000 got=0x00000001
  SA-MISMATCH: S: mstatus.TSR once misa.S is cleared expect=0x00000000 got=0x00000001
  SA-MISMATCH: S: mstatus SIE/SPIE/SUM/MXR/TVM/TSR after csrs with misa.S cleared expect=0x00000000 got=0x005c0022
  SA-MISMATCH: U: mstatus.TW once misa.U is cleared expect=0x00000000 got=0x00000001
  SA-MISMATCH: U: mstatus.MPP (written U before misa.U was cleared): M is the only legal value expect=0x00000003 got=0x00000000
  SA-MISMATCH: U: first trap after MRET with misa.U cleared (11 = the M-mode ecall; 2 = csrr mstatus ran in U-mode) expect=0x0000000b got=0x00000002
  SA-MISMATCH: U: mstatus.MPP after that MRET (least-privileged supported mode = M) expect=0x00000003 got=0x00000000
  SA-MISMATCH: U: mstatus.MPRV after csrs with misa.U cleared expect=0x00000000 got=0x00000001
  RVCP: Test Info: number of SA-MISMATCH soft-check failures (see the log)
```

With the fix, both pass.

The ELFs were built with the riscv-arch-test act4 framework (riscv/riscv-arch-test#3162, commit 205129dbd8, for
the whisper-rv64-max configuration with the writable misa above, and for whisper-rv32-max); `sa.h` has the `SA_SOFT` check macros. Rebuilding needs
that framework.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09), with the same test built for each: With S and U writable in `misa` (Sail's default configuration; Imperas with `misa_Extensions_mask=0x3410af`), Sail fails the read-back, MPP and MRET checks on RV64 and RV32 (riscv/sail-riscv#1522 covers the MRET part) but ignores writes of these fields while the mode is disabled, and Imperas fails the S-mode field checks and passes the U-mode ones. Spike and the stock Imperas configuration do not make `misa.S` and `misa.U` writable, so the test checks nothing there.
