# Whisper: a misaligned AMO, LR or SC that faults on its second page reports rs1 in xtval

When a misaligned access crosses a page boundary and only the second page faults, the trap value must be the
address of the faulting portion (or 0):

- priv/machine.adoc:2026-2028, norm:mtval_vaddr_wr_misaligned_addr: "If `mtval` is written with a nonzero value
  when a misaligned load or store causes an access-fault, page-fault, or hardware-error exception, then `mtval`
  will contain the virtual address of the portion of the access that caused the fault." (supervisor.adoc:731-736,
  norm:stval_op_load_store_fault, says the same for `stval`.)
- priv/hypervisor.adoc:2050-2058, norm:H_straddle: "the faulting virtual address written to `mtval`/`stval` is
  the same as would be required for a regular page fault. Thus, the faulting virtual address may be a page-boundary
  address that is higher than the instruction's original virtual address".
- priv/hypervisor.adoc:2060-2064, norm:mtval2_htval_virtaddr: "a nonzero guest physical address written to
  `mtval2`/`htval` shall correspond to the exact virtual address written to `mtval`/`stval`."
- priv/hypervisor.adoc:2797-2801, norm:H_tinst_addr_offset: the Addr. Offset of a transformed instruction "is the
  positive difference between the faulting virtual address (written to `mtval` or `stval`) and the original
  virtual address".

A misaligned AMO/LR/SC may instead raise an address-misaligned or access-fault exception; the tests accept those.

- `whisper-amo-straddle-htval.S` (H): HS boot, vsatp = Bare, hgatp = Sv39x4 identity-mapping GPA
  0x80000000-0xffffffff, GPA 0x100000000 unmapped. In VS-mode, `amoadd.w`, `lr.w` and `sc.w` at 0xfffffffe
  straddle into the unmapped page. For a guest-page fault it checks stval (0 or 0x100000000), htval (0 or the GPA
  of stval >> 2) and htinst (0 or the transformed instruction with Addr. Offset stval - 0xfffffffe).
- `whisper-amo-straddle-stval-s.S` (no H): satp = Sv39 mapping only 0x80000000-0xffffffff; the same three
  instructions in S-mode; for a page fault it checks stval (0 or 0x100000000).

Each test fails with a bitmask of failed checks; `run.sh` decodes it.

Run: `./run.sh path/to/whisper` (prints PASS or FAIL per ELF and the failed checks). `whisper.json` is the
riscv-arch-test whisper-rv64-max configuration. The ELFs were built with the riscv-arch-test (ACT4) framework
(`tests_ai` self-checking harness, Sail as the reference model); the `.S` files are the sources.

Whisper master fa18e475 (`master.out`): every instruction takes the (guest-)page fault for the second page but
reports stval = 0xfffffffe; with H, htval = 0x40000000 (the GPA of the second page) and htinst has Addr. Offset 0:

```
         scause  stval       htval       htinst
amoadd.w 23      0xfffffffe  0x40000000  0x009023af
lr.w     21      0xfffffffe  0x40000000  0x100023af
sc.w     23      0xfffffffe  0x40000000  0x189023af
S-mode:  15/13/15, stval 0xfffffffe
```

With the atomic paths reporting the faulting part (`fixed.out`): stval = 0x100000000, htval = 0x40000000,
htinst = 0x009123af / 0x100123af / 0x189123af (Addr. Offset 2), and both tests pass.

Other simulators: Spike c20813c, Sail master 81184531 and stock Imperas Y-2026.09 pass both tests (Spike and Sail
take a store or load access fault, which a misaligned AMO/LR/SC may raise).
