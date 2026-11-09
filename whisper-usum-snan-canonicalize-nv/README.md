# Whisper: vfredusum/vfwredusum canonicalize a signaling-NaN scalar without raising invalid

With `fp_usum_nan_canonicalize` enabled and the tree reduction (`tt_fp_usum_tree_reduction`) disabled,
`vfredusum.vs` and `vfwredusum.vs` with no active element and a signaling-NaN scalar (`vs1[0]`) return the
canonical NaN with `fflags` = 0.

vector-common.adoc (norm:vfredusum_op): the result must be equivalent to a reduction tree in which "A node
where one input is derived only from elements masked-off or beyond the active vector length may either treat
that input as the additive identity of the appropriate EEW or simply copy the other input to its output", and
"An implementation is allowed to add an additional additive identity to the final result." With no active
element the legal outcomes are therefore the scalar copied unchanged with no flags, or the canonical NaN with
NV (the NOTE after the rule says the same). norm:vfwredosum_vfwredusum_op_reduction applies this to
`vfwredusum.vs`.

`usum-snan-canonicalize-nv.S` (M-mode, RV64) masks off every element (v0 = 0) and runs:

1. `vfredusum.vs` at SEW = 32 with `vs1[0]` = 0x7fa00000;
2. `vfredusum.vs` at SEW = 64 with `vs1[0]` = 0x7ff4000000000000;
3. `vfwredusum.vs` at SEW = 32 with the 64-bit `vs1[0]` = 0x7ff4000000000000.

For each it checks that the result and `fflags` are (the signaling NaN, 0) or (the canonical NaN, NV set).

`whisper.json` is riscv-arch-test's `whisper-rv64-max` configuration with only `"tt_fp_usum_tree_reduction": []`
changed (it keeps `"fp_usum_nan_canonicalize": ["e16", "e32", "e64"]`). With the tree reduction enabled, as in
the unmodified configuration, Whisper passes.

Expected: PASS. Whisper master fa18e475 (`master.out`) fails the first check: 0x7fc00000 with `fflags` = 0. With
the fix (`fixed.out`) all three pass.

## Files

- `usum-snan-canonicalize-nv.S`: the test (riscv-arch-test framework, self-checking with the `tests_ai` `sa.h`
  macros of riscv-arch-test 205129dbd8).
- `usum-snan-canonicalize-nv.elf`: built by riscv-arch-test's `act` for its `whisper-rv64-max` configuration.
- `whisper.json`: the configuration described above.
- `master.out`, `fixed.out`: `run.sh` output for Whisper master fa18e475 and for the fix.

## Run

    ./run.sh path/to/whisper     # prints PASS or FAIL; exit status 0 = pass

The run is `whisper --maxinst 100000000:f --config whisper.json usum-snan-canonicalize-nv.elf`; the test prints
`RVCP-SUMMARY: TEST PASSED` or `TEST FAILED` on Whisper's console.

## Other simulators

The same test built for riscv-arch-test's RV64 configurations passes on Spike c20813c (`spike-rv64-max`), Sail
master 81184531 (`sail-RVA23-master`) and stock ImperasDV Y-2026.09 (`imperas-rv64-max`).
