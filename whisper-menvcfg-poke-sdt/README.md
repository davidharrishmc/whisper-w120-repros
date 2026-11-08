# Whisper: poking menvcfg/henvcfg does not apply the DTE rules (snapshot restore loses SDT)

`CsRegs::write` of `menvcfg` calls `enableSdt(menvcfg.DTE)`, which makes `mstatus.SDT`, `sstatus.SDT` and
`henvcfg.DTE` readable and writable when DTE = 1, and a write of `menvcfg` or `henvcfg` calls
`updateVsstatusSdt()` for `vsstatus.SDT`. `CsRegs::poke` does neither. After a test bench poke of `menvcfg`,
or a snapshot restore (which pokes every CSR), those bits stay read-only zero with DTE = 1: the restored
`mstatus.SDT` reads as 0, `henvcfg.DTE` reads as 0, and software cannot set SDT.

`sdt.S` sets `menvcfg.DTE`, `henvcfg.DTE` (`menvcfgh`/`henvcfgh` on RV32) and `mstatus.SDT` in M-mode, runs a
nop sled, then checks:

- check 1: `csrr mstatus` shows SDT = 1;
- check 2: `csrr henvcfg` shows DTE = 1;
- check 3: after `csrc`/`csrs sstatus` of SDT, `sstatus` shows SDT = 1;
- check 4: after `csrs vsstatus` of SDT, `vsstatus` shows SDT = 1.

x31 = bitmask of failed checks; tohost = (x31 << 1) | 1. No trap is taken. `run.sh` runs each ELF straight
through, then saves a snapshot after 40 instructions (in the sled; `--snapshotperiod 40 --snapshotdir
snap-rv$x/s`) and runs from it (`--loadfrom snap-rv$x/s0`).

Expected: x31 = 0 for the straight and restored runs.

Whisper master 6b8cce1a (`master.out`): the straight runs pass; the restored runs give x31 = 0x1e on RV64 and
RV32 (the snapshot has `mstatus.SDT` = 1 and `menvcfg.DTE` = 1):

```
rv64 straight run: x31 = 0x0
  PASS
rv64 snapshot at instruction 40: pm 3 pc 0x8000005e 
rv64 restored from snapshot: x31 = 0x1e
  FAIL check 1: mstatus.SDT lost
  FAIL check 2: henvcfg.DTE reads 0
  FAIL check 3: sstatus.SDT not writable/readable
  FAIL check 4: vsstatus.SDT not writable/readable
rv32 straight run: x31 = 0x0
  PASS
rv32 snapshot at instruction 40: pm 3 pc 0x80000060 
rv32 restored from snapshot: x31 = 0x1e
  FAIL check 1: mstatus.SDT lost
  FAIL check 2: henvcfg.DTE reads 0
  FAIL check 3: sstatus.SDT not writable/readable
  FAIL check 4: vsstatus.SDT not writable/readable
```

With `CsRegs::poke` applying the same rules as `CsRegs::write` (`fixed.out`), all four runs pass.

Run: `./run.sh [path/to/whisper]` (prints the failed checks; exit status 0 = pass). Rebuild: `./build.sh`.

Other simulators: CSR poke and snapshot save/restore are Whisper features, so there is no equivalent to
compare. The straight-through test is ordinary Ssdbltrp code.
