# Whisper: M-mode ssamoswap with MPRV=1 and menvcfg.SSE=0 fails an assertion

`ssamoswap` executes in M-mode whatever `menvcfg.SSE` is. With `mstatus.MPRV` = 1 and MPP = S its access is
translated as S-mode (VS-mode with MPV = 1). All five tests run in M-mode with Sv39 page tables that map VA
0x40000000 to an ordinary read-write page, and execute `ssamoswap.d x8, x9, (x6)` on it:

- `whisper-ssamoswap-mprv-sse0.S`: MPP = S; control with `menvcfg.SSE` = 1, case 1 with `menvcfg.SSE` = 0
  (page-table walk), case 2 with `menvcfg.SSE` = 0 after an MPRV `ld` from the page (cached translation).
  Expected cause 7 (store/AMO access fault: not a shadow-stack page, not read-only) for all three.
- `whisper-ssamoswap-mprv-sse0-tlb.S`: the control and case 2 only.
- `whisper-ssamoswap-mprv-mpv-hsse0.S` and `-tlb.S`: the same with MPV = 1 (VS-stage page tables in vsatp,
  identity Sv39x4 G-stage), `menvcfg.SSE` = 1 and `henvcfg.SSE` = 1 (control) or 0 (cases). Expected 7.
- `whisper-ssamoswap-mprv-mpv-sse0-gstage.S`: MPV = 1 with the G-stage leaf for the gigapage holding the
  VS-stage page tables invalid (V = 0, other bits as a valid leaf). An `sd` (control 1), `ssamoswap.d` with
  `menvcfg.SSE` = 1 (control 2) and `ssamoswap.d` with `menvcfg.SSE` = 0 (case) must all raise a store/AMO
  guest-page fault (23) on the first VS-stage PTE read.

Expected: as above. Whisper master (fa18e475, `master.out`): the controls pass, and every program stops on an
assertion at its first case:

```
whisper-ssamoswap-mprv-sse0.elf              VirtMem.cpp:811  pageTableWalk     Assertion `ssEnabled_' failed
whisper-ssamoswap-mprv-sse0-tlb.elf          VirtMem.cpp:314  translate         Assertion `ssEnabled_' failed
whisper-ssamoswap-mprv-mpv-hsse0.elf         VirtMem.cpp:1220 stage1PageTableWalk Assertion `vsSsEnabled_' failed
whisper-ssamoswap-mprv-mpv-hsse0-tlb.elf     VirtMem.cpp:582  stage1Translate   Assertion `vsSsEnabled_' failed
whisper-ssamoswap-mprv-mpv-sse0-gstage.elf   VirtMem.cpp:1220 stage1PageTableWalk Assertion `vsSsEnabled_' failed
```

In the last one the G-stage walk does not fault on the invalid PTE, so the VS-stage walk reaches its leaf
(with the assertions removed, the case then takes cause 7 instead of 23). `fixed.out` is the output with the fix.

## Run

`./run.sh path/to/whisper` (prints PASS or FAIL per ELF and overall; exit status 0 = pass).

## Build

Self-checking programs built with the riscv-arch-test framework (`act`) from riscv-arch-test PR #3162 (commit
205129dbd8, which adds the `tests_ai/common` helpers; `ai_macros.h` and `sa.h` are included here) for the
riscv-arch-test Whisper configuration named below; the `whisper*.json` files are the configurations they run with.
A test prints `RVCP-SUMMARY: TEST PASSED` or `TEST FAILED`; a failed check prints `RVCP: Test Info: <check>` and
the bad value, and soft checks print `SA-MISMATCH: <check> expect=... got=...` and fail the test at the end. Configuration: `whisper-rv64-max`.
