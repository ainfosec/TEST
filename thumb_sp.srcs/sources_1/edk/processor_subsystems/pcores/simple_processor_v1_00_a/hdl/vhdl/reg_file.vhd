-- Filename:          reg_file.vhd
-- Version:           1.00.a
-- Description:       provides both registers and data memory compatible with
--                    the ARM(R) instruction set
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Tue, Dec 24, 2013 15:08:23
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
  generic
  (
    -- number of comm channels owned by EDK register file
    NUM_CHANNELS  : integer          := 32
  );
  port
  (
    -- For I/O with block memory
    data_to_mem          : out   std_logic_vector (
        DATA_WIDTH*NUM_CHANNELS-1 downto 0
        );
    data_from_mem        : in    std_logic_vector (
        DATA_WIDTH*NUM_CHANNELS-1 downto 0
        );
    addresses            : out   std_logic_vector (
        DATA_WIDTH*NUM_CHANNELS-1 downto 0
        );
    enables              : out   std_logic_vector(NUM_CHANNELS-1 downto 0);
    data_mode            : out   std_logic;
    mem_rd_ack           : in    std_logic;
    mem_wr_ack           : in    std_logic;

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
    send_inst_ack        : out   std_logic;
    load_ack             : out   std_logic;
    store_ack            : out   std_logic;

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

  -- One of 7 ARM(R) processor modes
  signal mode          : std_logic_vector(4 downto 0);

begin

  ---
  -- Trigger I/O between registers and memory, and the ALU and EDK
  ---
  SEND_TO_MEMORY : process ( state )
  is
    variable flags_hh_u    : std_logic_vector(3 downto 0);
    variable flags_hl_u    : std_logic_vector(3 downto 0);
    variable rm_reg_i      : integer;
    variable rn_reg_i      : integer;
    variable rs_reg_i      : integer;
    variable rd_reg_i      : integer;
    variable rn_plus_off_i : integer;
    variable rm_plus_rn_i  : integer;
    variable rm_hh_reg_i   : integer;
    variable rm_hl_reg_i   : integer;
    variable rn_hh_reg_i   : integer;
    variable rn_hl_reg_i   : integer;
    variable rd_h_reg_i    : integer;
    variable sp_plus_off_i : integer;
    variable pc_plus_off_i : integer;
    variable lr_plus_off_i : integer;
  begin

    -- pre-calculate in-bounds addresses
    if state = DO_ALU_INPUT or state = DO_LOAD_STORE
    then
      flags_hh_u(3) := '1' when flags_h(1) = '1' else '0';
      flags_hh_u(2 downto 0) := (others => '0');
      flags_hl_u(3) := '1' when flags_h(0) = '1' else '0';
      flags_hl_u(2 downto 0) := (others => '0');
      rm_reg_i      := to_integer(unsigned(Rm));
      rn_reg_i      := to_integer(unsigned(Rn));
      rs_reg_i      := to_integer(unsigned(Rs));
      rd_reg_i      := to_integer(unsigned(Rd));
      rn_plus_off_i := to_integer(unsigned(Rn) + (unsigned(Imm_5) & "00"));
      rm_plus_rn_i  := to_integer(unsigned(Rm) + unsigned(Rn));
      rm_hh_reg_i   := to_integer(unsigned(Rm) + unsigned(flags_hh_u));
      rm_hl_reg_i   := to_integer(unsigned(Rm) + unsigned(flags_hl_u));
      rn_hh_reg_i   := to_integer(unsigned(Rn) + unsigned(flags_hh_u));
      rn_hl_reg_i   := to_integer(unsigned(Rn) + unsigned(flags_hl_u));
      rd_h_reg_i    := to_integer(unsigned(Rd) + unsigned(flags_hh_u));
      sp_plus_off_i := sp + to_integer(unsigned(Imm_8) & "00");
      pc_plus_off_i := pc + to_integer(unsigned(Imm_8) & "00");
      lr_plus_off_i := lr + to_integer(unsigned(Imm_8) & "00");
      if sp_plus_off_i >= NUM_REGS
      then
        sp_plus_off_i := NUM_REGS-1;
      end if;
      if pc_plus_off_i >= NUM_REGS
      then
        pc_plus_off_i := NUM_REGS-1;
      end if;
      if lr_plus_off_i < NUM_REGS
      then
        lr_plus_off_i := NUM_REGS-1;
      end if;
    end if;

    -- initialize memory
    if    state = DO_REG_FILE_RESET
    then

      -- write to memory
      data_mode <= '1';

      -- set up addresses
      addresses (
        (MEMIO_INSTR_REG+1)*DATA_WIDTH-1 downto MEMIO_INSTR_REG*DATA_WIDTH
        ) <= std_logic_vector(to_unsigned(INSTR_REG, DATA_WIDTH));
      addresses (
        (MEMIO_USRSS_REG+1)*DATA_WIDTH-1 downto MEMIO_USRSS_REG*DATA_WIDTH
        ) <= std_logic_vector(to_unsigned(USRSS_REG, DATA_WIDTH));
      addresses (
        (MEMIO_FIQSS_REG+1)*DATA_WIDTH-1 downto MEMIO_FIQSS_REG*DATA_WIDTH
        ) <= std_logic_vector(to_unsigned(FIQSS_REG, DATA_WIDTH));
      addresses (
        (MEMIO_IRQSS_REG+1)*DATA_WIDTH-1 downto MEMIO_IRQSS_REG*DATA_WIDTH
        ) <= std_logic_vector(to_unsigned(IRQSS_REG, DATA_WIDTH));
      addresses (
        (MEMIO_SVCSS_REG+1)*DATA_WIDTH-1 downto MEMIO_SVCSS_REG*DATA_WIDTH
        ) <= std_logic_vector(to_unsigned(SVCSS_REG, DATA_WIDTH));
      addresses (
        (MEMIO_MONSS_REG+1)*DATA_WIDTH-1 downto MEMIO_MONSS_REG*DATA_WIDTH
        ) <= std_logic_vector(to_unsigned(MONSS_REG, DATA_WIDTH));
      addresses (
        (MEMIO_UNDSS_REG+1)*DATA_WIDTH-1 downto MEMIO_UNDSS_REG*DATA_WIDTH
        ) <= std_logic_vector(to_unsigned(UNDSS_REG, DATA_WIDTH));
      addresses (
        (MEMIO_ABOSS_REG+1)*DATA_WIDTH-1 downto MEMIO_ABOSS_REG*DATA_WIDTH
        ) <= std_logic_vector(to_unsigned(ABOSS_REG, DATA_WIDTH));

      -- most values should be zeroed
      data_to_mem <= (others => '0');

      -- default instruction is "unused"
      data_to_mem (
          (MEMIO_INSTR_REG+1)*DATA_WIDTH-1 downto MEMIO_INSTR_REG*DATA_WIDTH
          ) <= "00000000000000001101111011111111";

      -- hard-drive the modes in the saved program state registers
      data_to_mem ((USRSS_REG+1)*DATA_WIDTH-1 downto USRSS_REG*DATA_WIDTH)
        (PSR_M_4 downto PSR_M_0) <= PM_USER;
      data_to_mem((FIQSS_REG+1)*DATA_WIDTH-1  downto FIQSS_REG*DATA_WIDTH)
        (PSR_M_4 downto PSR_M_0) <= PM_FIQ;
      data_to_mem((IRQSS_REG+1)*DATA_WIDTH-1  downto IRQSS_REG*DATA_WIDTH)
        (PSR_M_4 downto PSR_M_0) <= PM_IRQ;
      data_to_mem((SVCSS_REG+1)*DATA_WIDTH-1  downto SVCSS_REG*DATA_WIDTH)
        (PSR_M_4 downto PSR_M_0) <= PM_SVC;
      data_to_mem((MONSS_REG+1)*DATA_WIDTH-1  downto MONSS_REG*DATA_WIDTH)
        (PSR_M_4 downto PSR_M_0) <= PM_MONITOR;
      data_to_mem((UNDSS_REG+1)*DATA_WIDTH-1  downto UNDSS_REG*DATA_WIDTH)
        (PSR_M_4 downto PSR_M_0) <= PM_UNDEF;
      data_to_mem((ABOSS_REG+1)*DATA_WIDTH-1  downto ABOSS_REG*DATA_WIDTH)
        (PSR_M_4 downto PSR_M_0) <= PM_ABORT;

      -- every mode uses thumb state
      data_to_mem((USRSS_REG+1)*DATA_WIDTH-1 downto USRSS_REG*DATA_WIDTH)
        (PSR_T) <= '1';
      data_to_mem((FIQSS_REG+1)*DATA_WIDTH-1 downto FIQSS_REG*DATA_WIDTH)
        (PSR_T) <= '1';
      data_to_mem((IRQSS_REG+1)*DATA_WIDTH-1 downto IRQSS_REG*DATA_WIDTH)
        (PSR_T) <= '1';
      data_to_mem((SVCSS_REG+1)*DATA_WIDTH-1 downto SVCSS_REG*DATA_WIDTH)
        (PSR_T) <= '1';
      data_to_mem((MONSS_REG+1)*DATA_WIDTH-1 downto MONSS_REG*DATA_WIDTH)
        (PSR_T) <= '1';
      data_to_mem((UNDSS_REG+1)*DATA_WIDTH-1 downto UNDSS_REG*DATA_WIDTH)
        (PSR_T) <= '1';
      data_to_mem((ABOSS_REG+1)*DATA_WIDTH-1 downto ABOSS_REG*DATA_WIDTH)
        (PSR_T) <= '1';

      -- enable writes on the modified channels
      enables <= (
          MEMIO_INSTR_REG => '1',
          MEMIO_USRSS_REG       => '1',
          MEMIO_FIQSS_REG       => '1',
          MEMIO_IRQSS_REG       => '1',
          MEMIO_SVCSS_REG       => '1',
          MEMIO_MONSS_REG       => '1',
          MEMIO_UNDSS_REG       => '1',
          MEMIO_ABOSS_REG       => '1',
          others          => '0'
          );

      -- default stack pointer is 16 regs below the top of memory
      sp <= NUM_REGS-16;

      -- default link register and program counter is bottom of memory
      lr <= MEM_BOUND;
      pc <= MEM_BOUND;

      -- default mode is user, using thumb
      mode <= PM_USER;

    -- send a new instruction in to the decoder
    elsif state = DO_SEND_INST
    then

      -- reading from memory
      data_mode <= '0';

      -- we just want the instruction, nothing else
      addresses <= (others => '0');
      addresses (
        (MEMIO_INSTR_REG+1)*DATA_WIDTH-1 downto MEMIO_INSTR_REG*DATA_WIDTH
        ) <= std_logic_vector(to_unsigned(INSTR_REG, DATA_WIDTH));
      enables <= (MEMIO_INSTR_REG => '1', others => '0');

    -- grab all possible ALU inputs
    elsif state = DO_ALU_INPUT
    then

      -- reading from memory
      data_mode <= '0';

      -- enable all 16 channels
      enables <= (others => '1');

      -- set up address space
      addresses (
          (MEMIO_SPPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_SPPLUSOFF*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(sp_plus_off_i, DATA_WIDTH));
      addresses (
          (MEMIO_PCPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_PCPLUSOFF*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(pc_plus_off_i, DATA_WIDTH));
      addresses (
          (MEMIO_LRPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_LRPLUSOFF*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(lr_plus_off_i, DATA_WIDTH));
      addresses (
          (MEMIO_RNPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_RNPLUSOFF*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rn_plus_off_i, DATA_WIDTH));
      addresses (
          (MEMIO_RMPLUSRN+1)*DATA_WIDTH-1  downto MEMIO_RMPLUSRN*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rm_plus_rn_i, DATA_WIDTH));
      addresses (
          (MEMIO_RMHHREG+1)*DATA_WIDTH-1   downto MEMIO_RMHHREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rm_hh_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RMHLREG+1)*DATA_WIDTH-1   downto MEMIO_RMHLREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rm_hl_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RNHHREG+1)*DATA_WIDTH-1   downto MEMIO_RNHHREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rn_hh_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RNHLREG+1)*DATA_WIDTH-1   downto MEMIO_RNHLREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rn_hl_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RMREG+1)*DATA_WIDTH-1     downto MEMIO_RMREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rm_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RNREG+1)*DATA_WIDTH-1     downto MEMIO_RNREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rn_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RSREG+1)*DATA_WIDTH-1     downto MEMIO_RSREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rs_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RDREG+1)*DATA_WIDTH-1     downto MEMIO_RDREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rd_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_SPREG+1)*DATA_WIDTH-1     downto MEMIO_SPREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(sp, DATA_WIDTH));
      addresses (
          (MEMIO_PCREG+1)*DATA_WIDTH-1     downto MEMIO_PCREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(pc, DATA_WIDTH));
      addresses (
          (MEMIO_LRREG+1)*DATA_WIDTH-1     downto MEMIO_LRREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(lr, DATA_WIDTH));

    -- initialize component
    elsif state = DO_LOAD_STORE
    then

      -- writing to memory
      data_mode <= '1';

      -- rely on the write enable to sort out where this actually goes
      for i in MEMIO_N_CHANNELS-1 downto 0
      loop
        data_to_mem((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH) <= alu_out;
      end loop;

      -- set up address space
      addresses (
          (MEMIO_SPPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_SPPLUSOFF*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(sp_plus_off_i, DATA_WIDTH));
      addresses (
          (MEMIO_PCPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_PCPLUSOFF*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(pc_plus_off_i, DATA_WIDTH));
      addresses (
          (MEMIO_LRPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_LRPLUSOFF*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(lr_plus_off_i, DATA_WIDTH));
      addresses (
          (MEMIO_RNPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_RNPLUSOFF*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rn_plus_off_i, DATA_WIDTH));
      addresses (
          (MEMIO_RMPLUSRN+1)*DATA_WIDTH-1  downto MEMIO_RMPLUSRN*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rm_plus_rn_i, DATA_WIDTH));
      addresses (
          (MEMIO_RDHREG+1)*DATA_WIDTH-1    downto MEMIO_RDHREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rd_h_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RMHLREG+1)*DATA_WIDTH-1   downto MEMIO_RMHLREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rm_hl_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RNHHREG+1)*DATA_WIDTH-1   downto MEMIO_RNHHREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rn_hh_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RNHLREG+1)*DATA_WIDTH-1   downto MEMIO_RNHLREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rn_hl_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RMREG+1)*DATA_WIDTH-1     downto MEMIO_RMREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rm_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RNREG+1)*DATA_WIDTH-1     downto MEMIO_RNREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rn_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RSREG+1)*DATA_WIDTH-1     downto MEMIO_RSREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rs_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_RDREG+1)*DATA_WIDTH-1     downto MEMIO_RDREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(rd_reg_i, DATA_WIDTH));
      addresses (
          (MEMIO_SPREG+1)*DATA_WIDTH-1     downto MEMIO_SPREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(sp, DATA_WIDTH));
      addresses (
          (MEMIO_PCREG+1)*DATA_WIDTH-1     downto MEMIO_PCREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(pc, DATA_WIDTH));
      addresses (
          (MEMIO_LRREG+1)*DATA_WIDTH-1     downto MEMIO_LRREG*DATA_WIDTH
          ) <= std_logic_vector(to_unsigned(lr, DATA_WIDTH));

      -- set enable bits
      enables <= (
          MEMIO_SPPLUSOFF => alu_wr_en(WR_EN_SP_PLUS_OFF),
          MEMIO_RNPLUSOFF => alu_wr_en(WR_EN_RN_PLUS_OFF),
          MEMIO_RMPLUSRN  => alu_wr_en(WR_EN_RM_PLUS_RN),
          MEMIO_RDHREG    => alu_wr_en(WR_EN_RD_H_REG),
          MEMIO_RDREG     => alu_wr_en(WR_EN_RD),
          MEMIO_SPREG     => alu_wr_en(WR_EN_SP),
          MEMIO_PCREG     => alu_wr_en(WR_EN_PC),
          MEMIO_LRREG     => alu_wr_en(WR_EN_LR),
          others          => '0'
          );

    -- keep bits clear when we aren't reading or writing
    else
      data_to_mem <= (others => '0');
      addresses   <= (others => '0');
      enables <= (others => '0');

    end if STATE_SELECT;

  end process SEND_TO_MEMORY;

  ---
  -- Event handler for memory I/O
  ---
  RECEIVE_FROM_MEMORY : process ( mem_rd_ack, mem_wr_ack, state )
  is
    variable check_send       : std_logic;
  begin

    -- take load/store action during the appropriate state
    case state is

      -- send a new instruction in to the decoder
      when DO_SEND_INST =>
        if mem_rd_ack = '1'
        then
          instruction   <= data_from_mem (
              (MEMIO_INSTR_REG+1)*DATA_WIDTH-1 downto MEMIO_INSTR_REG*DATA_WIDTH
              ) (15 downto 0);
          send_inst_ack <= '1';
        end if;

      -- grab all possible ALU inputs
      when DO_ALU_INPUT =>
        if mem_rd_ack = '1'
        then

          -- send retrieved memory values out
          sp_plus_off <= data_from_mem (
              (MEMIO_SPPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_SPPLUSOFF*DATA_WIDTH
              );
          pc_plus_off <= data_from_mem (
              (MEMIO_PCPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_PCPLUSOFF*DATA_WIDTH
              );
          lr_plus_off <= data_from_mem (
              (MEMIO_LRPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_LRPLUSOFF*DATA_WIDTH
              );
          rn_plus_off <= data_from_mem (
              (MEMIO_RNPLUSOFF+1)*DATA_WIDTH-1 downto MEMIO_RNPLUSOFF*DATA_WIDTH
              );
          rm_plus_rn  <= data_from_mem (
              (MEMIO_RMPLUSRN+1)*DATA_WIDTH-1  downto MEMIO_RMPLUSRN*DATA_WIDTH
              );
          rm_hh_reg   <= data_from_mem (
              (MEMIO_RMHHREG+1)*DATA_WIDTH-1   downto MEMIO_RMHHREG*DATA_WIDTH
              );
          rm_hl_reg   <= data_from_mem (
              (MEMIO_RMHLREG+1)*DATA_WIDTH-1   downto MEMIO_RMHLREG*DATA_WIDTH
              );
          rn_hh_reg   <= data_from_mem (
              (MEMIO_RNHHREG+1)*DATA_WIDTH-1   downto MEMIO_RNHHREG*DATA_WIDTH
              );
          rn_hl_reg   <= data_from_mem (
              (MEMIO_RNHLREG+1)*DATA_WIDTH-1   downto MEMIO_RNHLREG*DATA_WIDTH
              );
          rm_reg      <= data_from_mem (
              (MEMIO_RMREG+1)*DATA_WIDTH-1     downto MEMIO_RMREG*DATA_WIDTH
              );
          rn_reg      <= data_from_mem (
              (MEMIO_RNREG+1)*DATA_WIDTH-1     downto MEMIO_RNREG*DATA_WIDTH
              );
          rs_reg      <= data_from_mem (
              (MEMIO_RSREG+1)*DATA_WIDTH-1     downto MEMIO_RSREG*DATA_WIDTH
              );
          rd_reg      <= data_from_mem (
              (MEMIO_RDREG+1)*DATA_WIDTH-1     downto MEMIO_RDREG*DATA_WIDTH
              );
          sp_reg      <= data_from_mem (
              (MEMIO_SPREG+1)*DATA_WIDTH-1     downto MEMIO_SPREG*DATA_WIDTH
              );
          pc_reg      <= data_from_mem (
              (MEMIO_PCREG+1)*DATA_WIDTH-1     downto MEMIO_PCREG*DATA_WIDTH
              );
          lr_reg      <= data_from_mem (
              (MEMIO_LRREG+1)*DATA_WIDTH-1     downto MEMIO_LRREG*DATA_WIDTH
              );
 
          -- send pointers
          sp_val      <= sp;
          pc_val      <= pc;
          lr_val      <= lr;

          -- let the state machine know load work is done
          load_ack <= '1';

        end if;

      -- initialize component
      when DO_REG_FILE_RESET =>
        reg_file_reset_ack <= mem_wr_ack;

      -- write ALU output to registers
      when DO_LOAD_STORE =>

        -- possibly no writes, so always ack
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

  end process RECEIVE_FROM_MEMORY;

end IMP;
