# Clearing misa.M disables an explicitly listed Zmmul

`Hart::processExtensions` (Hart.cpp:627-632 at f069895c) sets Zmmul to misa.M whenever `m` is in the
isa string, overriding the earlier `enableExtension(RvExtension::Zmmul, isa_.isEnabled(Zmmul))`. On a
hart with M, Zmmul and a writable misa.M, clearing misa.M makes `mul` raise an illegal-instruction
exception. machine.adoc: "if the Zmmul extension is supported then the multiply instructions it
specifies are supported irrespective of the value of the m bit."

The hart is RVI20U64 + M + Zmmul with misa.M writable (whisper `isa: rv64im_zicsr_zmmul` with
`csr.misa.mask = 0x1000`; spike `--isa=rv64im_zicsr_zmmul`; Sail `extensions.M.mutable_misa: true`).
`W120Zmmul_misa_m-00.S` clears misa.M, executes `mul` and `mulhsu` (must execute), `div` (reserved with M clear; Sail, Spike and Whisper trap),
restores misa and executes `mul` again.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

Expected (Whisper master f069895c):

    whisper: FAIL   (mul at 0x800000a0 traps, mcause 2; the first expected trap is the div at 0x80000128)
    spike:   PASS
    sail:    PASS

With the fix, whisper: PASS.
