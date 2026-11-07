# Whisper: DRET does not apply the Sdext resume rules for MPRV, MDT and SDT

Sdext.adoc (Resume) says that when the hart resumes from Debug Mode:

- if the new privilege mode is less privileged than M-mode, `mstatus.MPRV` is cleared;
- with Smdbltrp, if the new privilege mode is not M, `MDT` is set to 0;
- with Ssdbltrp, if the new privilege mode is U, VS or VU, `sstatus.SDT` is set to 0, and if it is VU,
  `vsstatus.SDT` is also set to 0.

`dret.S` enters Debug Mode with `ebreak` (`whisper-rv*.json` makes `dcsr.ebreakm` reset to 1, makes the
`dcsr` ebreak/prv/v fields writable, and sets `debug_park_loop` to the `park` label). For each new mode
M, S, U, VS and VU it sets `mstatus.MPRV`, `MDT`, `SDT` and `vsstatus.SDT` to 1 in Debug Mode, sets
`dcsr.prv`/`dcsr.v`, and executes `dret` to an `ebreak`, which re-enters Debug Mode at once
(`dcsr.ebreaks/u/vs/vu` = 1). Back in Debug Mode it checks the four bits. No trap is taken.

x31 is a bitmask of failed checks: check 1 + 4*step + field, with step M=0, S=1, U=2, VS=3, VU=4 and field
MPRV=0, MDT=1, SDT=2, vsstatus.SDT=3. tohost = (x31 << 1) | 1.

Expected: x31 = 0 (M: nothing cleared; S: MPRV, MDT; U and VS: MPRV, MDT, SDT; VU: all four).

Whisper master 6b8cce1a (`master.out`): x31 = 0x1eee60 on RV64 and RV32, every bit that should be
cleared stays 1:

```
rv64: x31 = 0x1eee60
  FAIL check 5: dret to S: MPRV
  FAIL check 6: dret to S: MDT
  FAIL check 9: dret to U: MPRV
  FAIL check 10: dret to U: MDT
  FAIL check 11: dret to U: SDT
  FAIL check 13: dret to VS: MPRV
  FAIL check 14: dret to VS: MDT
  FAIL check 15: dret to VS: SDT
  FAIL check 17: dret to VU: MPRV
  FAIL check 18: dret to VU: MDT
  FAIL check 19: dret to VU: SDT
  FAIL check 20: dret to VU: vsstatus.SDT
rv32: x31 = 0x1eee60
  FAIL check 5: dret to S: MPRV
  FAIL check 6: dret to S: MDT
  FAIL check 9: dret to U: MPRV
  FAIL check 10: dret to U: MDT
  FAIL check 11: dret to U: SDT
  FAIL check 13: dret to VS: MPRV
  FAIL check 14: dret to VS: MDT
  FAIL check 15: dret to VS: SDT
  FAIL check 17: dret to VU: MPRV
  FAIL check 18: dret to VU: MDT
  FAIL check 19: dret to VU: SDT
  FAIL check 20: dret to VU: vsstatus.SDT
```

Run: `./run.sh [path/to/whisper]` (prints the failed checks; exit status 0 = pass). Rebuild: `./build.sh`.

Other simulators: Spike, Sail and QEMU have no Debug Mode that a bare-metal program can enter, so the test
cannot run there. Imperas (`debug_mode=vector`, `debug_address=0x80000800`, `dexc_address=0x80000900`,
`dcsr_ebreak_mask=0x3f`) gives x31 = 0x44440 on RV64: it clears MPRV, SDT and vsstatus.SDT, but leaves MDT = 1.
