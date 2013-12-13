-- Filename:          state_machine.vhd
-- Version:           0.01
-- Description:       Controls event ordering
-- Date Created:      Tue, Nov 19, 2013 16:00:21
-- Last Modified:     Fri, Dec 06, 2013 00:24:45
-- VHDL Standard:     VHDL '93
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

---
-- Triggers all processor events in order
---
entity state_machine
is
  generic
  (
    SOFT_ADDRESS_WIDTH : integer          := 32
  );
  port
  (
    -- acknowledgements, sent when a signal has done its work
    reg_file_reset_ack : in    std_logic;
    alu_reset_ack      : in    std_logic;
    send_inst_ack      : in    std_logic;
    decode_ack         : in    std_logic;
    load_ack           : in    std_logic;
    math_ack           : in    std_logic;
    store_ack          : in    std_logic;
    soft_read_ack      : in    std_logic;
    soft_write_ack     : in    std_logic;
    decode_r_ack       : in    std_logic;
    decode_w_ack       : in    std_logic;

    -- An address in decoded integer form, used to trigger reads or writes
    soft_addr_r        : in    std_logic_vector (
        SOFT_ADDRESS_WIDTH-1 downto 0
        );
    soft_addr_w        : in    std_logic_vector (
        SOFT_ADDRESS_WIDTH-1 downto 0
        );

    -- Acknowledgement sent out on the AXI bus for reads and writes
    axi_read_ack       : out std_logic;
    axi_write_ack      : out std_logic;

    -- main state variable, used in a manner similar to a clock
    state              : inout integer range STATE_MIN to STATE_MAX;

    -- clock
    Clk                : in    std_logic;

    -- reset
    Reset              : in    std_logic
  );

end entity state_machine;

architecture IMP of state_machine
is

  -- last bit is true when a software read was requested
  signal software_read_event  : std_logic_vector(SOFT_ADDRESS_WIDTH downto 0);

  -- last bit is true when a software write was requested
  signal software_write_event : std_logic_vector(SOFT_ADDRESS_WIDTH downto 0);

begin

  ---
  -- Detect whether a software read or write was requested
  ---
  software_read_event(0)  <= '0';
  software_write_event(0) <= '0';
  DETECT_READ : for i in SOFT_ADDRESS_WIDTH downto 1 generate
    software_read_event(i)  <=
      '1' when soft_addr_r(i-1) = '1' or software_read_event(i-1)  = '1'
      else '0';
    software_write_event(i) <=
      '1' when soft_addr_w(i-1) = '1' or software_write_event(i-1) = '1'
      else '0';
  end generate DETECT_READ;
  axi_read_ack  <= software_read_event(SOFT_ADDRESS_WIDTH);
  axi_write_ack <= software_write_event(SOFT_ADDRESS_WIDTH);

  ---
  -- Select the current state
  ---
  DO_UPDATE : process (
      Clk, state,
      software_read_event, software_write_event,
      reg_file_reset_ack, alu_reset_ack,
      send_inst_ack, decode_ack, load_ack, math_ack, store_ack,
      soft_read_ack, soft_write_ack, decode_r_ack, decode_w_ack
      )
  is
  begin

    -- an AXI read was requested
    if    software_read_event(SOFT_ADDRESS_WIDTH) = '1'
      and state /= DO_DECODE_SOFT_READ
      and state /= DO_SOFT_READ
      and state /= DO_CLEAR_FLAGS
    then
      state <= DO_DECODE_SOFT_READ;

    -- reset requested
    elsif (Clk'event and Clk = '1')
      and Reset = '0'
    then
      state <= DO_REG_FILE_RESET;

    -- an AXI write was requested
    elsif (Clk'event and Clk = '1')
      and software_write_event(SOFT_ADDRESS_WIDTH) = '1'
    then
      state <= DO_DECODE_SOFT_WRITE;

    -- if no other work, start processing on a clock edge
    elsif (Clk'event and Clk = '1')
       or (Clk'event and Clk = '0')
    then
      state <= DO_SEND_INST;

    -- already processing, advance to the next state
    elsif state = DO_REG_FILE_RESET
      and (reg_file_reset_ack'event and reg_file_reset_ack = '1')
    then
      state <= DO_ALU_RESET;
    elsif state = DO_ALU_RESET
      and (alu_reset_ack'event and alu_reset_ack = '1')
    then
      state <= DO_CLEAR_FLAGS;
    elsif state = DO_SEND_INST
      and (send_inst_ack'event and send_inst_ack = '1')
    then
      state <= DO_DECODE;
    elsif state = DO_DECODE
      and (decode_ack'event and decode_ack = '1')
    then
      state <= DO_ALU_INPUT;
    elsif state = DO_ALU_INPUT
      and (load_ack'event and load_ack = '1')
    then
      state <= DO_MATH;
    elsif state = DO_MATH
      and (math_ack'event and math_ack = '1')
    then
      state <= DO_LOAD_STORE;
    elsif state = DO_LOAD_STORE
      and (store_ack'event and store_ack = '1')
    then
      state <= DO_CLEAR_FLAGS;
    elsif state = DO_DECODE_SOFT_READ
      and (decode_r_ack'event and decode_r_ack = '1')
    then
      state <= DO_SOFT_READ;
    elsif state = DO_DECODE_SOFT_WRITE
      and (decode_w_ack'event and decode_w_ack = '1')
    then
      state <= DO_SOFT_WRITE;
    elsif state = DO_SOFT_READ
      and (soft_read_ack'event and soft_read_ack = '1')
    then
      state <= DO_CLEAR_FLAGS;
    elsif state = DO_SOFT_WRITE
      and (soft_write_ack'event and soft_write_ack = '1')
    then
      state <= DO_CLEAR_FLAGS;
    end if;

  end process DO_UPDATE;

end IMP;
