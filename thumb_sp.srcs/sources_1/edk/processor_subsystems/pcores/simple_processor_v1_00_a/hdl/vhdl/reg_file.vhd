-- Filename:          reg_file.vhd
-- Version:           1.00.a
-- Description:       provides a user-specified number of data storage registers
--                    which have I/O with both software and hardware
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Tue, Nov 19, 2013 19:54:53
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
use simple_processor_v1_00_a.states.all;

---
-- An n-register file which can be controlled by a simple_processor.decoder
--  device.
-- Note that the Xilinx EDK(R) software can only address 32 registers directly.
-- Note that ARM Thumb(R) can only address 8 registers directly, and 16
--  registers indirectly.
-- In compliance with ARM standards, there must be at least
-- (30 data registers + 7 special purpose registers + 16 stack registers)
--  = 53 registers.
-- This device is designed to be readable from Xilinx EDK(R). Instructions
--  can also be written from that platform.
---
entity reg_file
is
  generic
  (
    -- number of registers in this file (at least 53)
    num_regs             : integer            := 53;

    -- width of the address sent in by Xilinx EDK(R)
    soft_address_width   : integer            := 32;

    -- bit width of the data in this file (typically 32 or 64)
    data_width           : integer            := 32
  );
  port
  (
    -- Sends incoming instructions to the decoder
    instruction          : out   std_logic_vector(15 downto 0);

    -- One of 64 ARM Thumb(R) opcodes, specified in simple_processor.opcodes
    opcode               : in    integer;

    -- hint provided for this opcode's functionality
    op_type              : in    integer;

    -- One of four registers available to a single ARM instruction
    Rm                   : in    std_logic_vector(2 downto 0);

    -- One of four registers available to a single ARM instruction
    Rn                   : in    std_logic_vector(2 downto 0);

    -- One of four registers available to a single ARM instruction
    Rs                   : in    std_logic_vector(2 downto 0);

    -- One of four registers available to a single ARM instruction
    Rd                   : in    std_logic_vector(2 downto 0);

    -- An immediate value coded into the instruction, for relative load/store
    Imm_3                : in    std_logic_vector(2 downto 0);

    -- An immediate value coded into the instruction, for relative load/store
    Imm_5                : in    std_logic_vector(4 downto 0);

    -- An immediate value coded into the instruction, for relative load/store
    Imm_8                : in    std_logic_vector(7 downto 0);

    -- An immediate value coded into the instruction, for relative load/store
    Imm_11               : in    std_logic_vector(10 downto 0);

    -- convenience values for comparisons
    zero                 : in    std_logic_vector(data_width-1 downto 0);

    -- a flag used by the PUSH and POP instructions
    flag_lr_pc           : in    std_logic;

    -- flags used by ADD_Rd_Rm, CMP_Rm_Rn_2, MOV_Rd, RM, BX, and BLX
    flags_h              : in    std_logic_vector(1 downto 0);

    -- input data from ALU
    alu_out              : in    std_logic_vector(data_width-1 downto 0);

    -- The Negative flag from the ALU
    flag_n               : in    std_logic;

    -- The Zero flag from the ALU
    flag_z               : in    std_logic;

    -- The Carry flag from the ALU
    flag_c               : in    std_logic;

    -- The oVerflow flag from the ALU
    flag_v               : in    std_logic;

    -- First argument to the ALU
    alu_a                : out   std_logic_vector(data_width-1 downto 0);

    -- Second argument to the ALU
    alu_b                : out   std_logic_vector(data_width-1 downto 0);

    -- An address in the format Xilinx EDK(R) uses, for reading
    soft_addr_r          : in    std_logic_vector (
        soft_address_width-1 downto 0
        );

    -- An address in the format Xilinx EDK(R) uses, for writing
    soft_addr_w          : in    std_logic_vector (
        soft_address_width-1 downto 0
        );

    -- Data incoming from Xilinx EDK(R)
    soft_data_i          : in    std_logic_vector(data_width-1 downto 0);

    -- Data to be relayed back to Xilinx EDK(R)
    soft_data_o          : out   std_logic_vector(data_width-1 downto 0);

    -- acknowledge a reset has been performed
    reg_file_reset_ack   : out   std_logic;

    -- acknowledge an instruction has been sent to the decoder
    send_inst_ack        : out std_logic;

    -- acknowledge data has been prepared for the ALU
    load_ack             : out std_logic;

    -- acknowledge alu output has been stored in registers
    store_ack            : out std_logic;

    -- read acknowledge for Xilinx EDK(R)
    soft_read_ack        : out   std_logic;

    -- write acknowledge for Xilinx EDK(R)
    soft_write_ack       : out   std_logic;

    -- lets us know when to trigger an event
    state                : in    integer
  );

end entity reg_file;

architecture IMP of reg_file
is

  -- highest data register
  constant REG_BOUND : integer := 29;

  -- register where NZCV flags are stored
  constant APSR_REG  : integer := 30;

  -- register to store the next instruction in
  constant PC_REG    : integer := 31;

  --
  constant CPSR_REG  : integer := 32;

  --
  constant SPSR1_REG : integer := 33;

  --
  constant SPSR2_REG : integer := 34;

  --
  constant SPSR3_REG : integer := 35;

  --
  constant SPSR4_REG : integer := 36;

  -- lowest memory register
  constant MEM_BOUND : integer := 37;

  -- data and memory registers
  type slv_regs_type is array(num_regs-1 downto 0)
    of std_logic_vector(data_width-1 downto 0);
  signal slv_regs    : slv_regs_type;

  -- stack pointer
  signal sp          : integer range MEM_BOUND to num_regs-16;

  -- stores the last sent in instruction (to prevent bounce)
  signal last_inst   : std_logic_vector(15 downto 0);

begin

  -- perform all operations that retrive values from the registers and memory
  DO_UPDATE : process ( state )
  is
    variable a_l    : std_logic_vector(data_width-1 downto 0);
    variable b_l    : std_logic_vector(data_width-1 downto 0);
    variable temp_i : integer;
  begin

    -- load values to be sent to the ALU
    LOAD_EVENT : if state = DO_LOAD
    then

      -- update alu outputs and perform load/store operations
      case op_type
      is

        -- special purpose functions
        when ARITH_IM8         =>

          -- sub: SP = SP - (#OFF << 2)
          if opcode = SUB_I
          then
            a_l := std_logic_vector(to_unsigned(sp, data_width));
            b_l(data_width-1 downto 8) := (others => '0');
            b_l(7 downto 0)            := Imm_8;

          -- BKPT, B_COND, or SWI
          else
            a_l(data_width-1 downto 8) := (others => '0');
            a_l(7 downto 0)            := Imm_8;
            b_l                        := (others => '0');

          end if;

        -- branch
        when ARITH_IM11        =>
          a_l(data_width-1 downto 11) := (others => '0');
          a_l(10 downto 0)            := Imm_11;
          b_l                         := (others => '0');

        -- Rd := Rd <op> #
        when ARITH_DST_IM8    =>

          -- add/sub #
          if    opcode = ADD_Rd_I   or opcode = SUB_Rd_I
          then
            a_l := slv_regs(to_integer(unsigned(Rd)));

          -- add/sub [SP + (#OFF >> 2)]
          elsif opcode = ADD_Rd_IPC or opcode = ADD_Rd_ISP
          then
            temp_i := sp + to_integer(shift_right(signed(Imm_8), 2));
            if temp_i > data_width-1
            then
              temp_i := data_width-1;
            end if;
            a_l := slv_regs(temp_i);

          -- mov
          else
            a_l := (others => '0');

          end if;

          -- 2nd arg is the same for all 3 cases
          b_l(data_width-1 downto 8) := (others => '0');
          b_l(7 downto 0)            := Imm_8;

        -- Rd := Rd <op> Rm
        when ARITH_RGM_DST     =>
          a_l := slv_regs(to_integer(unsigned(Rd)));
          b_l := slv_regs(to_integer(unsigned(Rm)));

        -- Rd := Rd <op> Rs
        when ARITH_SRC_DST     =>
          a_l := slv_regs(to_integer(unsigned(Rd)));
          b_l := slv_regs(to_integer(unsigned(Rs)));

        -- Rd := Rm <op> #
        when ARITH_IM5_RGM_DST =>
          a_l := slv_regs(to_integer(unsigned(Rm)));
          b_l(data_width-1 downto 5) := (others => '0');
          b_l(4 downto 0)            := Imm_5;

        -- Rd := Rn <op> #
        when ARITH_IM3_RGN_DST =>
          a_l := slv_regs(to_integer(unsigned(Rn)));
          b_l(data_width-1 downto 3) := (others => '0');
          b_l(2 downto 0)            := Imm_3;

        -- Rd := Rm <op> Rn
        when ARITH_RGM_RGN_DST =>
          a_l := slv_regs(to_integer(unsigned(Rm)));
          b_l := slv_regs(to_integer(unsigned(Rn)));

        -- depending on H flags, one of the following:
        -- Rd := Rd <op> Rm
        -- [Rd + 8] := [Rd + 8] <op> Rm
        -- Rd := Rd <op> [Rm + 8]
        -- [Rd + 8] := [Rd + 8] <op> [Rm + 8]
        when ARITH_HFLAGS      =>
          case flags_h
          is
            when "01"   =>
              a_l := slv_regs(to_integer(unsigned(Rd)));
              b_l := slv_regs(to_integer(unsigned(Rm)) + 8);
            when "10"   =>
              a_l := slv_regs(to_integer(unsigned(Rd)) + 8);
              b_l := slv_regs(to_integer(unsigned(Rm)));
            when "11" =>
              a_l := slv_regs(to_integer(unsigned(Rd)) + 8);
              b_l := slv_regs(to_integer(unsigned(Rm)) + 8);
            when others   =>
              a_l := slv_regs(to_integer(unsigned(Rd)));
              b_l := slv_regs(to_integer(unsigned(Rm)));
          end case;

        -- Rm <op> #
        when TEST_RGN_IM8     =>
          a_l := slv_regs(to_integer(unsigned(Rn)));
          b_l(data_width-1 downto 8) := (others => '0');
          b_l(7 downto 0)            := Imm_8;

        -- Rm <op> Rn
        when TEST_RGN_RGM      =>
          a_l := slv_regs(to_integer(unsigned(Rm)));
          b_l := slv_regs(to_integer(unsigned(Rn)));

        -- Depending on H flags, one of the following:
        -- Rm <op> Rn
        -- [Rm + 8] <op> Rn
        -- Rm <op> [Rn + 8]
        -- [Rm + 8] <op> [Rn + 8]
        when TEST_HFLAGS       =>
          case flags_h
          is
            when "01"   =>
              a_l := slv_regs(to_integer(unsigned(Rd)));
              b_l := slv_regs(to_integer(unsigned(Rm)) + 8);
            when "10"   =>
              a_l := slv_regs(to_integer(unsigned(Rd)) + 8);
              b_l := slv_regs(to_integer(unsigned(Rm)));
            when "11" =>
              a_l := slv_regs(to_integer(unsigned(Rd)) + 8);
              b_l := slv_regs(to_integer(unsigned(Rm)) + 8);
            when others   =>
              a_l := slv_regs(to_integer(unsigned(Rd)));
              b_l := slv_regs(to_integer(unsigned(Rm)));
          end case;

        -- Rd = [SP + (#OFF << 2)]
        when LOAD_DST_IM8      =>
          temp_i := sp + to_integer(shift_right(signed(Imm_8), 2));
          if temp_i > data_width-1
          then
            temp_i := data_width-1;
          end if;
          a_l := slv_regs(temp_i);
          b_l := (others => '0');

        -- Rd = [Rn + (#OFF << 2)]
        when LOAD_IM5_RGN_DST  =>

          -- byte
          if    opcode = LDRB_Rd_Rn_I
          then
            a_l(data_width-1 downto 8) := (others => '0');
            a_l(7 downto 0) := slv_regs (
                to_integer(unsigned(Rn))
              + to_integer(shift_right(signed(Imm_5), 2))
              ) (7 downto 0);

          -- half word
          elsif opcode = LDRH_Rd_Rn_I
          then
            a_l(data_width-1 downto 16) := (others => '0');
            a_l(15 downto 0) := slv_regs (
                to_integer(unsigned(Rn))
              + to_integer(shift_right(signed(Imm_5), 2))
              ) (15 downto 0);

          -- whole word
          else
            a_l := slv_regs (
                to_integer(unsigned(Rn))
              + to_integer(shift_right(signed(Imm_5), 2))
              );

          end if;
          b_l := (others => '0');

        -- RD = [Rn + Rm]
        when LOAD_RGM_RGN_DST  =>

          -- byte
          if    opcode = LDRB_Rd_Rn_Rm
          then
            a_l(data_width-1 downto 8) := (others => '0');
            a_l(7 downto 0)            := slv_regs (
                to_integer(unsigned(Rn))
              + to_integer(unsigned(Rm))
              ) (7 downto 0);

          -- half word
          elsif opcode = LDRH_Rd_Rn_Rm
          then
            a_l(data_width-1 downto 16) := (others => '0');
            a_l(15 downto 0)            := slv_regs (
                to_integer(unsigned(Rn))
              + to_integer(unsigned(Rm))
              ) (15 downto 0);

          -- byte, signed
          elsif opcode = LDRSB_Rd_Rn_Rm
          then
            temp_i := to_integer(signed(Rn)) + to_integer(signed(Rm));
            if temp_i < MEM_BOUND
            then
              temp_i := MEM_BOUND;
            elsif temp_i > num_regs-1
            then
              temp_i := num_regs-1;
            end if;
            a_l(data_width-1 downto 8) := (others => '0');
            a_l(7 downto 0)            := slv_regs(temp_i)(7 downto 0);

          -- half word, signed
          elsif opcode = LDRSH_Rd_Rn_Rm
          then
            temp_i := to_integer(signed(Rn)) + to_integer(signed(Rm));
            if temp_i < MEM_BOUND
            then
              temp_i := MEM_BOUND;
            elsif temp_i > num_regs-1
            then
              temp_i := num_regs-1;
            end if;
            a_l(data_width-1 downto 16) := (others => '0');
            a_l(15 downto 0)            := slv_regs(temp_i)(15 downto 0);

          -- whole word
          else
            a_l := slv_regs (
                to_integer(unsigned(Rn))
              + to_integer(unsigned(Rm))
              );

          end if;
          b_l := (others => '0');

        -- not coded for data load
        when others            =>
          a_l := (others => '0');
          b_l := (others => '0');

      end case;

      -- send alu outputs out
      alu_a   <= a_l;
      alu_b   <= b_l;

      -- let the state machine know load work is done
      load_ack <= '1';

    end if LOAD_EVENT;

    -- read from a register to Xilinx(R) EDK software
    SOFT_READ_EVENT : if state = DO_SOFT_READ
    then

      -- decode the read ID
      temp_i := 0;
      for i in soft_address_width-1 downto 0
      loop
        if soft_addr_r(soft_address_width-1 - i) = '1' and temp_i = 0
        then

          -- read the decoded register out to Xilinx EDK(R)
          soft_data_o <= slv_regs(i);
          temp_i := 1;

        end if;
      end loop;

      -- let the state machine know software read work is done
      soft_read_ack <= '1';

    end if SOFT_READ_EVENT;

    -- initialize component
    RESET_EVENT : if state = DO_REG_FILE_RESET
    then

      -- clear all registers
      for i in num_regs-1 downto PC_REG+1
      loop
--        slv_regs(i) <= (others => '0');
        slv_regs(i) <= std_logic_vector(to_unsigned(i, 32));
      end loop;
      for i in PC_REG-1 downto 0 loop
--        slv_regs(i) <= (others => '0');
        slv_regs(i) <= std_logic_vector(to_unsigned(i, 32));
      end loop;

      -- the default instruction is "UNUSED_I8"
      slv_regs(PC_REG) <= "00000000000000001101111011111111";
      last_inst        <=                 "1101111011111111";

      -- reset stack pointer
      sp <= num_regs - 16;

      -- let the state machine know reset work is done
      reg_file_reset_ack <= '1';

    end if RESET_EVENT;

    -- send a new instruction in to the decoder
    SEND_INST_EVENT : if state = DO_SEND_INST
    then

      -- send instruction
      if slv_regs(PC_REG)(15 downto 0) /= last_inst
      then
        instruction <= slv_regs(PC_REG)(15 downto 0);
      end if;

      -- copy this instruction to the save buffer to prevent bounce
      last_inst <= slv_regs(PC_REG)(15 downto 0);

      -- let the state machine know the instruction was sent
      send_inst_ack <= '1';

    end if SEND_INST_EVENT;

    -- store the results of an ALU operation
    STORE_EVENT : if state = DO_STORE
    then

      -- update alu outputs and perform load/store operations
      case op_type
      is

        -- special purpose functions
        when ARITH_IM8         =>

          -- sub: SP = SP - (#OFF << 2)
          if opcode = SUB_I
          then
            temp_i := to_integer(unsigned(alu_out));
            if temp_i > data_width-16
            then
              temp_i := data_width-16;
            end if;
            sp <= temp_i;

          -- BKPT, B_COND, or SWI otherwise, nothing stored

          end if;

        -- simple arithmetic
        when ARITH_IM11        =>
          slv_regs(to_integer(unsigned(Rd))) <= alu_out;
        when ARITH_DST_IM8    =>
          slv_regs(to_integer(unsigned(Rd))) <= alu_out;
        when ARITH_RGM_DST     =>
          slv_regs(to_integer(unsigned(Rd))) <= alu_out;
        when ARITH_SRC_DST     =>
          slv_regs(to_integer(unsigned(Rd))) <= alu_out;
        when ARITH_IM5_RGM_DST =>
          slv_regs(to_integer(unsigned(Rd))) <= alu_out;
        when ARITH_IM3_RGN_DST =>
          slv_regs(to_integer(unsigned(Rd))) <= alu_out;
        when ARITH_RGM_RGN_DST =>
          slv_regs(to_integer(unsigned(Rd))) <= alu_out;

        -- math using registers 9-15
        when ARITH_HFLAGS      =>
          case flags_h(1)
          is
            when '1'   =>
              slv_regs(to_integer(unsigned(Rd)) + 8) <= alu_out;
            when others   =>
              slv_regs(to_integer(unsigned(Rd))) <= alu_out;
          end case;

        -- memory -> registers
        when LOAD_DST_IM8      =>
          slv_regs(to_integer(unsigned(Rd))) <= alu_out;
        when LOAD_IM5_RGN_DST  =>
          slv_regs(to_integer(unsigned(Rd))) <= alu_out;
        when LOAD_RGM_RGN_DST  =>
          slv_regs(to_integer(unsigned(Rd))) <= alu_out;

        -- registers -> memory
        when STORE_DST_IM8     =>
          slv_regs(to_integer(unsigned(Rd)) + MEM_BOUND) <= alu_out;
        when STORE_IM5_RGN_DST =>
          slv_regs(to_integer(unsigned(Rd)) + MEM_BOUND) <= alu_out;
        when STORE_RGM_RGN_DST =>
          slv_regs(to_integer(unsigned(Rd)) + MEM_BOUND) <= alu_out;

        -- Imm_8 is a bit mask for the 8 addressable data registers
        --
        -- For each ith hit Rh:
        -- [SP + Rn + (i - 1)] := Rh
        --
        -- Example:
        --
        -- Reg[0 to 7] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08}
        -- Imm_8 = b11011010
        -- Reg[(SP+0) to (SP+4)] = {0x02, 0x04, 0x05, 0x07, 0x08}
        when LOAD_REGLIST      =>
          temp_i := 0;
          for i in 7 downto 0
          loop
            if Imm_8(i) = '1'
            then
              slv_regs(i) <= slv_regs(sp + to_integer(unsigned(Rn)) + temp_i);
              temp_i := temp_i + 1;
            end if;
          end loop;

        -- Imm_8 is a bit mask for the 8 addressable data registers
        --
        -- For each ith hit Rh:
        -- Rh := [SP + Rn + (i - 1)]
        --
        -- Example:
        --
        -- Reg[(SP+0) to (SP+3)] = {0x01, 0x02, 0x03, 0x04}
        -- Reg[(SP+4) to (SP+7)] = {0x05, 0x06, 0x07, 0x08}
        -- Reg[0 to 7] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
        -- Imm_8 = b11011010
        -- Reg[0 to 7] = {0x00, 0x01, 0x00, 0x02, 0x03, 0x00, 0x04, 0x05}
        when STORE_REGLIST     =>
          temp_i := 0;
          for i in 7 downto 0
          loop
            if Imm_8(i) = '1'
            then
              slv_regs(sp + to_integer(unsigned(Rn)) + temp_i) <= slv_regs(i);
              temp_i := temp_i + 1;
            end if;
          end loop;

        -- push values onto the stack or pull values off the stack
        -- uses a register list similar to (LD|ST)MIA
        when PUSH_POP          =>

          -- loop through bit mask
          temp_i := 0;
          for i in 7 downto 0
          loop
            if Imm_8(i) = '1'
            then

              -- pop
              if opcode = POP_RL_PC
              then
                slv_regs(i) <= slv_regs(sp + temp_i);
                temp_i := temp_i + 1;

              -- push
              else
                slv_regs(sp + temp_i) <= slv_regs(i);
                temp_i := temp_i + 1;

              end if;
            end if;
          end loop;

        -- not coded for data storage
        when others =>
          temp_i := 0;

      end case;

      -- update flags
      slv_regs(APSR_REG)(data_width-1 downto 4) <= (others => '0');
      slv_regs(APSR_REG)(3) <= flag_n;
      slv_regs(APSR_REG)(2) <= flag_z;
      slv_regs(APSR_REG)(1) <= flag_c;
      slv_regs(APSR_REG)(0) <= flag_v;

      -- let the state machine know store work is done
      store_ack <= '1';

    end if STORE_EVENT;

    -- write data from Xilinx EDK(R) software to a register
    SOFT_WRITE_EVENT : if state = DO_SOFT_WRITE
    then

      -- write values in from software
      if soft_addr_w /= zero
      then

        -- decode the write ID
        temp_i := 0;
        for i in soft_address_width-1 downto 0
        loop
          if    soft_addr_w(soft_address_width-1 - i) = '1'
            and temp_i = 0
            and (REG_BOUND >= i or i = PC_REG or i >= MEM_BOUND)
          then

            -- write data from Xilinx EDK(R) to the decoded register
            slv_regs(i) <= soft_data_i;
            temp_i := 1;

          end if;
        end loop;
      end if;

      -- let the state machine know write work is done
      soft_write_ack <= '1';

    end if SOFT_WRITE_EVENT;

    -- reset state machine outputs
    CLEAR_FLAGS_EVENT : if state = DO_CLEAR_FLAGS
    then
      reg_file_reset_ack <= '0';
      load_ack           <= '0';
      soft_read_ack      <= '0';
      send_inst_ack      <= '0';
      store_ack          <= '0';
      soft_write_ack     <= '0';
    end if;

  end process DO_UPDATE;

end IMP;
