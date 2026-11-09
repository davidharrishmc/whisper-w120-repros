// Whisper: a misaligned load or store that crosses from a PBMT=PMA page into a PBMT=IO page is checked
// with the second page's PBMT for both parts, so the access fault is charged to the first part (xtval =
// the first part's address, which is in ordinary main memory).
// Spec: priv/machine.adoc [norm:mtval_vaddr_wr_misaligned_addr] "If mtval is written with a nonzero value
//   when a misaligned load or store causes an access-fault, page-fault, or hardware-error exception, then
//   mtval will contain the virtual address of the portion of the access that caused the fault."
//   priv/svpbmt.adoc: the PBMT bits override the PMAs "for the associated memory pages" (each page its own).
// Scenario: Sv39, menvcfg.PBMTE=1, S-mode accesses via MPRV=1/MPP=S. VA 0x40051000 -> page A (PBMT=0),
//   VA 0x40052000 -> page B (PBMT=IO). ld and sd at 0x40051ffc.
// Expected: each access completes, or raises an address-misaligned exception, or raises an access fault
//   with mtval = 0x40052000 (the part in page B) or 0. Whisper master: access fault with mtval 0x40051ffc.

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'Svpbmt']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

RVTEST_BEGIN
  // identity-map the image: root[2], root[3] = 1 GiB leaves, D A X W R V
  LA(x8, sa_root)
  li x7, (0x80000000 >> 12) << 10 | 0xcf
  sd x7, 16(x8)
  li x7, (0xC0000000 >> 12) << 10 | 0xcf
  sd x7, 24(x8)
  // root[1] -> t2, t2[0] -> t3
  LA(x6, sa_t2)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  sd x6, 8(x8)
  LA(x8, sa_t2)
  LA(x6, sa_t3)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 1
  sd x6, 0(x8)
  // t3[0x51] -> page A (PBMT=0), t3[0x52] -> page B (PBMT=IO: bit 62), D A W R V
  LA(x8, sa_t3)
  LA(x6, sa_pgA)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 0xc7
  sd x6, 0x51*8(x8)
  LA(x6, sa_pgB)
  srli x6, x6, 12
  slli x6, x6, 10
  ori x6, x6, 0xc7
  li x7, 1
  slli x7, x7, 62
  or x6, x6, x7
  sd x6, 0x52*8(x8)
  // data: A[0xff8] = 0x0807060504030201, B[0] = 0x100f0e0d0c0b0a09
  LA(x8, sa_pgA)
  li x7, 0xff8
  add x8, x8, x7
  li x7, 0x0807060504030201
  sd x7, 0(x8)
  LA(x8, sa_pgB)
  li x7, 0x100f0e0d0c0b0a09
  sd x7, 0(x8)
  // satp = Sv39; menvcfg.PBMTE = 1
  LA(x6, sa_root)
  srli x6, x6, 12
  li x7, 0x8000000000000000
  or x6, x6, x7
  csrw satp, x6
  li x7, 1
  slli x7, x7, 62
  csrs menvcfg, x7
  sfence.vma x0, x0
  li x11, 0x20800          // MPRV | MPP=S
  li x7, 0x1800
  csrc mstatus, x7
  // Each access may complete, raise an address-misaligned exception, or raise an access fault whose
  // mtval is 0 or the address of the part in page B (0x40052000). (mtval 0 is mapped to 0x40052000 below.)
  li x6, 0x40051ffc
  li x9, 0
  SA_TRY(1)
  csrs mstatus, x11
  ld x9, 0(x6)
  csrc mstatus, x11
  AI_OUTCOME
  csrc mstatus, x11
  beqz x13, ld_notrap
  li x7, 4
  beq x14, x7, ld_done
  SA_SOFT(x14, 5, "ld at 0x40051ffc (PMA page -> IO page): cause")
  AI_LOG(x7, TRAPLOG_TVAL)
  bnez x7, 1f
  li x7, 0x40052000
1:
  SA_SOFT(x7, 0x40052000, "ld at 0x40051ffc (PMA page -> IO page): access-fault mtval must be the page-B part")
  j ld_done
ld_notrap:
  SA_SOFT(x9, 0x0c0b0a0908070605, "ld at 0x40051ffc (PMA page -> IO page): data")
ld_done:
  LI(x9, 0x1122334455667788)
  SA_TRY(1)
  csrs mstatus, x11
  sd x9, 0(x6)
  csrc mstatus, x11
  AI_OUTCOME
  csrc mstatus, x11
  beqz x13, sd_done
  li x7, 6
  beq x14, x7, sd_done
  SA_SOFT(x14, 7, "sd at 0x40051ffc (PMA page -> IO page): cause")
  AI_LOG(x7, TRAPLOG_TVAL)
  bnez x7, 1f
  li x7, 0x40052000
1:
  SA_SOFT(x7, 0x40052000, "sd at 0x40051ffc (PMA page -> IO page): access-fault mtval must be the page-B part")
sd_done:
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 12
sa_root: .fill 4096, 1, 0
sa_t2:   .fill 4096, 1, 0
sa_t3:   .fill 4096, 1, 0
sa_pgA:  .fill 4096, 1, 0
sa_pgB:  .fill 4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
