# HFENCE.GVMA with rs2 bits VMIDMAX-1:VMIDLEN set leaves a stale translation

`whisper.json` is the riscv-arch-test whisper-rv64-max configuration, with an `hgatp` mask that implements 7 VMID bits
(VMIDLEN = 7 < VMIDMAX = 14). `hfence-gvma_vmid.elf` (source `hfence-gvma_vmid.S`, riscv-arch-test tests_ai/H) maps a
guest page, changes the G-stage PTE, and executes HFENCE.GVMA x0, rs2 with rs2 = VMID | bits 13:7. The ISA manual says
"if VMIDLEN < VMIDMAX, the implementation shall ignore bits VMIDMAX-1:VMIDLEN of the value held in rs2", so the fence
must remove the stale translation.

`./run.sh`: Whisper 6b8cce1 fails ("after the fence with unimplemented ID bits MAX-1:LEN set: reads D") because it
compares the whole rs2 value with the VMID. With tenstorrent/whisper#232 applied, the test passes.
