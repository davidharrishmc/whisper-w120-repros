# whisper-rv32-menvcfgh-cde

On RV32 with Smcdeleg/Ssccfg, setting `menvcfgh.CDE` (bit 28, `menvcfg` bit 60) does not make `scountinhibit`
accessible: it stays an M-level CSR that is not implemented. smcdeleg.adoc (norm:Ssccfg_scountinhibit_exists):
"Smcdeleg/Ssccfg defines a new `scountinhibit` register, a masked alias of `mcountinhibit`"; only "When
`menvcfg`.CDE=0, attempts to access `scountinhibit` raise an illegal-instruction exception"; and
(norm:Ssccfg_illegal_scountinhibit_vs_vu) "When Supervisor Counter Delegation is enabled, attempts to access
`scountinhibit` from VS-mode or VU-mode raise a virtual-instruction exception."

- `rv32_menvcfgh_cde_scountinhibit`: M-mode sets `menvcfgh.CDE` (it reads back 1) and `mcounteren` = all ones;
  S-mode reads `scountinhibit`. Expected: no trap. Whisper: illegal-instruction.
- `scountinhibit_vs_cde1_virtual`: the same with H, read from VS-mode. Expected: virtual-instruction (cause 22).
  Whisper: illegal-instruction (cause 2).

`CsRegs::write` and `CsRegs::poke` (`CsRegs.cpp`, master 6b8cce1a, lines 5384-5389 and 7487-7492) call
`updateSmcdeleg()`, which enables `scountinhibit` and makes it an S-level CSR, after writes of `menvcfg`, `senvcfg`
and `henvcfg`, but not after writes of `menvcfgh`/`henvcfgh`. RV64 is not affected.

The tests are riscv-arch-test rule-derived tests (riscv/riscv-arch-test#3162), self-checking, built without C for
the whisper-rv32-max configuration with `smcsrind_sscsrind_smcdeleg_ssccfg_smctr_ssctr` added to the isa string
(`whisper-rv32.json`). The tests boot into S-mode and reach M-level CSRs through the framework's ecall interface.
On Whisper 6b8cce1a:

    RVCP-SUMMARY: TEST FAILED - Test File "rv32_menvcfgh_cde_scountinhibit.S"
    RVCP: Test Info: rv32_menvcfgh_cde_scountinhibit: read (csrrs rs1=x0) of scountinhibit (CDE=1) in S-mode: number of traps; expect 0x00000000
    RVCP: Bad Value:      0x00000001
    RVCP-SUMMARY: TEST FAILED - Test File "scountinhibit_vs_cde1_virtual.S"
    RVCP: Test Info: scountinhibit_vs_cde1_virtual: read (csrrs rs1=x0) of scountinhibit (CDE=1) in VS-mode: outcome (xcause, or all ones for no trap); expect 0x00000016
    RVCP: Bad Value:      0x00000002

## Run

    ./run.sh [path/to/whisper]
