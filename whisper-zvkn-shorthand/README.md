# Whisper: zvkn in the isa string enables none of Zvkn's extensions

zvk.adoc (norm:Zvkn_def): Zvkn "is shorthand for the following set of other extensions: Zvkned, Zvknhb, Zvkb,
Zvkt". Whisper accepts `zvkn` in its isa string without a warning, but enables none of them, so every Zvkned,
Zvknha/Zvknhb and Zvkb instruction raises an illegal-instruction exception.

`zvkn-shorthand.S` (M-mode, RV64) checks that these execute without a trap:

1. `vaesef.vv v8, v16` at e32, m1 (Zvkned);
2. `vsha2ms.vv v8, v16, v24` at e32, m1 (Zvknha, implied by Zvknhb);
3. `vandn.vv v8, v16, v24` at e32, m1 (Zvkb);
4. `vsha2ms.vv v8, v16, v24` at e64, m2 (Zvknhb).

`whisper.json` is riscv-arch-test's `whisper-rv64-max` configuration whose isa string has `zvkn` in place of
`zvbb_zvbc_zvkg_zvkned_zvknhb_zvksed_zvksh` (so Zvkb is not implied by Zvbb).

Expected: PASS. Whisper master fa18e475 (`master.out`) raises an illegal-instruction exception for check 1 (and
for all of the members' instructions). With the fix (`fixed.out`) all checks pass.

## Files

- `zvkn-shorthand.S`: the test (riscv-arch-test framework, self-checking with the `tests_ai` `sa.h` macros of
  riscv-arch-test 205129dbd8).
- `zvkn-shorthand.elf`: built by riscv-arch-test's `act` for a copy of its `whisper-rv64-max` configuration.
- `whisper.json`: the configuration described above.
- `master.out`, `fixed.out`: `run.sh` output for Whisper master fa18e475 and for the fix.

## Run

    ./run.sh path/to/whisper     # prints PASS or FAIL; exit status 0 = pass

The run is `whisper --maxinst 100000000:f --config whisper.json zvkn-shorthand.elf`; the test prints
`RVCP-SUMMARY: TEST PASSED` or `TEST FAILED` on Whisper's console.

## Other simulators

The same test passes on Spike c20813c with `--isa=..._zvkn` and no other vector crypto extension. Sail master
81184531 has no shorthand names in its configuration; with the member extensions enabled (`sail-RVA23-master`)
it passes. Stock ImperasDV Y-2026.09 (variant RVA23S64mandatory with `--override cpu*/Zvkn=T`) fails check 1 the
same way: its `Zvkn` parameter does not enable the members either.
