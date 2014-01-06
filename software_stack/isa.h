#ifndef __SOFT_STACK_ISA
#define __SOFT_STACK_ISA

/**
 * Represents the binary codes used in the ARM Thumb ISA.
 *
 * Bits 12-15 represent the number of bits in the instruction part,
 * and bits 11-0 represent the instruction part.
 *
 * The identifiers all contain a clue as to the instruction's arguments.
 *
 * Example:
 *
 * Given the instruction
 * 0x0000A10D
 *
 * First look at bits 12-15,
 * 0x0000[A]10D
 * This means here are 10 bits in the instruction binary.
 * XXXXXXXXXX
 *
 * When there is not a multiple of 4 bits, the lowest ones comprise a word,
 * so that would be more like
 * XX XXXX XXXX
 *
 * Now examining bits 11-0,
 * 0x0000A[10D]
 * We populate using these bits
 * XX XXXX XXXX
 * 1  0    D
 * 01 0000 1101
 *
 * We see below that this is the code for MUL_RGM_RGD, which means that
 *  this functions takes two arguments: a source register (RGN, RGM, and RGS
 *  are all 3 bit source registers), and a 3-bit destination register (RGD).
 *  If you see IMX (for example IM3), this is an immediate code, and the number
 *  X represents the width in bits. HFX means there are X h-flags. CXY means
 *  there is a constant X bits wide filled with Y, for example, C30 means
 *  3 0s.
 *
 * So for source register 2 and destination register 3, we can finish the
 * instruction,
 * 1  0    D
 * 01 0000 1101
 * 1  0    D    2   3
 * 01 0000 1101 010 011
 *
 * and translated back into hexadecimal, that would look like
 * 0100001101010011
 * 0100 0011 0101 0011
 * 4    3    5    3
 * 0x00004353
 *
 * The lower 16 bits, 0x4353, is the ARM Thumb code for multiplying the
 *  contents of register 3 by the contents of register 2, and storing the
 *  result in register 3, or the assembler instruction
 *
 * MUL r3, r2
 */
typedef enum _ThumbISA
{

  /* Rd = Rm shift # */
  LSL_IM5_RGM_RGD    = 0x00005000, LSR_IM5_RGM_RGD    = 0x00005001,
  ASR_IM5_RGM_RGD    = 0x00005002,

  /* Rd = Rm +/- Rn */
  ADD_RGM_RGN_RGD    = 0x0000700C, SUB_RGM_RGN_RGD    = 0x0000700D,

  /* Rd = Rn +/- #, replace Rn with 0 for move instructions */
  ADD_IM3_RGN_RGD    = 0x0000700E, SUB_IM3_RGN_RGD    = 0x0000700F,
  MOV_RGD_IM8        = 0x00005004,

  /* Rm <op> #, in test functions CMP subtracts, CMN adds, TST ands */
  CMP_RGN_IM8        = 0x00005005,

  /* Rd = Rd +/- # */
  ADD_RGD_IM8        = 0x00005006, SUB_RGM_IM8        = 0x00005007,

  /* Rd = Rd <op> Rm, ADC and SBC include the carry bit */
  AND_RGM_RGD        = 0x0000A100, EOR_RGM_RGD        = 0x0000A101,
  ADC_RGM_RGD        = 0x0000A105, SBC_RGM_RGD        = 0x0000A106,
  NEG_RGM_RGD        = 0x0000A109, ORR_RGM_RGD        = 0x0000A10C,
  MUL_RGM_RGD        = 0x0000A10D, MVN_RGM_RGD        = 0x0000A10F, 

  /* Rd = Rd shift Rs */
  LSL_RGS_RGD        = 0x0000A102, LSR_RGS_RGD        = 0x0000A103,
  ASR_RGS_RGD        = 0x0000A104, ROR_RGS_RGD        = 0x0000A107,

  /* Rn <op> Rn */
  TST_RGN_RGM        = 0x0000A108, CMP_RGN_RGM        = 0x0000A10A,
  CMN_RGN_RGM        = 0x0000A10B, BIC_RGN_RGM        = 0x0000A10E,

  /* Rd = Rd + (PC|SP) + # */
  ADDPC_RGD_IM8      = 0x00005014, ADDSP_RGD_IM8      = 0x00005015,

  /* SP = SP - # */
  SUB_C11_IM7        = 0x00009161,

  /* These operations use h flags to access registers 8-15.
     H flags are the two bits immediately following the instruction code.
     The 1st is for Rd (or Rm for CMP) and the 2nd is for Rm (or Rn).
     When high, add 8 to the register number. */
  ADD_HF2_RGM_RGD    = 0x00008044, CMP_HF2_RGN_RGM    = 0x00008045,
  MOV_HF2_RGM_RGD    = 0x00008046,

  /* Branches using a single h flag, as described previously */
  BX_HF1_RGM_C30     = 0x0000908E, BLX_HF1_RGM_C30    = 0x0000908F,

  /* either Rd = [(PC|SP) + #] or [SP + #] = Rd */
  LDRPC_RGD_IM8      = 0x00005009, LDRSP_RGD_IM8      = 0x00005013, 
  STRSP_RGD_IM8      = 0x00005012,

  /* either Rd = [Rn + Rm] or [Rn + Rm] = Rd
     b means byte, h means half word */
  STR_RGM_RGN_RGD    = 0x00007028, STRH_RGM_RGN_RGD   = 0x00007029,
  STRB_RGM_RGN_RGD   = 0x0000702A, LDRSB_RGM_RGN_RGD  = 0x0000702B,
  LDR_RGM_RGN_RGD    = 0x0000702C, LDRH_RGM_RGN_RGD   = 0x0000702D,
  LDRB_RGM_RGN_RGD   = 0x0000702E, LDRSH_RGM_RGN_RGD  = 0x0000702F,

  /* either Rd = [Rn + #] or [Rn + #] = Rd */
  STR_IM5_RGN_RGD    = 0x0000500C, LDR_IM5_RGN_RGD    = 0x0000500D,
  STRB_IM5_RGN_RGD   = 0x0000500E, LDRB_IM5_RGN_RGD   = 0x0000500F,
  STRH_IM5_RGN_RGD   = 0x00005010, LDRH_IM5_RGN_RGD   = 0x00005011,

  /* IM8 is a bitmask for the lower 8 registers which are all operated
     on at the same time. PUSH and POP both use an h flag. */
  PUSH_HF1_IM8       = 0x0000705A, POP_HF1_IM8        = 0x0000705E,
  STMIA_RGN_IM8      = 0x00005018, LDMIA_RGN_RL8      = 0x00005019,

  /* Other operations using the 8-bit immediate as an argument. Note
     that BCOND uses bits 11-8 as condition bits. */
  BKPT_IM8           = 0x000080BE, BCOND_IM8          = 0x0000400D,
  UNUSED_IM8         = 0x000080DE, SWI_IM8            = 0x000080DF,
  B_IM8              = 0x0000501C, BLX_IM8            = 0x0000501D,
  BLXH_IM8           = 0x0000501E, BL_IM8             = 0x0000501F

} ThumbISA;

/**
 * Represents the 16 condition bits used for conditional branching.
 */
typedef enum _ConditionBits
{
  CB_EQ = 0x0, /* equal */
  CB_NE,       /* not equal */
  CB_CS,       /* carry set */
  CB_CC,       /* carry clear */
  CB_HS = 0x2, /* unsigned higher or same */
  CB_LO,       /* unsigned lower */
  CB_MI,       /* minus/negative */
  CB_PL,       /* plus/positive or zero */
  CB_VS,       /* overflow */
  CB_VC,       /* no overflow */
  CB_HI,       /* unsigned higher */
  CB_LS,       /* unsigned lower or same */
  CB_GE,       /* signed greater than or equal */
  CB_LT,       /* signed less than */
  CB_GT,       /* signed greater than */
  CB_LE,       /* signed less than or equal */
  CB_AL,       /* always */
  CB_NV        /* never */
} ConditionBits;

/**
 * Determine if a 16 bit opcode matches one of the 64 ARM Thumb opcodes
 *
 * @param x 16 bit opcode with arguments
 * @param y a ThumbISA value, defined above
 * @return 1 if x and y are the same opcode
 */
#define CODE_MATCHES(x, y) \
  (\
                         /* ( bit width for test code ) */ \
         /* ( 1s covering the bit width for test code  ) */ \
    /* (part of x covering the bit width for test code  ) */ \
       (x & (0xFFFF0000  >> ((y & 0x0000F000) / 0x1000))) \
                                 /* ( bit width for test code ) */ \
                         /* ( opcode width - bit width for tc  ) */ \
     /* ( tc code part ) */ \
    /* (  tc code part shifted opcode width - bit width for tc  ) */ \
    == ((y & 0x00000FFF) << (0x10 - ((y & 0x0000F000) / 0x1000))) \
    ? 1 /* code part of x matches code part of y */ \
    : 0 /* code part of x doesn't match code part of y */ \
  )

#endif /* __SOFT_STACK_ISA */
