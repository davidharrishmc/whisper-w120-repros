# whisper-h-hfence-rs2

HFENCE.GVMA and HFENCE.VVMA use the whole rs2 value as the VMID / ASID. hypervisor.adoc
(norm:hfence-gvma_vmid, norm:hfence-vvma_asid): "bits XLEN-1:VMIDMAX of the value held in _rs2_ are reserved
for future standard use. Until their use is defined by a standard extension, they should be zeroed by software
and ignored by current implementations. Furthermore, if VMIDLEN < VMIDMAX, the implementation shall ignore bits
VMIDMAX-1:VMIDLEN of the value held in _rs2_" (and the same for ASIDs). With a reserved bit set, Whisper
fences a different VMID / ASID and the stale translation stays in use.

`execHfence_vvma` and `execHfence_gvma` (`hypervisor.cpp`, master 6b8cce1a, lines 63, 78, 127 and 145) read
rs2 unmasked:

    URV vmid = intRegs_.read(di->op1());

Each test maps a guest virtual page to page A (0x5a5a0111) through the VS-stage and G-stage, loads it with
`hlv.w`, retargets the leaf at page B (0x5a5a0222), runs the fence with rs2 = current VMID / ASID (0) plus one
reserved bit (bit 30 for `hfence.gvma x0, rs2`, bit 20 for `hfence.vvma x0, rs2`), and loads again, which
must read page B. They are riscv-arch-test rule-derived tests (riscv/riscv-arch-test#3162) for the
whisper-rv64-max configuration (`whisper.json`); the `.sail.elf` builds pass on Sail. On Whisper 6b8cce1a:

    RVCP: Test Info: whisper_hfence_gvma_rs2_bit30: hlv.w (after fence rs2=0x40000000) loads 0x5a5a0222; expect 0x000000005a5a0222
    RVCP: Bad Value:      0x000000005a5a0111
    RVCP: Test Info: whisper_hfence_vvma_rs2_bit20: hlv.w (after fence rs2=0x100000) loads 0x5a5a0222; expect 0x000000005a5a0222
    RVCP: Bad Value:      0x000000005a5a0111

## Run

    ./run.sh [path/to/whisper] [path/to/sail_riscv_sim path/to/sail.json]
