# Whisper: memory writes by the IOMMU or a PCI device do not invalidate reservations

Zalrsc (unpriv/zalrsc.adoc, norm:sc_other_device_write_fail): "The SC must fail if a write from some other device
to the bytes accessed by the LR can be observed to occur between the LR and SC." (also norm:sc_device_write_failure).

`lrsc-iommu-write.S` runs on one hart in M-mode with Whisper's IOMMU model (`whisper-iommu.json` is the
riscv-arch-test whisper-rv64-max configuration plus an `iommu` section at 0x30000000 and a PMA region for its
registers). It sets up the IOMMU command queue (`cqb`, `cqt`, `cqcsr.cqen`) and enqueues an IOFENCE.C command with
AV = 1, which makes the IOMMU write DATA (32 bits) to ADDR. It then does `lr.w` on ADDR, writes `cqt` (the IOMMU
executes the command and writes ADDR), checks that ADDR now holds DATA, and does `sc.w` on ADDR with the value its
LR read. The SC must fail; if it succeeds, it overwrites the IOMMU's data.

tohost: 1 = pass (SC failed), 3 = FAIL (SC succeeded after the IOMMU wrote the bytes), 5 = setup problem.

Run: `./run.sh path/to/whisper` (prints PASS or FAIL). Rebuild: `./build.sh` (riscv64-unknown-elf-gcc).

Whisper master fa18e475 (`master.out`): FAIL. The trace shows the LR reading 0x11111111, the load after the
doorbell reading the IOMMU's 0x5a5aa5a5, and the SC succeeding and writing 0x11111111 back:

```
#31 0  M 0000000080000074 1004ae2f r 000000000000001c 0000000011111111 lr.w x28, (x9) [0x80002100]
#34 0  M 000000008000007e 0004ae83 r 000000000000001d 000000005a5aa5a5 lw       x29, 0x0(x9) [0x80002100]
#38 0  M 0000000080000092 19c4af2f r 000000000000001e 0000000000000000 sc.w x30, x28, (x9) [0x80002100]  +
#38 0  M 0000000080000092 19c4af2f m 0000000080002100 0000000011111111 sc.w x30, x28, (x9) [0x80002100]
```

With the IOMMU and PCI memory-write callbacks invalidating every hart's overlapping reservation (`fixed.out`), it
passes.

The PCI DMA path (`System::configPci`'s `writef`, used by the virtio-blk model) has the same cause; this
reproducer does not exercise it, because that needs a PCI configuration with a disk image and a virtio driver.

Other simulators: Spike, Sail and Imperas have no IOMMU or DMA model in their riscv-arch-test configurations, so
the test cannot run on them.
