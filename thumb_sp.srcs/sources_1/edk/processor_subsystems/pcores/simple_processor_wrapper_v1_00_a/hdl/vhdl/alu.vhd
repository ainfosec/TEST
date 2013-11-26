-- Filename:          alu.vhd
-- Version:           0.01
-- Description:       Performs all arithmetic and sets/clears flags
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Tue, Nov 26, 2013 14:07:55
-- VHDL Standard:     VHDL '93
-- Author:            Sean McClain <mcclains@ainfosec.com>
-- Copyright:         (c) 2013 Assured Information Security, All Rights Reserved

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

library simple_processor_wrapper_v1_00_a;
use simple_processor_wrapper_v1_00_a.opcodes.all;
use simple_processor_wrapper_v1_00_a.states.all;

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
  generic
  (
    data_width : integer            := 32
  );
  port
  (
    -- first argument to the requested operation
    a             : in    std_logic_vector(data_width-1 downto 0);

    -- second argument to the requested operation
    b             : in    std_logic_vector(data_width-1 downto 0);

    -- convenience values for comparisons
    zero          : in    std_logic_vector(data_width-1 downto 0);

    -- one of 64 unique ARM Thumb ISA opcodes for the requested operation
    opcode        : in    integer;

    -- the return value of the requested operation
    result        : out   std_logic_vector(data_width-1 downto 0);

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
    state         : in    integer
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
    variable result_tmp   : std_logic_vector(data_width-1 downto 0);
    variable math_buff    : std_logic_vector(data_width*2-1 downto 0);
    variable a_se         : std_logic_vector(data_width*2-1 downto 0);
    variable b_se         : std_logic_vector(data_width*2-1 downto 0);
    variable did_subtract : std_logic;
    variable temp_i       : integer;
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
      result_tmp := (others => '0');

      -- load carry-in bit as an integer
      if c_l = '1'
      then
        carry := 1;
      else
        carry := 0;
      end if;

      -- mark if subtraction was performed, for overflow
      did_subtract := '0';

      -- addition and subtraction
      IF_ARITH_OR_LOG_SHIFT:
      if    opcode = ADC_Rd_Rm    or opcode = ADD_Rd_I
         or opcode = ADD_Rd_IPC   or opcode = ADD_Rd_ISP
         or opcode = ADD_Rd_Rm    or opcode = ADD_Rd_Rn_I
         or opcode = ADD_Rd_Rn_Rm or opcode = CMN_Rm_Rn
         or opcode = CMP_Rm_Rn    or opcode = CMP_Rm_Rn_2
         or opcode = CMP_Rn_I     or opcode = MOV_Rd_I
         or opcode = MOV_Rd_Rm    or opcode = MVN_Rd_Rm
         or opcode = MUL_Rd_Rm    or opcode = NEG_Rd_Rm
         or opcode = SBC_Rd_Rm    or opcode = SUB_I
         or opcode = SUB_Rd_I     or opcode = SUB_Rd_Rn_I
         or opcode = SUB_Rd_Rn_Rm
      then

        -- sign extend operands for math ops
        for i in data_width*2-1 downto data_width
        loop
          a_se(i) := a(data_width-1);
          b_se(i) := b(data_width-1);
        end loop;
        a_se(data_width-1 downto 0) := a;
        b_se(data_width-1 downto 0) := b;

        -- move stack pointer
        if    opcode = SUB_I
        then
          math_buff :=
            std_logic_vector(signed(a_se) - shift_right(signed(b_se), 2));

        -- multiply
        elsif opcode = MUL_Rd_Rm
        then
          math_buff :=
            std_logic_vector(signed(a) * signed(b));

          -- strip leading ones from upper bits to set carry bit properly
          if   (a(data_width-1) = '1' and b(data_width-1) = '0')
            or (a(data_width-1) = '0' and b(data_width-1) = '1')
          then
            temp_i := 0;
            for i in data_width*2-1 downto data_width
            loop
              if math_buff(i) = '1' and temp_i = 0
              then
                math_buff(i) := '0';
              else
                temp_i := 1;
              end if;
            end loop;
          end if;

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
          did_subtract := '1';

        -- add
        elsif opcode = ADD_Rd_I     or opcode = ADD_Rd_IPC
           or opcode = ADD_Rd_ISP   or opcode = ADD_Rd_Rm
           or opcode = ADD_Rd_Rn_I  or opcode = ADD_Rd_Rn_Rm
           or opcode = CMN_Rm_Rn    or opcode = MOV_Rd_I
           or opcode = MOV_Rd_Rm
        then
          math_buff :=
            std_logic_vector(signed(a_se) + signed(b_se));

        -- subtract
        elsif opcode = CMP_Rm_Rn    or opcode = CMP_Rm_Rn_2
           or opcode = CMP_Rn_I     or opcode = SUB_Rd_I
           or opcode = SUB_Rd_Rn_I  or opcode = SUB_Rd_Rn_Rm
        then
          math_buff :=
            std_logic_vector(signed(a_se) - signed(b_se));
          did_subtract := '1';

        end if;

        -- lower 32 bits are our result
        result_tmp  := math_buff(data_width-1 downto 0);

        -- set flags
        if    opcode /= SUB_I       and opcode /= ADD_Rd_IPC
          and opcode /= ADD_Rd_ISP  and opcode /= ADD_Rd_Rm
          and opcode /= MOV_Rd_Rm
        then

          -- zero
          if result_tmp = zero
          then
            z_l <= '1';
          else
            z_l <= '0';
          end if;

          -- carry
          if math_buff(data_width*2-1 downto data_width) /= zero
          then
            c_l <= '1';
          else
            c_l <= '0';
          end if;

          -- negative, highest bit in the data width is the sign bit
          if result_tmp(data_width-1) = '1'
          then
            n_l <= '1';
          else
            n_l <= '0';
          end if;

          -- overflow
          if (
                  did_subtract = '0'
              and a(data_width-1) = '0'
              and b(data_width-1) = '0'
              and result_tmp(data_width-1) /= '0'
              )
            or (
                  did_subtract = '0'
              and a(data_width-1) = '1'
              and b(data_width-1) = '1'
              and result_tmp(data_width-1) /= '1'
              )
            or (
                  did_subtract = '1'
              and a(data_width-1) = '0'
              and b(data_width-1) = '1'
              and result_tmp(data_width-1) /= '0'
              )
            or (
                  did_subtract = '1'
              and a(data_width-1) = '1'
              and b(data_width-1) = '0'
              and result_tmp(data_width-1) /= '1'
              )
          then
            v_l <= '1';
          else
            v_l <= '0';
          end if;

        end if;

      -- shifts and bitwise logic
      elsif opcode = AND_Rd_Rm    or opcode = ASR_Rd_Rm_I
         or opcode = ASR_Rd_Rs    or opcode = BIC_Rn_Rm
         or opcode = EOR_Rd_Rm    or opcode = LSL_Rd_Rm_I
         or opcode = LSL_Rd_Rs    or opcode = LSR_Rd_Rm_I
         or opcode = LSR_Rd_Rs    or opcode = ORR_Rd_Rm
         or opcode = ROR_Rd_Rs    or opcode = TST_Rm_Rn
      then

        -- arithmetic shift right
        if    opcode = ASR_Rd_Rm_I  or opcode = ASR_Rd_Rs
        then
          result_tmp :=
            std_logic_vector(shift_right(signed(a), to_integer(unsigned(b))));

        -- logical shift left
        elsif opcode = LSL_Rd_Rm_I  or opcode = LSL_Rd_Rs
        then
          result_tmp :=
            std_logic_vector(shift_left(unsigned(a), to_integer(unsigned(b))));

        -- logical shift right
        elsif opcode = LSR_Rd_Rm_I  or opcode = LSR_Rd_Rs
        then
          result_tmp :=
            std_logic_vector(shift_right(unsigned(a), to_integer(unsigned(b))));

        -- bitwise and
        elsif opcode = AND_Rd_Rm    or opcode = TST_Rm_Rn
        then
          result_tmp := a and b;

        -- bit clear
        elsif opcode = BIC_Rn_Rm
        then
          result_tmp := a and not b;

        -- bitwise exclusive or
        elsif opcode = EOR_Rd_Rm
        then
          result_tmp := a xor b;

        -- bitwise or
        elsif opcode = ORR_Rd_Rm
        then
          result_tmp := a or b;

        -- logical rotate right
        else
          result_tmp :=
            std_logic_vector (
                rotate_right(unsigned(a), to_integer(unsigned(b)))
                );

        end if;

        -- set flags

        -- zero
        if result_tmp = zero
        then
          z_l <= '1';
        else
          z_l <= '0';
        end if;

        -- carry

        -- carry for left shift
        if    opcode = LSL_Rd_Rm_I  or opcode = LSL_Rd_Rs
        then
          if   b = zero
            or   a (
                data_width-1 downto data_width-to_integer(unsigned(b))
                )
               = zero (
                data_width-1 downto data_width-to_integer(unsigned(b))
                )
          then
            c_l <= '0';
          else
            c_l <= '1';
          end if;

        -- carry for logical and
        elsif opcode = AND_Rd_Rm
        then
          c_l <= a(data_width-1) and b(data_width-1);

        -- carry for bit clear
        elsif opcode = BIC_Rn_Rm
        then
          c_l <= a(data_width-1) and not b(data_width-1);

        -- carry for exclusive or
        elsif opcode = EOR_Rd_Rm
        then
          c_l <= a(data_width-1) xor b(data_width-1);

        -- carry for rotate right
        elsif opcode = ROR_Rd_Rs
        then
          if b = zero
          then
            c_l <= '0';
          else
            c_l <= a(to_integer(unsigned(b))-1);
          end if;

        -- carry for right shift
        elsif opcode /= TST_Rm_Rn
        then
          if   b = zero
            or   a(to_integer(unsigned(b))-1 downto 0)
               = zero(to_integer(unsigned(b))-1 downto 0)
          then
            c_l <= '0';
          else
            c_l <= '1';
          end if;
        end if;

        -- negative
        n_l <= result_tmp(data_width-1);

        -- overflow
        if    opcode = AND_Rd_Rm
        then
          v_l <= a(data_width-1) and b(data_width-1);
        elsif opcode = EOR_Rd_Rm
        then
          v_l <= a(data_width-1) xor b(data_width-1);
        end if;

      -- pass through
      else
        result_tmp := a;

      end if IF_ARITH_OR_LOG_SHIFT;

      -- copy our result on out
      result <= result_tmp;

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
