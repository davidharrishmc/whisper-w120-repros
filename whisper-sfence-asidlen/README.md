# Whisper: sfence.vma does not ignore rs2 bits above ASIDLEN

supervisor.adoc (norm:sfence_vma_rs2_bits): "if ASIDLEN<ASIDMAX, the implementation shall ignore bits
ASIDMAX-1:ASIDLEN of the value held in rs2" (bits SXLEN-1:ASIDMAX "should be zeroed by software and ignored
by current implementations"). `execSfence_vma` (Hart.cpp, master 6b8cce1a, lines 12530 and 12549) uses the
whole rs2 value as the ASID for the HS TLB and, when V=1, for the VS TLB; sinval.vma calls the same code.

V=0 tests (RV64, M-mode with MPRV=1/MPP=S, satp Sv39 ASID 1, non-global leaf): load VA 0x40000000 (page A),
retarget the leaf to page B, run `sfence.vma x0, rs2` and load again, which must read page B:

- sfence_asid_bit7 with asid7.json (satp/vsatp masks implement ASIDLEN=7): rs2 = 1 | 1<<7 ("shall ignore")
- sfence_asid_bit20 with base.json (ASIDLEN=16): rs2 = 1 | 1<<20 (reserved, "should ignore")
- sfence_asid_ctrl: control, rs2 = 1 (passes on master)
- sfence_asid_probe: rs2 = 2 (another ASID). The stale value ("FAIL check 2") is the expected result: it shows
  that the simulator keeps ASID 1 translations across a fence for another ASID, which the tests need in order
  to mean anything.

V=1 tests (sfence_asid_vs.S): the same with hgatp=Bare and vsatp Sv39 ASID 1; the loads and the fence run
in VS-mode (VA 0x40001000; the code is mapped by a global identity gigapage), M-mode retargets the leaf in
between: sfence_asid_vs_bit7 (asid7.json), sfence_asid_vs_bit20, sfence_asid_vs_ctrl, sfence_asid_vs_probe.

tohost = (n << 1) | 1: n = 0 pass, 1 first load wrong, 2 load after the fence wrong (stale), 99 unexpected trap.

Whisper 6b8cce1a (with the fix: everything PASS except the two probes, which stay FAIL check 2):

    sfence_asid_ctrl [base.json]: PASS
    sfence_asid_bit7 [asid7.json]: FAIL check 2
    sfence_asid_bit20 [base.json]: FAIL check 2
    sfence_asid_vs_ctrl [base.json]: PASS
    sfence_asid_vs_bit7 [asid7.json]: FAIL check 2
    sfence_asid_vs_bit20 [base.json]: FAIL check 2
    sfence_asid_probe [base.json]: FAIL check 2
    sfence_asid_vs_probe [base.json]: FAIL check 2

Run: `./run.sh path/to/whisper`. base.json is riscv-arch-test whisper-rv64-max; asid7.json adds satp and vsatp
masks. `./build.sh` rebuilds the ELFs: `*.elf` for Whisper; `*_nosmrnmi.elf` without the mnstatus.NMIE write
(Spike, Sail and Imperas lack Smrnmi); `*_qemu.elf` (also without it) exit through the QEMU virt test
finisher (exit code = n).

Other simulators: Sail 0.16 and Imperas pass bit20 (V=0 and V=1) and cache per ASID (probes stale). The bit7
tests are meaningful only with ASIDLEN=7: Sail with `"asidlen": 7` in sail.json and Imperas with
`--override cpu*/ASID_bits=7` pass them; with their default ASIDLEN=16, ASID 129 is a different ASID and the
stale value is correct. Spike f90d5af and QEMU master 76fdb33 pass everything including the probes (they
flush all ASIDs on any sfence.vma), so their passes are no evidence. QEMU 11.1.3 never reaches the V=1 checks
(mstatus.MPV stays 0 after the csrs, so mret returns to HS-mode and the ecall is cause 9; status 99).
