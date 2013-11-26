-- Filename:          simple_processor.vhd
-- Version:           1.00.a
-- Description:       Simple ARM Thumb(R) processor
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Tue, Nov 19, 2013 15:48:47
-- VHDL Standard:     VHDL'93
-- Author:            Sean McClain <mcclains@ainfosec.com>
-- Copyright:         (c) 2013 Assured Information Security, All Rights Reserved

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;
use proc_common_v3_00_a.ipif_pkg.all;
use proc_common_v3_00_a.soft_reset;

library axi_lite_ipif_v1_01_a;
use axi_lite_ipif_v1_01_a.axi_lite_ipif;

library simple_processor_v1_00_a;
use simple_processor_v1_00_a.alu;
use simple_processor_v1_00_a.decoder;
use simple_processor_v1_00_a.reg_file;
use simple_processor_v1_00_a.opcodes.all;

---
-- A single instruction ARM Thumb(R) processor with no flow control
--  or branching.
-- This includes a Xilinx(R) AXI4Lite controller, and support from accessing
--  register values from Xilinx EDK(R).
---
entity simple_processor
is
  generic
  (
    -- These are all used by the AXI4_Lite controller
    C_S_AXI_DATA_WIDTH       : integer            := 32;
    C_S_AXI_ADDR_WIDTH       : integer            := 32;
    C_S_AXI_MIN_SIZE         : std_logic_vector   := X"000001FF";
    C_USE_WSTRB              : integer            := 0;
    C_DPHASE_TIMEOUT         : integer            := 8;
    C_BASEADDR               : std_logic_vector   := X"FFFFFFFF";
    C_HIGHADDR               : std_logic_vector   := X"00000000";
    C_FAMILY                 : string             := "virtex6";
    C_NUM_REG                : integer            := 1;
    C_NUM_MEM                : integer            := 1;
    C_SLV_AWIDTH             : integer            := 32;
    C_SLV_DWIDTH             : integer            := 32
  );
  port
  (
    -- These are all used by the AXI4_Lite controller
    S_AXI_ACLK               : in    std_logic;
    S_AXI_ARESETN            : in    std_logic;
    S_AXI_AWADDR             : in    std_logic_vector (
                                         C_S_AXI_ADDR_WIDTH-1 downto 0
                                         );
    S_AXI_AWVALID            : in    std_logic;
    S_AXI_WDATA              : in    std_logic_vector (
                                         C_S_AXI_DATA_WIDTH-1 downto 0
                                         );
    S_AXI_WSTRB              : in    std_logic_vector( (
                                         C_S_AXI_DATA_WIDTH/8)-1 downto 0
                                         );
    S_AXI_WVALID             : in    std_logic;
    S_AXI_BREADY             : in    std_logic;
    S_AXI_ARADDR             : in    std_logic_vector (
                                         C_S_AXI_ADDR_WIDTH-1 downto 0
                                         );
    S_AXI_ARVALID            : in    std_logic;
    S_AXI_RREADY             : in    std_logic;
    S_AXI_ARREADY            : out   std_logic;
    S_AXI_RDATA              : out   std_logic_vector (
                                         C_S_AXI_DATA_WIDTH-1 downto 0
                                         );
    S_AXI_RRESP              : out   std_logic_vector(1 downto 0);
    S_AXI_RVALID             : out   std_logic;
    S_AXI_WREADY             : out   std_logic;
    S_AXI_BRESP              : out   std_logic_vector(1 downto 0);
    S_AXI_BVALID             : out   std_logic;
    S_AXI_AWREADY            : out   std_logic
  );

  -- Xilinx EDK(R) configuration parameters
  attribute MAX_FANOUT                  : string;
  attribute SIGIS                       : string;
  attribute MAX_FANOUT of S_AXI_ACLK    : signal is "10000";
  attribute MAX_FANOUT of S_AXI_ARESETN : signal is "10000";
  attribute SIGIS of S_AXI_ACLK         : signal is "Clk";
  attribute SIGIS of S_AXI_ARESETN      : signal is "Rst";

end entity simple_processor;

architecture IMP of simple_processor
is

  -- These constants were provided by Xilinx EDK(R) for use with their
  --  AXI4_Lite controller and Reset peripherals.
  constant USER_SLV_DWIDTH   : integer          := C_SLV_DWIDTH;
  constant IPIF_SLV_DWIDTH   : integer          := C_SLV_DWIDTH;
  constant ZERO_ADDR_PAD     : std_logic_vector(0 to 31) := (others => '0');
  constant RST_BASEADDR      : std_logic_vector := C_BASEADDR or X"00000100";
  constant RST_HIGHADDR      : std_logic_vector := C_BASEADDR or X"000001FF";
  constant USER_SLV_BASEADDR : std_logic_vector := C_BASEADDR or X"00000000";
  constant USER_SLV_HIGHADDR : std_logic_vector := C_BASEADDR or X"000000FF";
  constant IPIF_ARD_ADDR_RANGE_ARRAY : SLV64_ARRAY_TYPE :=
  (
    ZERO_ADDR_PAD & RST_BASEADDR,      -- soft reset space base address
    ZERO_ADDR_PAD & RST_HIGHADDR,      -- soft reset space high address
    ZERO_ADDR_PAD & USER_SLV_BASEADDR, -- user logic slave space base address
    ZERO_ADDR_PAD & USER_SLV_HIGHADDR  -- user logic slave space high address
  );
  constant RST_NUM_CE        : integer := 1;
  constant USER_SLV_NUM_REG  : integer := C_NUM_REG;
  constant USER_NUM_REG      : integer := USER_SLV_NUM_REG;
  constant TOTAL_IPIF_CE     : integer := USER_NUM_REG + RST_NUM_CE;
  constant IPIF_ARD_NUM_CE_ARRAY : INTEGER_ARRAY_TYPE :=
  (
    0  => (RST_NUM_CE),      -- number of ce for soft reset space
    1  => (USER_SLV_NUM_REG) -- number of ce for user logic slave space
  );
  constant RESET_WIDTH       : integer          := 8;
  constant RST_CS_INDEX      : integer          := 0;
  constant RST_CE_INDEX      : integer          := USER_NUM_REG;
  constant USER_SLV_CS_INDEX : integer          := 1;
  constant USER_SLV_CE_INDEX : integer          := calc_start_ce_index (
      IPIF_ARD_NUM_CE_ARRAY, USER_SLV_CS_INDEX
      );
  constant USER_CE_INDEX     : integer          := USER_SLV_CE_INDEX;

  -- total number of data and memory registers, plus 7 special purpose registers
  -- minimum 53
  constant NUM_REG_FILE_REGS : integer := 293;

  -- These signals were provided by Xilinx EDK(R) for use with their
  --  AXI4_Lite controller and Reset peripherals.
  signal ipif_Bus2IP_Clk     : std_logic;
  signal ipif_Bus2IP_Resetn  : std_logic;
  signal ipif_Bus2IP_Addr    : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
  signal ipif_Bus2IP_RNW     : std_logic;
  signal ipif_Bus2IP_BE      : std_logic_vector(IPIF_SLV_DWIDTH/8-1 downto 0);
  signal ipif_Bus2IP_CS      : std_logic_vector (
      (IPIF_ARD_ADDR_RANGE_ARRAY'LENGTH)/2-1 downto 0
      );
  signal ipif_Bus2IP_RdCE    : std_logic_vector (
      calc_num_ce(IPIF_ARD_NUM_CE_ARRAY)-1 downto 0
      );
  signal ipif_Bus2IP_WrCE    : std_logic_vector (
      calc_num_ce(IPIF_ARD_NUM_CE_ARRAY)-1 downto 0
      );
  signal ipif_Bus2IP_Data    : std_logic_vector(IPIF_SLV_DWIDTH-1 downto 0);
  signal ipif_IP2Bus_WrAck   : std_logic;
  signal ipif_IP2Bus_RdAck   : std_logic;
  signal ipif_IP2Bus_Error   : std_logic;
  signal ipif_IP2Bus_Data    : std_logic_vector(IPIF_SLV_DWIDTH-1 downto 0);
  signal ipif_Bus2IP_Reset   : std_logic;
  signal rst_Bus2IP_Reset    : std_logic;
  signal rst_IP2Bus_WrAck    : std_logic;
  signal rst_IP2Bus_Error    : std_logic;
  signal rst_Bus2IP_Reset_tmp: std_logic;
  signal user_Bus2IP_RdCE    : std_logic_vector(USER_NUM_REG-1 downto 0);
  signal user_Bus2IP_WrCE    : std_logic_vector(USER_NUM_REG-1 downto 0);
  signal user_IP2Bus_Data    : std_logic_vector(USER_SLV_DWIDTH-1 downto 0);
  signal user_IP2Bus_RdAck   : std_logic;
  signal user_IP2Bus_WrAck   : std_logic;
  signal user_IP2Bus_Error   : std_logic;

  -- for sending data back to Xilinx EDK(R)
  signal soft_addr_w         : std_logic_vector(C_NUM_REG-1 downto 0);
  signal soft_addr_r         : std_logic_vector(C_NUM_REG-1 downto 0);

  -- convenience variable, for comparisons
  signal zero                : std_logic_vector(31 downto 0);

  -- current processing state
  signal state               : integer;

  -- acknowledgements to drive the state machine
  signal reg_file_reset_ack  : std_logic;
  signal alu_reset_ack       : std_logic;
  signal send_inst_ack       : std_logic;
  signal decode_ack          : std_logic;
  signal load_ack            : std_logic;
  signal math_ack            : std_logic;
  signal store_ack           : std_logic;

  -- raw binary for the current instruction
  signal raw_instruction     : std_logic_vector(15 downto 0);

  -- decoded instruction
  signal opcode              : integer;

  -- hint for the decoded instruction's functionality
  signal op_type             : integer;

  -- argument register addresses m, n, source, and dest
  signal Rm                  : std_logic_vector(2 downto 0);
  signal Rn                  : std_logic_vector(2 downto 0);
  signal Rs                  : std_logic_vector(2 downto 0);
  signal Rd                  : std_logic_vector(2 downto 0);

  -- immediate values hard-coded in the raw instruction binary
  signal Imm_3               : std_logic_vector(2 downto 0);
  signal Imm_5               : std_logic_vector(4 downto 0);
  signal Imm_8               : std_logic_vector(7 downto 0);
  signal Imm_11              : std_logic_vector(10 downto 0);

  -- decoded condition
  signal condition           : std_logic_vector(15 downto 0);

  -- flag used by push/pop
  signal flag_lr_pc          : std_logic;

  -- flags used to access registers 8-15
  signal flags_h             : std_logic_vector(1 downto 0);

  -- flags set by the last ALU operation representing
  --  negative, zero, carry, overflow
  signal flag_n              : std_logic;
  signal flag_z              : std_logic;
  signal flag_c              : std_logic;
  signal flag_v              : std_logic;

  -- 2 arguments and return value for ALU
  signal alu_a               : std_logic_vector(31 downto 0);
  signal alu_b               : std_logic_vector(31 downto 0);
  signal alu_out             : std_logic_vector(31 downto 0);

begin

  ---
  -- Xilinx(R) provided AXI4_Lite controller
  ---
  AXI_LITE_IPIF_I : entity axi_lite_ipif_v1_01_a.axi_lite_ipif
    generic map
    (
      C_S_AXI_DATA_WIDTH     => IPIF_SLV_DWIDTH,
      C_S_AXI_ADDR_WIDTH     => C_S_AXI_ADDR_WIDTH,
      C_S_AXI_MIN_SIZE       => C_S_AXI_MIN_SIZE,
      C_USE_WSTRB            => C_USE_WSTRB,
      C_DPHASE_TIMEOUT       => C_DPHASE_TIMEOUT,
      C_ARD_ADDR_RANGE_ARRAY => IPIF_ARD_ADDR_RANGE_ARRAY,
      C_ARD_NUM_CE_ARRAY     => IPIF_ARD_NUM_CE_ARRAY,
      C_FAMILY               => C_FAMILY
    )
    port map
    (
      S_AXI_ACLK             => S_AXI_ACLK,
      S_AXI_ARESETN          => S_AXI_ARESETN,
      S_AXI_AWADDR           => S_AXI_AWADDR,
      S_AXI_AWVALID          => S_AXI_AWVALID,
      S_AXI_WDATA            => S_AXI_WDATA,
      S_AXI_WSTRB            => S_AXI_WSTRB,
      S_AXI_WVALID           => S_AXI_WVALID,
      S_AXI_BREADY           => S_AXI_BREADY,
      S_AXI_ARADDR           => S_AXI_ARADDR,
      S_AXI_ARVALID          => S_AXI_ARVALID,
      S_AXI_RREADY           => S_AXI_RREADY,
      S_AXI_ARREADY          => S_AXI_ARREADY,
      S_AXI_RDATA            => S_AXI_RDATA,
      S_AXI_RRESP            => S_AXI_RRESP,
      S_AXI_RVALID           => S_AXI_RVALID,
      S_AXI_WREADY           => S_AXI_WREADY,
      S_AXI_BRESP            => S_AXI_BRESP,
      S_AXI_BVALID           => S_AXI_BVALID,
      S_AXI_AWREADY          => S_AXI_AWREADY,
      Bus2IP_Clk             => ipif_Bus2IP_Clk,
      Bus2IP_Resetn          => ipif_Bus2IP_Resetn,
      Bus2IP_Addr            => ipif_Bus2IP_Addr,
      Bus2IP_RNW             => ipif_Bus2IP_RNW,
      Bus2IP_BE              => ipif_Bus2IP_BE,
      Bus2IP_CS              => ipif_Bus2IP_CS,
      Bus2IP_RdCE            => ipif_Bus2IP_RdCE,
      Bus2IP_WrCE            => ipif_Bus2IP_WrCE,
      Bus2IP_Data            => ipif_Bus2IP_Data,
      IP2Bus_WrAck           => ipif_IP2Bus_WrAck,
      IP2Bus_RdAck           => ipif_IP2Bus_RdAck,
      IP2Bus_Error           => ipif_IP2Bus_Error,
      IP2Bus_Data            => ipif_IP2Bus_Data
    );

  ---
  -- Xilinx(R) provided reset peripheral
  ---
  SOFT_RESET_I : entity proc_common_v3_00_a.soft_reset
    generic map
    (
      C_SIPIF_DWIDTH         => IPIF_SLV_DWIDTH,
      C_RESET_WIDTH          => RESET_WIDTH
    )
    port map
    (
      Bus2IP_Reset           => ipif_Bus2IP_Reset,
      Bus2IP_Clk             => ipif_Bus2IP_Clk,
      Bus2IP_WrCE            => ipif_Bus2IP_WrCE(RST_CE_INDEX),
      Bus2IP_Data            => ipif_Bus2IP_Data,
      Bus2IP_BE              => ipif_Bus2IP_BE,
      Reset2IP_Reset         => rst_Bus2IP_Reset,
      Reset2Bus_WrAck        => rst_IP2Bus_WrAck,
      Reset2Bus_Error        => rst_IP2Bus_Error,
      Reset2Bus_ToutSup      => open
    );

  ---
  --
  ---
  STATE_MACHINE_I : entity simple_processor_v1_00_a.state_machine
    port map
    (
      reg_file_reset_ack     => reg_file_reset_ack,
      alu_reset_ack          => alu_reset_ack,
      send_inst_ack          => send_inst_ack,
      decode_ack             => decode_ack,
      load_ack               => load_ack,
      math_ack               => math_ack,
      store_ack              => store_ack,
      soft_write_ack         => user_IP2Bus_WrAck,
      soft_read_ack          => user_IP2Bus_RdAck,
      state                  => state,
      Clk                    => ipif_Bus2IP_Clk,
      Reset                  => rst_Bus2IP_Reset
    );

  ---
  -- Register file, containing both registers and data memory
  ---
  REG_FILE_I : entity simple_processor_v1_00_a.reg_file
    generic map
    (
      num_regs               => NUM_REG_FILE_REGS,
      soft_address_width     => C_NUM_REG,
      data_width             => C_SLV_DWIDTH
    )
    port map
    (
      instruction            => raw_instruction,
      opcode                 => opcode,
      op_type                => op_type,
      Rm                     => Rm,
      Rn                     => Rn,
      Rs                     => Rs,
      Rd                     => Rd,
      Imm_3                  => Imm_3,
      Imm_5                  => Imm_5,
      Imm_8                  => Imm_8,
      Imm_11                 => Imm_11,
      zero                   => zero,
      flag_lr_pc             => flag_lr_pc,
      flags_h                => flags_h,
      alu_out                => alu_out,
      flag_n                 => flag_n,
      flag_z                 => flag_z,
      flag_c                 => flag_c,
      flag_v                 => flag_v,
      alu_a                  => alu_a,
      alu_b                  => alu_b,
      soft_addr_r            => soft_addr_r,
      soft_addr_w            => soft_addr_w,
      soft_data_i            => ipif_Bus2IP_Data,
      soft_data_o            => user_IP2Bus_Data,
      reg_file_reset_ack     => reg_file_reset_ack,
      send_inst_ack          => send_inst_ack,
      load_ack               => load_ack,
      store_ack              => store_ack,
      soft_read_ack          => user_IP2Bus_RdAck,
      soft_write_ack         => user_IP2Bus_WrAck,
      state                  => state
    );

  ---
  -- ARM Thumb(R) decoder
  ---
  DECODER_I : entity simple_processor_v1_00_a.decoder
    generic map
    (
      data_width             => 32
    )
    port map
    (
      data                   => raw_instruction,
      condition              => condition,
      opcode                 => opcode,
      op_type                => op_type,
      Rm                     => Rm,
      Rn                     => Rn,
      Rs                     => Rs,
      Rd                     => Rd,
      Imm_3                  => Imm_3,
      Imm_5                  => Imm_5,
      Imm_8                  => Imm_8,
      Imm_11                 => Imm_11,
      zero                   => zero,
      flag_lr_pc             => flag_lr_pc,
      flags_h                => flags_h,
      decode_ack             => decode_ack,
      state                  => state
    );

  ---
  -- Arithmetic Logical Unit
  ---
  ALU_I : entity simple_processor_v1_00_a.alu
    generic map
    (
      data_width             => 32
    )
    port map
    (
      a                      => alu_a,
      b                      => alu_b,
      zero                   => zero,
      opcode                 => opcode,
      result                 => alu_out,
      n                      => flag_n,
      z                      => flag_z,
      c                      => flag_c,
      v                      => flag_v,
      alu_reset_ack          => alu_reset_ack,
      math_ack               => math_ack,
      state                  => state
  );

  ---
  -- Xilinx(R) provided procedure for selecting data to send back to EDK(R)
  ---
  IP2BUS_DATA_MUX_PROC : process( ipif_Bus2IP_CS, user_IP2Bus_Data )
  is
  begin

    case ipif_Bus2IP_CS (1 downto 0)
    is
      when "01"   => ipif_IP2Bus_Data <= user_IP2Bus_Data;
      when "10"   => ipif_IP2Bus_Data <= (others => '0');
      when others => ipif_IP2Bus_Data <= (others => '0');
    end case;

  end process IP2BUS_DATA_MUX_PROC;

  -- The following code is provided by Xilinx(R) to aid its AXI4_Lite peripheral
  --  in relaying data back to EDK(R)
  ipif_IP2Bus_WrAck    <= user_IP2Bus_WrAck or rst_IP2Bus_WrAck;
  ipif_IP2Bus_RdAck    <= user_IP2Bus_RdAck;
  ipif_IP2Bus_Error    <= user_IP2Bus_Error or rst_IP2Bus_Error;
  user_Bus2IP_RdCE     <= ipif_Bus2IP_RdCE(USER_NUM_REG-1 downto 0);
  user_Bus2IP_WrCE     <= ipif_Bus2IP_WrCE(USER_NUM_REG-1 downto 0);
  ipif_Bus2IP_Reset    <= not ipif_Bus2IP_Resetn;
  rst_Bus2IP_Reset_tmp <= not rst_Bus2IP_Reset;

end IMP;
