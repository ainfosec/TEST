-- Filename:          reg_file.vhd
-- Version:           1.00.a
-- Description:       provides both registers and data memory compatible with
--                    the ARM(R) instruction set
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Fri, Dec 20, 2013 00:00:44
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
use simple_processor_v1_00_a.reg_file_constants.all;

---
-- Provides both registers and data memory compatible with the ARM(R)
--  instruction set
---
entity reg_file
is
  port
  (
    -- One of four registers available to a single ARM instruction
    Rm                   : in    std_logic_vector(2 downto 0);
    Rn                   : in    std_logic_vector(2 downto 0);
    Rs                   : in    std_logic_vector(2 downto 0);
    Rd                   : in    std_logic_vector(2 downto 0);

    -- An immediate value coded into the instruction
    Imm_3                : in    std_logic_vector(2 downto 0);
    Imm_5                : in    std_logic_vector(4 downto 0);
    Imm_8                : in    std_logic_vector(7 downto 0);
    Imm_11               : in    std_logic_vector(10 downto 0);

    -- a flag used by the PUSH and POP instructions
    flag_lr_pc           : in    std_logic;

    -- flags used by ADD_Rd_Rm, CMP_Rm_Rn_2, MOV_Rd, RM, BX, and BLX
    flags_h              : in    std_logic_vector(1 downto 0);

    -- input data from ALU
    alu_out              : in    std_logic_vector(DATA_WIDTH-1 downto 0);

    -- write enables for alu output
    alu_wr_en            : in    std_logic_vector(WR_EN_SIZEOF-1 downto 0);

    -- The negative, zero, carry, and overflow flags from the ALU
    flag_n               : in    std_logic;
    flag_z               : in    std_logic;
    flag_c               : in    std_logic;
    flag_v               : in    std_logic;

    -- state machine ack signals
    reg_file_reset_ack   : out   std_logic;
    send_inst_ack        : out std_logic;
    load_ack             : out std_logic;
    store_ack            : out std_logic;
    decode_r_ack         : out   std_logic;
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

    -- a software generated ARM Thumb(R) instruction
    instruction          : out   std_logic_vector(15 downto 0);

    -- lets us know when to trigger an event
    state                : in    integer range STATE_MIN to STATE_MAX
  );

end entity reg_file;

architecture IMP of reg_file
is

  -- encoded stack pointer
  signal sp            : integer range MEM_BOUND to NUM_REGS-1;

  -- encoded program counter
  signal pc            : integer range MEM_BOUND to NUM_REGS-1;

  -- encoded link register
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

  -- I/O channels for memory
  signal mem_enables   : std_logic_vector(MEMIO_N_CHANNELS-1 downto 0);
  signal mem_addresses : std_logic_vector (
      MEMIO_N_CHANNELS*DATA_WIDTH-1 downto 0
      );
  signal mem_data_in   : std_logic_vector (
      MEMIO_N_CHANNELS*DATA_WIDTH-1 downto 0
      );
  signal mem_data_out  : std_logic_vector (
      MEMIO_N_CHANNELS*DATA_WIDTH-1 downto 0
      );
  signal mem_rd_ack    : std_logic;
  signal mem_wr_ack    : std_logic;

begin

  ---
  -- Set memory indices so they stay inside memory bounds
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
  -- Set up the memory I/O channels. 18 words are read and written
  --  at a time.
  mem_addresses (
      (MEMIO_SPPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_SPPLUSOFF*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(sp_plus_off_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_PCPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_PCPLUSOFF*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(pc_plus_off_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_LRPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_LRPLUSOFF*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(lr_plus_off_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RNPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_RNPLUSOFF*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rn_plus_off_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RMPLUSRN+1)*DATA_WIDTH-1  downto MEMIO_RMPLUSRN*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rm_plus_rn_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RDHREG+1)*DATA_WIDTH-1    downto MEMIO_RDHREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rd_h_reg_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RMHHREG+1)*DATA_WIDTH-1   downto MEMIO_RMHHREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rm_hh_reg_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RMHLREG+1)*DATA_WIDTH-1   downto MEMIO_RMHLREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rm_hl_reg_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RNHHREG+1)*DATA_WIDTH-1   downto MEMIO_RNHHREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rn_hh_reg_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RNHLREG+1)*DATA_WIDTH-1   downto MEMIO_RNHLREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rn_hl_reg_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RMREG+1)*DATA_WIDTH-1     downto MEMIO_RMREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rm_reg_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RNREG+1)*DATA_WIDTH-1     downto MEMIO_RNREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rn_reg_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RSREG+1)*DATA_WIDTH-1     downto MEMIO_RSREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rs_reg_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_RDREG+1)*DATA_WIDTH-1     downto MEMIO_RDREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(rd_reg_i, DATA_WIDTH));
  mem_addresses (
      (MEMIO_SPREG+1)*DATA_WIDTH-1     downto MEMIO_SPREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(sp, DATA_WIDTH));
  mem_addresses (
      (MEMIO_PCREG+1)*DATA_WIDTH-1     downto MEMIO_PCREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(pc, DATA_WIDTH));
  mem_addresses (
      (MEMIO_LRREG+1)*DATA_WIDTH-1     downto MEMIO_LRREG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(lr, DATA_WIDTH));
  mem_addresses (
      (MEMIO_INSTR_REG+1)*DATA_WIDTH-1 downto MEMIO_INSTR_REG*DATA_WIDTH
      ) <= std_logic_vector(to_unsigned(INSTR_REG, DATA_WIDTH));

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
        instruction   <= mem_data_out (
            (MEMIO_INSTR_REG+1)*DATA_WIDTH-1 downto MEMIO_INSTR_REG*DATA_WIDTH
            ) (15 downto 0);
        send_inst_ack <= mem_rd_ack;

      -- grab all possible ALU inputs
      when DO_ALU_INPUT =>

        -- send retrieved memory values out
        sp_plus_off <= mem_data_out (
            (MEMIO_SPPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_SPPLUSOFF*DATA_WIDTH
            );
        pc_plus_off <= mem_data_out (
            (MEMIO_PCPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_PCPLUSOFF*DATA_WIDTH
            );
        lr_plus_off <= mem_data_out (
            (MEMIO_LRPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_LRPLUSOFF*DATA_WIDTH
            );
        rn_plus_off <= mem_data_out (
            (MEMIO_RNPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_RNPLUSOFF*DATA_WIDTH
            );
        rm_plus_rn  <= mem_data_out (
            (MEMIO_RMPLUSRN+1)*DATA_WIDTH-1 downto MEMIO_RMPLUSRN*DATA_WIDTH
            );
        rm_hh_reg   <= mem_data_out (
            (MEMIO_RMHHREG+1)*DATA_WIDTH-1 downto MEMIO_RMHHREG*DATA_WIDTH
            );
        rm_hl_reg   <= mem_data_out (
            (MEMIO_RMHLREG+1)*DATA_WIDTH-1 downto MEMIO_RMHLREG*DATA_WIDTH
            );
        rn_hh_reg   <= mem_data_out (
            (MEMIO_RNHHREG+1)*DATA_WIDTH-1 downto MEMIO_RNHHREG*DATA_WIDTH
            );
        rn_hl_reg   <= mem_data_out (
            (MEMIO_RNHLREG+1)*DATA_WIDTH-1 downto MEMIO_RNHLREG*DATA_WIDTH
            );
        rm_reg      <= mem_data_out (
            (MEMIO_RMREG+1)*DATA_WIDTH-1 downto MEMIO_RMREG*DATA_WIDTH
            );
        rn_reg      <= mem_data_out (
            (MEMIO_RNREG+1)*DATA_WIDTH-1 downto MEMIO_RNREG*DATA_WIDTH
            );
        rs_reg      <= mem_data_out (
            (MEMIO_RSREG+1)*DATA_WIDTH-1 downto MEMIO_RSREG*DATA_WIDTH
            );
        rd_reg      <= mem_data_out (
            (MEMIO_RDREG+1)*DATA_WIDTH-1 downto MEMIO_RDREG*DATA_WIDTH
            );
        sp_reg      <= mem_data_out (
            (MEMIO_SPREG+1)*DATA_WIDTH-1 downto MEMIO_SPREG*DATA_WIDTH
            );
        pc_reg      <= mem_data_out (
            (MEMIO_PCREG+1)*DATA_WIDTH-1 downto MEMIO_PCREG*DATA_WIDTH
            );
        lr_reg      <= mem_data_out (
            (MEMIO_LRREG+1)*DATA_WIDTH-1 downto MEMIO_LRREG*DATA_WIDTH
            );
 
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

      -- reset state machine outputs
      when DO_CLEAR_FLAGS =>
        send_inst_ack      <= '0';
        load_ack           <= '0';
        reg_file_reset_ack <= '0';
        store_ack          <= '0';

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
    if    state = DO_SEND_INST
    then
      mem_addresses (
          (MEMIO_INSTR_REG+1)*DATA_WIDTH-1 downto MEMIO_INSTR_REG*DATA_WIDTH
          ) <=
        std_logic_vector(to_unsigned(INSTR_REG, DATA_WIDTH));
      mem_enables <= (MEMIO_INSTR_REG => '1', others => '0');

    -- grab all possible ALU inputs
    elsif state = DO_ALU_INPUT
    then

      -- set enable bits
      mem_enables <= (others => '1');

    -- keep read enables clear when we aren't reading
    else
      mem_enables <= (others => '0');

    end if;

  end process DO_READS;

  ---
  -- Modify registers and memory using the ALU and the external peripheral
  ---
  DO_WRITES: process ( state )
  is
  begin

    -- initialize component
    if state = DO_LOAD_STORE
    then

      -- rely on the write enable to sort out where this actually goes
      for i in 15 downto 0
      loop
        mem_data_in((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH) <= alu_out;
      end loop;

      -- set enable bits
      mem_enables <= (
          MEMIO_SPPLUSOFF => wr_en(WR_EN_SP_PLUS_OFF),
          MEMIO_RNPLUSOFF => wr_en(WR_EN_RN_PLUS_OFF),
          MEMIO_RMPLUSRN) => wr_en(WR_EN_RM_PLUS_RN),
          MEMIO_RDHREG    => wr_en(WR_EN_RD_H_REG),
          MEMIO_RDREG     => wr_en(WR_EN_RD),
          MEMIO_SPREG     => wr_en(WR_EN_SP),
          MEMIO_PCREG     => wr_en(WR_EN_PC),
          MEMIO_LRREG     => wr_en(WR_EN_LR),
          others          => '0'
          );

    -- keep write enable bits clear when we aren't writing
    else
      mem_enables <= (others => '0');

    end if STATE_SELECT;

  end process DO_WRITES;

end IMP;
