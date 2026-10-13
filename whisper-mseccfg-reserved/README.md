# whisper-mseccfg-reserved

machine.adoc (`norm:mseccfg_presence`): mseccfg "exists if any extension that adds a field to `mseccfg`
is implemented. Otherwise, it is reserved." The extensions that add fields are Smepmp (MML, MMWP, RLB),
Zkr (USEED, SSEED), Zicfilp (MLPE) and Smmpm (PMM). Whisper always implements mseccfg (and mseccfgh on
RV32) and only changes their read masks, so on a hart with none of those extensions `csrr mseccfg`
returns 0.

The harts here have M, S and U and claim Ssstrict (ssstrict.adoc,
`norm:Ssstrict_unimplemented_opcodes_csr_exception`: "attempts to execute unimplemented opcodes or
access unimplemented CSRs in the standard or reserved encoding spaces raises an illegal instruction
exception"). They are the riscv-arch-test derived RVI20U32-s / RVI20U64-s configurations (I, Zicsr, Sm,
S, U, Svbare) plus Ssstrict and Zifencei: whisper `isa: rv32ius_zicsr_zifencei` /
`rv64ius_zicsr_zifencei`, spike `--isa=rv32i_zicsr_zifencei` / `--isa=rv64i_zicsr_zifencei`, and the
matching Sail configuration. `W120S2Strict_mseccfg-00.S` runs in M-mode and reads, writes and sets
mseccfg (and on RV32 reads and writes mseccfgh); Spike and Sail raise an illegal-instruction exception
for each access. (Ssstrict's sentence goes on "that results in a contained trap to the supervisor-mode
trap handler", so it is written for accesses from S/U-mode, where mseccfg traps anyway for privilege;
riscv-arch-test's SsstrictSm suite applies the same rule to M-mode accesses of every other M-level CSR
address but skips 0x747.)

    ./run.sh [whisper] [spike] [sail_riscv_sim]

Expected (Whisper master f069895c):

    whisper (rv32): FAIL   (csrr mseccfg returns 0: "test: 1 ... bin: csrr mseccfg")
    spike (rv32):   PASS
    sail (rv32):    PASS
    whisper (rv64): FAIL
    spike (rv64):   PASS
    sail (rv64):    PASS

With the fix both whisper cases PASS.
