------------------------------------------------------------------------------
-- user_logic.vhd - entity/architecture pair
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
-- Filename:          user_logic.vhd
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

entity user_logic is
  generic
  (
    -- user generics
    C_M_USER_WIDTH           : integer            := 32;

    -- built-in generics
    C_NUM_REG                : integer            := 1;
    C_SLV_DWIDTH             : integer            := 32
  );
  port
  (
    -- user ports
    S_AXI_AWPROT             : in    std_logic_vector(2 downto 0);
    S_AXI_ARPROT             : in    std_logic_vector(2 downto 0);
    M_AXI_AWPROT             : out   std_logic_vector(2 downto 0);
    M_AXI_ARPROT             : out   std_logic_vector(2 downto 0);
    M_AXI_AWUSER             : out   std_logic_vector (
                                         C_M_USER_WIDTH-1 downto 0
                                         );
    M_AXI_ARUSER             : out   std_logic_vector (
                                         C_M_USER_WIDTH-1 downto 0
                                         );
    M_AXI_WUSER              : out   std_logic_vector (
                                         C_M_USER_WIDTH-1 downto 0
                                         );
    M_AXI_RUSER              : in    std_logic_vector (
                                         C_M_USER_WIDTH-1 downto 0
                                         );
    M_AXI_BUSER              : in    std_logic_vector (
                                         C_M_USER_WIDTH-1 downto 0
                                         );
    KEY_OUT                  : out   std_logic_vector(31 downto 0);

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

end entity user_logic;

architecture IMP of user_logic is

  -- bits in the control register, and register numbers
  constant C_ID_CTRL         : integer          := 0;
  constant C_ID_UAXPROT      : integer          := 0;
  constant C_ID_UARPROT      : integer          := 1;
  constant C_ID_UAWPROT      : integer          := 2;
  constant C_ID_NS           : integer          := 3;
  constant C_ID_CRIT         : integer          := 4;
  constant C_ID_GPIO_I       : integer          := 5;
  constant C_ID_GPIO_O       : integer          := 6;
  constant C_ID_GPIO_T       : integer          := 7;
  constant C_ID_MEM_R        : integer          := 8;
  constant C_ID_MEM_W        : integer          := 9;
  constant C_ID_AWUSER       : integer          := 10;
  constant C_ID_ARUSER       : integer          := 11;
  constant C_ID_WUSER        : integer          := 12;
  constant C_ID_RUSER        : integer          := 13;
  constant C_ID_BUSER        : integer          := 14;
  constant C_ID_IRQ          : integer          := 15;
  constant C_ID_NS_SMP       : integer          := 16;
  constant C_ID_TL           : integer          := 17;
  constant C_ID_PLE          : integer          := 18;
  constant C_ID_NSASEDIS     : integer          := 19;
  constant C_ID_NSD32DIS     : integer          := 20;
  constant C_ID_SUNIDEN      : integer          := 21;
  constant C_ID_SUIDEN       : integer          := 22;
  constant C_ID_SIF          : integer          := 23;
  constant C_ID_HCE          : integer          := 24;
  constant C_ID_SCD          : integer          := 25;
  constant C_ID_AW           : integer          := 26;
  constant C_ID_FW           : integer          := 27;
  constant C_ID_IW           : integer          := 28;
  constant C_ID_EA           : integer          := 29;
  constant C_ID_FIQM         : integer          := 30;
  constant C_ID_IRQM         : integer          := 31;

  type slv_regs_type is array(C_NUM_REG-1 downto 0)
    of std_logic_vector(C_SLV_DWIDTH-1 downto 0);
  signal slv_regs            : slv_regs_type;
  signal slv_ip2bus_data     : std_logic_vector(C_SLV_DWIDTH-1 downto 0);
  signal slv_read_ack        : std_logic;
  signal slv_write_ack       : std_logic;
  signal awprot              : std_logic_vector(2 downto 0);
  signal arprot              : std_logic_vector(2 downto 0);
  signal axprot              : std_logic;
  signal viewy               : integer;

begin

  -- send user signals out
  M_AXI_AWUSER <= slv_regs(C_ID_AWUSER);
  M_AXI_ARUSER <= slv_regs(C_ID_ARUSER);
  M_AXI_WUSER  <= slv_regs(C_ID_WUSER);

  -- decode TrustZone signal, UAXPROT selects source (PS or this peripheral)
  awprot(0) <= '0';
  awprot(2) <= '0';
  arprot(0) <= '0';
  arprot(2) <= '0';
  with axprot select M_AXI_AWPROT <= awprot when '1', S_AXI_AWPROT when others;
  with axprot select M_AXI_ARPROT <= arprot when '1', S_AXI_ARPROT when others;

  -- Allow the user to write IDs in for 28 special purpose keys,
  --  and select and use either one of these keys or the "normal world" key
  --  using the first register as the control register
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
        awprot(1) <= '1';
        arprot(1) <= '1';
        axprot <= '0';

      -- write requested
      elsif fw = '1'
      then
        slv_regs(slv_reg_write_sel) <= bus2ip_data;

        -- control register
        if slv_reg_write_sel = 0
        then

          -- swap the output key with the secure/normal state key
          if bus2ip_data(C_ID_NS) = '1'
          then
            KEY_OUT <= slv_regs(C_ID_NS);

          -- swap the output key with a selected key
          else
            for j in C_SLV_DWIDTH-1 downto C_ID_CRIT
            loop
              if fw = '1' and bus2ip_data(j) = '1'
              then
                viewy <= j;
                KEY_OUT <= slv_regs(j);
                fw := '0';
              end if;
            end loop;
          end if;

          -- set axprot
          axprot    <= bus2ip_data(C_ID_UAXPROT);
          awprot(1) <= bus2ip_data(C_ID_UAWPROT);
          arprot(1) <= bus2ip_data(C_ID_UARPROT);

        end if;
      end if;
    end if;

    -- update wire signals regardless clock edge
    slv_regs(C_ID_RUSER)  <= M_AXI_RUSER;
    slv_regs(C_ID_BUSER)  <= M_AXI_BUSER;

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
