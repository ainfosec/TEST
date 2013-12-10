-- Filename:          reg_file_constants.vhd
-- Version:           1.00.a
-- Description:       Contains the ids used by the state_machine
-- Date Created:      Wed, Dec 04, 2013 01:17:21
-- Last Modified:     Thu, Dec 05, 2013 22:25:40
-- VHDL Standard:     VHDL'93
-- Author:            Sean McClain <mcclains@ainfosec.com>
-- Copyright:         (c) 2013 Assured Information Security, All Rights Reserved

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- constants for the register file
package reg_file_constants is

  -- number of register file registers, including memory (317 = 1 KB mem)
  constant NUM_REGS          : integer          := 317;

    -- width of a single register, in bits
  constant DATA_WIDTH        : integer          := 32;

  -- register file write enable indices
  constant WR_EN_RD          : integer          := 0;
  constant WR_EN_SP_PLUS_OFF : integer          := 1;
  constant WR_EN_RN_PLUS_OFF : integer          := 2;
  constant WR_EN_RM_PLUS_RN  : integer          := 3;
  constant WR_EN_RD_H_REG    : integer          := 4;
  constant WR_EN_SP          : integer          := 5;
  constant WR_EN_PC          : integer          := 6;
  constant WR_EN_LR          : integer          := 7;
  constant WR_EN_LIST_RTS    : integer          := 8;
  constant WR_EN_LIST_STR    : integer          := 9;
  constant WR_EN_SIZEOF      : integer          := 10;

  -- swap-in registers
  constant USRSP_REG         : integer := 13;
  constant USRLR_REG         : integer := 14;

  -- system wide program counter
  constant SYSPC_REG         : integer := 15;

  -- register where instructions from external peripheral are stored
  constant INSTR_REG         : integer := 16;

  -- rest of the swap-in registers
  constant FIQ8_REG          : integer := 17;
  constant FIQ9_REG          : integer := 18;
  constant FIQ10_REG         : integer := 19;
  constant FIQ11_REG         : integer := 20;
  constant FIQ12_REG         : integer := 21;
  constant FIQSP_REG         : integer := 22;
  constant FIQLR_REG         : integer := 23;
  constant IRQSP_REG         : integer := 24;
  constant IRQLR_REG         : integer := 25;
  constant SVCSP_REG         : integer := 26;
  constant SVCLR_REG         : integer := 27;
  constant MONSP_REG         : integer := 28;
  constant MONLR_REG         : integer := 29;
  constant ABOSP_REG         : integer := 30;
  constant ABOLR_REG         : integer := 31;
  constant UNDSP_REG         : integer := 32;
  constant UNDLR_REG         : integer := 33;

  -- register where NZCV flags are stored
  constant CPSR_REG          : integer := 34;

  -- saved program state registers
  constant USRSS_REG         : integer := 35;
  constant FIQSS_REG         : integer := 36;
  constant IRQSS_REG         : integer := 37;
  constant SVCSS_REG         : integer := 38;
  constant MONSS_REG         : integer := 39;
  constant UNDSS_REG         : integer := 40;
  constant ABOSS_REG         : integer := 41;

  -- highest data register
  constant REG_BOUND         : integer := 41;

  -- lowest memory register
  constant MEM_BOUND         : integer := 42;

  -- indices for the program status register
  constant PSR_N             : integer := 30;
  constant PSR_Z             : integer := 30;
  constant PSR_C             : integer := 29;
  constant PSR_V             : integer := 28;
  constant PSR_Q             : integer := 27;
  constant PSR_IT_1          : integer := 26;
  constant PSR_IT_0          : integer := 25;
  constant PSR_J             : integer := 24;
  constant PSR_RSVD_3        : integer := 23;
  constant PSR_RSVD_0        : integer := 20;
  constant PSR_GE_3          : integer := 19;
  constant PSR_GE_0          : integer := 16;
  constant PSR_IT_7          : integer := 15;
  constant PSR_IT_2          : integer := 10;
  constant PSR_E             : integer := 9;
  constant PSR_A             : integer := 8;
  constant PSR_I             : integer := 7;
  constant PSR_F             : integer := 6;
  constant PSR_T             : integer := 5;
  constant PSR_M_4           : integer := 4;
  constant PSR_M_0           : integer := 0;

  -- processor modes
  constant PM_USER           : std_logic_vector(4 downto 0) := "10000";
  constant PM_FIQ            : std_logic_vector(4 downto 0) := "10001";
  constant PM_IRQ            : std_logic_vector(4 downto 0) := "10010";
  constant PM_SVC            : std_logic_vector(4 downto 0) := "10011";
  constant PM_MONITOR        : std_logic_vector(4 downto 0) := "10110";
  constant PM_ABORT          : std_logic_vector(4 downto 0) := "10111";
  constant PM_UNDEF          : std_logic_vector(4 downto 0) := "11011";
  constant PM_SYSTEM         : std_logic_vector(4 downto 0) := "11111";

  -- indices of ALU read registers within the memory I/O channel
  constant MEMIO_SPPLUSOFF   : integer := 0;
  constant MEMIO_PCPLUSOFF   : integer := 1;
  constant MEMIO_LRPLUSOFF   : integer := 2;
  constant MEMIO_RNPLUSOFF   : integer := 3;
  constant MEMIO_RMPLUSRN    : integer := 4;
  constant MEMIO_RMHHREG     : integer := 5;
  constant MEMIO_RDHREG      : integer := 5;
  constant MEMIO_RMHLREG     : integer := 6;
  constant MEMIO_RNHHREG     : integer := 7;
  constant MEMIO_RNHLREG     : integer := 8;
  constant MEMIO_RMREG       : integer := 9;
  constant MEMIO_RNREG       : integer := 10;
  constant MEMIO_RSREG       : integer := 11;
  constant MEMIO_RDREG       : integer := 12;
  constant MEMIO_SPREG       : integer := 13;
  constant MEMIO_PCREG       : integer := 14;
  constant MEMIO_LRREG       : integer := 15;

  -- 4-byte or 8-byte word-addressable memory
  type regs_type is array(NUM_REGS-1 downto 0)
    of std_logic_vector(DATA_WIDTH-1 downto 0);

  -- 512 or 1024 bit word-addressed load/store channel
  type mem_channel is array(15 downto 0)
    of std_logic_vector(DATA_WIDTH-1 downto 0);

  -- 16 4-byte word or 8-byte word addresses
  type mem_address is array(15 downto 0)
    of integer range NUM_REGS-1 downto 0;

end package reg_file_constants;

package body reg_file_constants is

end package body reg_file_constants;
