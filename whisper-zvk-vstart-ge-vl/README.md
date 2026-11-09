# Whisper: vector crypto element-group instructions with vstart >= vl leave vstart nonzero

With `trap_non_zero_vstart` false, the vector crypto element-group instructions with `vstart` >= `vl` (a
multiple of EGS, below VLMAX) complete without a trap and leave `vstart` unchanged.

vector-common.adoc (norm:vstart_op, norm:vstart_update): all vector instructions "reset the csr:vstart[] CSR to
zero at the end of execution"; norm:vstart_vl_dep: with `vstart` >= `vl` no element is updated. An
implementation may instead raise an illegal-instruction exception for a `vstart` it never produces
(norm:vstart_vtype_dep), which Whisper does with `trap_non_zero_vstart` true (its default).

`zvk-vstart-ge-vl.S` (M-mode, RV64, e32, LMUL = 4, vl = 8) runs each of `vaesef.vv`, `vaesz.vs`, `vaeskf1.vi`
(Zvkned), `vghsh.vv` (Zvkg), `vsha2ms.vv` (Zvknha), `vsm4r.vv` (Zvksed) and `vsm3me.vv` (Zvksh) with `vstart` =
8 and checks for either an illegal-instruction exception with `vstart` still 8, or no trap with `vstart` = 0.
vl = 8 is a multiple of both EGS values (4 and 8), and `vstart` = 8 is below VLMAX for any VLEN >= 128.

`whisper.json` is riscv-arch-test's `whisper-rv64-max` configuration with only `"trap_non_zero_vstart": false`.

Expected: PASS. Whisper master fa18e475 (`master.out`) completes `vaesef.vv` without a trap and leaves `vstart` =
8. With the fix (`fixed.out`) all checks pass.

## Files

- `zvk-vstart-ge-vl.S`: the test (riscv-arch-test framework, self-checking with the `tests_ai` `sa.h` macros of
  riscv-arch-test 205129dbd8).
- `zvk-vstart-ge-vl.elf`: built by riscv-arch-test's `act` for its `whisper-rv64-max` configuration.
- `whisper.json`: the configuration described above.
- `master.out`, `fixed.out`: `run.sh` output for Whisper master fa18e475 and for the fix.

## Run

    ./run.sh path/to/whisper     # prints PASS or FAIL; exit status 0 = pass

The run is `whisper --maxinst 100000000:f --config whisper.json zvk-vstart-ge-vl.elf`; the test prints
`RVCP-SUMMARY: TEST PASSED` or `TEST FAILED` on Whisper's console.

## Other simulators

The same test built for riscv-arch-test's RV64 configurations passes on Spike c20813c (`spike-rv64-max`), Sail
master 81184531 (`sail-RVA23-master`, and with `vstart.zero_required.arith` false) and stock ImperasDV
Y-2026.09 (`imperas-rv64-max`). Whisper with the unmodified `whisper-rv64-max` configuration also passes (it
raises the illegal-instruction exception).
