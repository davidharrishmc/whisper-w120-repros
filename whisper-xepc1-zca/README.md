# whisper-xepc1-zca

With Zca implemented, IALIGN is 16, so bit 1 of mepc/sepc must be kept. Whisper keys the xepc read mask
on misa.C instead (`CsRegs::enableRvc`, called only from the misa.C path of `Hart::processExtensions`),
so on a hart with Zca but misa.C = 0, mepc[1] reads as zero and mret/sret return 2 bytes early.
C depends on Zcf when XLEN=32 and F is present, and on Zcd when D is present (c-st-ext.adoc
`norm:C_dep_Zcf`, `norm:C_dep_Zcd`), so misa.C is 0 on such harts without Zcf/Zcd, while Zca still gives IALIGN=16 (zca.adoc `norm:Zca_align16`); machine.adoc
`norm:mepc_align` drops mepc[1] only for IALIGN=32.

The hart is RVI20U32 + F + D + Zca + Zcd (no Zcf, so no C): whisper `isa: rv32ifd_zca_zcd_zicsr`,
misa = 0x40000128 (C clear); spike `--isa=rv32ifd_zca_zcd_zicsr`; Sail with the same extensions.
`W120Xepc_zca-00.S` points mepc at a halfword-aligned instruction (4n+2) and executes mret; the
instruction at 4n is a `c.j` to a failure path. It then reads mepc back and checks misa.C = 0.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

Expected (Whisper master f069895c):

    whisper: FAIL   (mret returns to 4n: "test: 1 ... mret_target", x12 = 0xbad, expected 5)
    spike:   PASS
    sail:    PASS

With the fix, whisper: PASS.

Files: `whisper.json`, `spike_cmd.txt`, `sail.json` (Sail 0.15), the .S, and one ELF per simulator
(built by the act4 framework from the .S; expected values come from Sail).
