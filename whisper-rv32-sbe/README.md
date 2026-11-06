# whisper-rv32-sbe

On RV32, `mstatush.SBE` reads back 1, but after MRET into S-mode, S-mode loads and stores stay
little-endian. machine.adoc (norm:mstatus_sbe_op): "sbe controls whether explicit load and store memory
accesses made from S-mode are little-endian (sbe=0) or big-endian (sbe=1)." Whisper implements big-endian
data accesses (`bigEnd_`, set by `updateBigEndian` from MBE/SBE/UBE for the effective mode), and the
riscv-arch-test whisper-rv32-max configuration declares `S_MODE_ENDIANNESS: dynamic`.

`updateBigEndian` runs when mstatus is written, but `execMret` (`Hart.cpp`, master 6b8cce1a) writes mstatus
(line 12685) while still in M-mode and only then calls `setPrivilegeMode` (line 12710), which does not
recompute `bigEnd_` (`Hart.hpp`, lines 3234-3238). So S-mode keeps M-mode's endianness (MBE = 0). SRET has
the same order.

`mstatus_sbe_op.S` is the riscv-arch-test rule-derived test for norm:mstatus_sbe_op
(riscv/riscv-arch-test#3162), self-checking, built for the whisper-rv32-max configuration
(`whisper-rv32.json`). M-mode sets SBE and, if it reads back 1, MRETs to S-mode, which loads the word stored
as 0x11223344 and stores 0x55667788; M-mode (MBE = 0) must then read 0x88776655. On Whisper 6b8cce1a:

    RVCP: Test Info: mstatus_sbe_op: lw with SBE = 1 is big-endian; expect 0x44332211
    RVCP: Bad Value:      0x11223344

and the `--log` trace shows the S-mode store writing 0x55667788 (little-endian). Sail keeps SBE read-only 0,
so `mstatus_sbe_op.sail.elf` (sail-rv32-max, `sail-rv32.json`) skips the check and passes.

## Run

    ./run.sh [path/to/whisper] [path/to/sail_riscv_sim]
