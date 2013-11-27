-- Filename:          reg_file.vhd
-- Version:           1.00.a
-- Description:       provides a user-specified number of data storage registers
--                    which have I/O with both software and hardware
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Tue, Nov 26, 2013 14:08:13
-- VHDL Standard:     VHDL'93
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
-- An n-register file which can be controlled by a
--  simple_processor_wrapper.decoder device.
-- Note that the external peripheral can only address 32 registers directly.
-- Note that ARM Thumb(R) can only address 8 registers directly, and 16
--  registers indirectly.
-- In compliance with ARM standards, there must be at least
-- (30 data registers + 7 special purpose registers + 16 stack registers)
--  = 53 registers.
-- This device is designed to be readable from an external device. Instructions
--  can also be written from that device.
---
entity reg_file
is
  generic
  (
    -- number of registers in this file (at least 53)
    NUM_REGS             : integer            := 53;

    -- number of registers addressable by external peripheral
    SOFT_ADDRESS_WIDTH   : integer            := 32;

    -- bit width of the data in this file (typically 32 or 64)
    DATA_WIDTH           : integer            := 32
  );
  port
  (
    -- Sends incoming instructions to the decoder
    instruction          : out   std_logic_vector(15 downto 0);

    -- One of 64 ARM Thumb(R) opcodes, specified in
    -- simple_processor_wrapper.opcodes
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
    zero                 : in    std_logic_vector(DATA_WIDTH-1 downto 0);

    -- a flag used by the PUSH and POP instructions
    flag_lr_pc           : in    std_logic;

    -- flags used by ADD_Rd_Rm, CMP_Rm_Rn_2, MOV_Rd, RM, BX, and BLX
    flags_h              : in    std_logic_vector(1 downto 0);

    -- input data from ALU
    alu_out              : in    std_logic_vector(DATA_WIDTH-1 downto 0);

    -- The Negative flag from the ALU
    flag_n               : in    std_logic;

    -- The Zero flag from the ALU
    flag_z               : in    std_logic;

    -- The Carry flag from the ALU
    flag_c               : in    std_logic;

    -- The oVerflow flag from the ALU
    flag_v               : in    std_logic;

    -- First argument to the ALU
    alu_a                : out   std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Second argument to the ALU
    alu_b                : out   std_logic_vector(DATA_WIDTH-1 downto 0);

    -- An address in decoded integer (e.g. 2^0 = 1, 2^32 = 31, 2^n = n-1) form,
    --  for reading
    soft_addr_r          : in    std_logic_vector (
        SOFT_ADDRESS_WIDTH-1 downto 0
        );

    -- An address in decoded integer (e.g. 2^0 = 1, 2^31 = 32, 2^n = n+1) form,
    --  for writing
    soft_addr_w          : in    std_logic_vector (
        SOFT_ADDRESS_WIDTH-1 downto 0
        );

    -- Data incoming from external peripheral
    soft_data_i          : in    std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Data to be relayed back to external peripheral
    soft_data_o          : out   std_logic_vector(DATA_WIDTH-1 downto 0);

    -- acknowledge a reset has been performed
    reg_file_reset_ack   : out   std_logic;

    -- acknowledge an instruction has been sent to the decoder
    send_inst_ack        : out std_logic;

    -- acknowledge data has been prepared for the ALU
    load_ack             : out std_logic;

    -- acknowledge alu output has been stored in registers
    store_ack            : out std_logic;

    -- acknowledge any soft reads are done for state machine
    soft_read_ack        : out   std_logic;

    -- acknowledge any soft writes are done for state machine
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

  -- current program state register
  constant CPSR_REG  : integer := 32;

  -- saved program state registers
  constant SPSR1_REG : integer := 33;
  constant SPSR2_REG : integer := 34;
  constant SPSR3_REG : integer := 35;
  constant SPSR4_REG : integer := 36;
  constant MEM_BOUND : integer := 37;

  -- data and memory registers
  type slv_regs_type is array(NUM_REGS-1 downto 0)
    of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal slv_regs    : slv_regs_type;

  -- stack pointer
  signal sp          : integer range MEM_BOUND to NUM_REGS-1;

  -- stores the last sent in instruction (to prevent bounce)
  signal last_inst   : std_logic_vector(15 downto 0);

begin

  -- perform all operations that retrive values from the registers and memory
  DO_UPDATE : process ( state )
  is
    variable a_l    : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable b_l    : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable mem_i  : integer range MEM_BOUND to DATA_WIDTH-1;
    variable mask_i : integer range 0 to 7;
    variable temp   : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable found  : std_logic;
  begin

    -- load values to be sent to the ALU
    ALU_INPUT_EVENT : if state = DO_ALU_INPUT
    then

      -- arithmetic with an 8 bit immediate value,
      --  mostly special purpose functions
      if    op_type = ARITH_IM8         or op_type = ARITH_DST_IM8
         or op_type = TEST_RGN_IM8
      then

        -- sub: SP = SP - (#OFF << 2)
        if opcode = SUB_I
        then
          a_l := std_logic_vector(to_unsigned(sp, DATA_WIDTH));

        -- BKPT, B_COND, SWI, or MOV
        elsif op_type = ARITH_IM8 or opcode = MOV_Rd_I
        then
          a_l := (others => '0');

        -- add/sub #
        elsif opcode = ADD_Rd_I   or opcode = SUB_Rd_I
        then
          a_l := slv_regs(to_integer(unsigned(Rd)));

        -- add/sub [SP + (#OFF >> 2)], so -32 to +31
        elsif opcode = ADD_Rd_IPC or opcode = ADD_Rd_ISP
        then
          mem_i := sp + to_integer(signed(Imm_8(7 downto 2)));
          a_l := slv_regs(mem_i);

        -- Rn <op> #
        else
          a_l := slv_regs(to_integer(unsigned(Rn)));

        end if;

        -- 2nd argument is the 8 bit immediate value
        b_l(DATA_WIDTH-1 downto 8) := (others => '0');
        b_l(7 downto 0) := Imm_8;

      -- arithmetic with an 11, 5, or 3 bit immediate value
      elsif op_type = ARITH_IM11
      then
        a_l := (others => '0');
        b_l(DATA_WIDTH-1 downto 11) := (others => '0');
        b_l(10 downto 0) := Imm_11;
      elsif op_type = ARITH_IM5_RGM_DST
      then
        a_l := slv_regs(to_integer(unsigned(Rm)));
        b_l(DATA_WIDTH-1 downto 5) := (others => '0');
        b_l(4 downto 0) := Imm_5;
      elsif op_type = ARITH_IM3_RGN_DST
      then
        a_l := slv_regs(to_integer(unsigned(Rn)));
        b_l(DATA_WIDTH-1 downto 3) := (others => '0');
        b_l(2 downto 0) := Imm_3;


      -- arithmetic operating on two registers
      elsif op_type = ARITH_RGM_DST     or op_type = ARITH_SRC_DST
         or op_type = ARITH_HFLAGS      or op_type = TEST_HFLAGS
         or op_type = ARITH_RGM_RGN_DST or op_type = TEST_RGN_RGM
      then

        -- ALU Argument 1, flags_h(1) means load from regs 8-15
        if    op_type  = TEST_HFLAGS  and flags_h(1) = '1'
        then
          a_l := slv_regs(to_integer(unsigned(Rm)) + 8);
        elsif op_type  = TEST_HFLAGS   or op_type = ARITH_RGM_RGN_DST
           or op_type = TEST_RGN_RGM
        then
          a_l := slv_regs(to_integer(unsigned(Rm)));
        elsif op_type /= ARITH_HFLAGS or flags_h(1) /= '1'
        then
          a_l := slv_regs(to_integer(unsigned(Rd)));
        else
          a_l := slv_regs(to_integer(unsigned(Rd)) + 8);
        end if;

        -- ALU argument 2, flags_h(0) means load from regs 8-15
        if    op_type = TEST_HFLAGS   and flags_h(0) = '1'
        then
          b_l := slv_regs(to_integer(unsigned(Rn)) + 8);
        elsif op_type = TEST_HFLAGS    or op_type = ARITH_RGM_RGN_DST
           or op_type = TEST_RGN_RGM
        then
          b_l := slv_regs(to_integer(unsigned(Rn)));
        elsif op_type = ARITH_RGM_DST
           or (op_type = ARITH_HFLAGS and flags_h(0) /= '1')
        then
          b_l := slv_regs(to_integer(unsigned(Rm)));
        elsif op_type = ARITH_HFLAGS
        then
          b_l := slv_regs(to_integer(unsigned(Rm)) + 8);
        else
          b_l := slv_regs(to_integer(unsigned(Rs)));
        end if;

      end if;

      -- send alu outputs out
      alu_a   <= a_l;
      alu_b   <= b_l;

      -- let the state machine know load work is done
      load_ack <= '1';

    end if ALU_INPUT_EVENT;

    -- read from a register to external peripheral
    SOFT_READ_EVENT : if state = DO_SOFT_READ
    then

      -- decode the read ID
      found := '0';
      for i in SOFT_ADDRESS_WIDTH-1 downto 0
      loop
        if soft_addr_r(SOFT_ADDRESS_WIDTH-1 - i) = '1' and found = '0'
        then

          -- read the decoded register out to external peripheral
          soft_data_o <= slv_regs(i);
          found := '1';

        end if;
      end loop;

      -- let the state machine know software read work is done
      soft_read_ack <= '1';

    end if SOFT_READ_EVENT;

    -- initialize component
    RESET_EVENT : if state = DO_REG_FILE_RESET
    then

      -- clear all registers
      for i in NUM_REGS-1 downto PC_REG+1
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
      sp <= NUM_REGS - 16;

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
    LOAD_STORE_EVENT : if state = DO_LOAD_STORE
    then

      -- SP = SP - (#OFF << 2)
      LOAD_STORE_SWITCH_OP_TYPE : if opcode = SUB_I
      then
        sp <= to_integer(unsigned(alu_out));

      -- simple arithmetic
      elsif op_type = ARITH_IM11        or op_type = ARITH_DST_IM8
         or op_type = ARITH_RGM_DST     or op_type = ARITH_SRC_DST
         or op_type = ARITH_IM5_RGM_DST or op_type = ARITH_IM3_RGN_DST
         or op_type = ARITH_RGM_RGN_DST
         or (op_type = ARITH_HFLAGS and flags_h(1) /= '1')
      then
        slv_regs(to_integer(unsigned(Rd))) <= alu_out;

      -- math using registers 9-15
      elsif op_type = ARITH_HFLAGS
      then
        slv_regs(to_integer(unsigned(Rd)) + 8) <= alu_out;

      -- Rd = [(PC|SP|Rn) + (#OFF << 2)] or vice-versa
      -- Rd = [Rn + Rm] or vice-versa
      elsif op_type = LOAD_DST_IM8     or op_type = LOAD_IM5_RGN_DST
         or op_type = STORE_DST_IM8    or op_type = STORE_IM5_RGN_DST
         or op_type = LOAD_RGM_RGN_DST or op_type = STORE_RGM_RGN_DST
      then

        -- Rd = [PC + (#OFF << 2)]
        if    opcode  = LDR_Rd_IPC
        then
          mem_i := PC_REG + to_integer(signed(Imm_8(7 downto 2)));

        -- Rd = [SP + (#OFF << 2)] or vice-versa
        elsif opcode  = LDR_Rd_ISP       or opcode = STR_Rd_I
        then
          mem_i := sp + to_integer(signed(Imm_8(7 downto 2)));

        -- Rd = [Rn + (#OFF << 2)] or vice-versa
        elsif opcode  = LDR_Rd_Rn_I      or opcode = LDRB_Rd_Rn_I
           or opcode  = LDRH_Rd_Rn_I     or opcode = STR_Rd_Rn_I
           or opcode  = STRB_Rd_Rn_I     or opcode = STRH_Rd_Rn_I
           or opcode  = LDRSB_Rd_Rn_Rm   or opcode = LDRSH_Rd_Rn_Rm
        then
          mem_i := to_integer(unsigned(Rn))
                 + to_integer(signed(Imm_5(4 downto 2)));

        -- Rd = [Rn + Rm] or vice-versa
        elsif op_type = LOAD_RGM_RGN_DST or op_type = STORE_RGM_RGN_DST
        then
          mem_i := to_integer(unsigned(Rn)) + to_integer(unsigned(Rm));

        end if;

        -- load/store using the immediate coded address,
        --  b means byte, h means half word, s means signed
        if    opcode  = LDR_Rd_Rn_I  or op_type = LOAD_DST_IM8
        then
          slv_regs(to_integer(unsigned(Rd))) <=
            slv_regs(mem_i);
        elsif opcode  = LDRB_Rd_Rn_I or opcode = LDRB_Rd_Rn_Rm
        then
          slv_regs(to_integer(unsigned(Rd)))(7 downto 0) <=
            slv_regs(mem_i)(7 downto 0);
        elsif opcode  = LDRH_Rd_Rn_I or opcode = LDRH_Rd_Rn_Rm
        then
          slv_regs(to_integer(unsigned(Rd)))(15 downto 0) <=
            slv_regs(mem_i)(15 downto 0);
        elsif opcode  = LDRSB_Rd_Rn_Rm
        then
          slv_regs(to_integer(unsigned(Rd)))(6 downto 0) <=
            slv_regs(mem_i)(6 downto 0);
          slv_regs(to_integer(unsigned(Rd)))(7) <=
            slv_regs(mem_i)(DATA_WIDTH-1);
        elsif opcode  = LDRSH_Rd_Rn_Rm
        then
          slv_regs(to_integer(unsigned(Rd)))(14 downto 0) <=
            slv_regs(mem_i)(14 downto 0);
          slv_regs(to_integer(unsigned(Rd)))(15) <=
            slv_regs(mem_i)(DATA_WIDTH-1);
        elsif opcode  = STR_Rd_Rn_I  or op_type = STORE_DST_IM8
           or opcode  = STR_Rd_Rn_Rm
        then
          slv_regs(mem_i) <=
            slv_regs(to_integer(unsigned(Rd)));
        elsif opcode  = STRB_Rd_Rn_I or opcode = STRB_Rd_Rn_Rm
        then
          slv_regs(mem_i)(7 downto 0) <=
            slv_regs(to_integer(unsigned(Rd)))(7 downto 0);
        elsif opcode  = STRH_Rd_Rn_I or opcode = STRH_Rd_Rn_Rm
        then
          slv_regs(mem_i)(15 downto 0) <=
            slv_regs(to_integer(unsigned(Rd)))(15 downto 0);
        end if;

      -- load/store a register list, Imm_8 is a bit mask for the 1st 8 regs
      elsif opcode  = STMIA_RN_RL  or opcode = LDMIA_RN_RL
         or opcode  = PUSH_RL_LR   or opcode = POP_RL_PC
      then

        -- loop over bit mask until a value is found
        mask_i := 0;
        for i in 7 downto 0
        loop
          if Imm_8(i) = '1'
          then

            -- grab the index to load/store from
            if    op_type = LOAD_REGLIST or op_type = STORE_REGLIST
            then
              mem_i := sp + to_integer(unsigned(Rn)) + mask_i;
            elsif op_type = PUSH_POP
            then
              mem_i := sp + mask_i;
            else
              mem_i := sp;
            end if;

            -- load
            if    opcode = LDMIA_RN_RL or opcode = POP_RL_PC
            then
              slv_regs(i) <= slv_regs(mem_i);

            -- store
            elsif opcode = STMIA_RN_RL or opcode = PUSH_RL_LR
            then
              slv_regs(mem_i) <= slv_regs(i);

            end if;

        -- increment the number of found values and keep going
            mask_i := mask_i + 1;
          end if;
        end loop;

      end if LOAD_STORE_SWITCH_OP_TYPE;

      -- update flags
      slv_regs(APSR_REG)(DATA_WIDTH-1 downto 4) <= (others => '0');
      slv_regs(APSR_REG)(3) <= flag_n;
      slv_regs(APSR_REG)(2) <= flag_z;
      slv_regs(APSR_REG)(1) <= flag_c;
      slv_regs(APSR_REG)(0) <= flag_v;

      -- let the state machine know store work is done
      store_ack <= '1';

    end if LOAD_STORE_EVENT;

    -- write data from external peripheral to a register
    SOFT_WRITE_EVENT : if state = DO_SOFT_WRITE
    then

      -- write values in from software
      if soft_addr_w /= zero
      then

        -- decode the write ID
        found := '0';
        for i in SOFT_ADDRESS_WIDTH-1 downto 0
        loop
          if    soft_addr_w(SOFT_ADDRESS_WIDTH-1 - i) = '1'
            and found = '0'
            and (REG_BOUND >= i or i = PC_REG or i >= MEM_BOUND)
          then

            -- write data from external peripheral to the decoded register
            slv_regs(i) <= soft_data_i;
            found := '1';

          end if;
        end loop;

        soft_write_ack <= found;

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
    end if CLEAR_FLAGS_EVENT;

  end process DO_UPDATE;

end IMP;
