# Whisper: vsm3me.vv executes with a vs1 register group that is not aligned to LMUL

`vsm3me.vv vd, vs2, vs1` reads `vs1` and `vs2` as LMUL register groups (zvk.adoc, norm:vsm3me-vv_op_sm3), and
naming a group with a register that is not a multiple of LMUL is a reserved encoding (vector-common.adoc,
norm:vreg_offgroup_lmul2_rsv / norm:vreg_offgroup_lmul4_rsv / norm:emul_offgroup_rsv; zvk.adoc: "All standard
vector instruction constraints specified by the V extension apply to Vector Crypto instructions"). With
Ssstrict, which riscv-arch-test's whisper configurations claim, such an encoding must raise an
illegal-instruction exception (riscv/riscv-isa-manual#3258: any other behavior is a non-conforming extension).
Whisper does so for a misaligned `vd` or `vs2`, but not for a misaligned `vs1`.

`vsm3me-vs1-align.S` (M-mode, RV64, e32, vl = 8) checks:

1. LMUL = 2: `vsm3me.vv v8, v16, v24` executes (control);
2. LMUL = 2: `vsm3me.vv v8, v16, v25` (vs1 odd) raises an illegal-instruction exception;
3. LMUL = 2: `vsm3me.vv v8, v13, v24` (vs2 odd, control) raises an illegal-instruction exception;
4. LMUL = 4: `vsm3me.vv v8, v16, v24` executes (control);
5. LMUL = 4: `vsm3me.vv v8, v16, v2` (vs1 not a multiple of 4) raises an illegal-instruction exception.

The misaligned forms are written as `.word` (0x830ca477, 0x82dc2477, 0x83012477).

Expected: PASS. Whisper master fa18e475 (`master.out`) executes check 2's instruction (no trap). With the fix
(`fixed.out`) all checks pass.

## Files

- `vsm3me-vs1-align.S`: the test (riscv-arch-test framework, self-checking with the `tests_ai` `sa.h` macros of
  riscv-arch-test 205129dbd8).
- `vsm3me-vs1-align.elf`: built by riscv-arch-test's `act` for its `whisper-rv64-max` configuration.
- `whisper.json`: that configuration's Whisper config file.
- `master.out`, `fixed.out`: `run.sh` output for Whisper master fa18e475 and for the fix.

## Run

    ./run.sh path/to/whisper     # prints PASS or FAIL; exit status 0 = pass

The run is `whisper --maxinst 100000000:f --config whisper.json vsm3me-vs1-align.elf`; the test prints
`RVCP-SUMMARY: TEST PASSED` or `TEST FAILED` on Whisper's console.

## Other simulators

The same test built for riscv-arch-test's RV64 configurations passes on Spike c20813c (`spike-rv64-max`), Sail
master 81184531 (`sail-RVA23-master`) and stock ImperasDV Y-2026.09 (`imperas-rv64-max`): all three raise an
illegal-instruction exception for the misaligned groups.
