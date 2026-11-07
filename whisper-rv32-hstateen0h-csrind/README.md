# whisper-rv32-hstateen0h-csrind

On RV32, a VS-mode access to `siselect` raises a virtual-instruction exception although `hstateen0h.CSRIND`
(bit 60 of `hstateen0`) and `mstateen0h.CSRIND` are 1. smcsrind.adoc (norm:hypervisor_impl_csrs_access_control):
"When `hstateen0`[60]=0 and `mstateen0`[60]=1, all attempts from VS or VU-mode to access `siselect` or `sireg*`
raise a virtual-instruction exception"; with `hstateen0`[60]=1 the access reaches `vsiselect`
(smstateen.adoc, norm:hstateen0_csrind_op).

The `siselect`/`sireg*` checks in `Hart.cpp` (master 6b8cce1a, lines 13106-13114 and 13158-13166) read
`hstateen0` and `mstateen0` with `CsRegs::read64`, which only adds the high half of CSRs that are marked as a
high/low pair. The `mstateen*h`/`hstateen*h` CSRs are not paired (`CsRegs.cpp`, lines 6992-7004), so on RV32 bit
60 always reads 0. RV64 is not affected.

`hstateen_encoding.S` is the riscv-arch-test rule-derived test `Ssstateen/hstateen_encoding`
(riscv/riscv-arch-test#3162), self-checking, built for the whisper-rv32-max configuration (`whisper-rv32.json`).
HS-mode writes all ones to `hstateen0` and `hstateen0h` (`hstateen0h` reads back 0xde000000, CSRIND set) and
reads `siselect` in VS-mode. On Whisper 6b8cce1a:

    RVCP: Test Info: hstateen_encoding: siselect with hstateen0 written all ones in VS-mode: outcome is the one the stateen bits give (m=x6, h=x8, s=x9: no trap, 2 illegal or 22 virtual); expect 0x00000001
    RVCP: Bad Value:      0x00000000

`stopi` and `scontext`, gated by `hstateen0h.AIA` and `hstateen0h.CONTEXT` through `CsRegs::isStateEnabled`,
pass; only the `CSRIND` checks miss the high half.

## Run

    ./run.sh [path/to/whisper]
