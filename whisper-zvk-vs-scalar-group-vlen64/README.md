# Whisper: with VLEN = 64, a vector crypto .vs instruction whose scalar element group is an odd register crashes

The scalar element group (`vs2`) of the vector crypto `.vs` instructions holds 128 bits, so with VLEN = 64 it
is a group of two registers (zvk.adoc: "The Scalar Element Group operand has EMUL = ceil(EGW / VLEN)";
norm:veccrypto_vsins_vdvs2overlap: with VLEN < 128 "_vs2_ refers to a register group comprised of the number of
registers needed to hold the 128-bit scalar element group" and the `vd` group must not overlap it). Naming that
group with an odd register is a reserved encoding (vector-common.adoc, norm:emul_offgroup_rsv), which must raise
an illegal-instruction exception under Ssstrict (claimed by riscv-arch-test's whisper configurations; see
riscv/riscv-isa-manual#3258). Whisper master instead dies with SIGSEGV: it reads the 128-bit key from a
register offset that is not 16-byte aligned.

`zvk-vs-scalar-group-vlen64.S` (M-mode, RV64) does nothing unless `vlenb` = 8. At VLEN = 64, with e32, LMUL = 2,
vl = 4 (one element group in v8-v9), it checks:

1. `vaesz.vs v8, v6` (scalar group v6-v7) executes (control);
2. `vaesdf.vs v8, v7` (v7-v8: odd, and overlaps vd) raises an illegal-instruction exception;
3. `vaesz.vs v8, v5` (v5-v6: odd) raises an illegal-instruction exception;
4. `vsm4r.vs v8, v3` (v3-v4: odd) raises an illegal-instruction exception.

`whisper.json` is riscv-arch-test's `whisper-rv64-max` configuration with only `"bytes_per_vec": 8` (VLEN = 64,
a Zve64x-style hart).

Expected: PASS. Whisper master fa18e475 (`master.out`) dies with signal 11 (SIGSEGV) at check 2. With the fix
(`fixed.out`) all checks pass.

## Files

- `zvk-vs-scalar-group-vlen64.S`: the test (riscv-arch-test framework, self-checking with the `tests_ai` `sa.h`
  macros of riscv-arch-test 205129dbd8).
- `zvk-vs-scalar-group-vlen64.elf`: built by riscv-arch-test's `act` for its `whisper-rv64-max` configuration.
- `whisper.json`: the configuration described above.
- `master.out`, `fixed.out`: `run.sh` output for Whisper master fa18e475 and for the fix.

## Run

    ./run.sh path/to/whisper     # prints PASS or FAIL; exit status 0 = pass

The run is `whisper --maxinst 100000000:f --config whisper.json zvk-vs-scalar-group-vlen64.elf`; the test prints
`RVCP-SUMMARY: TEST PASSED` or `TEST FAILED` on Whisper's console.

## Other simulators

The same test built for VLEN = 64 versions of riscv-arch-test's RV64 configurations passes on Spike c20813c and
Sail master 81184531. Stock ImperasDV Y-2026.09 fails the control (check 1): with VLEN < 128 it raises an
illegal-instruction exception for the Zvkned and Zvksed `.vs` forms although LMUL*VLEN >= EGW, a separate
Imperas problem already reported to Synopsys.
