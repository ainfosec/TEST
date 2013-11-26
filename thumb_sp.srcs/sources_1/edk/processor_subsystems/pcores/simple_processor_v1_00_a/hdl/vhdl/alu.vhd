------------------------------------------------------------------------------
-- alu.vhd - entity/architecture pair
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 1995-2012 Xilinx, Inc.  All rights reserved.            **
-- **                                                                       **
-- ** Xilinx, Inc.                                                          **
-- ** XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"         **
-- ** AS A COURTESY TO YOU, SOLELY FOR USE IN DEVELOPING PROGRAMS AND       **
-- ** SOLUTIONS FOR XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE,        **
-- ** OR INFORMATION AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE,        **
-- ** APPLICATION OR STANDARD, XILINX IS MAKING NO REPRESENTATION           **
-- ** THAT THIS IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,     **
-- ** AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE      **
-- ** FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY              **
-- ** WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE               **
-- ** IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR        **
-- ** REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF       **
-- ** INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS       **
-- ** FOR A PARTICULAR PURPOSE.                                             **
-- **                                                                       **
-- ***************************************************************************
--
------------------------------------------------------------------------------
-- Filename:          alu.vhd
-- Version:           1.00.a
-- Description:       User logic.
-- Date:              Wed Oct 09 18:48:52 2013 (by Create and Import Peripheral Wizard)
-- VHDL Standard:     VHDL'93
------------------------------------------------------------------------------
-- Naming Conventions:
--   active low signals:                    "*_n"
--   clock signals:                         "clk", "clk_div#", "clk_#x"
--   reset signals:                         "rst", "rst_n"
--   generics:                              "C_*"
--   user defined types:                    "*_TYPE"
--   state machine next state:              "*_ns"
--   state machine current state:           "*_cs"
--   combinatorial signals:                 "*_com"
--   pipelined or register delay signals:   "*_d#"
--   counter signals:                       "*cnt*"
--   clock enable signals:                  "*_ce"
--   internal version of output port:       "*_i"
--   device pins:                           "*_pin"
--   ports:                                 "- Names begin with Uppercase"
--   processes:                             "*_PROCESS"
--   component instantiations:              "<ENTITY_>I_<#|FUNC>"
------------------------------------------------------------------------------

-- DO NOT EDIT BELOW THIS LINE --------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

-- DO NOT EDIT ABOVE THIS LINE --------------------

--USER libraries added here

------------------------------------------------------------------------------
-- Entity section
------------------------------------------------------------------------------
-- Definition of Generics:
--   C_NUM_REG                    -- Number of software accessible registers
--   C_SLV_DWIDTH                 -- Slave interface data bus width

-- Definition of User Generics:

-- Definition of Ports:
--   Bus2IP_Clk                   -- Bus to IP clock
--   Bus2IP_Resetn                -- Bus to IP reset
--   Bus2IP_Data                  -- Bus to IP data bus
--   Bus2IP_BE                    -- Bus to IP byte enables
--   Bus2IP_RdCE                  -- Bus to IP read chip enable
--   Bus2IP_WrCE                  -- Bus to IP write chip enable
--   IP2Bus_Data                  -- IP to Bus data bus
--   IP2Bus_RdAck                 -- IP to Bus read transfer acknowledgement
--   IP2Bus_WrAck                 -- IP to Bus write transfer acknowledgement
--   IP2Bus_Error                 -- IP to Bus error response

-- Definition of User Ports:

------------------------------------------------------------------------------

entity alu is
  generic
  (
    -- user generics

    -- built-in generics
    C_NUM_REG                : integer            := 1;
    C_SLV_DWIDTH             : integer            := 32
  );
  port
  (
    -- user ports

    -- built-in ports
    Bus2IP_Clk               : in    std_logic;
    Bus2IP_Resetn            : in    std_logic;
    Bus2IP_Data              : in    std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    Bus2IP_BE                : in    std_logic_vector (
                                         C_SLV_DWIDTH/8-1 downto 0
                                         );
    Bus2IP_RdCE              : in    std_logic_vector(C_NUM_REG-1 downto 0);
    Bus2IP_WrCE              : in    std_logic_vector(C_NUM_REG-1 downto 0);
    IP2Bus_Data              : out   std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    IP2Bus_RdAck             : out   std_logic;
    IP2Bus_WrAck             : out   std_logic;
    IP2Bus_Error             : out   std_logic
  );

  attribute MAX_FANOUT             : string;
  attribute SIGIS                  : string;
  attribute SIGIS of Bus2IP_Clk    : signal is "CLK";
  attribute SIGIS of Bus2IP_Resetn : signal is "RST";

end entity alu;

architecture IMP of alu is

  type slv_regs_type is array(C_NUM_REG-1 downto 0)
    of std_logic_vector(C_SLV_DWIDTH-1 downto 0);
  signal slv_regs            : slv_regs_type;
  signal slv_ip2bus_data     : std_logic_vector(C_SLV_DWIDTH-1 downto 0);
  signal slv_read_ack        : std_logic;
  signal slv_write_ack       : std_logic;

begin

  -- write
  SLAVE_REG_WRITE_PROC : process( Bus2IP_Clk ) is
    variable fw                : std_logic;
    variable slv_reg_write_sel : integer;
  begin

    -- decode write address signal
    fw := '0';
    slv_reg_write_sel := 0;
    for i in C_NUM_REG-1 downto 0 loop
      if Bus2IP_WrCE(C_NUM_REG-1 - i) = '1' and fw = '0' then
        slv_reg_write_sel := i;
        fw := '1';
      end if;
    end loop;
    slv_write_ack <= fw;

    -- read/write from Bus2IP on high clock edge
    if Bus2IP_Clk'event and Bus2IP_Clk = '1' then

      -- reset requested
      if Bus2IP_Resetn = '0' then
        for i in C_NUM_REG-1 downto 0 loop
          slv_regs(i) <= (others => '0');
        end loop;

      -- write requested
      elsif fw = '1' then
        slv_regs(slv_reg_write_sel) <= bus2ip_data;
      end if;

    end if;

    -- update wire signals regardless clock edge

  end process SLAVE_REG_WRITE_PROC;

  -- read stored key values
  SLAVE_REG_READ_PROC : process( Bus2IP_RdCE, slv_regs ) is
    variable fr               : std_logic;
    variable slv_reg_read_sel : integer;
  begin

    -- decode read address signal
    fr := '0';
    slv_reg_read_sel := 0;
    for i in C_NUM_REG-1 downto 0 loop
      if Bus2IP_RdCE(C_NUM_REG-1 - i) = '1' and fr = '0' then
        fr := '1';
        slv_reg_read_sel := i;
      end if;
    end loop;
    slv_read_ack <= fr;

    -- grab chosen register
    slv_ip2bus_data <= slv_regs(slv_reg_read_sel);

  end process SLAVE_REG_READ_PROC;

  -- send data back out to the world
  IP2Bus_Data  <= slv_ip2bus_data
    when slv_read_ack = '1'
    else (others => '0');
  IP2Bus_WrAck <= slv_write_ack;
  IP2Bus_RdAck <= slv_read_ack;
  IP2Bus_Error <= '0';

end IMP;
