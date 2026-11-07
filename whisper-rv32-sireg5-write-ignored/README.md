# whisper-rv32-sireg5-write-ignored

On RV32 with Smcdeleg/Ssccfg and `menvcfg.CDE = 1`, a write through `sireg5` does not change the selected
`mcyclecfgh`, `minstretcfgh` or `mhpmevent3h-31h`. smcdeleg.adoc (norm:Smcdeleg_delegated_access): "When a counter
_i_ is delegated (`mcounteren`[_i_]=1 and `menvcfg`.CDE=1) and `siselect` is 0x40+__i__, `sireg*` aliases counter
_i_." `sireg5` at `siselect` 0x43 is `hpmevent3h`, and only MINH is read-only 0 through `sireg*`.

`rv32_sireg5_write`: `menvcfgh.CDE = 1`, `mcounteren` = all ones, `mhpmevent3h` = 0, `siselect` = 0x43. S-mode
writes 0x30000000 (SINH | UINH) to `sireg5`; M-mode reads `mhpmevent3h`. Expected: 0x30000000. Whisper: 0.

`CsRegs::writeSireg5` (`CsRegs.cpp`, master 6b8cce1a, line 4450) does `value = csr->read();` before it merges the
read-only MINH bit, so the CSR is rewritten with its own value. RV64 is not affected (`sireg5` is illegal there).

The test is a riscv-arch-test rule-derived test (riscv/riscv-arch-test#3162), self-checking, built without C for
the whisper-rv32-max configuration with `smcsrind_sscsrind_smcdeleg_ssccfg_smctr_ssctr` added to the isa string
(`whisper-rv32.json`). On Whisper 6b8cce1a:

    RVCP-SUMMARY: TEST FAILED - Test File "rv32_sireg5_write.S"
    RVCP: Test Info: rv32_sireg5_write: mhpmevent3h after an S-mode sireg5 write of SINH|UINH; expect 0x30000000
    RVCP: Bad Value:      0x00000000

## Run

    ./run.sh [path/to/whisper]
