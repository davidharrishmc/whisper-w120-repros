# Whisper: RV32 Zilsd ld with rd = rs1 overwrites the base register when the second word faults

zilsd.adoc norm:Zilsd_ld_resume_trap: "To ensure resumable trap handling is possible for the load
instructions, the base register must have its original value if a trap is taken." `Hart<uint32_t>::execLd`
(Hart.cpp, master 6b8cce1a, lines 14704-14705) writes rd after the first 32-bit access and before the second.
When rd = rs1 and the second access traps, the trap is taken with the base register already overwritten.
Zclsd c.ld and c.ldsp run the same function.

zilsd_ld_base.S (RV32, M-mode, bare): PMP gives [0, P+0x1000) RWX, [P+0x1000, P+0x2000) locked with no access,
and the rest RWX, so the word at P+0xffc loads and the word at P+0x1000 faults. x31 = 0 pass, else the
failing check:

1. control: `ld x12, 0(x10)`, x10 = P+0xffc: x10 unchanged
2. ... load access fault (mcause 5)
3. `ld x10, 0(x10)`, x10 = P+0xffc: x10 (rd = rs1) unchanged
4. ... load access fault (mcause 5)
5. `ld x10, 0(x10)` with both words accessible: x10/x11 = 0x55667788/0x11223344 (sanity)
6. (zilsd_ld_base_zclsd.elf only, before check 3) the same as 3 for Zclsd `c.ld x10, 0(x10)`
7. ... mcause 5

Whisper 6b8cce1a (x10 holds the first word, 0xdeadbeef, after the trap):

    zilsd_ld_base [whisper.json]: FAIL check 3
    zilsd_ld_base_zclsd [whisper-zclsd.json]: FAIL check 6

Expected (and with the fix): both PASS.

Run: `./run.sh path/to/whisper`. whisper.json is riscv-arch-test whisper-rv32-max with `zilsd` added to the ISA
string; whisper-zclsd.json uses ISA rv32imacsu_zicsr_zifencei_zicntr_smaia_ssaia_smrnmi_smdbltrp_zilsd_zclsd
(Zclsd needs C without F). `./build.sh` rebuilds the ELFs; `*_nosmrnmi.elf` omit the mnstatus.NMIE write
(Spike and Imperas lack Smrnmi), and `*_qemu.elf` (also without it) exit through the QEMU virt test finisher
(exit code = check number).

Other simulators, all with Zilsd enabled: Spike f90d5af (`--isa=<spike-rv32-max>_zilsd`, and
`rv32imac_zicsr_zicclsm_zilsd_zclsd` for c.ld), QEMU 11.1.3 and master 76fdb33 (`-cpu max,zilsd=true,zclsd=false`,
and `-cpu rv32,f=false,d=false,zfa=false,zilsd=true,zclsd=true` for c.ld) and Imperas (RV32GCV with
`Zilsd=T`, RV32IMAC with `Zilsd=T Zclsd=T` for c.ld) pass. Sail 0.16 does not implement Zilsd (ld is an
illegal instruction), so the check cannot run there.
