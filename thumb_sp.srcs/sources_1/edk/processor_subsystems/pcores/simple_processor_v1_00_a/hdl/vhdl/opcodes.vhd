-- Filename:          opcodes.vhd
-- Version:           1.00.a
-- Description:       Contains the opcodes and condition bits from the
--                    ARM Thumb ISA
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Tue, Nov 19, 2013 15:48:47
-- VHDL Standard:     VHDL'93
-- Author:            Sean McClain <mcclains@ainfosec.com>
-- Copyright:         (c) 2013 Assured Information Security, All Rights Reserved

-- from the ARM thumb instruction set
package opcodes is
  -- 64 16-bit opcodes
  constant LSL_Rd_Rm_I       : integer          := 0;
  constant LSR_Rd_Rm_I       : integer          := 1;
  constant ASR_Rd_Rm_I       : integer          := 2;
  constant ADD_Rd_Rm_Rn      : integer          := 3;
  constant SUB_Rd_Rm_Rn      : integer          := 4;
  constant ADD_Rd_Rn_I       : integer          := 5;
  constant SUB_Rd_Rn_I       : integer          := 6;
  constant MOV_Rd_I          : integer          := 7;
  constant CMP_Rn_I          : integer          := 8;
  constant ADD_Rd_I          : integer          := 9;
  constant SUB_Rd_I          : integer          := 10;
  constant AND_Rd_Rm         : integer          := 11;
  constant EOR_Rd_Rm         : integer          := 12;
  constant LSL_Rd_Rs         : integer          := 13;
  constant LSR_Rd_Rs         : integer          := 14;
  constant ASR_Rd_Rs         : integer          := 15;
  constant ADC_Rd_Rm         : integer          := 16;
  constant SBC_Rd_Rm         : integer          := 17;
  constant ROR_Rd_Rs         : integer          := 18;
  constant TST_Rm_Rn         : integer          := 19;
  constant NEG_Rd_Rm         : integer          := 20;
  constant CMP_Rm_Rn         : integer          := 21;
  constant CMN_Rm_Rn         : integer          := 22;
  constant ORR_Rd_Rm         : integer          := 23;
  constant MUL_Rd_Rm         : integer          := 24;
  constant BIC_Rm_Rn         : integer          := 25;
  constant MVN_Rd_Rm         : integer          := 26;
  constant ADD_Rd_Rm         : integer          := 27;
  constant CMP_Rm_Rn_2       : integer          := 28;
  constant MOV_Rd_Rm         : integer          := 29;
  constant BX_Rm             : integer          := 30;
  constant BLX_Rm            : integer          := 31;
  constant LDR_Rd_IPC        : integer          := 32;
  constant STR_Rd_Rm_Rn      : integer          := 33;
  constant STRH_Rd_Rm_Rn     : integer          := 34;
  constant STRB_Rd_Rm_Rn     : integer          := 35;
  constant LDRSB_Rd_Rm_Rn    : integer          := 36;
  constant LDR_Rd_Rm_Rn      : integer          := 37;
  constant LDRH_Rd_Rm_Rn     : integer          := 38;
  constant LDRB_Rd_Rm_Rn     : integer          := 39;
  constant LDRSH_Rd_Rm_Rn    : integer          := 40;
  constant STR_Rd_Rn_I       : integer          := 41;
  constant LDR_Rd_Rn_I       : integer          := 42;
  constant STRB_Rd_Rn_I      : integer          := 43;
  constant LDRB_Rd_Rn_I      : integer          := 44;
  constant STRH_Rd_Rn_I      : integer          := 45;
  constant LDRH_Rd_Rn_I      : integer          := 46;
  constant STR_Rd_I          : integer          := 47;
  constant LDR_Rd_ISP        : integer          := 48;
  constant ADD_Rd_IPC        : integer          := 49;
  constant ADD_Rd_ISP        : integer          := 50;
  constant SUB_I             : integer          := 51;
  constant PUSH_RL_LR        : integer          := 52;
  constant POP_RL_PC         : integer          := 53;
  constant BKPT_I            : integer          := 54;
  constant STMIA_RN_RL       : integer          := 55;
  constant LDMIA_RN_RL       : integer          := 56;
  constant B_COND_I          : integer          := 57;
  constant UNUSED            : integer          := 58;
  constant SWI_I             : integer          := 59;
  constant B_I               : integer          := 60;
  constant BLX_L_I           : integer          := 61;
  constant BLX_H_I           : integer          := 62;
  constant BL_I              : integer          := 63;

  -- condition bits (31 - 28)
  constant EQ                : integer          := 0;
  constant NE                : integer          := 1;
  constant HS                : integer          := 2;
  constant LO                : integer          := 3;
  constant MI                : integer          := 4;
  constant PL                : integer          := 5;
  constant VS                : integer          := 6;
  constant VC                : integer          := 7;
  constant HI                : integer          := 8;
  constant LS                : integer          := 9;
  constant GE                : integer          := 10;
  constant LT                : integer          := 11;
  constant GT                : integer          := 12;
  constant LE                : integer          := 13;
  constant AL                : integer          := 14;
  constant NV                : integer          := 15;

end package opcodes;

package body opcodes is

end package body opcodes;
