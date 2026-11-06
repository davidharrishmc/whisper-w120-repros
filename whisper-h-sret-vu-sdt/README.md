# whisper-h-sret-vu-sdt

With Ssdbltrp and `menvcfg.DTE = henvcfg.DTE = 1`, SRET does not clear `vsstatus.SDT` when it is executed in
HS-mode and the new privilege mode is VU, or when it is executed in VS-mode. hypervisor.adoc (norm:sret_dt):
"If the Ssdbltrp extension is implemented, when `SRET` is executed in HS-mode, if the new privilege mode is VU,
the `SRET` instruction sets `vsstatus.SDT` to 0. When executed in VS-mode, `vsstatus.SDT` is set to 0."

`execSret` (`Hart.cpp`, master 6b8cce1a, lines 12832-12837) only clears `mstatus.SDT`.

`sret_dt.S` is the riscv-arch-test rule-derived test for norm:sret_dt (riscv/riscv-arch-test#3162),
self-checking, built for the whisper-rv64-max and whisper-rv32-max configurations (`whisper-rv64.json`,
`whisper-rv32.json`). HS-mode sets `vsstatus.SDT`, returns to VU-mode and checks that SDT is 0; then it
returns to VS-mode, runs SRET in VS-mode and checks SDT again. On Whisper 6b8cce1a (RV64 and RV32):

    RVCP: Test Info: sret_dt: SRET from HS-mode into VU-mode clears vsstatus.SDT; expect 0x0000000000000000
    RVCP: Bad Value:      0x0000000001000000

With only the HS-to-VU case fixed, the VS-mode case fails the same way
(`SRET in VS-mode clears vsstatus.SDT`, bad value 0x1000000).

`diag_sdt2.S` sets `vsstatus.SDT`, does SRET into VU-mode and back, and always fails so that it prints
`vsstatus`: Whisper 6b8cce1a prints 0x8000000201006600 (SDT, bit 24, still set).

## Run

    ./run.sh [path/to/whisper]
