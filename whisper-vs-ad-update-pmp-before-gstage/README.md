# Whisper: a VS-stage A/D update is checked against PMP before the G-stage translation of the PTE store

A VS-level PTE is at a guest physical address, so the implicit store that sets its A or D bit is subject to
G-stage translation (hypervisor.adoc, norm:H_vm_gstagetrans, norm:H_vm_gpapriv), and PMP applies to the supervisor
physical address that translation produces (norm:H_pmp). Whisper checks PMP write permission first, so when the
G-stage maps the VS page table read-only and PMP also write-protects it, a VS-mode load takes a load access fault
instead of a load guest-page fault.

`vs-ad-update-pmp-before-gstage.S` (M boot, `menvcfg.ADUE` = `henvcfg.ADUE` = 1): the G-stage (Sv39x4)
identity-maps the image and maps the alias GPA 0x140000000 to PA 0x80000000 read-only. `vsatp` (Sv39) has its
root at the alias, and VS root[1] maps VA 0x40000000 with A = 0, so a VS-mode `lw` from 0x40000000 needs an A-bit
store to the VS root table.

- Case 1: PMP lets S/U write everything. Expected: mcause 21, mtval2 = 0 or GPA(VS PTE) >> 2, mtinst = 0x3020 when
  mtval2 != 0.
- Case 2: PMP entry 0 makes the VS root table's page read-only for S/U. Expected: the same as case 1.
- Case 3: as case 2, but `vsatp` uses the root table's identity GPA (writable at the G-stage). Expected: mcause 5.

Run: `./run.sh [path/to/whisper]` (prints PASS or FAIL and the failed check; exit status 0 = pass). The ELF runs as
`whisper --maxinst 100000000:f --config whisper.json vs-ad-update-pmp-before-gstage.elf`; `whisper.json` is the
riscv-arch-test whisper-rv64-max configuration.

Whisper master fa18e475 (`master.out`): case 2 takes mcause 5 with mtval2 = 0 and mtinst = 0x2383; cases 1 and 3
are as expected. With the G-stage write translation done before the PMP check (`fixed.out`), all three pass.

Built with the riscv-arch-test act4 framework (`tests/env`, tree at 205129dbd8) and the check macros in
`include/sa.h` and `include/ai_macros.h` (the `.S` files include them as `../common/sa.h`): each `.S` was put in
a `<testdir>/ai/<Suite>/` directory and built with
`act config/whisper/whisper-rv64-max/test_config.yaml --test-dir <testdir> --extensions <Suite>`.

Other simulators (Spike c20813c, Sail master 81184531, stock Imperas Y-2026.09): Spike, Sail and Imperas pass all three cases.
