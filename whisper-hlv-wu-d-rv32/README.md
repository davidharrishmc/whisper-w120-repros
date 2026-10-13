# whisper-hlv-wu-d-rv32

On an RV32 hart with H that claims Ssstrict, Whisper executes `hlv.wu` and `hlv.d` instead of raising an
illegal-instruction exception. hypervisor.adoc (line 1479): "Instructions HLV.WU, HLV.D, and HSV.D are not valid
for RV32, of course." On RV32 their encodings are therefore unimplemented opcodes in the standard encoding space,
and ssstrict.adoc (lines 8-12, norm:Ssstrict_unimplemented_opcodes_csr_exception): "attempts to execute
unimplemented opcodes ... in the standard or reserved encoding spaces raises an illegal instruction exception".
(Without Ssstrict the base ISA leaves a reserved encoding UNSPECIFIED, unpriv/rv32.adoc line 124.)

The decoder maps both encodings regardless of XLEN (`Decoder.cpp`, master f069895c, lines 3232-3233), and
`execHlv_wu` / `execHlv_d` (`hypervisor.cpp` lines 257 and 293) call `hyperLoad` without an XLEN check;
`execHsv_d` (line 381) already checks `isRv64()` and raises illegal instruction.

`W120H_hlv_rv32-00.S` is a small act4-format test. The hart is RV32I + Zicsr + S + U + H + Ssstrict (derived
configuration RVI20U32-h with Ssstrict added; Spike `--isa=rv32ih_zicsr_ssstrict`; Sail `Ssstrict.supported`
true). It boots to HS-mode, where HLV is permitted, executes `hlv.w` (positive control, loads normally), then the
`hlv.wu` (0x68134573) and `hlv.d` (0x6c034573) encodings, which must raise illegal-instruction exceptions; the
trap is delegated to the supervisor trap handler, which records it.

The ELFs are self-checking: expected values come from Sail. There is one ELF per simulator because the act4
model macros (halt, console) differ.

Expected (Sail, Spike): `RVCP-SUMMARY: TEST PASSED`. Whisper master f069895c executes hlv.wu:

    RVCP: Test Info: hlv.wu (0x68134573)
    RVCP: Register: x10
    RVCP: Bad Value:      0x12345678
    RVCP: Expected Value: 0x00000bad

## Run

    ./run.sh [path/to/whisper] [path/to/spike] [path/to/sail_riscv_sim]

prints PASS/FAIL per simulator. On whisper f069895c:

    == W120H_hlv_rv32-00
    whisper: FAIL
    spike:   PASS
    sail:    PASS

With the fix (`execHlv_wu` and `execHlv_d` raise illegal instruction unless RV64, like `execHsv_d`), whisper
prints PASS.

Files: `whisper.json` (Whisper has no Ssstrict switch; it is the RVI20U32-h configuration), `spike_args.txt`
(spike options), `sail.json` (Sail 0.15 configuration) and the three ELFs built from the .S by the act4 framework
(hypervisor branch test environment).
