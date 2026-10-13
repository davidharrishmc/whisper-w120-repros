# whisper-svinval-absent-vu

On a hart with H and Ssstrict but without Svinval, Whisper raises a virtual-instruction exception instead of an
illegal-instruction exception when `sinval.vma`, `sfence.w.inval` or `sfence.inval.ir` executes in VU-mode.

Without Svinval these encodings are unimplemented opcodes, and ssstrict.adoc (lines 8-12,
norm:Ssstrict_unimplemented_opcodes_csr_exception): "attempts to execute unimplemented opcodes ... in the standard
or reserved encoding spaces raises an illegal instruction exception". The virtual-instruction exception does not
apply: hypervisor.adoc (lines 2323-2330, norm:H_cause_virtual_instruction) raises it instead of illegal instruction
only "if the attempted instruction is HS-qualified", and "An instruction is HS-qualified if it would be valid to
execute in HS-mode (for some values of the instruction's register operands)"; without Svinval no operand values
make these valid in HS-mode. The VU-mode virtual-instruction rules for these instructions (svinval.adoc lines
60-61 and 67) are part of Svinval, which is absent.

`Hart.cpp` `execSinval_vma`, `execSfence_w_inval` and `execSfence_inval_ir` (master f069895c, lines 12360,
12376, 12391) choose `virtualInst` whenever V=1 and the mode is U, before considering whether Svinval is
implemented. (VS-mode already gets illegal instruction, and `hinval.vvma` / `hinval.gvma` raise illegal
instruction whenever Svinval is absent, `hypervisor.cpp` lines 394 and 405.)

`W120H_svinval_absent-00.S` is a small act4-format test. It runs on two harts, RV64I and RV32I + Zicsr + S + U +
H + Ssstrict without Svinval (derived configurations RVI20U64-h and RVI20U32-h with Ssstrict added; Spike
`--isa=rv64ih_zicsr_ssstrict` / `--isa=rv32ih_zicsr_ssstrict`; Sail `Ssstrict.supported` true). In VU-mode it
executes `sfence.vma` (positive control: virtual instruction), then the three Svinval instructions; in VS-mode
it executes the three Svinval instructions again. The trap handler records each trap; all six Svinval traps must
be illegal instruction (cause 2).

The ELFs are self-checking: expected values come from Sail. There is one ELF per simulator because the act4
model macros (halt, console) differ.

Expected (Sail, Spike): `RVCP-SUMMARY: TEST PASSED`. Whisper master f069895c, at the VU-mode sinval.vma:

    RVCP: Mismatching field: XCAUSE (trap signature word 1)
    RVCP: Expected value: 0x0000000000000002
    RVCP: Actual value:   0x0000000000000016

## Run

    ./run.sh [path/to/whisper] [path/to/spike] [path/to/sail_riscv_sim]

prints PASS/FAIL per simulator for each hart. On whisper f069895c:

    == rv64 W120H_svinval_absent-00
    whisper: FAIL
    spike:   PASS
    sail:    PASS
    == rv32 W120H_svinval_absent-00
    whisper: FAIL
    spike:   PASS
    sail:    PASS

With the fix (virtual instruction only when Svinval is implemented), whisper prints PASS on both.

Files: per hart `whisper.json` (Whisper has no Ssstrict switch; these are the RVI20U64-h / RVI20U32-h
configurations), `spike_args.txt` (spike options), `sail.json` (Sail 0.15 configuration) and the three ELFs
built from the .S by the act4 framework (hypervisor branch test environment).
