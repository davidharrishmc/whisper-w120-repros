# whisper-ssamoswap-rd-rs2

`ssamoswap.w` / `ssamoswap.d` with rd = rs2 store the loaded value instead of the original rs2 value.
cfi.adoc (norm:rv32_ssamoswap-w_op) lists the operation as `temp = mem[X(rs1)]; mem[X(rs1)] = X(rs2);
X(rd) = temp`, so rd is written last (riscv/riscv-isa-manual#3433).

`execSsamoswap_w` and `execSsamoswap_d` (`shadow-stack.cpp`, master 6b8cce1a, lines 222-224 and 278-280)
write rd before they read rs2:

    intRegs_.write(rd, SRV(int32_t(data)));

    URV rs2Val = intRegs_.read(rs2);

`rv32_ssamoswap-w_op.S` (XLEN-wide swap: `ssamoswap.w` on RV32, `ssamoswap.d` on RV64) and
`rv64_ssamoswap-w_op.S` (RV64 `ssamoswap.w`) are riscv-arch-test rule-derived tests
(riscv/riscv-arch-test#3162), self-checking, built for the whisper-rv64-max and whisper-rv32-max
configurations (`whisper-rv64.json`, `whisper-rv32.json`; `.rv64.elf` / `.rv32.elf`). In S-mode on a
shadow-stack page they run, among other cases, `ssamoswap x8, x8, (x6)` and read the word back. The
`.sail.elf` builds (sail-rv64-max / sail-rv32-max, `sail-rv64.json`, `sail-rv32.json`) pass on Sail.
On Whisper 6b8cce1a:

    RVCP: Test Info: rv32_ssamoswap-w_op: ssamoswap in S-mode (rd=x8, rs1=x6, rs2=x8) stores rs2; expect 0x471abff9fd635c2f
    RVCP: Bad Value:      0xebaf53775cbed8ef
    RVCP: Test Info: rv64_ssamoswap-w_op: ssamoswap.w in S-mode stores rs2[31:0]; expect 0x0000000000000002
    RVCP: Bad Value:      0x00000000f0f0f0f0
    RVCP: Test Info: rv32_ssamoswap-w_op: ssamoswap in S-mode (rd=x8, rs1=x6, rs2=x8) stores rs2; expect 0xdf2d8867
    RVCP: Bad Value:      0x5cbed8ef

The bad value is the word that was already in memory.

## Run

    ./run.sh [path/to/whisper] [path/to/sail_riscv_sim]
