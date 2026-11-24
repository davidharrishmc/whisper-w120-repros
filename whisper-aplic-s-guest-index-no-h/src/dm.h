// dm.h: bare-metal harness for the u32-debug-a class (b) tests on the Imperas ISS with vectored Debug Mode
// (act/config/imperas/rr-u32-debug-a-imp{64,32}/imperas.ic: debug_mode=vector, debug_address=0x80000800,
// dexc_address=0x80000900, dcsr_ebreak_mask=63 so dcsr.ebreak* reset to 1).
//
// The code at debug_address plays the external debugger: on every Debug Mode entry it saves the GPRs, records a
// snapshot of dcsr, dpc and the trap CSRs in dm_log[dm_cnt] (minstret and mcycle first), calls an optional hook
// (dm_hook) and then applies the next entry of the action queue (DMQ*): dpc := label / advance past the EBREAK /
// keep, and dcsr := (dcsr & ~clr) | set. With an empty queue it advances dpc past an EBREAK (cause 1) and keeps it
// otherwise. Then it restores the GPRs and executes DRET. An exception in Debug Mode jumps to dexc_address: the
// stub there counts it (dexc_cnt), records dcsr and the trap CSRs in dexc_rec and continues at dexc_resume (if set,
// cleared on use) or leaves Debug Mode as above.
// M-mode trap handler: logs each trap (trap_log[trap_cnt]); ecall with a7 = 0x6d returns to M at a6 (BACK_M);
// otherwise it resumes at trap_resume (if set; in M if trap_resume_m) or after the trapping instruction.
// S/VS handlers log the trap and go back to M at s_resume (with BACK_M). Checks (CHK*) run in M-mode and print
// "FAIL: <msg> exp=<hex> got=<hex>" without stopping; TEST_END prints the totals and writes tohost (1 = pass).
// Registers t3-t6 belong to the harness (clobbered by every check); a6/a7 by BACK_M.

#if __riscv_xlen == 64
#define LREG ld
#define SREG sd
#define RB 8
#else
#define LREG lw
#define SREG sw
#define RB 4
#endif

#define DCSR 0x7b0
#define DPC 0x7b1
#define DSCRATCH0 0x7b2
#define DSCRATCH1 0x7b3
#define DRET .word 0x7b200073
#ifndef UART
#define UART 0x10010000      // Imperas customControl console (Whisper: -DUART=0x10000000, its consoleio)
#endif

// dcsr fields
#define D_PRV     0x3
#define D_STEP    (1 << 2)
#define D_NMIP    (1 << 3)
#define D_MPRVEN  (1 << 4)
#define D_V       (1 << 5)
#define D_CAUSE   (7 << 6)
#define D_STOPTIME (1 << 9)
#define D_STOPCOUNT (1 << 10)
#define D_STEPIE  (1 << 11)
#define D_EBU     (1 << 12)
#define D_EBS     (1 << 13)
#define D_EBM     (1 << 15)
#define D_EBVU    (1 << 16)
#define D_EBVS    (1 << 17)
#define D_PELP    (1 << 18)
#define D_CETRIG  (1 << 19)
#define D_EXTCAUSE (7 << 24)
#define D_EBALL   (D_EBM | D_EBS | D_EBU | D_EBVS | D_EBVU)
#define D_MODE    (D_PRV | D_V)
// mode encodings for dcsr (prv | v << 5)
#define DM_M  3
#define DM_S  1
#define DM_U  0
#define DM_VS (1 | D_V)
#define DM_VU (0 | D_V)

// dm_log record fields
#define R_DCSR 0
#define R_DPC 1
#define R_MSTATUS 2
#define R_MSTATUSH 3
#define R_MEPC 4
#define R_MCAUSE 5
#define R_MTVAL 6
#define R_SEPC 7
#define R_SCAUSE 8
#define R_STVAL 9
#define R_VSEPC 10
#define R_VSCAUSE 11
#define R_VSTVAL 12
#define R_VSSTATUS 13
#define R_HSTATUS 14
#define R_HTVAL 15
#define R_HTINST 16
#define R_MTVAL2 17
#define R_MTINST 18
#define R_IR 19
#define R_CY 20
#define R_TIME 21
#define R_MIP 22
#define R_MSECCFG 23
#define NREC 24
#define NLOG 16
// trap_log record fields
#define T_MCAUSE 0
#define T_MEPC 1
#define T_MTVAL 2
#define T_MSTATUS 3
#define T_MSTATUSH 4
#define T_MTVAL2 5
#define T_MTINST 6
#define T_MIP 7
#define NTREC 8
// s_log / vs_log record fields (S or VS handler, seen through the S CSR names)
#define S_SCAUSE 0
#define S_SEPC 1
#define S_STVAL 2
#define S_SSTATUS 3
#define S_HSTATUS 4
#define NSREC 5

#if __riscv_xlen == 64
#define MSTATUS_MDT (1 << 42)
#define MSTATUS_MPV (1 << 39)
#define MSTATUS_GVA (1 << 38)
#define SET_MDT  li t0, 1; slli t0, t0, 42; csrs mstatus, t0
#define CLR_MDT  li t0, 1; slli t0, t0, 42; csrc mstatus, t0
#define SET_MPV  li t0, 1; slli t0, t0, 39; csrs mstatus, t0
#define CLR_MPV  li t0, 1; slli t0, t0, 39; csrc mstatus, t0
#else
#define SET_MDT  li t0, 1 << 10; csrs 0x310, t0
#define CLR_MDT  li t0, 1 << 10; csrc 0x310, t0
#define SET_MPV  li t0, 1 << 7; csrs 0x310, t0
#define CLR_MPV  li t0, 1 << 7; csrc 0x310, t0
#endif
#define MPRV (1 << 17)
#define SDT  (1 << 24)
#define MSECCFG 0x747

// ---------------------------------------------------------------- mode changes (M-mode)
// mret to _LBL in (_PRV, _V): MPP = _PRV, MPV = _V, MIE = MPIE = 0. Clobbers t0.
#define GOTO_MODE(_PRV, _V, _LBL)                            \
    li t0, 0x1888; csrc mstatus, t0                         ;\
    li t0, ((_PRV) << 11); csrs mstatus, t0                 ;\
    CLR_MPV                                                 ;\
    .if _V                                                  ;\
    SET_MPV                                                 ;\
    .endif                                                  ;\
    la t0, _LBL; csrw mepc, t0; mret
// back to M-mode at the next instruction from any mode (ecall into the M handler; medeleg[8..10] = 0)
#define BACK_M  la a6, 1f; li a7, 0x6d; ecall; 1:

// ---------------------------------------------------------------- Debug Mode action queue (M-mode)
#define DMQ(_PC, _SET, _CLR)   la t0, _PC; li t1, _SET; li t2, _CLR; jal t3, dmq_push
#define DMQ_SKIP(_SET, _CLR)   li t0, 1; li t1, _SET; li t2, _CLR; jal t3, dmq_push
#define DMQ_KEEP(_SET, _CLR)   li t0, 2; li t1, _SET; li t2, _CLR; jal t3, dmq_push
// forget queued actions and logs (dm_log, trap_log, s_log, vs_log, dexc)
#define LOG_RESET              jal t3, log_reset
// _R = field _F of Debug Mode entry _N (0 = first since LOG_RESET)
#define DMREC(_R, _N, _F)      la t6, dm_log; LREG _R, ((_N)*NREC + (_F))*RB(t6)
#define TRREC(_R, _N, _F)      la t6, trap_log; LREG _R, ((_N)*NTREC + (_F))*RB(t6)
#define SREC(_R, _N, _F)       la t6, s_log; LREG _R, ((_N)*NSREC + (_F))*RB(t6)
#define VSREC(_R, _N, _F)      la t6, vs_log; LREG _R, ((_N)*NSREC + (_F))*RB(t6)
#define LDV(_R, _V)            la t6, _V; LREG _R, 0(t6)
#define STV(_R, _V)            la t6, _V; SREG _R, 0(t6)
#define STL(_LBL, _V)          la t5, _LBL; la t6, _V; SREG t5, 0(t6)

// ---------------------------------------------------------------- checks (M-mode or Debug Mode)
#define _MSG(_M) .pushsection .rodata; 97: .asciz _M; .popsection; la t4, 97b
#define CHK(_R, _E, _M)        mv t5, _R; li t6, _E; _MSG(_M); jal t3, chk_eq
#define CHKR(_R, _R2, _M)      mv t5, _R; mv t6, _R2; _MSG(_M); jal t3, chk_eq
#define CHKL(_R, _LBL, _M)     mv t5, _R; la t6, _LBL; _MSG(_M); jal t3, chk_eq
#define CHK2(_R, _E1, _E2, _M) li t6, _E2; la t5, chk_alt; SREG t6, 0(t5); mv t5, _R; li t6, _E1; _MSG(_M); jal t3, chk_eq2
#define CHKM(_R, _MASK, _E, _M) li t6, _MASK; and t5, _R, t6; li t6, _E; _MSG(_M); jal t3, chk_eq
#define INFO(_R, _M)           mv t5, _R; _MSG(_M); jal t3, info_p
#define TEST_END               j test_end

// ---------------------------------------------------------------- start-up
// The harness is assembled without compressed instructions so that it keeps working while a test clears misa.C;
// tests use .option rvc locally for 16-bit instructions under test.
  .option norvc
  .option norelax
  .section .text.init, "ax"
  .globl _start
_start:
#ifdef PRE_START
  PRE_START                // test-specific code before the start-up (e.g. a Whisper dcsr.step preset probe)
#endif
  la sp, stack_top
  la t0, mtrap
  csrw mtvec, t0
  li t0, -1
  csrw pmpaddr0, t0
  li t0, 0x1f              // pmp0: NAPOT RWX over all memory (S/U/VS/VU need a PMP match)
  csrw pmpcfg0, t0
  csrw mie, zero
  CLR_MDT                  // Smdbltrp: MDT resets to 1; clear it so traps into M are not double traps
#ifdef HAS_S
  csrw satp, zero
  csrw medeleg, zero
  csrw mideleg, zero
  la t0, strap
  csrw stvec, t0
#endif
#ifdef HYP
  csrw 0x602, zero         // hedeleg
  csrw 0x603, zero         // hideleg
  csrw 0x680, zero         // hgatp = Bare
  csrw 0x280, zero         // vsatp = Bare
  la t0, vstrap
  csrw 0x205, t0           // vstvec
#endif
#ifdef HAS_U
  li t0, -1
  csrw mcounteren, t0
#endif
#ifdef HAS_S
  csrw scounteren, t0
#endif
  j main

// ---------------------------------------------------------------- Debug Mode entry (debug_address)
  .section .dmentry, "ax"
  .globl dm_entry
dm_entry:
  csrw DSCRATCH0, t0
  csrr t0, minstret
  csrw DSCRATCH1, t0
  la t0, dm_regs
  SREG x1, 1*RB(t0)
  SREG x2, 2*RB(t0)
  SREG x3, 3*RB(t0)
  SREG x4, 4*RB(t0)
  SREG x6, 6*RB(t0)
  SREG x7, 7*RB(t0)
  SREG x8, 8*RB(t0)
  SREG x9, 9*RB(t0)
  SREG x10, 10*RB(t0)
  SREG x11, 11*RB(t0)
  SREG x12, 12*RB(t0)
  SREG x13, 13*RB(t0)
  SREG x14, 14*RB(t0)
  SREG x15, 15*RB(t0)
  SREG x16, 16*RB(t0)
  SREG x17, 17*RB(t0)
  SREG x18, 18*RB(t0)
  SREG x19, 19*RB(t0)
  SREG x20, 20*RB(t0)
  SREG x21, 21*RB(t0)
  SREG x22, 22*RB(t0)
  SREG x23, 23*RB(t0)
  SREG x24, 24*RB(t0)
  SREG x25, 25*RB(t0)
  SREG x26, 26*RB(t0)
  SREG x27, 27*RB(t0)
  SREG x28, 28*RB(t0)
  SREG x29, 29*RB(t0)
  SREG x30, 30*RB(t0)
  SREG x31, 31*RB(t0)
  csrr t1, DSCRATCH0
  SREG t1, 5*RB(t0)
  j dm_body

// ---------------------------------------------------------------- Debug Mode exception (dexc_address)
  .section .dmexc, "ax"
dm_exc:
  csrw DSCRATCH0, t0
  li t0, MPRV               // the stub's own stores must not be translated (a test may fault with mprven = MPRV = 1)
  csrc mstatus, t0
  la t0, dexc_rec
  SREG t1, 0(t0)
  csrr t1, DCSR
  SREG t1, 1*RB(t0)
  csrr t1, mcause
  SREG t1, 2*RB(t0)
  csrr t1, mepc
  SREG t1, 3*RB(t0)
  csrr t1, mtval
  SREG t1, 4*RB(t0)
  csrr t1, mstatus
  SREG t1, 5*RB(t0)
#ifdef HAS_S
  csrr t1, scause
  SREG t1, 6*RB(t0)
#endif
  csrr t1, DPC
  SREG t1, 7*RB(t0)
  la t0, dexc_cnt
  LREG t1, 0(t0)
  addi t1, t1, 1
  SREG t1, 0(t0)
  la t0, dexc_rec
  LREG t1, 0(t0)
  la t0, dexc_resume
  LREG t0, 0(t0)
  beqz t0, 1f
  csrw DSCRATCH1, t1
  la t1, dexc_resume
  SREG zero, 0(t1)
  csrr t1, DSCRATCH1
  jr t0                    // continue the Debug Mode code (t0 = the resume address; t1 kept)
1:
  la sp, dm_stack_top
  j dm_exit

  .text
dm_body:
  la sp, dm_stack_top
  // record (dm_log[dm_cnt], dm_cnt < NLOG)
  la t0, dm_cnt
  LREG t1, 0(t0)
  li t2, NLOG - 1
  bleu t1, t2, 1f
  mv t1, t2
1:
  li t2, NREC*RB
  mul t2, t1, t2
  la t0, dm_log
  add t0, t0, t2
  csrr t1, DSCRATCH1
  SREG t1, R_IR*RB(t0)
  csrr t1, mcycle
  SREG t1, R_CY*RB(t0)
  csrr t1, time
  SREG t1, R_TIME*RB(t0)
  csrr t1, DCSR
  SREG t1, R_DCSR*RB(t0)
  csrr t1, DPC
  SREG t1, R_DPC*RB(t0)
  csrr t1, mstatus
  SREG t1, R_MSTATUS*RB(t0)
#if __riscv_xlen == 32
  csrr t1, 0x310
  SREG t1, R_MSTATUSH*RB(t0)
#endif
  csrr t1, mepc
  SREG t1, R_MEPC*RB(t0)
  csrr t1, mcause
  SREG t1, R_MCAUSE*RB(t0)
  csrr t1, mtval
  SREG t1, R_MTVAL*RB(t0)
#ifdef HAS_S
  csrr t1, sepc
  SREG t1, R_SEPC*RB(t0)
  csrr t1, scause
  SREG t1, R_SCAUSE*RB(t0)
  csrr t1, stval
  SREG t1, R_STVAL*RB(t0)
#endif
  csrr t1, mip
  SREG t1, R_MIP*RB(t0)
#ifdef HYP
  csrr t1, 0x241
  SREG t1, R_VSEPC*RB(t0)
  csrr t1, 0x242
  SREG t1, R_VSCAUSE*RB(t0)
  csrr t1, 0x243
  SREG t1, R_VSTVAL*RB(t0)
  csrr t1, 0x200
  SREG t1, R_VSSTATUS*RB(t0)
  csrr t1, 0x600
  SREG t1, R_HSTATUS*RB(t0)
  csrr t1, 0x643
  SREG t1, R_HTVAL*RB(t0)
  csrr t1, 0x64a
  SREG t1, R_HTINST*RB(t0)
  csrr t1, 0x34b
  SREG t1, R_MTVAL2*RB(t0)
  csrr t1, 0x34a
  SREG t1, R_MTINST*RB(t0)
#endif
  la t0, dm_cnt
  LREG t1, 0(t0)
  addi t1, t1, 1
  SREG t1, 0(t0)
  // optional hook
  la t0, dm_hook
  LREG t0, 0(t0)
  beqz t0, 1f
  jalr ra, t0
1:
  // queued action, else default
  la t0, dm_qi
  LREG t1, 0(t0)
  la t2, dm_qn
  LREG t2, 0(t2)
  bgeu t1, t2, dm_default
  addi t2, t1, 1
  SREG t2, 0(t0)
  li t2, 3*RB
  mul t1, t1, t2
  la t0, dm_q
  add t0, t0, t1
  LREG t1, 1*RB(t0)        // set
  LREG t2, 2*RB(t0)        // clr
  csrr t3, DCSR
  not t2, t2
  and t3, t3, t2
  or t3, t3, t1
  csrw DCSR, t3
  LREG t1, 0(t0)           // pc: 1 = skip the EBREAK, 2 = keep, else the new dpc
  li t2, 1
  beq t1, t2, dm_skip
  li t2, 2
  beq t1, t2, dm_exit
  csrw DPC, t1
  j dm_exit
dm_default:
  csrr t1, DCSR
  srli t1, t1, 6
  andi t1, t1, 7
  li t2, 1
  bne t1, t2, dm_exit
dm_skip:
  csrr t1, DPC
  lhu t2, 0(t1)
  andi t2, t2, 3
  li t3, 3
  addi t1, t1, 2
  bne t2, t3, 1f
  addi t1, t1, 2
1:
  csrw DPC, t1
dm_exit:
  csrr t1, minstret
  la t0, dm_exit_ir
  SREG t1, 0(t0)
  la t0, dm_regs
  LREG x1, 1*RB(t0)
  LREG x2, 2*RB(t0)
  LREG x3, 3*RB(t0)
  LREG x4, 4*RB(t0)
  LREG x6, 6*RB(t0)
  LREG x7, 7*RB(t0)
  LREG x8, 8*RB(t0)
  LREG x9, 9*RB(t0)
  LREG x10, 10*RB(t0)
  LREG x11, 11*RB(t0)
  LREG x12, 12*RB(t0)
  LREG x13, 13*RB(t0)
  LREG x14, 14*RB(t0)
  LREG x15, 15*RB(t0)
  LREG x16, 16*RB(t0)
  LREG x17, 17*RB(t0)
  LREG x18, 18*RB(t0)
  LREG x19, 19*RB(t0)
  LREG x20, 20*RB(t0)
  LREG x21, 21*RB(t0)
  LREG x22, 22*RB(t0)
  LREG x23, 23*RB(t0)
  LREG x24, 24*RB(t0)
  LREG x25, 25*RB(t0)
  LREG x26, 26*RB(t0)
  LREG x27, 27*RB(t0)
  LREG x28, 28*RB(t0)
  LREG x29, 29*RB(t0)
  LREG x30, 30*RB(t0)
  LREG x31, 31*RB(t0)
  LREG x5, 5*RB(t0)
  DRET
  j dm_exit                // not reached

// ---------------------------------------------------------------- M-mode trap handler
  .align 6
mtrap:
  csrw mscratch, t0
  la t0, trap_save
  SREG t1, 0(t0)
  SREG t2, 1*RB(t0)
  SREG t3, 2*RB(t0)
  csrr t1, mcause           // ecall with a7 = 0x6d (BACK_M): back to M at a6, not logged
  addi t1, t1, -8
  li t2, 3
  bgtu t1, t2, 1f
  li t1, 0x6d
  bne a7, t1, 1f
  csrw mepc, a6
  li t1, 0x1800
  csrs mstatus, t1
  CLR_MPV
  j mtrap_ret
1:
  la t0, trap_cnt
  LREG t1, 0(t0)
  addi t2, t1, 1
  SREG t2, 0(t0)
  li t2, NLOG - 1
  bleu t1, t2, 1f
  mv t1, t2
1:
  li t2, NTREC*RB
  mul t2, t1, t2
  la t0, trap_log
  add t0, t0, t2
  csrr t1, mcause
  SREG t1, T_MCAUSE*RB(t0)
  csrr t1, mepc
  SREG t1, T_MEPC*RB(t0)
  csrr t1, mtval
  SREG t1, T_MTVAL*RB(t0)
  csrr t1, mstatus
  SREG t1, T_MSTATUS*RB(t0)
  csrr t1, mip
  SREG t1, T_MIP*RB(t0)
#if __riscv_xlen == 32
  csrr t1, 0x310
  SREG t1, T_MSTATUSH*RB(t0)
#endif
#ifdef HYP
  csrr t1, 0x34b
  SREG t1, T_MTVAL2*RB(t0)
  csrr t1, 0x34a
  SREG t1, T_MTINST*RB(t0)
#endif
mtrap_resume:
  csrr t1, mcause
  bgez t1, 4f
  li t1, 0x80               // interrupts are one-shot: return with MIE = 0 (MPIE cleared)
  csrc mstatus, t1
4:
  la t0, trap_resume
  LREG t1, 0(t0)
  beqz t1, 2f
  SREG zero, 0(t0)
  csrw mepc, t1
  la t0, trap_resume_m
  LREG t1, 0(t0)
  beqz t1, mtrap_ret
  SREG zero, 0(t0)
  li t1, 0x1800
  csrs mstatus, t1
  CLR_MPV
  j mtrap_ret
2:
  csrr t1, mcause
  bltz t1, mtrap_ret        // interrupt: return to mepc
  li t2, 1                  // fetch faults and misaligned targets need trap_resume
  beq t1, t2, mtrap_fatal
  li t2, 12
  beq t1, t2, mtrap_fatal
  li t2, 20
  beq t1, t2, mtrap_fatal
  beqz t1, mtrap_fatal
  csrr t1, mepc
  lhu t2, 0(t1)
  andi t2, t2, 3
  li t3, 3
  addi t1, t1, 2
  bne t2, t3, 3f
  addi t1, t1, 2
3:
  csrw mepc, t1
mtrap_ret:
#if __riscv_xlen == 64
  li t1, 1                  // MPELP = 0: the handler never resumes expecting a landing pad
  slli t1, t1, 41
  csrc mstatus, t1
#else
  li t1, 1 << 9
  csrc 0x310, t1
#endif
  la t0, trap_save
  LREG t1, 0(t0)
  LREG t2, 1*RB(t0)
  LREG t3, 2*RB(t0)
  csrr t0, mscratch
  mret
mtrap_fatal:
  la sp, stack_top
  la a0, s_fatal
  call puts
  csrr a0, mcause
  call puthex
  la a0, s_fatal_epc
  call puts
  csrr a0, mepc
  call puthex
  la a0, s_nl
  call puts
  la t0, nfail
  LREG t1, 0(t0)
  addi t1, t1, 1
  SREG t1, 0(t0)
  j test_end

// S and VS handlers: log, then back to M at s_resume
  .align 6
strap:
  la t0, s_cnt
  la t1, s_log
  j sv_common
  .align 6
vstrap:
  la t0, vs_cnt
  la t1, vs_log
sv_common:
  LREG t2, 0(t0)
  addi t3, t2, 1
  SREG t3, 0(t0)
  li t3, NLOG - 1
  bleu t2, t3, 1f
  mv t2, t3
1:
  li t3, NSREC*RB
  mul t2, t2, t3
  add t1, t1, t2
  csrr t2, scause
  SREG t2, S_SCAUSE*RB(t1)
  csrr t2, sepc
  SREG t2, S_SEPC*RB(t1)
  csrr t2, stval
  SREG t2, S_STVAL*RB(t1)
  csrr t2, sstatus
  SREG t2, S_SSTATUS*RB(t1)
  la t0, s_resume
  LREG a6, 0(t0)
  beqz a6, 2f
  li a7, 0x6d
  ecall
2:
  li a7, 0
  ecall                     // no s_resume: the M handler sees an unexpected ecall and resumes after it

// ---------------------------------------------------------------- helpers
// snap (M-mode, call): the trap CSRs into snap_rec (dm_log field numbering); clobbers t0, t1
snap:
  la t0, snap_rec
  csrr t1, mstatus
  SREG t1, R_MSTATUS*RB(t0)
#if __riscv_xlen == 32
  csrr t1, 0x310
  SREG t1, R_MSTATUSH*RB(t0)
#endif
  csrr t1, mepc
  SREG t1, R_MEPC*RB(t0)
  csrr t1, mcause
  SREG t1, R_MCAUSE*RB(t0)
  csrr t1, mtval
  SREG t1, R_MTVAL*RB(t0)
#ifdef HAS_S
  csrr t1, sepc
  SREG t1, R_SEPC*RB(t0)
  csrr t1, scause
  SREG t1, R_SCAUSE*RB(t0)
  csrr t1, stval
  SREG t1, R_STVAL*RB(t0)
#endif
#ifdef HYP
  csrr t1, 0x241
  SREG t1, R_VSEPC*RB(t0)
  csrr t1, 0x242
  SREG t1, R_VSCAUSE*RB(t0)
  csrr t1, 0x243
  SREG t1, R_VSTVAL*RB(t0)
  csrr t1, 0x200
  SREG t1, R_VSSTATUS*RB(t0)
  csrr t1, 0x600
  SREG t1, R_HSTATUS*RB(t0)
  csrr t1, 0x643
  SREG t1, R_HTVAL*RB(t0)
  csrr t1, 0x64a
  SREG t1, R_HTINST*RB(t0)
  csrr t1, 0x34b
  SREG t1, R_MTVAL2*RB(t0)
  csrr t1, 0x34a
  SREG t1, R_MTINST*RB(t0)
#endif
  ret
// sentinels (M-mode, call): distinctive values in the trap CSRs; clobbers t0
sentinels:
  la t0, sent_area
  addi t0, t0, 0x10
  csrw mepc, t0
  li t0, 7
  csrw mcause, t0
  li t0, 0x1234
  csrw mtval, t0
#ifdef HAS_S
  la t0, sent_area
  addi t0, t0, 0x20
  csrw sepc, t0
  li t0, 5
  csrw scause, t0
  li t0, 0x2345
  csrw stval, t0
#endif
#ifdef HYP
  la t0, sent_area
  addi t0, t0, 0x30
  csrw 0x241, t0
  li t0, 13
  csrw 0x242, t0
  li t0, 0x3456
  csrw 0x243, t0
  li t0, 0x45
  csrw 0x643, t0
  li t0, 0x56
  csrw 0x34b, t0
#endif
  ret
// compare the snap_rec field _F with field _F of DM entry _N
#define SAME(_N, _F, _M)  DMREC(s10, _N, _F); la t6, snap_rec; LREG s11, (_F)*RB(t6); CHKR(s10, s11, _M)
dmq_push:                   // t0 pc, t1 set, t2 clr; return via t3
  la t4, dm_qn
  LREG t5, 0(t4)
  addi t6, t5, 1
  SREG t6, 0(t4)
  li t6, 3*RB
  mul t5, t5, t6
  la t4, dm_q
  add t4, t4, t5
  SREG t0, 0(t4)
  SREG t1, 1*RB(t4)
  SREG t2, 2*RB(t4)
  jr t3

log_reset:
  la t4, dm_cnt
  SREG zero, 0(t4)
  la t4, dm_qn
  SREG zero, 0(t4)
  la t4, dm_qi
  SREG zero, 0(t4)
  la t4, trap_cnt
  SREG zero, 0(t4)
  la t4, s_cnt
  SREG zero, 0(t4)
  la t4, vs_cnt
  SREG zero, 0(t4)
  la t4, dexc_cnt
  SREG zero, 0(t4)
  la t4, dm_hook
  SREG zero, 0(t4)
  la t4, trap_resume
  SREG zero, 0(t4)
  la t4, trap_resume_m
  SREG zero, 0(t4)
  la t4, dexc_resume
  SREG zero, 0(t4)
  la t4, s_resume
  SREG zero, 0(t4)
  jr t3

chk_eq2:                    // pass if t5 == t6 or t5 == chk_alt
  beq t5, t6, chk_pass
  la t6, chk_alt
  LREG t6, 0(t6)
chk_eq:                     // t5 got, t6 expected, t4 message; return via t3
  bne t5, t6, chk_fail
chk_pass:
  la t4, nchk
  LREG t6, 0(t4)
  addi t6, t6, 1
  SREG t6, 0(t4)
  jr t3
chk_fail:
  csrw mscratch, t0        // (mscratch is free outside the trap handler)
  la t0, chk_expv
  SREG t6, 0(t0)
  csrr t0, mscratch
  la t6, chk_save
  SREG a0, 0(t6)
  SREG a1, 1*RB(t6)
  SREG ra, 2*RB(t6)
  SREG t0, 3*RB(t6)
  SREG t1, 4*RB(t6)
  SREG t2, 5*RB(t6)
  SREG t3, 6*RB(t6)
  SREG sp, 7*RB(t6)
  la t1, chk_got
  SREG t5, 0(t1)
  la sp, stack_top
  la a0, s_fail
  call puts
  mv a0, t4
  call puts
  la a0, s_exp
  call puts
  la a0, chk_expv
  LREG a0, 0(a0)
  call puthex
  la a0, s_got
  call puts
  la a0, chk_got
  LREG a0, 0(a0)
  call puthex
  la a0, s_nl
  call puts
  la t4, nfail
  LREG t6, 0(t4)
  addi t6, t6, 1
  SREG t6, 0(t4)
  la t4, nchk
  LREG t6, 0(t4)
  addi t6, t6, 1
  SREG t6, 0(t4)
  la t6, chk_save
  LREG a0, 0(t6)
  LREG a1, 1*RB(t6)
  LREG ra, 2*RB(t6)
  LREG t0, 3*RB(t6)
  LREG t1, 4*RB(t6)
  LREG t2, 5*RB(t6)
  LREG t3, 6*RB(t6)
  LREG sp, 7*RB(t6)
  jr t3

info_p:                     // print "INFO: <msg> = <hex>"
  la t6, chk_save
  SREG a0, 0(t6)
  SREG a1, 1*RB(t6)
  SREG ra, 2*RB(t6)
  SREG t0, 3*RB(t6)
  SREG t1, 4*RB(t6)
  SREG t2, 5*RB(t6)
  SREG t3, 6*RB(t6)
  SREG sp, 7*RB(t6)
  la t1, chk_got
  SREG t5, 0(t1)
  la sp, stack_top
  la a0, s_info
  call puts
  mv a0, t4
  call puts
  la a0, s_eq
  call puts
  la a0, chk_got
  LREG a0, 0(a0)
  call puthex
  la a0, s_nl
  call puts
  la t6, chk_save
  LREG a0, 0(t6)
  LREG a1, 1*RB(t6)
  LREG ra, 2*RB(t6)
  LREG t0, 3*RB(t6)
  LREG t1, 4*RB(t6)
  LREG t2, 5*RB(t6)
  LREG t3, 6*RB(t6)
  LREG sp, 7*RB(t6)
  jr t3

puts:                       // a0 string; clobbers t0, t1, a0
  li t1, UART
1:
  lbu t0, 0(a0)
  beqz t0, 2f
  sb t0, 0(t1)
  addi a0, a0, 1
  j 1b
2:
  ret
puthex:                     // a0 value; clobbers t0-t2, a0, a1
  li t1, UART
  li t2, RB*2
1:
  addi t2, t2, -1
  slli a1, t2, 2
  srl t0, a0, a1
  andi t0, t0, 15
  addi t0, t0, '0'
  li a1, '9'
  ble t0, a1, 2f
  addi t0, t0, 'a' - '9' - 1
2:
  sb t0, 0(t1)
  bnez t2, 1b
  ret
putdec:                     // a0 value; clobbers t0-t2, a0
  addi sp, sp, -32
  mv t2, sp
  li t1, 10
1:
  remu t0, a0, t1
  addi t0, t0, '0'
  sb t0, 0(t2)
  addi t2, t2, 1
  divu a0, a0, t1
  bnez a0, 1b
  li t1, UART
2:
  addi t2, t2, -1
  lbu t0, 0(t2)
  sb t0, 0(t1)
  bne t2, sp, 2b
  addi sp, sp, 32
  ret

test_end:
  la sp, stack_top
  la a0, s_name
  call puts
  la a0, s_checks
  call puts
  la a0, nchk
  LREG a0, 0(a0)
  call putdec
  la a0, s_fails
  call puts
  la a0, nfail
  LREG a0, 0(a0)
  call putdec
  la a0, nfail
  LREG a0, 0(a0)
  li s0, 1
  la a0, s_pass
  la t0, nfail
  LREG t0, 0(t0)
  beqz t0, 1f
  li s0, 3
  la a0, s_failw
1:
  call puts
  la t1, tohost
  .globl _test_exit
_test_exit:
  SREG s0, 0(t1)
  j _test_exit

  .section .rodata
s_fail:  .asciz "FAIL: "
s_info:  .asciz "INFO: "
s_exp:   .asciz " exp=0x"
s_got:   .asciz " got=0x"
s_eq:    .asciz " = 0x"
s_nl:    .asciz "\n"
s_fatal: .asciz "FAIL: unexpected trap (no trap_resume) mcause=0x"
s_fatal_epc: .asciz " mepc=0x"
s_checks: .asciz ": checks="
s_fails: .asciz " failures="
s_pass:  .asciz " RESULT=PASS\n"
s_failw: .asciz " RESULT=FAIL\n"

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost: .dword 0
  .globl fromhost
fromhost: .dword 0

  .data
  .align 4
nchk: .dword 0
nfail: .dword 0
chk_alt: .dword 0
chk_got: .dword 0
chk_expv: .dword 0
chk_save: .zero 10*8
dm_cnt: .dword 0
snap_rec: .zero NREC*8
  .align 6
sent_area: .zero 64
dm_qn: .dword 0
dm_qi: .dword 0
dm_hook: .dword 0
dm_exit_ir: .dword 0
dm_q: .zero 3*8*NLOG
dm_log: .zero NREC*8*NLOG
dm_regs: .zero 32*8
dexc_cnt: .dword 0
dexc_resume: .dword 0
dexc_rec: .zero 8*8
trap_cnt: .dword 0
trap_resume: .dword 0
trap_resume_m: .dword 0
trap_save: .zero 4*8
trap_log: .zero NTREC*8*NLOG
s_cnt: .dword 0
vs_cnt: .dword 0
s_resume: .dword 0
s_log: .zero NSREC*8*NLOG
vs_log: .zero NSREC*8*NLOG
  .align 4
stack: .zero 1024
stack_top:
dm_stack: .zero 1024
dm_stack_top:
  .text
