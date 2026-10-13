# whisper-mcounteren-menvcfg-without-u

machine.adoc: "In harts with U-mode, the mcounteren must be implemented" (`norm:mcounteren_flds_mandatory_warl`),
"In harts without U-mode, the mcounteren register should not exist" (`norm:mcounteren_presence`, a
recommendation), "In harts with U-mode, `menvcfg` must be implemented" (`norm:menvcfg_mandatory_u_mode`) and
"If U-mode is not supported, then registers `menvcfg` and `menvcfgh` do not exist"
(`norm:menvcfg_menvcfgh_no_u_mode`). Whisper defines all three as implemented regardless of U, and
`CsRegs::enableUserMode` only records a flag. riscv-arch-test's whisper configurations hide this with
`"mcounteren": {"exists": false}` and `"menvcfg": {"exists": false}` on every hart without U.

Three cases:

* `nou32`, `nou64`: the riscv-arch-test derived RVI20U32-ssstrict / RVI20U64-ssstrict configurations (I,
  Zicsr, Zifencei, Sm, Ssstrict; M-mode only) with that workaround removed from `whisper.json`; spike
  `--priv=m --isa=rv32i_zicsr_zifencei` / `rv64i_zicsr_zifencei`. `W120S2Nou_nou-00.S` reads mcounteren,
  menvcfg and (RV32) menvcfgh and writes mcounteren and menvcfg; Spike and Sail raise an
  illegal-instruction exception for each access, Whisper returns 0. (These harts claim Ssstrict as the
  riscv-arch-test rows do; Ssstrict itself describes traps to the supervisor-mode handler, so on an
  M-only hart this is the same principle rather than a literal requirement.)
* `scountovf`: RVI20U32 + S + U + Sscofpmf + Zihpm, with `"mcounteren": {"exists": false}` added to
  `scountovf.whisper.json` (Spike and Sail have no such knob and run the normal configuration). The spec
  requires mcounteren on this hart, but Whisper accepts the configuration and then fails an assertion
  (`CsRegs::adjustScountovfValue`) when `W120Csrexist_scountovf-00.S` reads scountovf in S-mode.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

Expected (Whisper master f069895c):

    whisper (nou32): FAIL        (csrr mcounteren returns 0; "test: 1 ... bin: mcounteren")
    spike (nou32):   PASS
    sail (nou32):    PASS
    whisper (nou64): FAIL
    spike (nou64):   PASS
    sail (nou64):    PASS
    whisper (scountovf): FAIL    (CsRegs.cpp:519: Assertion `csr and "MCOUNTEREN not implemented"' failed)
    spike (scountovf):   PASS
    sail (scountovf):    PASS

With the fix all whisper cases PASS (the scountovf case prints a warning that mcounteren must be
implemented when U-mode is). With the fix, `"mcounteren": {"exists": true}` on a hart without U still
keeps mcounteren (a legal, if not recommended, implementation), while `"menvcfg": {"exists": true}` there
is ignored with a warning.
