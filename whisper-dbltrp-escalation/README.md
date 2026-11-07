# whisper-dbltrp-escalation

With Ssdbltrp, a trap into S/HS-mode while `sstatus.SDT` = 1 is an unexpected trap, delivered into M-mode as a
double trap. supervisor.adoc, norm:sstatus_sdt_trap: "the hart writes registers, except `mcause` and `mtval2`, with
the same information that the _unexpected trap_ would have written if it was taken into M-mode." Whisper builds
this trap by hand in `Hart::initiateTrap` (`Hart.cpp`, master 6b8cce1a, lines 3667-3706) and returns before the
rest of the trap-into-M path, so it skips most of what that path writes.

`dbltrp_entry.S` is a bare-metal M-mode test. Each double trap comes from S/HS-mode (non-virtual), so master can
reach it. x31 is the bitmask of failed checks; `tohost` = (x31 << 1) | 1.

| check | what | Whisper 6b8cce1a |
|---|---|---|
| 1 | CTR (`mctrctl.M` = `sctrctl.S` = 1): an S-mode illegal instruction + ecall makes as many records when escalated as when it traps straight into M | 5 records, 6 expected |
| 2 | `mcause` = 16 | pass |
| 3 | `mtval2` = 2 | pass |
| 4 | M-mode handler `lw` is little-endian (`mstatus.MBE` = 0, `SBE` = 1) | 0x44332211 |
| 5 | `minstret` does not count in the M-mode handler (`minstretcfg.MINH` = 1) | counts 3 |
| 6 | `tcontrol.MPTE` = 1 (old MTE), `tcontrol.MTE` = 0 | `tcontrol` = 0x88, unchanged |
| 7 | HLV.W access fault in HS-mode, escalated: `mstatus.GVA` = 1 | GVA = 0 |
| 8 | ... `mtinst` = the value for the same fault taken straight into M (0x68004373), or 0 | stale 0x7777 |
| 9 | landing-pad fault (Zicfilp, ELP = 1), escalated: `mstatus.MPELP` = 1, ELP cleared | see below |
| 10 | control for 7: the same HLV.W fault taken straight into M sets GVA = 1 | pass |

Check 9: Whisper neither saves MPELP nor clears ELP. ELP stays 1, so the M-mode handler's first instruction takes a
landing-pad software-check exception while `mstatus.MDT` = 1. That is an unexpected trap, delivered as an RNMI with
`mncause` = 0x12 (the test's RNMI handler at `nmi_vec` marks check 9 failed and ends the test).

On Whisper 6b8cce1a, x31 = 0x3f2 (checks 1, 4, 5, 6, 7, 8, 9) on RV64 and RV32. The trace line that computes
x5 = x31 << 1 shows 0x7e4:

    #465 0  M ... slli     x5, x31, 1        (x5 = 0x00000000000007e4)

The configurations `whisper-rv64.json` and `whisper-rv32.json` are riscv-arch-test's whisper-rv64-max and
whisper-rv32-max (which include Smctr, Ssctr, Smcntrpmf, Sdtrig, Zicfilp, Smdbltrp, Ssdbltrp and Smrnmi) with
`mstatus.SBE`/`MBE`/`UBE` and `hstatus.VSBE` made writable and `nmi_vec` = 0x80000800 (plus Zilsd on RV32).
Only check 4 needs a writable `SBE`.

## Run

    ./run.sh [path/to/whisper]     # prebuilt w_rv64.elf and w_rv32.elf
    make                           # rebuild with riscv64-unknown-elf-gcc; q_rv*.elf are QEMU builds

QEMU: `qemu-system-riscv64 -nographic -machine virt -cpu max -bios q_rv64.elf` prints `x31=0x...`.
Spike: `spike --isa=<riscv-arch-test spike-rv64-max isa>_smrnmi w_rv64.elf` (exit status = x31).
