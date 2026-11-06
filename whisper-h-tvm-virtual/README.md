# whisper-h-tvm-virtual

With `mstatus.TVM=1`, a VS-mode write of `hgatp` and a VU-mode write of `satp` raise an illegal-instruction
exception (cause 2) instead of a virtual-instruction exception (cause 22). Reads of the same CSRs correctly
raise cause 22. hypervisor.adoc (norm:H_virtinst_vu_vs_nonhigh_allowedhs_tvm0,
norm:H_virtinst_vu_nonhigh_supervisor_allowedhs_tvm0) raises a virtual-instruction exception when the same
access "would be allowed in HS-mode, assuming `mstatus`.TVM=0", and norm:mstatus_modes says TVM affects
execution only in HS-mode.

`checkCsrAccess` (`Hart.cpp`, master 6b8cce1a, lines 13190-13193) decides whether a write is HS-qualified with
`isCsrWriteable(csr, PM::Supervisor, false)`, which applies the HS-mode TVM check to `satp` and `hgatp`.

`whisper_tvm_virtual.S` is a riscv-arch-test rule-derived test (riscv/riscv-arch-test#3162), self-checking,
for the whisper-rv64-max configuration (`whisper.json`). It passes on Sail. On Whisper 6b8cce1a:

    RVCP: Test Info: whisper_tvm_virtual: write (csrrw rd=x0) of hgatp (TVM=1) in VS-mode: outcome (xcause, or all ones for no trap); expect 0x0000000000000016
    RVCP: Bad Value:      0x0000000000000002

## Run

    ./run.sh [path/to/whisper]
