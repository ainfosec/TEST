-- Filename:          reg_file.vhd
-- Version:           1.00.a
-- Description:       provides a user-specified number of data storage registers
--                    which have I/O with both software and hardware
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Thu, Dec 12, 2013 09:57:11
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
use simple_processor_wrapper_v1_00_a.reg_file_constants.all;

---
-- An n-register file for use with the ARM Thumb(R) instruction set.
-- Note that the external peripheral can only address 32 registers directly.
-- Note that ARM Thumb(R) can only address 8 registers directly, and 16
--  registers indirectly.
-- In compliance with ARM standards, there must be at least
--  (16 user registers + 20 swap-in registers + 1 status register ...
--  ... + 7 saved status registers + 16 stack registers)
--  = 60 registers. This peripheral uses an extra register to communicate
--  with the external peripheral, for a total of 61 registers.
--  It is recommended that you use 317 registers, giving you 1024 bytes of
--  stack memory.
-- This device is designed to be readable from an external device. Instructions
--  can also be written from that device.
---
entity reg_file
is
  generic
  (
    -- number of registers addressable by external peripheral
    SOFT_ADDRESS_WIDTH   : integer            := 32
  );
  port
  (
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

    -- a flag used by the PUSH and POP instructions
    flag_lr_pc           : in    std_logic;

    -- flags used by ADD_Rd_Rm, CMP_Rm_Rn_2, MOV_Rd, RM, BX, and BLX
    flags_h              : in    std_logic_vector(1 downto 0);

    -- input data from ALU
    alu_out              : in    std_logic_vector(DATA_WIDTH-1 downto 0);

    -- write enables for alu output
    wr_en                : in    std_logic_vector(WR_EN_SIZEOF-1 downto 0);

    -- The Negative flag from the ALU
    flag_n               : in    std_logic;

    -- The Zero flag from the ALU
    flag_z               : in    std_logic;

    -- The Carry flag from the ALU
    flag_c               : in    std_logic;

    -- The oVerflow flag from the ALU
    flag_v               : in    std_logic;

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
    soft_data_in         : in    std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Data to be relayed back to external peripheral
    soft_data_out        : out   std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Sends incoming instructions to the decoder
    instruction          : out   std_logic_vector(15 downto 0);

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

    -- acknowledge read address has been decoded for state machine
    decode_r_ack         : out   std_logic;

    -- acknowledge write address has been decoded for state machine
    decode_w_ack         : out   std_logic;

    -- the contents of the accessible registers
    sp_plus_off          : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    pc_plus_off          : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    lr_plus_off          : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rn_plus_off          : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rm_plus_rn           : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rm_hh_reg            : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rm_hl_reg            : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rn_hh_reg            : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rn_hl_reg            : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rm_reg               : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rn_reg               : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rs_reg               : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    rd_reg               : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    sp_reg               : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    pc_reg               : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    lr_reg               : out   std_logic_vector(DATA_WIDTH-1 downto 0);

    -- pointer address values
    sp_val               : out   integer;
    pc_val               : out   integer;
    lr_val               : out   integer;

    -- lets us know when to trigger an event
    state                : in    integer range STATE_MIN to STATE_MAX
  );

end entity reg_file;

architecture IMP of reg_file
is

  -- decoded stack pointer
  signal sp            : integer range MEM_BOUND to NUM_REGS-1;

  -- decoded program counter
  signal pc            : integer range MEM_BOUND to NUM_REGS-1;

  -- decoded link register
  signal lr            : integer range MEM_BOUND to NUM_REGS-1;

  -- index safe register pointers for X + (Y << 2)
  signal sp_plus_off_i : integer range MEM_BOUND to NUM_REGS-1;
  signal pc_plus_off_i : integer range MEM_BOUND to NUM_REGS-1;
  signal lr_plus_off_i : integer range MEM_BOUND to NUM_REGS-1;
  signal rn_plus_off_i : integer range MEM_BOUND to NUM_REGS-1;

  -- index safe register pointers for X + Y
  signal rm_plus_rn_i  : integer range MEM_BOUND to NUM_REGS-1;

  -- index safe register pointers for X + (H ? 8  : 0)
  signal flags_hh_u    : unsigned(3 downto 0);
  signal flags_hl_u    : unsigned(3 downto 0);
  signal rm_hh_reg_i   : integer range 0 to REG_BOUND;
  signal rm_hl_reg_i   : integer range 0 to REG_BOUND;
  signal rn_hh_reg_i   : integer range 0 to REG_BOUND;
  signal rn_hl_reg_i   : integer range 0 to REG_BOUND;
  signal rd_h_reg_i    : integer range 0 to REG_BOUND;

  -- index safe register pointers for X
  signal rm_reg_i      : integer range 0 to REG_BOUND;
  signal rn_reg_i      : integer range 0 to REG_BOUND;
  signal rs_reg_i      : integer range 0 to REG_BOUND;
  signal rd_reg_i      : integer range 0 to REG_BOUND;

  -- decoded I/O addresses
  signal r_addr_i      : integer range SOFT_ADDRESS_WIDTH-1 downto 0;
  signal w_addr_i      : integer range SOFT_ADDRESS_WIDTH-1 downto 0;

  -- I/O is ready
  signal soft_r_en     : std_logic;
  signal soft_w_en     : std_logic;

  -- channel enables for memory
  signal mem_rd_en     : std_logic_vector(15 downto 0);
  signal mem_wr_en     : std_logic_vector(15 downto 0);

  -- channel acks for memory
  signal mem_rd_ack    : std_logic;
  signal mem_wr_ack    : std_logic;

  -- channel addresses for memory
  signal mem_rd_addr   : mem_address;
  signal mem_wr_addr   : mem_address;

  -- I/O channels for memory
  signal mem_data_in   : mem_channel;
  signal mem_data_out  : mem_channel;

  -- data_in synchronized with soft_addr_w
  signal soft_data_s   : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  ---
  -- Set memory indices so they stay inside memory bounds
  --
  -- Note: integer ranges don't really provide any guarantees except
  --       minimum bit width, so handle this manually
  ---
    flags_hh_u(3) <= '1' when flags_h(1) = '1' else '0';
    flags_hh_u(2 downto 0) <= (others => '0');
    flags_hl_u(3) <= '1' when flags_h(0) = '1' else '0';
    flags_hl_u(2 downto 0) <= (others => '0');
    rm_reg_i      <= to_integer(unsigned(Rm));
    rn_reg_i      <= to_integer(unsigned(Rn));
    rs_reg_i      <= to_integer(unsigned(Rs));
    rd_reg_i      <= to_integer(unsigned(Rd));
    rn_plus_off_i <= rn_reg_i + to_integer(unsigned(Imm_5) & "00");
    rm_plus_rn_i  <= rm_reg_i + rn_reg_i;
    rm_hh_reg_i   <= rm_reg_i + to_integer(flags_hh_u);
    rm_hl_reg_i   <= rm_reg_i + to_integer(flags_hl_u);
    rn_hh_reg_i   <= rn_reg_i + to_integer(flags_hh_u);
    rn_hl_reg_i   <= rn_reg_i + to_integer(flags_hl_u);
    rd_h_reg_i    <= rd_reg_i + to_integer(flags_hh_u);
    GRAB_SP_INDEX : process ( sp, Imm_8 )
    is
      variable i : integer;
    begin
      i := sp + to_integer(unsigned(Imm_8) & "00");
      if i < NUM_REGS
      then
        sp_plus_off_i <= i;
      else
        sp_plus_off_i <= NUM_REGS-1;
      end if;
    end process GRAB_SP_INDEX;
    GRAB_PC_INDEX : process ( pc, Imm_8 )
    is
      variable i : integer;
    begin
      i := pc + to_integer(unsigned(Imm_8) & "00");
      if i < NUM_REGS
      then
        pc_plus_off_i <= i;
      else
        pc_plus_off_i <= NUM_REGS-1;
      end if;
    end process GRAB_PC_INDEX;
    GRAB_LR_INDEX : process ( lr, Imm_8 )
    is
      variable i : integer;
    begin
      i := lr + to_integer(unsigned(Imm_8) & "00");
      if i < NUM_REGS
      then
        lr_plus_off_i <= i;
      else
        lr_plus_off_i <= NUM_REGS-1;
      end if;
    end process GRAB_LR_INDEX;

  ---
  -- Set up the memory I/O channels. 16 words are read and written
  --  at a time.
  ---
    -- This address gets overwritten by external and instruction reads
    --mem_rd_addr(MEMIO_SPPLUSOFF)  <= sp_plus_off_i;

    -- All others never change
    mem_rd_addr(MEMIO_PCPLUSOFF)  <= pc_plus_off_i;
    mem_rd_addr(MEMIO_LRPLUSOFF)  <= lr_plus_off_i;
    mem_rd_addr(MEMIO_RNPLUSOFF)  <= rn_plus_off_i;
    mem_rd_addr(MEMIO_RMPLUSRN)   <= rm_plus_rn_i;
    mem_rd_addr(MEMIO_RMHHREG)    <= rm_hh_reg_i;
    mem_rd_addr(MEMIO_RMHLREG)    <= rm_hl_reg_i;
    mem_rd_addr(MEMIO_RNHHREG)    <= rn_hh_reg_i;
    mem_rd_addr(MEMIO_RNHLREG)    <= rn_hl_reg_i;
    mem_rd_addr(MEMIO_RMREG)      <= rm_reg_i;
    mem_rd_addr(MEMIO_RNREG)      <= rn_reg_i;
    mem_rd_addr(MEMIO_RSREG)      <= rs_reg_i;
    mem_rd_addr(MEMIO_RDREG)      <= rd_reg_i;
    mem_rd_addr(MEMIO_SPREG)      <= sp;
    mem_rd_addr(MEMIO_PCREG)      <= pc;
--  mem_rd_addr(MEMIO_LRREG)      <= lr; never say never ;)

    -- This address gets overwritten by external and ALU writes
    --  mem_wr_addr(MEMIO_SPPLUSOFF)  <= sp_plus_off_i;

    -- All others never change
    mem_wr_addr(MEMIO_PCPLUSOFF)  <= pc_plus_off_i;
    mem_wr_addr(MEMIO_LRPLUSOFF)  <= lr_plus_off_i;
    mem_wr_addr(MEMIO_RNPLUSOFF)  <= rn_plus_off_i;
    mem_wr_addr(MEMIO_RMPLUSRN)   <= rm_plus_rn_i;
    mem_wr_addr(MEMIO_RDHREG)     <= rd_h_reg_i;
    mem_wr_addr(MEMIO_RMHLREG)    <= rm_hl_reg_i;
    mem_wr_addr(MEMIO_RNHHREG)    <= rn_hh_reg_i;
    mem_wr_addr(MEMIO_RNHLREG)    <= rn_hl_reg_i;
    mem_wr_addr(MEMIO_RMREG)      <= rm_reg_i;
    mem_wr_addr(MEMIO_RNREG)      <= rn_reg_i;
    mem_wr_addr(MEMIO_RSREG)      <= rs_reg_i;
    mem_wr_addr(MEMIO_RDREG)      <= rd_reg_i;
    mem_wr_addr(MEMIO_SPREG)      <= sp;
    mem_wr_addr(MEMIO_PCREG)      <= pc;
--  mem_wr_addr(MEMIO_LRREG)      <= lr;

  ---
  -- Registers plus data memory, and pointers (stack, program, link)
  ---
  ALL_MEM : entity simple_processor_wrapper_v1_00_a.memory
    port map
    (
      rd_en    => mem_rd_en,
      wr_en    => mem_wr_en,
      rd_ack   => mem_rd_ack,
      wr_ack   => mem_wr_ack,
      wr_addr  => mem_wr_addr,
      rd_addr  => mem_rd_addr,
      data_in  => mem_data_in,
      data_out => mem_data_out,
      sp       => sp,
      pc       => pc,
      lr       => lr
    );

  ---
  -- Decode external peripheral I/O addresses
  ---
  DECODE_I_O_ADDRESS : process ( state )
  is
    variable found_r : std_logic;
    variable found_w : std_logic;
  begin

    -- init search
    found_r := '0';
    found_w := '0';

    -- search for leftmost read/write ID
    if   state = DO_DECODE_SOFT_READ or state = DO_DECODE_SOFT_WRITE
      or state = DO_CLEAR_FLAGS
    then

      -- the leftmost bit controls the index to write to,
      --   number of positions from leftmost starting with 0 is the index or ID
      for i in SOFT_ADDRESS_WIDTH-1 downto 0
      loop

        -- decode read ID
        if soft_addr_r(SOFT_ADDRESS_WIDTH-1 - i) = '1' and found_r = '0'
        then
          r_addr_i <= i;
          found_r := '1';
        end if;

        -- decode write ID
        if soft_addr_w(SOFT_ADDRESS_WIDTH-1 - i) = '1' and found_w = '0'
        then
          w_addr_i <= i;
          found_w := '1';
        end if;

      end loop;

      -- note if there are any reads or writes to perform,
      --   synchronize write-in data with address
      if    state = DO_DECODE_SOFT_READ
      then
        soft_r_en <= found_r;
        decode_r_ack <= '1';
        decode_w_ack <= '0';
      elsif state = DO_DECODE_SOFT_WRITE
      then
        soft_w_en <= found_w;
        soft_data_s <= soft_data_in;
        decode_r_ack <= '0';
        decode_w_ack <= '1';
      elsif state = DO_CLEAR_FLAGS
      then
        decode_r_ack <= '0';
        decode_w_ack <= '0';
      end if;

    end if;

  end process DECODE_I_O_ADDRESS;

  ---
  -- Event handler for memory I/O
  ---
  HANDLE_MEMORY_I_O_EVENT : process ( mem_rd_ack, mem_wr_ack, state )
  is
    variable check_send       : std_logic;
  begin

    -- take load/store action during the appropriate state
    case state is

      -- send a new instruction in to the decoder
      when DO_SEND_INST =>
--        instruction   <= mem_data_out(0)(15 downto 0);
        instruction   <= mem_data_out(15)(15 downto 0);
        send_inst_ack <= mem_rd_ack;

      -- read from a register to external peripheral
      when DO_SOFT_READ =>
        soft_data_out <= mem_data_out(0);
        soft_read_ack <= mem_rd_ack;

      -- grab all possible ALU inputs
      when DO_ALU_INPUT =>

        -- send retrieved memory values out
        sp_plus_off <= mem_data_out(MEMIO_SPPLUSOFF);
        pc_plus_off <= mem_data_out(MEMIO_PCPLUSOFF);
        lr_plus_off <= mem_data_out(MEMIO_LRPLUSOFF);
        rn_plus_off <= mem_data_out(MEMIO_RNPLUSOFF);
        rm_plus_rn  <= mem_data_out(MEMIO_RMPLUSRN);
        rm_hh_reg   <= mem_data_out(MEMIO_RMHHREG);
        rm_hl_reg   <= mem_data_out(MEMIO_RMHLREG);
        rn_hh_reg   <= mem_data_out(MEMIO_RNHHREG);
        rn_hl_reg   <= mem_data_out(MEMIO_RNHLREG);
        rm_reg      <= mem_data_out(MEMIO_RMREG);
        rn_reg      <= mem_data_out(MEMIO_RNREG);
        rs_reg      <= mem_data_out(MEMIO_RSREG);
        rd_reg      <= mem_data_out(MEMIO_RDREG);
        sp_reg      <= mem_data_out(MEMIO_SPREG);
        pc_reg      <= mem_data_out(MEMIO_PCREG);
        lr_reg      <= mem_data_out(MEMIO_LRREG);

        -- send pointers
        sp_val      <= sp;
        pc_val      <= pc;
        lr_val      <= lr;

        -- let the state machine know load work is done
        load_ack <= mem_rd_ack;

      -- initialize component
      when DO_REG_FILE_RESET =>
        reg_file_reset_ack <= mem_wr_ack;

      -- write ALU output to registers (possibly no writes, so always ack)
      when DO_LOAD_STORE =>
        store_ack <= '1';

      -- write data from external peripheral to a register
      when DO_SOFT_WRITE =>
        soft_write_ack <= mem_wr_ack;

      -- reset state machine outputs
      when DO_CLEAR_FLAGS =>
        send_inst_ack      <= '0';
        load_ack           <= '0';
        soft_read_ack      <= '0';
        reg_file_reset_ack <= '0';
        store_ack          <= '0';
        soft_write_ack     <= '0';

      -- no reads or writes in any other states
      when others =>
        null;

    end case;

  end process HANDLE_MEMORY_I_O_EVENT;

  ---
  -- Read registers and memory to the ALU and external peripheral
  ---
  DO_READS : process ( state )
  is
  begin

    -- send a new instruction in to the decoder
    if state = DO_SEND_INST
    then
--      mem_rd_addr(0) <= INSTR_REG;
--      mem_rd_en(0)   <= '1';
--      mem_rd_en(15 downto 1) <= "000000000000000";
      mem_rd_addr(15) <= INSTR_REG;
      mem_rd_en(15)   <= '1';
      mem_rd_en(14 downto 0) <= "000000000000000";
    end if;

    --  read from a register to external peripheral
    if state = DO_SOFT_READ
    then
      mem_rd_addr(0) <= r_addr_i;
      mem_rd_en(0)   <= soft_r_en;
      mem_rd_en(15 downto 1) <= "000000000000000";
    end if;

    -- grab all possible ALU inputs
    if state = DO_ALU_INPUT
    then

      -- we need to map out the 1st address to allow SOFT_READ_EVENT
      --  to overwrite it; all others are mapped out already
      mem_rd_addr(MEMIO_SPPLUSOFF) <= sp_plus_off_i;
      mem_rd_addr(MEMIO_LRREG)     <= lr;

      -- set enable bits
      mem_rd_en <= "1111111111111111";
    end if;

    -- keep read enables clear when we aren't reading
    if    state /= DO_ALU_INPUT and state /= DO_SOFT_READ
      and state /= DO_SEND_INST
    then
      mem_rd_en <= "0000000000000000";
    end if;

  end process DO_READS;

  ---
  -- Modify registers and memory using the ALU and the external peripheral
  ---
  DO_WRITES: process ( state )
  is
  begin

    -- initialize component
    STATE_SELECT : if state = DO_REG_FILE_RESET
    then
      mem_wr_en <= "1111111111111111";

    -- handle data received from the ALU
    elsif state = DO_LOAD_STORE
    then

      -- rely on the write enable to sort out where this actually goes
      for i in 15 downto 0
      loop
        mem_data_in(i) <= alu_out;
      end loop;

      -- we need to map out the 1st address to allow SOFT_WRITE_EVENT
      --  to overwrite it; all others are mapped out already
      mem_wr_addr(MEMIO_SPPLUSOFF)  <= sp_plus_off_i;
      mem_wr_addr(MEMIO_LRREG)      <= lr;

      -- set enable bits
      mem_wr_en(MEMIO_SPPLUSOFF)  <= wr_en(WR_EN_SP_PLUS_OFF);
      mem_wr_en(MEMIO_PCPLUSOFF)  <= '0';
      mem_wr_en(MEMIO_LRPLUSOFF)  <= '0';
      mem_wr_en(MEMIO_RNPLUSOFF)  <= wr_en(WR_EN_RN_PLUS_OFF);
      mem_wr_en(MEMIO_RMPLUSRN)   <= wr_en(WR_EN_RM_PLUS_RN);
      mem_wr_en(MEMIO_RDHREG)     <= wr_en(WR_EN_RD_H_REG);
      mem_wr_en(MEMIO_RMHLREG)    <= '0';
      mem_wr_en(MEMIO_RNHHREG)    <= '0';
      mem_wr_en(MEMIO_RNHLREG)    <= '0';
      mem_wr_en(MEMIO_RMREG)      <= '0';
      mem_wr_en(MEMIO_RNREG)      <= '0';
      mem_wr_en(MEMIO_RSREG)      <= '0';
      mem_wr_en(MEMIO_RDREG)      <= wr_en(WR_EN_RD);
      mem_wr_en(MEMIO_SPREG)      <= wr_en(WR_EN_SP);
      mem_wr_en(MEMIO_PCREG)      <= wr_en(WR_EN_PC);
      mem_wr_en(MEMIO_LRREG)      <= wr_en(WR_EN_LR);

    -- write data from external peripheral to a register
    elsif state = DO_SOFT_WRITE
    then
      mem_wr_addr(15) <= w_addr_i;
      mem_data_in(15) <= soft_data_s;
      mem_wr_en(14 downto 0) <= "000000000000000";
      mem_wr_en(15)          <= soft_w_en;

    -- keep write enable bits clear when we aren't writing
    else
      mem_wr_en      <= "0000000000000000";

    end if STATE_SELECT;

  end process DO_WRITES;

end IMP;
