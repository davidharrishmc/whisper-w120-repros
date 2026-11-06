# whisper-hfence-gvma-rv32

On RV32 with H, `hfence.gvma rs1, rs2` with rs1 ≠ x0 drops bits 33:32 of the guest physical address, so it
removes the G-stage translation of the wrong page and the stale translation stays in use. The operand is the
guest physical address shifted right by 2 bits (hypervisor.adoc, HFENCE.GVMA: "it specifies a single guest
physical address, shifted right by 2 bits"; the note below it: "a guest physical address specified in _rs1_ is
shifted right by 2 bits to accommodate addresses wider than the current XLEN"), so on RV32 it carries Sv32x4's
34-bit guest physical addresses.

`execHfence_gvma` (`hypervisor.cpp`, master 6b8cce1a, lines 133 and 143) computes

    URV addr = intRegs_.read(di->op0()) << 2;

in XLEN bits, which shifts bits 33:32 out on RV32. `hinval.gvma` calls `execHfence_gvma`, so it has the same bug.

`Sv_H_sv32x4_fence_x4-00.S` is the riscv-arch-test `Sv_H_sv32x4_fence_x4` test (riscv/riscv-arch-test#3170).
In HS-mode it maps a guest virtual page through the VS-stage to guest physical page A = 0x12a300000 (bit 32 set)
and through the G-stage to physical page A (holding 0x0a0a0a0a), and loads it in VS-mode. It then points the
G-stage leaf of page A at physical page B (0x0b0b0b0b), runs `hfence.gvma x14, x0` with x14 = 0x12a300000 >> 2,
and loads again in VS-mode, which must read page B. The later cases repeat this with bit 33 and with both bits
set, and with the current VMID in rs2.

The ELFs are self-checking: expected values come from Sail. There is one ELF per simulator because the act4
model macros (halt, console) differ. The hart is the riscv-arch-test whisper-rv32-max / spike-rv32-max /
sail-rv32-max configuration.

Expected (Sail, Spike): `RVCP-SUMMARY: TEST PASSED`. Whisper master 6b8cce1a reads the stale page:

    RVCP: Test Info: "test: 685; cg: Sv_H_fence_cg; cp: cp_hfence_gvma_x4; bin: rs1_gpa_rs2_x0_x4bits01"
    RVCP: Bad Value:      0x0a0a0a0a
    RVCP: Expected Value: 0x0b0b0b0b

`fix-hfence-gvma-rv32.patch` computes the address in 64 bits. With it this test passes, and so do
`Svinval_H_sv32x4_inval_x4` (hinval.gvma) and the existing `Sv_H_sv32x4_fence` test.

## Run

    ./run.sh [path/to/whisper] [path/to/spike] [path/to/sail_riscv_sim]

prints PASS/FAIL per simulator. On whisper 6b8cce1a:

    == Sv_H_sv32x4_fence_x4-00
    whisper: FAIL
    spike:   PASS
    sail:    PASS
