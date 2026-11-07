#define HFENCE_GVMA(rs1, rs2) .word (0x62000073 | ((rs2) << 20) | ((rs1) << 15))
#define HLV_W(rd, rs1)        .word (0x68004073 | ((rs1) << 15) | ((rd) << 7))
#define FAIL(n) li t6, ((n) << 1) | 1; j write_tohost
#define PASS    li t6, 1; j write_tohost
// make PTE pointing at label (pa>>12)<<10 | perms into reg
#define MKPTE(reg, lbl, perms) la reg, lbl; srli reg, reg, 12; slli reg, reg, 10; ori reg, reg, perms
