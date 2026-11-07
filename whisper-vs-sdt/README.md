# whisper-vs-sdt

With Ssdbltrp, H and `menvcfg.DTE = henvcfg.DTE = 1`, Whisper does not implement `vsstatus.SDT` for traps into
VS-mode or for MRET/MNRET into VU-mode:

- check 2: a trap into VS-mode does not set `vsstatus.SDT`. supervisor.adoc (norm:sstatus_sdt_trap): "When a trap
  is to be taken into S-mode, if the `SDT` bit is currently 0, it is then set to 1"; hypervisor.adoc
  (norm:vsstatus_sdt_op) applies this to `vsstatus` in VS-mode.
- check 4: a trap into VS-mode with `vsstatus.SDT = 1` is delivered to VS-mode. It is an unexpected trap: "a
  double-trap exception trap is delivered into M-mode" (`mcause` = 16).
- check 5: MRET into VU-mode does not clear `vsstatus.SDT`. machine.adoc (norm:vsstatus_sdt_clr_mret_sret):
  "Additionally, if it is VU, then csr:vsstatus[sdt] is also set to 0." MNRET has the same problem
  (norm:vsstatus_sdt_clr_mnret).

`Hart::initiateTrap` (`Hart.cpp`, master 6b8cce1a) checks SDT only when `not nextVirt` (line 3670) and sets it
only when `not virtMode_` (line 3911); `execMret` (line 12681) and `execMnret` (line 12925) clear only
`mstatus.SDT`. Related: whisper#228 (SRET does not clear `vsstatus.SDT`).

`whisper_vs_sdt.S` is a standalone self-checking test for the whisper-rv64-max configuration (`whisper.json`).
x31 is the bitmask of failed checks and `tohost` = (x31 << 1) | 1. On Whisper 6b8cce1a, x31 = 0x34 (checks 2, 4
and 5); the trace line that computes x5 = x31 << 1 shows 0x68:

    #140 0  M 00000000800000e0 001f9293 r 0000000000000005 0000000000000068 slli     x5, x31, 1

## Run

    ./run.sh [path/to/whisper]     # prebuilt whisper_vs_sdt.elf
    make run WHISPER=path/to/whisper   # rebuild with riscv64-unknown-elf-gcc
