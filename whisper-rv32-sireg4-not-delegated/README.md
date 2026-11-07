# whisper-rv32-sireg4-not-delegated

On RV32 with Smcdeleg/Ssccfg and `menvcfg.CDE = 1`, an S-mode or M-mode access to `sireg4` or `sireg5` does not trap
when `siselect` selects a counter that is not delegated to S-mode. smcdeleg.adoc
(norm:Ssccfg_illegal_sireg_not_delegated): "While the privilege mode is M or S and `siselect` holds a value in the
range 0x40-0x5F, illegal-instruction exceptions are raised for [...] attempts to access `sireg*` when `siselect` =
0x41, or when the counter selected by `siselect` is not delegated to S-mode (the corresponding bit in `mcounteren` =
0)."

`rv32_sireg4_not_delegated`: `menvcfgh.CDE = 1`, `mcounteren` = ~1 (CY clear), `siselect` = 0x40 (cycle). S-mode
reads `sireg` (illegal-instruction, correct) and then `sireg4` (`cycleh`). Expected: illegal-instruction. Whisper:
no trap.

`CsRegs::readSireg`/`readSireg2` and `writeSireg`/`writeSireg2` (`CsRegs.cpp`, master 6b8cce1a, lines 813, 891, 4138
and 4239) check `mcounteren` in M-mode and S-mode, but the RV32-only `readSireg4`/`readSireg5` (lines 970, 1022) and
`writeSireg4`/`writeSireg5` (lines 4336, 4395) do not. The test exercises only the `sireg4` read; the `sireg5` read
and the `sireg4`/`sireg5` writes lack the same check in the source. RV64 is not affected (`sireg4`/`sireg5` are
illegal there).

The test is a riscv-arch-test rule-derived test (riscv/riscv-arch-test#3162), self-checking, built without C for
the whisper-rv32-max configuration with `smcsrind_sscsrind_smcdeleg_ssccfg_smctr_ssctr` added to the isa string
(`whisper-rv32.json`). On Whisper 6b8cce1a:

    RVCP-SUMMARY: TEST FAILED - Test File "rv32_sireg4_not_delegated.S"
    RVCP: Test Info: rv32_sireg4_not_delegated: read (csrrs rs1=x0) of sireg4 (mcounteren.CY=0) in S-mode: number of traps; expect 0x00000001
    RVCP: Bad Value:      0x00000000

## Run

    ./run.sh [path/to/whisper]
