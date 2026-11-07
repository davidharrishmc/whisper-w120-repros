# Whisper: hfence.gvma with rs2=x0 only fences the current VMID

hypervisor.adoc (norm:hfence-gvma_op) defines rs2!=x0 as "a single virtual machine identifier (VMID)", so
rs2=x0 means all VMIDs, and the PMP section says "Executing an HFENCE.GVMA instruction with rs1=x0 and rs2=x0
suffices to flush all G-stage or VS-stage address-translation cache entries". `execHfence_gvma`
(hypervisor.cpp, master 6b8cce1a, lines 122-126 and 131-139) uses `virtMem_.vmid()` (the current hgatp.VMID)
when rs2=x0, so G-stage translations cached under any other VMID survive the fence. hinval.gvma runs the same
code.

Each test (RV64, M-mode, vsatp=Bare, hgatp Sv39x4) loads GPA 0x40000000 with hlv.w under VMID 1 (page A,
0x11111111), switches hgatp to VMID 2, retargets the G-stage leaf to page B, runs the fence, switches back to
VMID 1 and loads again, which must read page B (0x22222222):

- gvma_allvmid_x0: `hfence.gvma x0, x0`
- gvma_allvmid_gpa: `hfence.gvma rs1, x0`, rs1 = 0x40000000 >> 2
- gvma_samevmid_ctrl: control, the fence is issued under VMID 1 (passes on master)
- gvma_othervmid_probe: `hfence.gvma x0, rs2` with rs2 = 2. Here the stale value ("FAIL check 2") is the
  expected result: it shows that the simulator keeps VMID 1 translations across a fence for another VMID,
  which the tests above need in order to mean anything.

tohost = (n << 1) | 1: n = 0 pass, 1 first load wrong, 2 load after the fence wrong (stale), 99 unexpected trap.

Whisper 6b8cce1a:

    gvma_samevmid_ctrl [base.json]: PASS
    gvma_allvmid_x0 [base.json]: FAIL check 2
    gvma_allvmid_gpa [base.json]: FAIL check 2
    gvma_othervmid_probe [base.json]: FAIL check 2

Expected (and with the fix): the first three PASS, the probe FAIL check 2.

Run: `./run.sh path/to/whisper`. base.json is the riscv-arch-test whisper-rv64-max config.
`./build.sh` rebuilds the ELFs: `*.elf` for Whisper; `*_nosmrnmi.elf` without the mnstatus.NMIE write
(Spike, Sail and Imperas lack Smrnmi); `*_qemu.elf` (also without it) exit through the QEMU virt test
finisher (`qemu-system-riscv64 -nographic -machine virt -cpu max -bios X_qemu.elf`, exit code = n).

Other simulators: Sail 0.16 and Imperas pass the three tests and keep VMID 1 entries in the probe. Spike
f90d5af and QEMU (11.1.3 and master 76fdb33) pass, but they also pass the probe (any hfence.gvma flushes
everything), so their passes are no evidence either way.
