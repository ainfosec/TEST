-- Filename:          muxer.vhd
-- Version:           1.00.a
-- Description:       selects 2 inputs for the ALU based on opcode
-- Date Created:      Wed, Dec 04, 2013 02:04:16
-- Last Modified:     Fri, Dec 06, 2013 00:23:18
-- VHDL Standard:     VHDL'93
-- Author:            Sean McClain <mcclains@ainfosec.com>
-- Copyright:         (c) 2013 Assured Information Security, All Rights Reserved

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

library simple_processor_v1_00_a;
use simple_processor_v1_00_a.opcodes.all;
use simple_processor_v1_00_a.reg_file_constants.all;

---
-- Selects 2 inputs based on a decoded 16 bit ARM Thumb opcode,
--  and any output registers written to
---
entity muxer
is
  port
  (
    -- decoded ARM Thumb(R) opcode
    opcode      : in    integer;

    -- immediate values
    Imm_3       : in    std_logic_vector(2  downto 0);
    Imm_5       : in    std_logic_vector(4  downto 0);
    Imm_8       : in    std_logic_vector(7  downto 0);
    Imm_11      : in    std_logic_vector(10 downto 0);

    -- register values
    sp_plus_off : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    pc_plus_off : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    rn_plus_off : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    rm_plus_rn  : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    rm_hh_reg   : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    rm_hl_reg   : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    rn_hh_reg   : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    rn_hl_reg   : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    rm_reg      : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    rn_reg      : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    rs_reg      : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    rd_reg      : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    sp_reg      : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    pc_reg      : in    std_logic_vector(DATA_WIDTH-1 downto 0);

    -- pointer address values
    sp          : in    integer;
    pc          : in    integer;

    -- alu outputs
    alu_a       : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    alu_b       : out   std_logic_vector(DATA_WIDTH-1 downto 0);

    -- which output register values to enable
    wr_en       : out   std_logic_vector(WR_EN_SIZEOF-1 downto 0)
  );

end entity muxer;

architecture IMP of muxer
is

  -- unsigned and signed immediate values extended to DATA_WIDTH
  signal Imm_3_uns  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal Imm_5_uns  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal Imm_8_uns  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal Imm_11_uns : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal Imm_3_sgn  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal Imm_5_sgn  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal Imm_8_sgn  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal Imm_11_sgn : std_logic_vector(DATA_WIDTH-1 downto 0);

  -- switch constants for turning on exactly one write enable
  constant EN_RD          : std_logic_vector := "0000000001";
  constant EN_SP_PLUS_OFF : std_logic_vector := "0000000010";
  constant EN_RN_PLUS_OFF : std_logic_vector := "0000000100";
  constant EN_RM_PLUS_RN  : std_logic_vector := "0000001000";
  constant EN_RD_H_REG    : std_logic_vector := "0000010000";
  constant EN_SP          : std_logic_vector := "0000100000";
  constant EN_PC          : std_logic_vector := "0001000000";
  constant EN_LR          : std_logic_vector := "0010000000";
  constant EN_LIST_RTS    : std_logic_vector := "0100000000";
  constant EN_LIST_STR    : std_logic_vector := "1000000000";
  constant EN_NONE        : std_logic_vector := "0000000000";

begin

  -- extend immediate values
  Imm_3_uns(DATA_WIDTH-1  downto 3)  <= (others => '0');
  Imm_3_uns(2 downto 0)              <= Imm_3;
  Imm_5_uns(DATA_WIDTH-1  downto 5)  <= (others => '0');
  Imm_5_uns(4 downto 0)              <= Imm_5;
  Imm_8_uns(DATA_WIDTH-1  downto 8)  <= (others => '0');
  Imm_8_uns(7 downto 0)              <= Imm_8;
  Imm_11_uns(DATA_WIDTH-1 downto 11) <= (others => '0');
  Imm_11_uns(10 downto 0)            <= Imm_11;
  Imm_3_sgn(DATA_WIDTH-1  downto 3)  <= (others => Imm_3(2));
  Imm_3_sgn(2 downto 0)              <= Imm_3;
  Imm_5_sgn(DATA_WIDTH-1  downto 5)  <= (others => Imm_5(4));
  Imm_5_sgn(4 downto 0)              <= Imm_5;
  Imm_8_sgn(DATA_WIDTH-1  downto 8)  <= (others => Imm_8(7));
  Imm_8_sgn(7 downto 0)              <= Imm_8;
  Imm_11_sgn(DATA_WIDTH-1 downto 11) <= (others => Imm_11(10));
  Imm_11_sgn(10 downto 0)            <= Imm_11;

  -- select 1st input
  with opcode select alu_a <= 

    -- Rd := Rd + PC + (#OFF << 2)
    rd_reg when ADD_Rd_IPC,

    -- Rd := SP + (#OFF << 2)
    std_logic_vector(to_unsigned(sp, DATA_WIDTH)) when ADD_Rd_ISP,

    -- SP := SP - (#OFF << 2)
    std_logic_vector(to_unsigned(sp, DATA_WIDTH)) when SUB_I,

    -- Rd := [(SP|PC) + (#OFF << 2)]
    pc_plus_off when LDR_Rd_IPC,
    sp_plus_off when LDR_Rd_ISP,

    -- [SP + (#OFF << 2)] := Rd
    rd_reg when STR_Rd_I,

    -- Rd := Rm <op> I
    rm_reg when LSL_Rd_Rm_I,
    rm_reg when LSR_Rd_Rm_I,
    rm_reg when ASR_Rd_Rm_I,

    -- Rd := Rn <op> I
    rn_reg when ADD_Rd_Rn_I,
    rn_reg when SUB_Rd_Rn_I,

    -- Rd := Rd <op> I
    rd_reg when MOV_Rd_I,
    rd_reg when ADD_Rd_I,
    rd_reg when SUB_Rd_I,

    -- Rd := Rm <op> Rn
    rm_reg when ADD_Rd_Rm_Rn,
    rm_reg when SUB_Rd_Rm_Rn,

    -- Rd := Rd <op> Rm
    rd_reg when AND_Rd_Rm,
    rd_reg when EOR_Rd_Rm,
    rd_reg when ADC_Rd_Rm,
    rd_reg when SBC_Rd_Rm,
    rd_reg when NEG_Rd_Rm,
    rd_reg when ORR_Rd_Rm,
    rd_reg when MUL_Rd_Rm,
    rd_reg when MVN_Rd_Rm,

    -- Rd := Rd <op> Rs
    rd_reg when LSL_Rd_Rs,
    rd_reg when LSR_Rd_Rs,
    rd_reg when ASR_Rd_Rs,
    rd_reg when ROR_Rd_Rs,

    -- <op> I
    Imm_8_uns when BKPT_I,
    Imm_8_uns when B_COND_I,
    Imm_8_uns when SWI_I,
    Imm_8_uns when B_I,
    Imm_8_uns when BLX_L_I,
    Imm_8_uns when BLX_H_I,
    Imm_8_uns when BL_I,

    -- Rn <op> I
    rn_reg when CMP_Rn_I,

    -- Rm <op> Rn
    rm_reg when TST_Rm_Rn,
    rm_reg when CMP_Rm_Rn,
    rm_reg when CMN_Rm_Rn,
    rm_reg when BIC_Rm_Rn,

    -- (Rd + H_1 * 8) := (Rd + H_1 * 8) <op> (Rm + H_0 * 8)
    rn_hh_reg when ADD_Rd_Rm,
    rn_hh_reg when MOV_Rd_Rm,

    -- (Rm + H_1 * 8) <op> (Rn + H_0 * 8)
    rm_hh_reg when CMP_Rm_Rn_2,

    -- <op> (Rm + 8 * H_0)
    rm_hl_reg when BX_Rm,
    rm_hl_reg when BLX_Rm,

    -- Rd := [Rn + (#OFF << 2)]
    rn_plus_off when LDR_Rd_Rn_I,
    rn_plus_off when LDRB_Rd_Rn_I,
    rn_plus_off when LDRH_Rd_Rn_I,

    -- Rd := [Rm + Rn]
    rm_plus_rn when LDRSB_Rd_Rm_Rn,
    rm_plus_rn when LDR_Rd_Rm_Rn,
    rm_plus_rn when LDRH_Rd_Rm_Rn,
    rm_plus_rn when LDRB_Rd_Rm_Rn,
    rm_plus_rn when LDRSH_Rd_Rm_Rn,

    -- [Rn + (#OFF << 2)] := Rd
    rd_reg when STR_Rd_Rn_I,
    rd_reg when STRB_Rd_Rn_I,
    rd_reg when STRH_Rd_Rn_I,

    -- [Rm + Rn] := Rd
    rd_reg when STR_Rd_Rm_Rn,
    rd_reg when STRH_Rd_Rm_Rn,
    rd_reg when STRB_Rd_Rm_Rn,

    -- operation on a list of registers
    Imm_8_uns when PUSH_RL_LR,
    Imm_8_uns when POP_RL_PC,
    Imm_8_uns when LDMIA_RN_RL,
    Imm_8_uns when STMIA_RN_RL,

    -- unused opcodes
    (others => '0') when UNUSED,
    (others => '0') when others;

  -- select 2nd input
  with opcode select alu_b <=

    -- Rd := Rd + PC + (#OFF << 2)
    std_logic_vector(to_unsigned(pc, DATA_WIDTH-8)) & Imm_8 when ADD_Rd_IPC,

    -- Rd := SP + (#OFF << 2)
    Imm_8_sgn when ADD_Rd_ISP,

    -- SP := SP - (#OFF << 2)
    Imm_8_sgn when SUB_I,

    -- Rd := [(SP|PC) + (#OFF << 2)]
    Imm_8_sgn when LDR_Rd_IPC,
    Imm_8_sgn when LDR_Rd_ISP,

    -- [SP + (#OFF << 2)] := Rd
    Imm_8_sgn when STR_Rd_I,

    -- Rd := [Rm] <op> I
    Imm_8_sgn when LSL_Rd_Rm_I,
    Imm_8_sgn when LSR_Rd_Rm_I,
    Imm_8_sgn when ASR_Rd_Rm_I,

    -- Rd := Rn <op> I
    Imm_8_sgn when ADD_Rd_Rn_I,
    Imm_8_sgn when SUB_Rd_Rn_I,

    -- Rd := Rd <op> I
    Imm_8_sgn when MOV_Rd_I,
    Imm_8_sgn when ADD_Rd_I,
    Imm_8_sgn when SUB_Rd_I,

    -- Rd := Rm <op> Rn
    rn_reg when ADD_Rd_Rm_Rn,
    rn_reg when SUB_Rd_Rm_Rn,

    -- Rd := Rd <op> Rm
    rm_reg when AND_Rd_Rm,
    rm_reg when EOR_Rd_Rm,
    rm_reg when ADC_Rd_Rm,
    rm_reg when SBC_Rd_Rm,
    rm_reg when NEG_Rd_Rm,
    rm_reg when ORR_Rd_Rm,
    rm_reg when MUL_Rd_Rm,
    rm_reg when MVN_Rd_Rm,

    -- Rd := Rd <op> Rs
    rs_reg when LSL_Rd_Rs,
    rs_reg when LSR_Rd_Rs,
    rs_reg when ASR_Rd_Rs,
    rs_reg when ROR_Rd_Rs,

    -- <op> I
    (others => '0') when BKPT_I,
    (others => '0') when B_COND_I,
    (others => '0') when SWI_I,
    (others => '0') when B_I,
    (others => '0') when BLX_L_I,
    (others => '0') when BLX_H_I,
    (others => '0') when BL_I,

    -- Rn <op> I
    (DATA_WIDTH-1 downto 8 => '0') & Imm_8 when CMP_Rn_I,

    -- Rm <op> Rn
    rn_reg when TST_Rm_Rn,
    rn_reg when CMP_Rm_Rn,
    rn_reg when CMN_Rm_Rn,
    rn_reg when BIC_Rm_Rn,

    -- (Rd + H_1 * 8) := (Rd + H_1 * 8) <op> (Rm + H_0 * 8)
    rm_hl_reg when ADD_Rd_Rm,
    rm_hl_reg when MOV_Rd_Rm,

    -- Rm + H_1 * 8 <op> Rn + H_0 * 8
    rn_hl_reg when CMP_Rm_Rn_2,

    -- <op> (Rm + 8 * H_0)
    (others => '0') when BX_Rm,
    (others => '0') when BLX_Rm,

    -- Rd := [Rn + (#OFF << 2)]
    (others => '0') when LDR_Rd_Rn_I,
    (others => '0') when LDRB_Rd_Rn_I,
    (others => '0') when LDRH_Rd_Rn_I,

    -- Rd := [Rm + Rn]
    (others => '0') when LDRSB_Rd_Rm_Rn,
    (others => '0') when LDR_Rd_Rm_Rn,
    (others => '0') when LDRH_Rd_Rm_Rn,
    (others => '0') when LDRB_Rd_Rm_Rn,
    (others => '0') when LDRSH_Rd_Rm_Rn,

    -- [Rn + (#OFF << 2)] := Rd
    (others => '0') when STR_Rd_Rn_I,
    (others => '0') when STRB_Rd_Rn_I,
    (others => '0') when STRH_Rd_Rn_I,

    -- [Rm + Rn] := Rd
    (others => '0') when STR_Rd_Rm_Rn,
    (others => '0') when STRH_Rd_Rm_Rn,
    (others => '0') when STRB_Rd_Rm_Rn,

    -- operation on a list of registers
    (others => '0') when PUSH_RL_LR,
    (others => '0') when POP_RL_PC,
    (others => '0') when LDMIA_RN_RL,
    (others => '0') when STMIA_RN_RL,

    -- unused opcodes
    (others => '0') when UNUSED,
    (others => '0') when others;

  -- select write enables
  with opcode select wr_en <=

    -- Rd := Rd + PC + (#OFF << 2)
    EN_RD when ADD_Rd_IPC,

    -- Rd := SP + (#OFF << 2)
    EN_RD when ADD_Rd_ISP,

    -- SP := SP - (#OFF << 2)
    EN_SP when SUB_I,

    -- Rd := [(SP|PC) + (#OFF << 2)]
    EN_RD when LDR_Rd_IPC,
    EN_RD when LDR_Rd_ISP,

    -- [SP + (#OFF << 2)] := Rd
    EN_SP_PLUS_OFF when STR_Rd_I,

    -- Rd := Rm <op> I
    EN_RD when LSL_Rd_Rm_I,
    EN_RD when LSR_Rd_Rm_I,
    EN_RD when ASR_Rd_Rm_I,

    -- Rd := Rn <op> I
    EN_RD when ADD_Rd_Rn_I,
    EN_RD when SUB_Rd_Rn_I,

    -- Rd := Rd <op> I
    EN_RD when MOV_Rd_I,
    EN_RD when ADD_Rd_I,
    EN_RD when SUB_Rd_I,

    -- Rd := Rm <op> Rn
    EN_RD when ADD_Rd_Rm_Rn,
    EN_RD when SUB_Rd_Rm_Rn,

    -- Rd := Rd <op> Rm
    EN_RD when AND_Rd_Rm,
    EN_RD when EOR_Rd_Rm,
    EN_RD when ADC_Rd_Rm,
    EN_RD when SBC_Rd_Rm,
    EN_RD when NEG_Rd_Rm,
    EN_RD when ORR_Rd_Rm,
    EN_RD when MUL_Rd_Rm,
    EN_RD when MVN_Rd_Rm,

    -- Rd := Rd <op> Rs
    EN_RD when LSL_Rd_Rs,
    EN_RD when LSR_Rd_Rs,
    EN_RD when ASR_Rd_Rs,
    EN_RD when ROR_Rd_Rs,

    -- <op> I
    EN_NONE when BKPT_I,
    EN_PC when B_COND_I,
    EN_NONE when SWI_I,
    EN_PC when B_I,
    EN_LR when BLX_L_I,
    EN_LR when BLX_H_I,
    EN_PC when BL_I,

    -- Rn <op> I
    EN_NONE when CMP_Rn_I,

    -- Rm <op> Rn
    EN_NONE when TST_Rm_Rn,
    EN_NONE when CMP_Rm_Rn,
    EN_NONE when CMN_Rm_Rn,
    EN_NONE when BIC_Rm_Rn,

    -- (Rd + H_1 * 8) := (Rd + H_1 * 8) <op> (Rm + H_0 * 8)
    EN_RD_H_REG when ADD_Rd_Rm,
    EN_RD_H_REG when MOV_Rd_Rm,

    -- (Rm + H_1 * 8) <op> (Rn + H_0 * 8)
    EN_NONE when CMP_Rm_Rn_2,

    -- <op> (Rm + 8 * H_0)
    EN_NONE when BX_Rm,
    EN_LR when BLX_Rm,

    -- Rd := [Rn + (#OFF << 2)]
    EN_RD when LDR_Rd_Rn_I,
    EN_RD when LDRB_Rd_Rn_I,
    EN_RD when LDRH_Rd_Rn_I,

    -- Rd := [Rm + Rn]
    EN_RD when LDRSB_Rd_Rm_Rn,
    EN_RD when LDR_Rd_Rm_Rn,
    EN_RD when LDRH_Rd_Rm_Rn,
    EN_RD when LDRB_Rd_Rm_Rn,
    EN_RD when LDRSH_Rd_Rm_Rn,

    -- [Rn + (#OFF << 2)] := Rd
    EN_RN_PLUS_OFF when STR_Rd_Rn_I,
    EN_RN_PLUS_OFF when STRB_Rd_Rn_I,
    EN_RN_PLUS_OFF when STRH_Rd_Rn_I,

    -- [Rm + Rn] := Rd
    EN_RM_PLUS_RN when STR_Rd_Rm_Rn,
    EN_RM_PLUS_RN when STRH_Rd_Rm_Rn,
    EN_RM_PLUS_RN when STRB_Rd_Rm_Rn,

    -- operation on a list of registers
    EN_LIST_RTS when PUSH_RL_LR,
    EN_LIST_STR when POP_RL_PC,
    EN_LIST_STR when LDMIA_RN_RL,
    EN_LIST_RTS when STMIA_RN_RL,

    -- unused opcodes
    EN_NONE when UNUSED,
    EN_NONE when others;

end IMP;
