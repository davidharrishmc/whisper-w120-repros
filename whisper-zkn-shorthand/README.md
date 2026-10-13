# Whisper ignores the zk/zkn/zks shorthands in the isa string

b1441834 and 542ae0f4 added `zk`, `zkn`, `zks` and `zkt` to the isa parser and expand them in
`Hart::processExtensions` (Hart.cpp:664-674 at f069895c). The expansion runs before the per-extension
lines `enableExtension(RvExtension::Zbkb, isa_.isEnabled(RvExtension::Zbkb))` etc. (Hart.cpp:676-690),
which clear every subextension that is not itself in the isa string. So `isa: rv64i_zicsr_zkn` gives a
hart with none of Zbkb, Zbkc, Zbkx, Zkne, Zknd, Zknh. (Also: the `zks` list contains Zkne, which is
not part of Zks, and `zk` adds Zks, which is not part of Zk, and does not reach Zkn's subextensions or
`enableZkr`.) zk.adoc: Zkn = Zbkb + Zbkc + Zbkx + Zkne + Zknd + Zknh;
Zks = Zbkb + Zbkc + Zbkx + Zksed + Zksh; Zk = Zkn + Zkr + Zkt.

The hart is the riscv-arch-test derived configuration RVI20U64 + Zkn with the isa string written with
the shorthand: whisper `isa: rv64i_zicsr_zkn`, spike `--isa=rv64i_zicsr_zkn`. The test is
riscv-arch-test `Zbkb-pack-00`.

    ./run.sh [whisper] [spike] [sail_riscv_sim]

Expected (Whisper master f069895c):

    whisper: FAIL   (the first pack raises an illegal-instruction exception)
    spike:   PASS
    sail:    PASS

With the fix, whisper: PASS. All 35 RV64 Zbkb/Zbkc/Zbkx/Zknd/Zkne/Zknh tests fail on master with this
isa string; with the fix 34 pass (rorw still fails: it checks only Zbb, item 9 of #120).
