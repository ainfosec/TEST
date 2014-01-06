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
-- Date:              Wed Oct 09 17:22:59 2013 (by Create and Import Peripheral Wizard)
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
use ieee.numeric_std.all;

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

entity user_logic
is
  generic
  (
    -- user generics
    C_PERMISSIONS_DWIDTH     : integer            := 32;
    C_S_AXI_AWUSER_WIDTH     : integer            := 32;
    C_S_AXI_ARUSER_WIDTH     : integer            := 32;
    C_GPIO_WIDTH             : integer            := 32;

    -- built-in generics
    C_NUM_REG                : integer            := 1;
    C_SLV_DWIDTH             : integer            := 32
  );
  port
  (
    -- user ports
    S_AXI_AWPROT             : in    std_logic_vector(2 downto 0);
    S_AXI_ARPROT             : in    std_logic_vector(2 downto 0);
    S_AXI_AWUSER             : in    std_logic_vector (
                                         C_S_AXI_AWUSER_WIDTH-1 downto 0
                                         );
    S_AXI_ARUSER             : in    std_logic_vector (
                                         C_S_AXI_ARUSER_WIDTH-1 downto 0
                                         );
    M_AXI_AWPROT             : out   std_logic_vector(2 downto 0);
    M_AXI_ARPROT             : out   std_logic_vector(2 downto 0);
    M_AXI_AWUSER             : out   std_logic_vector (
                                         C_S_AXI_AWUSER_WIDTH-1 downto 0
                                         );
    M_AXI_ARUSER             : out   std_logic_vector (
                                         C_S_AXI_ARUSER_WIDTH-1 downto 0
                                         );
    S_BRAM_RE                : in    std_logic;
    S_BRAM_WE                : in    std_logic;
    M_BRAM_RE                : out   std_logic;
    M_BRAM_WE                : out   std_logic;
    S_GPIO_IO_I              : out   std_logic_vector (
                                         C_GPIO_WIDTH-1 downto 0
                                         );
    S_GPIO_IO_O              : in    std_logic_vector (
                                         C_GPIO_WIDTH-1 downto 0
                                         );
    S_GPIO_IO_T              : in    std_logic_vector (
                                         C_GPIO_WIDTH-1 downto 0
                                         );
    M_GPIO_IO_I              : in    std_logic_vector (
                                         C_GPIO_WIDTH-1 downto 0
                                         );
    M_GPIO_IO_O              : out   std_logic_vector (
                                         C_GPIO_WIDTH-1 downto 0
                                         );
    M_GPIO_IO_T              : out   std_logic_vector (
                                         C_GPIO_WIDTH-1 downto 0
                                         );
    S_IRQ                    : in    std_logic;
    M_IRQ                    : out   std_logic;
    KEY_IN                   : in    std_logic_vector(31 downto 0);
    TABLE_OUT                : out   std_logic_vector (
                                         C_NUM_REG*C_PERMISSIONS_DWIDTH-1
                                         downto 0
                                         );

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

architecture IMP of user_logic
is

  -- bit offsets for permissions
  constant C_PERM_NUM        : integer          := 12;
  constant C_PERM_CRIT       : integer          := 11;
  constant C_PERM_IO_I       : integer          := 10;
  constant C_PERM_IO_O       : integer          := 9;
  constant C_PERM_IO_T       : integer          := 8;
  constant C_PERM_MEM_R      : integer          := 7;
  constant C_PERM_MEM_W      : integer          := 6;
  constant C_PERM_AWUSER     : integer          := 5;
  constant C_PERM_ARUSER     : integer          := 4;
  constant C_PERM_WUSER      : integer          := 3;
  constant C_PERM_RUSER      : integer          := 2;
  constant C_PERM_BUSER      : integer          := 1;
  constant C_PERM_IRQ        : integer          := 0;

  type slv_regs_type is array(C_NUM_REG-1 downto 0)
    of std_logic_vector(C_SLV_DWIDTH-1 downto 0);
  signal keys                : slv_regs_type;
  signal permissions         : slv_regs_type;
  signal slv_ip2bus_data     : std_logic_vector(C_SLV_DWIDTH-1 downto 0);
  signal slv_read_ack        : std_logic;
  signal slv_write_ack       : std_logic;
  signal stack_ptr           : integer;
begin

  -- send the state of the table constantly
  TABLE_STATUS : for i in C_NUM_REG-1 downto 0
  generate
    TABLE_OUT((i+1)*C_PERMISSIONS_DWIDTH-1 downto i*C_PERMISSIONS_DWIDTH) <=
      permissions(i)(C_PERMISSIONS_DWIDTH-1 downto 0);
  end generate TABLE_STATUS;

  -- write keys and permissions to the access control table
  SLAVE_REG_WRITE_PROC : process( Bus2IP_Clk )
  is
    variable fw               : std_logic;
    variable fr               : std_logic;
    variable temp_permissions : std_logic_vector(C_SLV_DWIDTH-1 downto 0);
    variable check_perm       : std_logic_vector(4 downto 0);
  begin

    -- test for reads and writes
    fw := '0';
    fr := '0';
    for i in C_NUM_REG-1 downto 0
    loop

      -- grab user permissions
      if Bus2IP_WrCE(C_NUM_REG-1 - i) = '1' and fw = '0'
      then

        -- found any write, set write acknowledge bit
        fw := '1';

        -- perform 32->5 encoding
        check_perm := std_logic_vector(to_unsigned(i, 5));

        -- decode permission bits
        temp_permissions(C_SLV_DWIDTH-1 downto C_PERM_NUM) :=
          (others => '0');
        temp_permissions(C_PERM_CRIT)   := check_perm(4);
        temp_permissions(C_PERM_IO_I)   := check_perm(3);
        temp_permissions(C_PERM_IO_O)   := check_perm(3);
        temp_permissions(C_PERM_IO_T)   := check_perm(3);
        temp_permissions(C_PERM_MEM_R)  := check_perm(2);
        temp_permissions(C_PERM_MEM_W)  := check_perm(2);
        temp_permissions(C_PERM_AWUSER) := check_perm(1);
        temp_permissions(C_PERM_ARUSER) := check_perm(1);
        temp_permissions(C_PERM_WUSER)  := check_perm(1);
        temp_permissions(C_PERM_RUSER)  := check_perm(1);
        temp_permissions(C_PERM_BUSER)  := check_perm(1);
        temp_permissions(C_PERM_IRQ)    := check_perm(0);

      end if;

      -- test for read requested (seals table)
      if Bus2IP_RdCE(C_NUM_REG-1 - i) = '1'
      then
        fr := '1';
      end if;

    end loop;
    slv_write_ack <= fw;

    -- read/write from Bus2IP on high clock edge
    if Bus2IP_Clk'event and Bus2IP_Clk = '1'
    then

      -- reset requested
      if Bus2IP_Resetn = '0'
      then
        for i in C_NUM_REG-1 downto 0
        loop
          keys(i)        <= (others => '0');
          permissions(i) <= (others => '0');
        end loop;
        stack_ptr <= 0;

      -- read requested, seal table
      elsif fr = '1'
      then
        stack_ptr <= C_NUM_REG;

      -- write requested
      elsif fw = '1' and stack_ptr < C_NUM_REG
      then
        keys(stack_ptr)        <= Bus2IP_Data;
        permissions(stack_ptr) <= temp_permissions;
        stack_ptr              <= stack_ptr + 1;
      end if;

    end if;

  end process SLAVE_REG_WRITE_PROC;

  -- read a key value from the access control table
  SLAVE_REG_READ_PROC : process( Bus2IP_RdCE, keys )
  is
    variable fr               : std_logic;
    variable slv_reg_read_sel : integer;
  begin

    -- decode read address signal
    fr := '0';
    slv_reg_read_sel := 0;
    for i in C_NUM_REG-1 downto 0
    loop
      if Bus2IP_RdCE(C_NUM_REG-1 - i) = '1' and fr = '0'
      then
        fr := '1';
        slv_reg_read_sel := i;
      end if;
    end loop;
    slv_read_ack <= fr;

    -- grab chosen register
    slv_ip2bus_data <= keys(slv_reg_read_sel);

  end process SLAVE_REG_READ_PROC;

  -- use the access control table
  USE_KEY_PROC : process (
      KEY_IN, keys, permissions,
      S_AXI_AWPROT, S_AXI_ARPROT, S_AXI_ARUSER, S_BRAM_RE, S_BRAM_WE,
      M_GPIO_IO_I, S_GPIO_IO_O, S_GPIO_IO_T, S_IRQ
      )
  is
    variable fr  : std_logic;
    variable fid : integer;
  begin

    -- find a matching key
    fr := '0';
    for i in C_NUM_REG-1 downto 0
    loop
      if KEY_IN = keys(i) and fr = '0'
      then
        fr := '1';
        fid := i;
      end if;
    end loop;

    -- if we don't have a matching key, shut everything off
    if fr = '0'
    then
      M_AXI_AWPROT <= "010";
      M_AXI_ARPROT <= "010";
      M_AXI_AWUSER <= (others => '0');
      M_AXI_ARUSER <= (others => '0');
      M_BRAM_RE    <= '0';
      M_BRAM_WE    <= '0';
      S_GPIO_IO_I  <= (others => '0');
      M_GPIO_IO_O  <= (others => '0');
      M_GPIO_IO_T  <= (others => '0');
      M_IRQ        <= '0';

    -- otherwise turn things on and off based on permissions
    else
      if permissions(fid)(C_PERM_CRIT) = '1'
      then
        M_AXI_AWPROT <= S_AXI_AWPROT;
        M_AXI_ARPROT <= S_AXI_ARPROT;
      else
        M_AXI_AWPROT <= "010";
        M_AXI_ARPROT <= "010";
      end if;
      if permissions(fid)(C_PERM_AWUSER) = '1'
      then
        M_AXI_AWUSER <= S_AXI_AWUSER;
      else
        M_AXI_AWUSER <= (others => '0');
      end if;
      if permissions(fid)(C_PERM_ARUSER) = '1'
      then
        M_AXI_ARUSER <= S_AXI_ARUSER;
      else
        M_AXI_ARUSER <= (others => '0');
      end if;
      if permissions(fid)(C_PERM_MEM_R) = '1'
      then
        M_BRAM_RE <= S_BRAM_RE;
      else
        M_BRAM_RE <= '0';
      end if;
      if permissions(fid)(C_PERM_MEM_W) = '1'
      then
        M_BRAM_WE <= S_BRAM_WE;
      else
        M_BRAM_WE <= '0';
      end if;
      if permissions(fid)(C_PERM_IO_I) = '1'
      then
        S_GPIO_IO_I <= M_GPIO_IO_I;
      else
        S_GPIO_IO_I <= (others => '0');
      end if;
      if permissions(fid)(C_PERM_IO_O) = '1'
      then
        M_GPIO_IO_O <= S_GPIO_IO_O;
      else
        M_GPIO_IO_O <= (others => '0');
      end if;
      if permissions(fid)(C_PERM_IO_T) = '1'
      then
        M_GPIO_IO_T <= S_GPIO_IO_T;
      else
        M_GPIO_IO_T <= (others => '0');
      end if;
      if permissions(fid)(C_PERM_IRQ) = '1'
      then
        M_IRQ <= S_IRQ;
      else
        M_IRQ <= '0';
      end if;
    end if;

  end process USE_KEY_PROC;

  -- send data back out to the world
  IP2Bus_Data  <= slv_ip2bus_data when slv_read_ack = '1' else (others => '0');
  IP2Bus_WrAck <= slv_write_ack;
  IP2Bus_RdAck <= slv_read_ack;
  IP2Bus_Error <= '0';

end IMP;
