# Whisper: setting menvcfg.DTE clears sstatus.SIE when it re-exposes a stored SDT = 1

With `menvcfg.DTE` = 0, `sstatus.SDT` is read-only zero. Setting DTE makes SDT writable again, and SDT gets an
UNSPECIFIED legal value (csrs.adoc norm:Zicsr_field_modulation); Whisper shows the SDT value stored before DTE was
cleared, which is legal. That change is not a write of `sstatus` and has no side effects
(norm:Zicsr_field_modulation_no_side_effects), so it must not apply the rule that an explicit write of SDT = 1 clears
SIE (supervisor.adoc norm:sstatus_sdt_sstatus_sie_overwrite). Whisper clears SIE.

`whisper-dte-sdt-sie.S` runs in M-mode (`menvcfgh` on RV32):

1. set DTE; set `sstatus.SDT` (an explicit write: SIE is cleared); checks nothing if SDT cannot be set;
2. clear DTE; check that SDT reads 0;
3. set `sstatus.SIE` (allowed: SDT reads 0);
4. set DTE; check that SIE still reads 1 (SDT may read 0 or 1).

Run: `./run.sh path/to/whisper` (exit status 0 = pass). It runs `whisper-dte-sdt-sie-rv64.elf` with
`whisper-rv64.json` and `whisper-dte-sdt-sie-rv32.elf` with `whisper-rv32.json`, which are riscv-arch-test's
`config/whisper/whisper-rv64-max/whisper.json` and `whisper-rv32-max/whisper.json`, unchanged.

Whisper master fa18e475 (SDT reads 1 and SIE 0 after step 4):

```
FAIL whisper-dte-sdt-sie-rv64.elf
  RVCP: Test Info: sstatus.SIE after menvcfg.DTE 0 -> 1 (not a write of sstatus: SIE stays 1)
FAIL whisper-dte-sdt-sie-rv32.elf
  RVCP: Test Info: sstatus.SIE after menvcfg.DTE 0 -> 1 (not a write of sstatus: SIE stays 1)
```

With the fix, both pass.

The ELFs were built with the riscv-arch-test act4 framework (riscv/riscv-arch-test#3162, commit 205129dbd8, for
the whisper-rv64-max and whisper-rv32-max configurations); `sa.h` has the `SA_CHECK` macro. Rebuilding needs that
framework.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09), with the same test built for each: Sail passes on RV64 and RV32 (SDT reads 0 after DTE is set again) and Imperas passes on RV64 (SDT reads 1 and SIE stays 1). Spike never reaches the last check: with DTE = 0 its `csrsi` of SIE is lost while the hidden SDT = 1 is stored (riscv-software-src/riscv-isa-sim#2534).
