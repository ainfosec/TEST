-- Filename:          alu.vhd
-- Version:           0.01
-- Description:       Performs all arithmetic and sets/clears flags
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Fri, Dec 06, 2013 00:20:08
-- VHDL Standard:     VHDL '93
-- Author:            Sean McClain <mcclains@ainfosec.com>
-- Copyright:         (c) 2013 Assured Information Security, All Rights Reserved

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

library simple_processor_v1_00_a;
use simple_processor_v1_00_a.opcodes.all;
use simple_processor_v1_00_a.states.all;
use simple_processor_v1_00_a.reg_file_constants.all;

---
-- Arithmetic Logic Unit
--
-- This device will perform a single requested operation on the two arguments
--  presented and output the result. In addition, under certain conditions,
--  the n(egative), z(ero), c(arry), and (o)v(erflow) flags will be set.
--  This device has internal storage for these flags, and they will be
--  carried between operations.
---
entity alu
is
  port
  (
    -- first argument to the requested operation
    a             : in    std_logic_vector(DATA_WIDTH-1 downto 0);

    -- second argument to the requested operation
    b             : in    std_logic_vector(DATA_WIDTH-1 downto 0);

    -- convenience values for comparisons
    zero          : in    std_logic_vector(DATA_WIDTH-1 downto 0);

    -- one of 64 unique ARM Thumb ISA opcodes for the requested operation
    opcode        : in    integer;

    -- the return value of the requested operation
    result        : out   std_logic_vector(DATA_WIDTH-1 downto 0);

    -- negative flag
    n             : out   std_logic;

    -- zero flag
    z             : out   std_logic;

    -- carry flag
    c             : out   std_logic;

    -- overflow flag
    v             : out   std_logic;

    -- acknowledge when the ALU's flags have been cleared
    alu_reset_ack : out   std_logic;

    -- acknowledge when the ALU has performed an arithmetic operation
    math_ack      : out   std_logic;

    -- lets us know when to trigger an event
    state         : in    integer range STATE_MIN to STATE_MAX
  );

end entity alu;

architecture IMP of alu
is

  -- anything past this is overflow
  constant INT_MAX           : integer          := 1073741823;
  constant INT_MIN           : integer          := -1073741824;

  -- storage for flags
  signal n_l                 : std_logic;
  signal z_l                 : std_logic;
  signal c_l                 : std_logic;
  signal v_l                 : std_logic;

begin

  -- send flags on out
  n <= n_l;
  z <= z_l;
  c <= c_l;
  v <= v_l;

  -- clear flags, or perform arithmetic operations and set flags
  DO_UPDATE : process( state )
  is
    variable carry        : integer;
    variable math_buff    : std_logic_vector(DATA_WIDTH*2-1 downto 0);
    variable a_se         : std_logic_vector(DATA_WIDTH*2-1 downto 0);
    variable b_se         : std_logic_vector(DATA_WIDTH*2-1 downto 0);
    variable b_i          : integer;
  begin

    -- clear all flags
    RESET_EVENT : if state = DO_ALU_RESET
    then

      -- clear flags
      n_l <= '0';
      z_l <= '0';
      c_l <= '0';
      v_l <= '0';

      -- let the state machine know we're done resetting
      alu_reset_ack <= '1';

    end if RESET_EVENT;

    -- perform arithmetic
    MATH_EVENT : if state = DO_MATH
    then

      -- default values
      math_buff(DATA_WIDTH-1 downto 0) := (others => '0');

      -- load carry-in bit as an integer
      if c_l = '1'
      then
        carry := 1;
      else
        carry := 0;
      end if;

      -- sign extend operands for math ops
      for i in DATA_WIDTH*2-1 downto DATA_WIDTH
      loop
        a_se(i) := a(DATA_WIDTH-1);
        b_se(i) := b(DATA_WIDTH-1);
      end loop;
      a_se(DATA_WIDTH-1 downto 0) := a;
      b_se(DATA_WIDTH-1 downto 0) := b;

      -- some shift/rotate ops need to treat b as an index
      b_i := to_integer(unsigned(b));

      SELECT_OPERATION :

      -- move stack pointer
      if    opcode = SUB_I
      then
        math_buff :=
          std_logic_vector(signed(a_se) - shift_right(signed(b_se), 2));

      -- multiply
      elsif opcode = MUL_Rd_Rm
      then
        math_buff :=
          std_logic_vector(unsigned(a) * unsigned(b));

      -- negate
      elsif opcode = NEG_Rd_Rm    or opcode = MVN_Rd_Rm
      then
        math_buff :=
          std_logic_vector(unsigned(not a_se) + 1);

      -- add with carry
      elsif opcode = ADC_Rd_Rm
      then
        math_buff :=
          std_logic_vector(signed(a_se) + signed(b_se) + carry);

      -- subtract with carry
      elsif opcode = SBC_Rd_Rm
      then
        math_buff :=
          std_logic_vector(unsigned(a_se) + unsigned(not b_se) + carry);

      -- add
      elsif opcode = ADD_Rd_I     or opcode = ADD_Rd_IPC
         or opcode = ADD_Rd_ISP   or opcode = ADD_Rd_Rm
         or opcode = ADD_Rd_Rn_I  or opcode = ADD_Rd_Rm_Rn
         or opcode = CMN_Rm_Rn    or opcode = MOV_Rd_I
         or opcode = MOV_Rd_Rm
      then
        math_buff :=
          std_logic_vector(signed(a_se) + signed(b_se));

      -- subtract
      elsif opcode = CMP_Rm_Rn    or opcode = CMP_Rm_Rn_2
         or opcode = CMP_Rn_I     or opcode = SUB_Rd_I
         or opcode = SUB_Rd_Rn_I  or opcode = SUB_Rd_Rm_Rn
      then
        math_buff :=
          std_logic_vector(signed(a_se) - signed(b_se));

      -- arithmetic or logical shift right
      elsif opcode = ASR_Rd_Rm_I  or opcode = ASR_Rd_Rs
         or opcode = LSR_Rd_Rm_I  or opcode = LSR_Rd_Rs
      then
        math_buff(DATA_WIDTH*2-1 downto DATA_WIDTH+b_i) := (others => '0');
        math_buff(DATA_WIDTH+b_i-1 downto DATA_WIDTH) := a(b_i-1 downto 0);
        if    opcode = ASR_Rd_Rm_I  or opcode = ASR_Rd_Rs
        then
          math_buff(DATA_WIDTH-1 downto 0) :=
            std_logic_vector(shift_right(signed(a), to_integer(unsigned(b))));
        elsif opcode = LSR_Rd_Rm_I  or opcode = LSR_Rd_Rs
        then
          math_buff(DATA_WIDTH-1 downto 0) :=
            std_logic_vector(shift_right(unsigned(a), to_integer(unsigned(b))));
        end if;

      -- logical shift left
      elsif opcode = LSL_Rd_Rm_I  or opcode = LSL_Rd_Rs
      then
        math_buff(DATA_WIDTH*2-1 downto DATA_WIDTH+b_i) := (others => '0');
        math_buff(DATA_WIDTH+b_i-1 downto DATA_WIDTH) :=
          a(DATA_WIDTH-1 downto DATA_WIDTH-b_i);
        math_buff(DATA_WIDTH-1 downto 0) :=
          std_logic_vector(shift_left(unsigned(a), to_integer(unsigned(b))));

      -- logical rotate right
      elsif opcode = ROR_Rd_Rs
      then
        math_buff(DATA_WIDTH*2-1 downto DATA_WIDTH+b_i) := (others => '0');
        math_buff(DATA_WIDTH+b_i-1 downto DATA_WIDTH) := a(b_i-1 downto 0);
        math_buff(DATA_WIDTH-1 downto 0) :=
          std_logic_vector (
              rotate_right(unsigned(a), to_integer(unsigned(b)))
              );

      -- bitwise and
      elsif opcode = AND_Rd_Rm    or opcode = TST_Rm_Rn
      then
        math_buff(DATA_WIDTH*2-1 downto DATA_WIDTH) := (others => '0');
        math_buff(DATA_WIDTH-1 downto 0) := a and b;

      -- bit clear
      elsif opcode = BIC_Rm_Rn
      then
        math_buff(DATA_WIDTH*2-1 downto DATA_WIDTH) := (others => '0');
        math_buff(DATA_WIDTH-1 downto 0) := a and not b;

      -- bitwise exclusive or
      elsif opcode = EOR_Rd_Rm
      then
        math_buff(DATA_WIDTH*2-1 downto DATA_WIDTH) := (others => '0');
        math_buff(DATA_WIDTH-1 downto 0) := a xor b;

      -- bitwise or
      elsif opcode = ORR_Rd_Rm
      then
        math_buff(DATA_WIDTH*2-1 downto DATA_WIDTH+1) := (others => '0');
        math_buff(DATA_WIDTH) := a(DATA_WIDTH-1) and b(DATA_WIDTH-1);
        math_buff(DATA_WIDTH-1 downto 0) := a or b;

      -- pass through
      else
        math_buff(DATA_WIDTH*2-1 downto DATA_WIDTH) := (others => '0');
        math_buff(DATA_WIDTH-1 downto 0) := a;

      end if SELECT_OPERATION;

        -- all 64 opcodes
--      if    opcode = ADC_Rd_Rm      or opcode = ADD_Rd_I
--         or opcode = ADD_Rd_IPC     or opcode = ADD_Rd_ISP
--         or opcode = ADD_Rd_Rm      or opcode = ADD_Rd_Rn_I
--         or opcode = ADD_Rd_Rm_Rn   or opcode = AND_Rd_Rm
--         or opcode = ASR_Rd_Rm_I    or opcode = ASR_Rd_Rs
--         or opcode = B_COND_I       or opcode = B_I
--         or opcode = BIC_Rm_Rn      or opcode = BKPT_I
--         or opcode = BL_I           or opcode = BLX_H_I
--         or opcode = BLX_L_I        or opcode = BLX_Rm
--         or opcode = BX_Rm          or opcode = CMN_Rm_Rn
--         or opcode = CMP_Rm_Rn      or opcode = CMP_Rm_Rn_2
--         or opcode = CMP_Rn_I       or opcode = EOR_Rd_Rm
--         or opcode = LDMIA_RN_RL    or opcode = LDR_Rd_IPC
--         or opcode = LDR_Rd_ISP     or opcode = LDR_Rd_Rn_I
--         or opcode = LDR_Rd_Rm_Rn   or opcode = LDRB_Rd_Rn_I
--         or opcode = LDRB_Rd_Rm_Rn  or opcode = LDRH_Rd_Rn_I
--         or opcode = LDRH_Rd_Rm_Rn  or opcode = LDRSB_Rd_Rm_Rn
--         or opcode = LDRSH_Rd_Rm_Rn or opcode = LSL_Rd_Rm_I
--         or opcode = LSL_Rd_Rs      or opcode = LSR_Rd_Rm_I
--         or opcode = LSR_Rd_Rs      or opcode = MOV_Rd_I
--         or opcode = MOV_Rd_Rm      or opcode = MUL_Rd_Rm
--         or opcode = MVN_Rd_Rm      or opcode = NEG_Rd_Rm
--         or opcode = ORR_Rd_Rm      or opcode = POP_RL_PC
--         or opcode = PUSH_RL_LR     or opcode = ROR_Rd_Rs
--         or opcode = SBC_Rd_Rm      or opcode = STMIA_RN_RL
--         or opcode = STR_Rd_I       or opcode = STR_Rd_Rn_I
--         or opcode = STR_Rd_Rm_Rn   or opcode = STRB_Rd_Rn_I
--         or opcode = STRB_Rd_Rm_Rn  or opcode = STRH_Rd_Rn_I
--         or opcode = STRH_Rd_Rm_Rn  or opcode = SUB_I
--         or opcode = SUB_Rd_I       or opcode = SUB_Rd_Rn_I
--         or opcode = SUB_Rd_Rm_Rn   or opcode = SWI_I
--         or opcode = TST_Rm_Rn      or opcode = UNUSED

      -- set zero flag
      SET_ZERO_FLAG:
      if    opcode = ADC_Rd_Rm      or opcode = ADD_Rd_I
                                    or opcode = ADD_Rd_Rn_I
         or opcode = ADD_Rd_Rm_Rn   or opcode = AND_Rd_Rm
         or opcode = ASR_Rd_Rm_I    or opcode = ASR_Rd_Rs
         or opcode = BIC_Rm_Rn
                                    or opcode = CMN_Rm_Rn
         or opcode = CMP_Rm_Rn      or opcode = CMP_Rm_Rn_2
         or opcode = CMP_Rn_I       or opcode = EOR_Rd_Rm
                                    or opcode = LSL_Rd_Rm_I
         or opcode = LSL_Rd_Rs      or opcode = LSR_Rd_Rm_I
         or opcode = LSR_Rd_Rs      or opcode = MOV_Rd_I
                                    or opcode = MUL_Rd_Rm
         or opcode = MVN_Rd_Rm      or opcode = NEG_Rd_Rm
         or opcode = ORR_Rd_Rm
                                    or opcode = ROR_Rd_Rs
         or opcode = SBC_Rd_Rm
         or opcode = SUB_Rd_I       or opcode = SUB_Rd_Rn_I
         or opcode = SUB_Rd_Rm_Rn
         or opcode = TST_Rm_Rn
      then
        if math_buff(DATA_WIDTH-1 downto 0) = zero
        then
          z_l <= '1';
        else
          z_l <= '0';
        end if;
      end if;

      -- set overflow flag
      SET_CARRY_FLAG:
      if    opcode = ADC_Rd_Rm      or opcode = ADD_Rd_I
                                    or opcode = ADD_Rd_Rn_I
         or opcode = ADD_Rd_Rm_Rn   or opcode = AND_Rd_Rm
         or opcode = ASR_Rd_Rm_I    or opcode = ASR_Rd_Rs
         or opcode = BIC_Rm_Rn
                                    or opcode = CMN_Rm_Rn
         or opcode = CMP_Rm_Rn      or opcode = CMP_Rm_Rn_2
         or opcode = CMP_Rn_I       or opcode = EOR_Rd_Rm
                                    or opcode = LSL_Rd_Rm_I
         or opcode = LSL_Rd_Rs      or opcode = LSR_Rd_Rm_I
         or opcode = LSR_Rd_Rs      or opcode = MOV_Rd_I
                                    or opcode = MUL_Rd_Rm
                                    or opcode = NEG_Rd_Rm
         or opcode = ORR_Rd_Rm
                                    or opcode = ROR_Rd_Rs
         or opcode = SBC_Rd_Rm
         or opcode = SUB_Rd_I       or opcode = SUB_Rd_Rn_I
         or opcode = SUB_Rd_Rm_Rn
      then
        if math_buff(DATA_WIDTH*2-1 downto DATA_WIDTH) /= zero
        then
          c_l <= '1';
        else
          c_l <= '0';
        end if;
      end if SET_CARRY_FLAG;

      -- set negative flag
      SET_NEGATIVE_FLAG:
      if    opcode = ADC_Rd_Rm      or opcode = ADD_Rd_I
                                    or opcode = ADD_Rd_Rn_I
         or opcode = ADD_Rd_Rm_Rn   or opcode = AND_Rd_Rm
         or opcode = ASR_Rd_Rm_I    or opcode = ASR_Rd_Rs
         or opcode = BIC_Rm_Rn
                                    or opcode = CMN_Rm_Rn
         or opcode = CMP_Rm_Rn      or opcode = CMP_Rm_Rn_2
         or opcode = CMP_Rn_I       or opcode = EOR_Rd_Rm
                                    or opcode = LSL_Rd_Rm_I
         or opcode = LSL_Rd_Rs      or opcode = LSR_Rd_Rm_I
         or opcode = LSR_Rd_Rs      or opcode = MOV_Rd_I
                                    or opcode = MUL_Rd_Rm
         or opcode = MVN_Rd_Rm      or opcode = NEG_Rd_Rm
         or opcode = ORR_Rd_Rm
                                    or opcode = ROR_Rd_Rs
         or opcode = SBC_Rd_Rm
         or opcode = SUB_Rd_I       or opcode = SUB_Rd_Rn_I
         or opcode = SUB_Rd_Rm_Rn
         or opcode = TST_Rm_Rn
      then
        n_l <= math_buff(DATA_WIDTH-1);
      end if;

      -- set overflow flag
      SET_OVERFLOW_FLAG:
      if    opcode = ADC_Rd_Rm      or opcode = ADD_Rd_I
                                    or opcode = ADD_Rd_Rn_I
         or opcode = ADD_Rd_Rm_Rn   or opcode = AND_Rd_Rm
                                    or opcode = EOR_Rd_Rm
                                    or opcode = NEG_Rd_Rm
      then
        if    a(DATA_WIDTH-1)  = b(DATA_WIDTH-1)
          and a(DATA_WIDTH-1) /= math_buff(DATA_WIDTH-1)
        then
          v_l <= '0';
        else
          v_l <= '1';
        end if;
      elsif                            opcode = CMN_Rm_Rn
         or opcode = CMP_Rm_Rn      or opcode = CMP_Rm_Rn_2
         or opcode = CMP_Rn_I
         or opcode = SBC_Rd_Rm
         or opcode = SUB_Rd_I       or opcode = SUB_Rd_Rn_I
         or opcode = SUB_Rd_Rm_Rn
      then
        if    a(DATA_WIDTH-1) /= b(DATA_WIDTH-1)
          and a(DATA_WIDTH-1) /= math_buff(DATA_WIDTH-1)
        then
          v_l <= '0';
        else
          v_l <= '1';
        end if;
      end if;

      -- copy our result on out
      result <= math_buff(DATA_WIDTH-1 downto 0);

      -- let the state machine know arithmetic work is done
      math_ack <= '1';

    end if MATH_EVENT;

    -- reset state machine outputs
    CLEAR_FLAGS_EVENT : if state = DO_CLEAR_FLAGS
    then
      alu_reset_ack <= '0';
      math_ack      <= '0';
    end if;

  end process DO_UPDATE;

  -- send flags on out
  UPDATE_FLAGS : process ( n_l, z_l, c_l, v_l )
  is
  begin
    n <= n_l;
    z <= z_l;
    c <= c_l;
    v <= v_l;
  end process UPDATE_FLAGS;

end IMP;
