-- Filename:          memory.vhd
-- Version:           1.00.a
-- Description:       contains readable and writeable word-addressed memory
-- Date Created:      Thu, Dec 05, 2013 22:03:13
-- Last Modified:     Fri, Dec 06, 2013 01:53:24
-- VHDL Standard:     VHDL'93
-- Author:            Sean McClain <mcclains@ainfosec.com>
-- Copyright:         (c) 2013 Assured Information Security, All Rights Reserved

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

library simple_processor_wrapper_v1_00_a;
use simple_processor_wrapper_v1_00_a.states.all;
use simple_processor_wrapper_v1_00_a.reg_file_constants.all;

---
-- contains word-addressed memory
---
entity memory
is
  port
  (
    -- channel enables
    rd_en    : in    std_logic_vector(15 downto 0);
    wr_en    : in    std_logic_vector(15 downto 0);

    -- channel acknowledgements
    rd_ack   : out   std_logic;
    wr_ack   : out   std_logic;

    -- channel addresses
    wr_addr  : in    mem_address;
    rd_addr  : in    mem_address;

    -- channel data
    data_in  : in    mem_channel;
    data_out : out   mem_channel;

    -- stack pointer
    sp       : out   integer range NUM_REGS-1 downto MEM_BOUND;

    -- program counter
    pc       : out   integer range NUM_REGS-1 downto MEM_BOUND;

    -- link register
    lr       : out   integer range NUM_REGS-1 downto MEM_BOUND
  );

end entity memory;

architecture IMP of memory
is

  -- all the registers and data memory
  signal mem : regs_type;

  -- which mode we are operating in
  signal mode : std_logic_vector(4 downto 0);

  -- to determine if we just swapped out of FIQ mode
  signal mode_was : std_logic_vector(4 downto 0);

  -- default value
  signal zero : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  zero <= (others => '0');

  -- read data into memory
  DO_WRITE : process ( wr_en )
  is
  begin

    -- reset requested
    if wr_en = "1111111111111111"
    then
      for i in NUM_REGS-1 downto 0
      loop

        -- default instruction is UNUSED
        if i = INSTR_REG
        then
          mem(i) <= "00000000000000001101111011111111";

        -- default stack pointer is 16 regs below the top of memory
        elsif i = USRSP_REG or i = FIQSP_REG or i = IRQSP_REG or i = SVCSP_REG
           or i = UNDSP_REG or i = ABOSP_REG or i = MONSP_REG
        then
          mem(i) <=
            std_logic_vector(to_unsigned(NUM_REGS - 16, DATA_WIDTH));

        -- default link register and program counter is bottom of memory
        elsif i = USRLR_REG or i = FIQLR_REG or i = IRQLR_REG or i = SVCLR_REG
           or i = UNDLR_REG or i = ABOLR_REG or i = MONLR_REG or i = SYSPC_REG
        then
          mem(i) <=
            std_logic_vector(to_unsigned(MEM_BOUND, DATA_WIDTH));

        -- default mode is user, using thumb
        elsif i = CPSR_REG
        then
          mem(i) <= (DATA_WIDTH-1 downto 5 => '0') & PM_USER;

        -- hard-drive the modes in the saved program state registers
        elsif i = USRSS_REG
        then
          mem(i) <= (DATA_WIDTH-1 downto 5 => '0') & PM_USER;
        elsif i = FIQSS_REG
        then
          mem(i) <= (DATA_WIDTH-1 downto 5 => '0') & PM_FIQ;
        elsif i = IRQSS_REG
        then
          mem(i) <= (DATA_WIDTH-1 downto 5 => '0') & PM_IRQ;
        elsif i = SVCSS_REG
        then
          mem(i) <= (DATA_WIDTH-1 downto 5 => '0') & PM_SVC;
        elsif i = MONSS_REG
        then
          mem(i) <= (DATA_WIDTH-1 downto 5 => '0') & PM_MONITOR;
        elsif i = UNDSS_REG
        then
          mem(i) <= (DATA_WIDTH-1 downto 5 => '0') & PM_UNDEF;
        elsif i = ABOSS_REG
        then
          mem(i) <= (DATA_WIDTH-1 downto 5 => '0') & PM_ABORT;

        -- default register content is zero, 
        else
          mem(i) <= std_logic_vector(to_unsigned(i, 32));

        end if;

      end loop;

      -- acknowledge reset complete
      wr_ack <= '1';

    -- perform mode switches between writes
    elsif wr_en = "0000000000000000"
    then

      -- for determining whether switching in to / out of FIQ mode
      mode_was <= mode;

      -- no write
      wr_ack <= '0';

      -- swap the current and saved program state registers,
      --  minus the mode bits
      case mode is
        when PM_FIQ =>
          mem(CPSR_REG)(DATA_WIDTH-1 downto 5) <=
            mem(FIQSS_REG)(DATA_WIDTH-1 downto 5);
          mem(FIQSS_REG)(DATA_WIDTH-1 downto 5) <=
            mem(CPSR_REG)(DATA_WIDTH-1 downto 5);
        when PM_IRQ =>
          mem(CPSR_REG)(DATA_WIDTH-1 downto 5) <=
            mem(IRQSS_REG)(DATA_WIDTH-1 downto 5);
          mem(IRQSS_REG)(DATA_WIDTH-1 downto 5) <=
            mem(CPSR_REG)(DATA_WIDTH-1 downto 5);
        when PM_SVC =>
          mem(CPSR_REG)(DATA_WIDTH-1 downto 5) <=
            mem(SVCSS_REG)(DATA_WIDTH-1 downto 5);
          mem(SVCSS_REG)(DATA_WIDTH-1 downto 5) <=
            mem(CPSR_REG)(DATA_WIDTH-1 downto 5);
        when PM_MONITOR =>
          mem(CPSR_REG)(DATA_WIDTH-1 downto 5) <=
            mem(MONSS_REG)(DATA_WIDTH-1 downto 5);
          mem(MONSS_REG)(DATA_WIDTH-1 downto 5) <=
            mem(CPSR_REG)(DATA_WIDTH-1 downto 5);
        when PM_UNDEF =>
          mem(CPSR_REG)(DATA_WIDTH-1 downto 5) <=
            mem(UNDSS_REG)(DATA_WIDTH-1 downto 5);
          mem(UNDSS_REG)(DATA_WIDTH-1 downto 5) <=
            mem(CPSR_REG)(DATA_WIDTH-1 downto 5);
        when PM_ABORT =>
          mem(CPSR_REG)(DATA_WIDTH-1 downto 5) <=
            mem(ABOSS_REG)(DATA_WIDTH-1 downto 5);
          mem(ABOSS_REG)(DATA_WIDTH-1 downto 5) <=
            mem(CPSR_REG)(DATA_WIDTH-1 downto 5);
        when PM_SYSTEM =>
          mem(CPSR_REG)(DATA_WIDTH-1 downto 5) <=
            mem(USRSS_REG)(DATA_WIDTH-1 downto 5);
          mem(USRSS_REG)(DATA_WIDTH-1 downto 5) <=
            mem(CPSR_REG)(DATA_WIDTH-1 downto 5);
        when others =>
          mem(CPSR_REG)(DATA_WIDTH-1 downto 5) <=
            mem(USRSS_REG)(DATA_WIDTH-1 downto 5);
          mem(USRSS_REG)(DATA_WIDTH-1 downto 5) <=
            mem(CPSR_REG)(DATA_WIDTH-1 downto 5);
      end case;

      -- fiq swaps in quite a few more registers
      if mode = PM_FIQ or mode_was = PM_FIQ
      then
        mem(FIQ8_REG)  <= mem(8);
        mem(FIQ9_REG)  <= mem(9);
        mem(FIQ10_REG) <= mem(10);
        mem(FIQ11_REG) <= mem(11);
        mem(FIQ12_REG) <= mem(12);
        mem(8)  <= mem(FIQ8_REG);
        mem(9)  <= mem(FIQ9_REG);
        mem(10) <= mem(FIQ10_REG);
        mem(11) <= mem(FIQ11_REG);
        mem(12) <= mem(FIQ12_REG);
      end if;

    -- no reset, do writes
    else

-- TODO: to limit compile times, only instruction and a single
--       destination register are writeable

--      for i in 15 downto 0
--      loop
--        if wr_en(i) = '1'
        if wr_en(15) = '1'
        then
          mem(INSTR_REG) <= data_in(15);
        elsif wr_en(MEMIO_RDREG) = '1'
        then
          mem(4) <= data_in(MEMIO_RDREG);
--          mem(wr_addr(i)) <= data_in(i);
        end if;
--      end loop;

      -- acknowledge write complete
      wr_ack <= '1';
    end if;

  end process DO_WRITE;

  -- send data out from memory

-- TODO: to limit compile times, only 4 pre-defined registers
--       for rm, rn, rs, and rd, respectively, are readable,
--       and the contents of rd are copied to the external
--       peripheral.

--  DO_READ : for i in 15 downto 0
--  generate
--    with rd_en(i) select data_out(i) <=
--      mem(rd_addr(i)) when '1',
--      zero when others;
--  end generate DO_READ;
  with rd_en(MEMIO_RMREG) select data_out(MEMIO_RMREG) <=
    mem(1) when '1',
    zero when others;
  with rd_en(MEMIO_RNREG) select data_out(MEMIO_RNREG) <=
    mem(2) when '1',
    zero when others;
  with rd_en(MEMIO_RSREG) select data_out(MEMIO_RSREG) <=
    mem(3) when '1',
    zero when others;
  with rd_en(MEMIO_RDREG) select data_out(MEMIO_RDREG) <=
    mem(4) when '1',
    zero when others;
  with rd_en(0) select data_out(0) <=
    mem(4) when '1',
    zero when others;

  -- acknowledge reads
  with rd_en select rd_ack <=
    '0' when "0000000000000000",
    '1' when others;

  -- determine the operating mode
  mode <= mem(CPSR_REG)(4 downto 0);

  -- drive the stack pointer
  with mode select sp <=
    to_integer(unsigned(mem(FIQSP_REG))) when PM_FIQ,
    to_integer(unsigned(mem(IRQSP_REG))) when PM_IRQ,
    to_integer(unsigned(mem(SVCSP_REG))) when PM_SVC,
    to_integer(unsigned(mem(MONSP_REG))) when PM_MONITOR,
    to_integer(unsigned(mem(ABOSP_REG))) when PM_ABORT,
    to_integer(unsigned(mem(UNDSP_REG))) when PM_UNDEF,
    to_integer(unsigned(mem(USRSP_REG))) when others;

  -- drive the program counter
  pc <= to_integer(unsigned(mem(SYSPC_REG)));

  -- drive the link register
  with mode select lr <=
    to_integer(unsigned(mem(FIQLR_REG))) when PM_FIQ,
    to_integer(unsigned(mem(IRQLR_REG))) when PM_IRQ,
    to_integer(unsigned(mem(SVCLR_REG))) when PM_SVC,
    to_integer(unsigned(mem(MONLR_REG))) when PM_MONITOR,
    to_integer(unsigned(mem(ABOLR_REG))) when PM_ABORT,
    to_integer(unsigned(mem(UNDLR_REG))) when PM_UNDEF,
    to_integer(unsigned(mem(USRLR_REG))) when others;

end IMP;
