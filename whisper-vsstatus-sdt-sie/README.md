# Whisper: vsstatus writes do not apply the Ssdbltrp rule "SDT=1 forces SIE=0"

supervisor.adoc norm:sstatus_sdt_sstatus_sie_overwrite: "When the SDT bit is set to 1 by an explicit CSR write,
the SIE (Supervisor Interrupt Enable) bit is cleared to 0. This clearing occurs regardless of the value written,
if any, to the SIE bit by the same write. The SIE bit can only be set to 1 by an explicit CSR write if the SDT bit
is being set to 0 by the same write or is already 0." vsstatus is the VS-level sstatus (it substitutes for sstatus
when V=1), so the rule applies to writes of vsstatus and to VS-mode writes of sstatus. Whisper applies it only to
mstatus/sstatus with V=0.

`vssie.S` (menvcfg.DTE = henvcfg.DTE = 1; x31 = bitmask of failed checks):

| check | write | expected |
|---|---|---|
| 1 | M-mode `csrs vsstatus, SDT\|SIE` | vsstatus.SIE = 0 |
| 2 | M-mode, vsstatus = SDT: `csrs vsstatus, SIE` | vsstatus.SIE = 0 |
| 3 | M-mode, vsstatus = SDT: `csrw vsstatus, SIE` (clears SDT) | vsstatus.SIE = 1 |
| 4 | HS-mode `csrs vsstatus, SDT\|SIE` | vsstatus.SIE = 0 |
| 5 | VS-mode `csrs sstatus, SDT\|SIE` | vsstatus.SIE = 0 |
| 6 | VS-mode, vsstatus = SDT: `csrs sstatus, SIE` | vsstatus.SIE = 0 |
| 7 | M-mode `csrs sstatus, SDT\|SIE` (V=0, control) | sstatus.SIE = 0 |
| 8 | after check 5 | vsstatus.SDT = 1 (the write took effect) |

Whisper master 6b8cce1a (`master.out`, whisper-rv64-max and whisper-rv32-max configs unchanged):

```
rv64: x31 = 0x76 : 1 2 4 5 6 (failed checks)
rv32: x31 = 0x76 : 1 2 4 5 6 (failed checks)
```

Run: `./run.sh [path/to/whisper]` (exit status 0 = pass). Rebuild: `./build.sh vssie`. `vssie_rv*_qemu.elf` are
the same test for QEMU virt (`qemu-system-riscv64 -nographic -machine virt -cpu max -bios vssie_rv64_qemu.elf`;
prints `x31=<hex>` and exits through the sifive test finisher).

Other simulators: Spike f90d5af, Sail 0.16, QEMU master 76fdb33 and Imperas (RV64) pass (x31 = 0) on RV64 and RV32.
QEMU 11.1.3 fails only check 8 (a VS-mode write of sstatus.SDT does not set vsstatus.SDT), so its pass of check 5
is not evidence.
