# whisper-stimecmp-without-s

Sstc "adds the S-level `stimecmp` CSR" (sstc.adoc, `norm:stimecmp_exist`) and the supervisor timer
interrupt it drives; riscv-unified-db lists S as a requirement of Sstc (`spec/std/isa/ext/Sstc.yaml`,
`requirements: extension: S`), Spike rejects an isa string with Sstc but no S ("ISA extensions require S
mode"), and Sail makes stimecmp accessible only with S. Whisper accepts such an isa string and implements
stimecmp (and stimecmph on RV32) on a hart without S-mode: `CsRegs::updateSstc` sets them implemented
from Sstc alone.

`whisper.json` is the riscv-arch-test derived RVI20U32 (I, Zicsr, Sm) configuration with the isa string
changed to `rv32i_zicsr_sstc` (and without the mcounteren/menvcfg `exists: false` workaround, which on
master keeps stimecmp unimplemented as a side effect because `updateSstc` returns early when mcounteren
does not exist). The configuration is inconsistent, so this is a configuration-consistency problem
rather than an architectural difference on a legal hart: Spike and Sail run the plain RVI20U32 hart
(`--isa=rv32i_zicsr`), which is the hart Whisper models apart from the extra extension name.
`W120Csrexist_nos-00.S` reads stimecmp and stimecmph; Spike and Sail raise an illegal-instruction
exception for each access, Whisper returns 0.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

Expected (Whisper master f069895c):

    whisper: FAIL   (csrr stimecmp returns 0: "test: 1 ... bin: stimecmp")
    spike:   PASS
    sail:    PASS

With the fix Whisper prints "Warning: Extension Sstc requires S-mode which is not enabled", leaves Sstc
off, and whisper: PASS.

srmcfg (Ssqosid) is not affected: ssqosid.adoc says "The Ssqosid extension does not require that
S-mode mode be implemented", and Sail agrees.
