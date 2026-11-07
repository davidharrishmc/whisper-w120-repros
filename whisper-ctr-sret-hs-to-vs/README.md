# whisper-ctr-sret-hs-to-vs

With Smctr/Ssctr and H, Whisper decides whether the HS-mode source of an SRET from HS-mode into VS-mode is enabled
from `vsctrctl.S` instead of `sctrctl.S`. smctr.adoc, Virtualization Mode Transitions: "`mctrctl`.M, `sctrctl`.S,
and `vsctrctl`.{S,U} are used to determine whether the source and target modes are enabled". Here the source is HS
(`sctrctl.S`) and the target VS (`vsctrctl.S`).

- check 1: `sctrctl.S = 0`, `vsctrctl.S = 1`. A trap return from a disabled mode is "Not recorded"
  (norm:ctr_trapret_de), so `sctrstatus.WRPTR` stays 0. Whisper records the SRET (WRPTR = 1).
- check 2: `sctrctl.S = 1`, `vsctrctl.S = 0`. A trap return from an enabled mode into a disabled mode is
  "Recorded, `ctrtarget`.PC is 0" (norm:ctr_trapret_ed), so WRPTR = 1. Whisper does not record it (WRPTR = 0).
- check 3: the entry recorded in check 2 has `ctrsource` = the SRET's pc | V.

`Hart::execSret` (`Hart.cpp`, master 6b8cce1a, line 12858) sets V before it calls `ctrRecordTrapReturn` (line
12871). `ctrRecordingEnabled(Supervisor, virt = false)` (`ctr.cpp`, line 147) then reads `SCTRCTL` with `peekCsr`,
which follows the current virtual mode, and `SCTRCTL` maps to `VSCTRCTL` while V = 1 (`CsRegs.cpp`, line 6376). The
other CTR helpers in `ctr.cpp` (lines 183, 216, 249, 310, 455) read `SCTRCTL` the same way.

`whisper_ctr_sret.S` is a standalone bare-metal M-mode test, built without C for the whisper-rv64-max and
whisper-rv32-max configurations with `smcsrind_sscsrind_smctr_ssctr` added to the isa string (`whisper-rv64.json`,
`whisper-rv32.json`). x31 is the bitmask of failed checks and `tohost` = (x31 << 1) | 1. On Whisper 6b8cce1a,
x31 = 0xe (checks 1, 2 and 3) on both XLENs; the trace line that computes x5 = x31 << 1 shows 0x1c:

    #122 0  M 0000000080000134 001f9293 r 0000000000000005 000000000000001c slli     x5, x31, 1

QEMU 11.1.3 (`make qemu`) passes.

## Run

    ./run.sh [path/to/whisper]             # prebuilt w_rv64.elf and w_rv32.elf
    make whisper WHISPER=path/to/whisper   # rebuild with riscv64-unknown-elf-gcc
