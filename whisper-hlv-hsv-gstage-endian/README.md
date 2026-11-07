# Whisper: HLV/HSV data endianness and G-stage page-table endianness

Two defects, one test (`hlv.S`; x31 = bitmask of failed checks; le_word holds 0x11223344 little-endian; MBE = 0;
satp = vsatp = 0):

- HLV/HSV data accesses use the endianness of the current mode (`bigEnd_`) instead of that of their effective mode
  VS (`hstatus.VSBE`, SPVP=1) or VU (`vsstatus.UBE`, SPVP=0). hypervisor.adoc norm:hlsv_priv. Checks 1-10.
- G-stage page-table walks use `hstatus.VSBE` instead of `mstatus.SBE`. G-stage tables are HS-level structures:
  machine.adoc norm:mstatus_sbe_implicit ("For implicit accesses to supervisor-level memory management data
  structures, such as page tables, endianness is always controlled by SBE"), and hstatus.VSBE covers only
  "VS-level memory management data structures" (hypervisor.adoc norm:hstatus_vsbe_implicit). Checks 11-13.

| check | what | expected |
|---|---|---|
| 1 | M, VSBE=1, SPVP=1: hlv.w | 0x44332211 |
| 2 | M, VSBE=0, vsstatus.UBE=1, SPVP=1: hlv.w | 0x11223344 |
| 3 | M, VSBE=0, vsstatus.UBE=1, SPVP=0: hlv.w | 0x44332211 |
| 4 | M, VSBE=1, vsstatus.UBE=0, SPVP=0: hlv.w | 0x11223344 |
| 5 | M, VSBE=1, SPVP=1: hsv.w 0x11223344, M lw | 0x44332211 |
| 6 | M, vsstatus.UBE=1, SPVP=0: hsv.w 0x11223344, M lw | 0x44332211 |
| 7 | M lw right after check 1's hlv.w | 0x11223344 |
| 8 | HS, SBE=1, VSBE=0, SPVP=1: hlv.w | 0x11223344 |
| 9 | HS, SBE=1, VSBE=0: hlv.w of a PMP no-access page traps to M; M handler lw | 0x11223344 |
| 10 | ... mcause | 5 |
| 11 | hgatp with a big-endian identity leaf PTE, SBE=1, VSBE=0: M hlv.w, SPVP=1 | 0x11223344, no trap |
| 12 | hgatp with a little-endian leaf PTE, SBE=0, VSBE=1: M hlv.w, SPVP=1 | 0x44332211, no trap |
| 13 | as 11, VS-mode lw (fetch and load through the G-stage) | 0x11223344, no trap |
| 14 | set if hstatus.VSBE, vsstatus.UBE or mstatus.SBE is read-only; checks needing it are skipped | |

`whisper-rv{64,32}.json` are the whisper-rv*-max configs with mstatus.UBE/SBE/MBE, vsstatus.UBE and hstatus.VSBE
writable.

Whisper master 6b8cce1a (`master.out`):

```
rv64: x31 = 0x386a : 1 3 5 6 11 12 13 (failed checks)
rv32: x31 = 0x386a : 1 3 5 6 11 12 13 (failed checks)
```

Checks 1, 3, 5, 6 are the HLV/HSV data defect; 11 and 12 fail with a guest-page fault because the leaf PTE is read
with VSBE; 13 fails with an instruction guest-page fault on the VS fetch. Checks 8 and 9 pass on master only by
accident: MRET does not update the data endianness (#234), so HS-mode runs with M's. With PR #236 they fail too.

With the fixes (`fixed.out`): HLV/HSV fix alone fails 11-13; G-stage fix alone fails 1, 3, 5, 6, 12 (12 also needs
big-endian HLV data) and 13 (13 also needs #236, so that MRET into VS sets the G-stage endianness); both fixes
plus #236 pass everything.

Run: `./run.sh [path/to/whisper]` (exit status 0 = pass). Rebuild: `./build.sh hlv`. `hlv_rv*_qemu.elf` are the same
test for QEMU virt (prints `x31=<hex>` on the UART, exits through the sifive test finisher).

Other simulators: Spike f90d5af and Sail 0.16 keep VSBE, vsstatus.UBE and SBE read-only 0 (x31 = 0x4000: every
check skipped). QEMU 11.1.3 and master 76fdb33 are fixed-endian (SBE, VSBE read-only) but let vsstatus.UBE be
written: x31 = 0x4048 (checks 3 and 6 fail, the rest skipped). Imperas (RV64, all three bits writable):
x31 = 0x3800: it passes the HLV/HSV checks 1-10 and fails the G-stage checks 11-13 like Whisper.
