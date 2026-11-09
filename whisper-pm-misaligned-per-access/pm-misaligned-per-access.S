// Whisper: pointer masking is applied once to the start address of a misaligned access, not to each of its
// parts, so the part of an access that crosses bit XLEN-PMLEN-1 uses an untransformed address.
// Spec: priv/zpm.adoc [norm:pm_misaligned_equivalence] "Misaligned accesses are supported, subject to the same
//   limitations as in the absence of pointer masking. The behavior is identical to applying the pointer
//   masking transformation to every constituent aligned memory access. In other words, the accessed bytes
//   should be identical to the bytes that would be accessed if the pointer masking transformation was
//   individually applied to every byte of the access without pointer masking."
//   [norm:pm_csr_hw_apply]: pointer masking is applied to the address the hardware writes to stval/mtval.
// Scenario: Sv48, S-mode accesses via MPRV=1/MPP=S, menvcfg.PMM=11 (PMLEN=16: the transformation
//   sign-extends bit 47). Page A at VA 0x00007ffffffff000 (last page of the lower half), page B at VA
//   0xffff800000000000 (first page of the upper half). ld and sd at 0x00007ffffffffffc: bytes ...ffc-...fff
//   are in page A; bytes 0x0000800000000000-...003 transform (bit 47 = 1) to 0xffff800000000000-...003, in
//   page B. Aligned accesses to both pages (control) work on every simulator.
// Expected: each access completes on A[0xffc..0xfff] and B[0..3] (it may instead raise an address-misaligned
//   exception or an access fault, never a page fault: every transformed byte address is mapped). Whisper
//   master: load and store page faults with mtval 0x0000800000000000 (the untransformed, non-canonical
//   address of the second part).

##### START_TEST_CONFIG #####
# REQUIRED_EXTENSIONS: ['I', 'Sm', 'S', 'Sv48', 'Smnpm']
# MARCH: rv${XLEN}i_zicsr_zifencei
# NEEDS_SIGNATURE: false
##### END_TEST_CONFIG #####

#define SIGUPD_COUNT 0
#define BOOT_TO_MMODE
#include "riscv_arch_test.h"
#include "../common/sa.h"

#define PTR(_tbl, _tgt, _idx)   \
  LA(x8, _tbl)                 ;\
  LA(x6, _tgt)                 ;\
  srli x6, x6, 12              ;\
  slli x6, x6, 10              ;\
  ori x6, x6, 1                ;\
  li x7, (_idx)*8              ;\
  add x8, x8, x7               ;\
  sd x6, 0(x8)
#define LEAF(_tbl, _tgt, _idx)  \
  LA(x8, _tbl)                 ;\
  LA(x6, _tgt)                 ;\
  srli x6, x6, 12              ;\
  slli x6, x6, 10              ;\
  ori x6, x6, 0xc7             ;\
  li x7, (_idx)*8              ;\
  add x8, x8, x7               ;\
  sd x6, 0(x8)

RVTEST_BEGIN
  // identity map 2..4 GiB: root[0] -> l2id, l2id[2], l2id[3] = 1 GiB leaves
  PTR(sa_root, sa_l2id, 0)
  LA(x8, sa_l2id)
  li x7, (0x80000000 >> 12) << 10 | 0xcf
  sd x7, 16(x8)
  li x7, (0xC0000000 >> 12) << 10 | 0xcf
  sd x7, 24(x8)
  // VA 0x00007ffffffff000: vpn3=0xff vpn2=vpn1=vpn0=0x1ff -> page A
  PTR(sa_root, sa_l2a, 0xff)
  PTR(sa_l2a, sa_l1a, 0x1ff)
  PTR(sa_l1a, sa_l0a, 0x1ff)
  LEAF(sa_l0a, sa_pgA, 0x1ff)
  // VA 0xffff800000000000: vpn3=0x100 vpn2=vpn1=vpn0=0 -> page B
  PTR(sa_root, sa_l2b, 0x100)
  PTR(sa_l2b, sa_l1b, 0)
  PTR(sa_l1b, sa_l0b, 0)
  LEAF(sa_l0b, sa_pgB, 0)
  // data: A[0xff8] = 0x0807060504030201, B[0] = 0x100f0e0d0c0b0a09
  LA(x8, sa_pgA)
  li x7, 0xff8
  add x8, x8, x7
  li x7, 0x0807060504030201
  sd x7, 0(x8)
  LA(x8, sa_pgB)
  li x7, 0x100f0e0d0c0b0a09
  sd x7, 0(x8)
  // satp = Sv48
  LA(x10, sa_root)
  srli x10, x10, 12
  li x7, 0x9000000000000000
  or x10, x10, x7
  csrw satp, x10
  sfence.vma x0, x0
  // menvcfg.PMM = 11 (PMLEN 16)
  li x7, 3
  slli x7, x7, 32
  csrs menvcfg, x7
  csrr x9, menvcfg
  srli x9, x9, 32
  andi x9, x9, 3
  SA_CHECK(x9, 3, "menvcfg.PMM holds 11")
  li x11, 0x20800          // MPRV | MPP=S
  li x7, 0x1800
  csrc mstatus, x7
  // control: aligned loads in both pages
  li x6, 0xffff800000000000
  li x12, 0x00007ffffffffff8
  csrs mstatus, x11
  ld x9, 0(x6)
  ld x15, 0(x12)
  csrc mstatus, x11
  SA_CHECK(x9, 0x100f0e0d0c0b0a09, "control: ld from page B")
  SA_CHECK(x15, 0x0807060504030201, "control: ld from page A")
  // misaligned ld crossing bit 47 of the untransformed address
  li x6, 0x00007ffffffffffc
  li x9, 0
  SA_TRY(1)
  csrs mstatus, x11
  ld x9, 0(x6)
  csrc mstatus, x11
  AI_OUTCOME
  csrc mstatus, x11
  mv x16, x14
  beqz x13, 1f
  li x7, 4                                 // address-misaligned and access fault are allowed
  beq x14, x7, 2f
  li x7, 5
  beq x14, x7, 2f
  AI_LOG(x17, TRAPLOG_TVAL)
  SA_SOFT(x16, -1, "ld at 0x00007ffffffffffc: cause (-1 = no trap)")
  SA_SOFT(x17, 0, "ld at 0x00007ffffffffffc: mtval")
  j 2f
1:
  SA_SOFT(x9, 0x0c0b0a0908070605, "ld at 0x00007ffffffffffc: bytes A[0xffc..0xfff], B[0..3]")
2:
  // misaligned sd crossing bit 47 of the untransformed address
  LI(x9, 0x8877665544332211)
  SA_TRY(1)
  csrs mstatus, x11
  sd x9, 0(x6)
  csrc mstatus, x11
  AI_OUTCOME
  csrc mstatus, x11
  mv x16, x14
  beqz x13, 1f
  li x7, 6                                 // address-misaligned and access fault are allowed
  beq x14, x7, 2f
  li x7, 7
  beq x14, x7, 2f
  AI_LOG(x17, TRAPLOG_TVAL)
  SA_SOFT(x16, -1, "sd at 0x00007ffffffffffc: cause (-1 = no trap)")
  SA_SOFT(x17, 0, "sd at 0x00007ffffffffffc: mtval")
  j 2f
1:
  LA(x8, sa_pgA)
  li x7, 0xff8
  add x8, x8, x7
  ld x15, 0(x8)
  LA(x8, sa_pgB)
  ld x16, 0(x8)
  SA_SOFT(x15, 0x4433221104030201, "sd at 0x00007ffffffffffc: page A bytes 0xff8-0xfff")
  SA_SOFT(x16, 0x100f0e0d88776655, "sd at 0x00007ffffffffffc: page B bytes 0-7")
2:
  SA_SOFT_END
RVTEST_CODE_END

RVTEST_DATA_BEGIN
  .p2align 12
sa_root: .fill 4096, 1, 0
sa_l2id: .fill 4096, 1, 0
sa_l2a:  .fill 4096, 1, 0
sa_l1a:  .fill 4096, 1, 0
sa_l0a:  .fill 4096, 1, 0
sa_l2b:  .fill 4096, 1, 0
sa_l1b:  .fill 4096, 1, 0
sa_l0b:  .fill 4096, 1, 0
sa_pgA:  .fill 4096, 1, 0
sa_pgB:  .fill 4096, 1, 0
RVTEST_DATA_END
RVTEST_SIG_SETUP
