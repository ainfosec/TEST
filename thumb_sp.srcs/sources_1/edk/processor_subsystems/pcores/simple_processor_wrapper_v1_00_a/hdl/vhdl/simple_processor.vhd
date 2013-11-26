-- Filename:          simple_processor.vhd
-- Version:           1.00.a
-- Description:       Simple ARM Thumb(R) processor
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Tue, Nov 26, 2013 14:09:25
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

library simple_processor_wrapper_v1_00_a;
use simple_processor_wrapper_v1_00_a.alu;
use simple_processor_wrapper_v1_00_a.decoder;
use simple_processor_wrapper_v1_00_a.reg_file;
use simple_processor_wrapper_v1_00_a.state_machine;
use simple_processor_wrapper_v1_00_a.opcodes.all;

---
-- A single instruction ARM Thumb(R) processor with no flow control
--  or branching.
---
entity simple_processor
is
  generic
  (
    -- number of registers in register file
    NUM_REGS                : integer          := 32;

    -- number of registers addressable by external peripheral
    ADDR_SPACE              : integer          := 32;

    -- width of a single register
    DATA_WIDTH              : integer          := 32
  );
  port
  (
    -- for communicating with an external peripheral
    extern_trigger          : in    std_logic;
    soft_addr_w             : in    std_logic_vector(ADDR_SPACE-1 downto 0);
    soft_addr_r             : in    std_logic_vector(ADDR_SPACE-1 downto 0);
    soft_data_w             : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    soft_data_r             : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    ack_read                : out   std_logic;
    ack_write               : out   std_logic;

    -- clock and reset
    Clk                     : in    std_logic;
    Reset                   : in    std_logic
  );

end entity simple_processor;

architecture IMP of simple_processor
is

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
  signal soft_read_ack       : std_logic;
  signal soft_write_ack      : std_logic;

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

  signal tmp_sig : std_logic;

begin

  ---
  -- Triggers all processor events in order
  ---
  STATE_MACHINE_I : entity simple_processor_wrapper_v1_00_a.state_machine
    port map
    (
      reg_file_reset_ack     => reg_file_reset_ack,
      alu_reset_ack          => alu_reset_ack,
      send_inst_ack          => send_inst_ack,
      decode_ack             => decode_ack,
      load_ack               => load_ack,
      math_ack               => math_ack,
      store_ack              => store_ack,
      soft_write_ack         => soft_write_ack,
      soft_read_ack          => soft_read_ack,
      extern_trigger         => extern_trigger,
      state                  => state,
      Clk                    => Clk,
      Reset                  => Reset
    );

  ---
  -- Register file, containing both registers and data memory
  ---
  REG_FILE_I : entity simple_processor_wrapper_v1_00_a.reg_file
    generic map
    (
      NUM_REGS               => NUM_REGS,
      SOFT_ADDRESS_WIDTH     => ADDR_SPACE,
      DATA_WIDTH             => DATA_WIDTH
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
      soft_data_i            => soft_data_w,
      soft_data_o            => soft_data_r,
      reg_file_reset_ack     => reg_file_reset_ack,
      send_inst_ack          => send_inst_ack,
      load_ack               => load_ack,
      store_ack              => store_ack,
      soft_read_ack          => soft_read_ack,
      soft_write_ack         => soft_write_ack,
      extern_trigger         => tmp_sig,
      read_axi_ack           => ack_read,
      write_axi_ack          => ack_write,
      state                  => state
    );

  ---
  -- ARM Thumb(R) decoder
  ---
  DECODER_I : entity simple_processor_wrapper_v1_00_a.decoder
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
  ALU_I : entity simple_processor_wrapper_v1_00_a.alu
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

end IMP;
