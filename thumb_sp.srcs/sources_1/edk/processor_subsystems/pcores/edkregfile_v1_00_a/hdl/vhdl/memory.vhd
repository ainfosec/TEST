-- Filename:          memory.vhd
-- Version:           1.00.a
-- Description:       contains word-addressed memory accessible through
--                    multiple clock controlled I/O signals
-- Date Created:      Thu, Dec 05, 2013 22:03:13
-- Last Modified:     Thu, Dec 19, 2013 19:15:57
-- VHDL Standard:     VHDL'93
-- Author:            Sean McClain <mcclains@ainfosec.com>
-- Copyright:         (c) 2013 Assured Information Security, All Rights Reserved

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

---
-- contains word-addressed memory
---
entity memory
is
  generic
  (
    -- Number of real 32-bit addressable memory registers
    NUM_REGS     : integer              := 1024;

    -- Number of clock controlled I/O channels exposed to other hardware
    NUM_CHANNELS : integer              := 32;

    -- Bit width of a single word
    DATA_WIDTH   : integer              := 32
  );
  port
  (
    -- Clock-controlled I/O channels which can be individually
    --  enabled/disabled for reads and writes
    addresses     : in    std_logic_vector(NUM_CHANNELS*DATA_WIDTH-1 downto 0);
    data_in       : in    std_logic_vector(NUM_CHANNELS*DATA_WIDTH-1 downto 0);
    data_out      : out   std_logic_vector(NUM_CHANNELS*DATA_WIDTH-1 downto 0);
    enables       : in    std_logic_vector(NUM_CHANNELS-1 downto 0);

    -- Side channels for software data
    side_address  : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    side_data_in  : in    std_logic_vector(DATA_WIDTH-1 downto 0);
    side_data_out : out   std_logic_vector(DATA_WIDTH-1 downto 0);
    side_enable   : in    std_logic;

    -- Whether to read or write during the current clock cycle
    -- 0 : read, 1 : write
    mode          : in    std_logic;

    -- acknowledge reads or writes were performed
    rd_ack        : out   std_logic;
    wr_ack        : out   std_logic;

    -- Initialize memory
    reset         : in    std_logic;

    -- Clock
    clock         : in    std_logic
  );

end entity memory;

architecture IMP of memory
is

  -- defines a set of word addressable registers
  type regs_type is array(NUM_REGS-1 downto 0)
    of std_logic_vector(DATA_WIDTH-1 downto 0);

  -- defines an array of word-addressable data
  type separated_channels is array(NUM_CHANNELS downto 0)
    of std_logic_vector(DATA_WIDTH-1 downto 0);

  -- all the registers and data memory
  signal mem : regs_type;

  -- AND'ed together mode and enable bits, and clock, for read enables
  signal channel_enable : separated_channels;

  -- default value to read out
  signal zero : std_logic_vector(DATA_WIDTH-1 downto 0);

  -- for setting acknowledgement signals on any high enable bit
  signal rd_ack_search : std_logic_vector(NUM_CHANNELS+1 downto 0);
  signal wr_ack_search : std_logic_vector(NUM_CHANNELS+1 downto 0);

begin

  -- initialize to avoid high impedance signals
  zero <= (others => '0');
  rd_ack_search(0) <= '0';
  wr_ack_search(0) <= '0';

  ---
  -- Set acknowledgements
  ---
  DO_ACKS : for chan in 0 to NUM_CHANNELS-1
  generate

    -- handle sensitivities
    channel_enable(chan) <= (
        3 => mode,
        2 => enables(chan),
        1 => clock,
        0 => reset,
        others => '0'
        );

    -- set ack signals
    with channel_enable(chan)(3 downto 0) select rd_ack_search(chan+1) <=
      '1' when "0110",
      rd_ack_search(chan) when others;
    with channel_enable(chan)(3 downto 0) select wr_ack_search(chan+1) <=
      '1' when "1110",
      wr_ack_search(chan) when others;

  end generate DO_ACKS;

  -- do the same with side channel acks
  channel_enable(NUM_CHANNELS)(DATA_WIDTH-1 downto 4) <= (others => '0');
  channel_enable(NUM_CHANNELS)(3 downto 0) <=
    mode & side_enable & clock & reset;
  with channel_enable(NUM_CHANNELS)(3 downto 0)
  select rd_ack_search(NUM_CHANNELS+1) <=
    '1' when "0110",
    rd_ack_search(NUM_CHANNELS) when others;
  with channel_enable(NUM_CHANNELS)(3 downto 0)
  select wr_ack_search(NUM_CHANNELS+1) <=
    '1' when "1110",
    wr_ack_search(NUM_CHANNELS) when others;

  -- send out OR'ed together acks
  rd_ack <= rd_ack_search(NUM_CHANNELS+1);
  wr_ack <= wr_ack_search(NUM_CHANNELS+1);

  ---
  -- Handle all memory -> channel I/O
  ---
  DO_READS : process ( rd_ack_search(NUM_CHANNELS+1) )
  is
    variable address : integer;
  begin

    -- reset requested, clear memory
    if reset = '1'
    then
      for chan in NUM_CHANNELS-1 downto 0
      loop
        data_out(DATA_WIDTH*(chan+1)-1 downto DATA_WIDTH*chan) <= zero;
      end loop;
      side_data_out <= zero;

    -- read op requested
    elsif rd_ack_search(NUM_CHANNELS+1) = '1'
    then

      -- read to side channel
      if channel_enable(NUM_CHANNELS)(3 downto 0) = "0110"
      then
        address := to_integer(unsigned(side_address));
        side_data_out <= mem(address);

      -- read to data channels
      else
        for chan in NUM_CHANNELS-1 downto 0
        loop
          if channel_enable(chan)(3 downto 0) = "0110"
          then
            address := to_integer (unsigned (
                addresses(DATA_WIDTH*(chan+1)-1 downto DATA_WIDTH*chan)
                ));
            if    address < 0
            then
              address := 0;
            elsif address > NUM_REGS or address = NUM_REGS
            then
              address := NUM_REGS-1;
            end if;
            data_out(DATA_WIDTH*(chan+1)-1 downto DATA_WIDTH*chan) <=
              mem(address);
          end if;
        end loop;
      end if;

    end if;

  end process DO_READS;

  ---
  -- Handle all channel -> memory I/O
  ---
  DO_WRITES : process ( wr_ack_search(NUM_CHANNELS+1) )
  is
    variable address : integer;
  begin

    -- reset requested, clear memory
    if reset = '1'
    then
      for reg in NUM_REGS-1 downto 0
      loop
        mem(reg) <= zero;
      end loop;

    -- write op requested
    elsif wr_ack_search(NUM_CHANNELS+1) = '1'
    then

      -- write from side channel
      if channel_enable(NUM_CHANNELS)(3 downto 0) = "1110"
      then
        address := to_integer(unsigned(side_address));
        mem(address) <= side_data_in;

      -- write from data channels
      else
        for chan in NUM_CHANNELS-1 downto 0
        loop
          if channel_enable(chan)(3 downto 0) = "1110"
          then
            address := to_integer (unsigned (
                addresses(DATA_WIDTH*(chan+1)-1 downto DATA_WIDTH*chan)
                ));
            if    address < 0
            then
              address := 0;
            elsif address > NUM_REGS or address = NUM_REGS
            then
              address := NUM_REGS-1;
            end if;
            mem(address) <=
              data_in(DATA_WIDTH*(chan+1)-1 downto DATA_WIDTH*chan);
          end if;
        end loop;
      end if;

    end if;

  end process DO_WRITES;

end IMP;
