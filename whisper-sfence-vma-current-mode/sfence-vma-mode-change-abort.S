// Whisper: SFENCE.VMA with rs1 != x0, executed after satp.MODE changed from Sv48 to Sv39 while the TLB holds a
// 512 GiB Sv48 translation, stops Whisper on an assertion.
// Spec: priv/supervisor.adoc [norm:satp_op_sfence_vma]: writing satp does not invalidate address-translation
//   caches, and "it may be necessary to execute an SFENCE.VMA instruction after, or in some cases before,
//   writing satp". SFENCE.VMA with rs1 != x0 is a legal instruction under any satp.MODE.
// Scenario: Sv48, root[0] = 512 GiB leaf identity-mapping 0-512 GiB; an S-mode load (MPRV=1, MPP=S) caches it.
//   satp is then set to Sv39 and SFENCE.VMA va, x0 runs in M-mode.
// Expected: the fence completes and the test continues. Whisper master: "Tlb.hpp:420: ... sizeIn4kBytes ...
//   Assertion `0 && "Error: Assertion failed"' failed."

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'Sv48']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  // Sv48 root[0] = 512 GiB leaf at PA 0, D A X W R V
  LA(x8, sa_root48)
  li x7, 0xcf
  sd x7, 0(x8)
  LA(x8, sa_pg)
  li x7, 0x1111
  sw x7, 0(x8)
  // satp = Sv48 (MODE 9), ASID 0
  LA(x10, sa_root48)
  srli x10, x10, 12
  li x7, 0x9000000000000000
  or x10, x10, x7
  csrw satp, x10
  sfence.vma x0, x0
  LA(x6, sa_pg)
  li x11, 0x20800          // MPRV | MPP=S
  li x7, 0x1800
  csrc mstatus, x7
  csrs mstatus, x11
  lw x9, 0(x6)             // caches a 512 GiB translation
  csrc mstatus, x11
  SA_CHECK(x9, 0x1111, "load through the Sv48 512 GiB page")
  // satp = Sv39 (empty root table), then fence the VA
  LA(x10, sa_root39)
  srli x10, x10, 12
  li x7, 0x8000000000000000
  or x10, x10, x7
  csrw satp, x10
  sfence.vma x6, x0
  li x9, 7
  SA_CHECK(x9, 7, "reached the instruction after SFENCE.VMA va")
  csrw satp, x0
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 12
sa_root48: .fill 4096, 1, 0
sa_root39: .fill 4096, 1, 0
sa_pg:     .fill 4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
