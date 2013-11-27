-- Filename:          decoder.vhd
-- Version:           1.00.a
-- Description:       takes a binary function and turns it into fetched data
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Tue, Nov 26, 2013 14:08:03
-- VHDL Standard:     VHDL'93
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
-- Converts a 16 bit ARM Thumb instruction in binary format into
--  an opcode and a series of arguments.
---
entity decoder
is
  generic
  (
    -- bit width of the data in this file (typically 32 or 64)
    DATA_WIDTH  : integer            := 32
  );
  port
  (
    -- 16 bit binary instruction
    data       : in    std_logic_vector(15 downto 0);

    -- 4 condition bits used for conditional branching
    condition  : out   std_logic_vector(15 downto 0);

    -- code for one of 64 unique ARM Thumb operations
    opcode     : out   integer;

    -- hint provided for this opcode's functionality
    op_type    : out   integer;

    -- one of four data register addresses to pull information from
    --  or store information in
    Rm         : out   std_logic_vector(2  downto 0);

    -- one of four data register addresses to pull information from
    --  or store information in
    Rn         : out   std_logic_vector(2  downto 0);

    -- one of four data register addresses to store information in
    --  (this register, destination, is never used to pull information from)
    Rs         : out   std_logic_vector(2  downto 0);

    -- one of four data register addresses to pull information from
    --  (this register, "source", is never used to store information in)
    Rd         : out   std_logic_vector(2  downto 0);

    -- a 3-bit immediate value, pulled directly from the instruction binary
    Imm_3      : out   std_logic_vector(2  downto 0);

    -- a 5-bit immediate value, pulled directly from the instruction binary
    Imm_5      : out   std_logic_vector(4  downto 0);

    -- a 8-bit immediate value, pulled directly from the instruction binary
    Imm_8      : out   std_logic_vector(7  downto 0);

    -- an 11-bit immediate value, pulled directly from the instruction binary
    Imm_11     : out   std_logic_vector(10 downto 0);

    -- convenience values for comparisons
    zero       : out   std_logic_vector(DATA_WIDTH-1 downto 0);

    -- a flag used by the PUSH and POP instructions
    flag_lr_pc : out   std_logic;

    -- flags used by ADD_Rd_Rm, CMP_Rm_Rn_2, MOV_Rd, RM, BX, and BLX
    flags_h    : out   std_logic_vector(1 downto 0);

    -- acknowledge an instruction has been decoded
    decode_ack : out   std_logic;

    -- lets us know when to trigger a decode event
    state      : in    integer
  );

end entity decoder;

architecture IMP of decoder
is

begin
  -- decode condition
  DECODE_CONDITION: for i in 15 downto 0 generate
    condition(i) <= '1'
      when  data(11 downto 8) = std_logic_vector(to_unsigned(i, 4))
      else '0';
  end generate DECODE_CONDITION;

  -- pull out immediate values and flags
  Imm_3      <= data(8 downto 6);
  Imm_5      <= data(10 downto 6);
  Imm_8      <= data(7 downto 0);
  Imm_11     <= data(10 downto 0);
  flag_lr_pc <= data(8);
  flags_h    <= data(7 downto 6);

  -- send out zeroes
  zero       <= (others => '0');

  -- decode data and opcodes
  DATA_DECODER : process ( state )
  is
    variable unclean : std_logic;
    variable Rm_l    : std_logic_vector(2 downto 0);
    variable Rn_l    : std_logic_vector(2 downto 0);
    variable Rs_l    : std_logic_vector(2 downto 0);
    variable Rd_l    : std_logic_vector(2 downto 0);
  begin

    DECODE_EVENT : if state = DO_DECODE
    then

      -- only work with clean data
      unclean := '0';
      for i in 15 downto 0
      loop
        if data(i) /= '0' and data(i) /= '1'
        then
          unclean := '1';
        end if;
      end loop;

      -- filter out unused and unpredictable opcodes
      if   unclean = '1'
        or data(15 downto 6) = "0100010000"
        or data(15 downto 6) = "0100010100"
        or data(15 downto 6) = "0100011000"
        or (data(15 downto 8) = "01000111" and data(2) = '1')
        or data(15 downto 8) = "10110001"
        or (data(15 downto 11) = "10110" and data(9) = '1')
        or data(15 downto 10) = "101110"
        or data(15 downto 8) = "10111111"
        or data(15 downto 8) = "11011110"
      then
        opcode  <= UNUSED;
        op_type <= UNUSED;
        Rm_l := (others => '0');
        Rn_l := (others => '0');
        Rs_l := (others => '0');
        Rd_l := (others => '0');

      -- valid opcode, go ahead and decode
      else
        case data(15 downto 13)
        is

          -- 000CCIIIIIMMMDDD LSL, LSR, ASR
          -- 00011CCMMMNNNDDD ADD, SUB
          -- 00011CCIIINNNDDD ADD, SUB
          when "000"  =>
            case data(12 downto 11)
            is

              -- 000CCIIIIIMMMDDD LSL, LSR, ASR

              -- LSL
              when "00"   =>
                opcode  <= LSL_Rd_Rm_I;
                op_type <= ARITH_IM5_RGM_DST;
                Rm_l := data(5 downto 3);
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(2 downto 0);

              -- LSR
              when "01"   =>
                opcode  <= LSR_Rd_Rm_I;
                op_type <= ARITH_IM5_RGM_DST;
                Rm_l := data(5 downto 3);
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(2 downto 0);

              -- ASR
              when "10"   =>
                opcode  <= ASR_Rd_Rm_I;
                op_type <= ARITH_IM5_RGM_DST;
                Rm_l := data(5 downto 3);
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(2 downto 0);

              -- 00011CCMMMNNNDDD ADD, SUB
              -- 00011CCIIINNNDDD ADD, SUB
              when others =>
                case data(10 downto 9)
                is

                  -- 00011CCMMMNNNDDD ADD, SUB

                  -- ADD
                  when "00"   =>
                    opcode  <= ADD_Rd_Rn_Rm;
                    op_type <= ARITH_RGM_RGN_DST;
                    Rm_l := data(8 downto 6);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- SUB
                  when "01"   =>
                    opcode  <= SUB_Rd_Rn_Rm;
                    op_type <= ARITH_RGM_RGN_DST;
                    Rm_l := data(8 downto 6);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- 00011CCIIINNNDDD ADD, SUB

                  -- ADD
                  when "10"   =>
                    opcode  <= ADD_Rd_Rn_I;
                    op_type <= ARITH_IM3_RGN_DST;
                    Rm_l := (others => '0');
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- SUB
                  when others =>
                    opcode  <= SUB_Rd_Rn_I;
                    op_type <= ARITH_IM3_RGN_DST;
                    Rm_l := (others => '0');
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                end case;
            end case;

          -- 001CCDDDIIIIIIII MOV, ADD, SUB
          -- 001CCNNNIIIIIIII CMP
          when "001"  =>
            case data(12 downto 11)
            is

              -- 001CCDDDIIIIIIII MOV

              -- MOV
              when "00"   =>
                opcode  <= MOV_Rd_I;
                op_type <= ARITH_DST_IM8;
                Rm_l := (others => '0');
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(10 downto 8);

              -- 001CCNNNIIIIIIII CMP

              -- CMP
              when "01"   =>
                opcode  <= CMP_Rn_I;
                op_type <= TEST_RGN_IM8;
                Rm_l := (others => '0');
                Rn_l := data(10 downto 8);
                Rs_l := (others => '0');
                Rd_l := (others => '0');

              -- 001CCDDDIIIIIIII ADD, SUB

              -- ADD
              when "10"   =>
                opcode  <= ADD_Rd_I;
                op_type <= ARITH_DST_IM8;
                Rm_l := (others => '0');
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(10 downto 8);

              -- SUB
              when others =>
                opcode  <= SUB_Rd_I;
                op_type <= ARITH_DST_IM8;
                Rm_l := (others => '0');
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(10 downto 8);

            end case;

          -- 010000CCCCMMMDDD AND, EOR, ADC, SBC, NEG, ORR, MUL, MVN
          -- 010000CCCCSSSDDD LSL, LSR, ASR, ROR
          -- 0100001CCCNNNMMM TST, CMP, CMN, BIC
          -- 010001C0HHMMMDDD ADD, MOV
          -- 01000101HHNNNDDD CMP
          -- 01000111CHMMM000 BX, BLX
          -- 01001DDDIIIIIIII LDR
          -- 0101CCCMMMNNNDDD STR, STRH, STRB, LDRSB, LDR, LDRH, LDRB, LDRSH
          when "010"  =>
            case data(12 downto 10)
            is

              -- 010000000CMMMDDD AND, EOR
              -- 0100000CCCSSSDDD LSL, LSR, ASR
              -- 010000CCCCMMMDDD ADC, SBC
              -- 0100000111SSSDDD ROR
              -- 0100001000NNNMMM TST
              -- 0100001001MMMDDD NEG, ORR, MUL, MVN
              -- 010000101CNNNMMM CMP, CMN
              -- 010000110CMMMDDD ORR, MUL
              -- 0100001110NNNMMM BIC
              -- 0100001111MMMDDD MVN
              when "000" =>
                case data(9 downto 6)
                is

                  -- 010000000CMMMDDD AND, EOR

                  -- AND
                  when "0000" =>
                    opcode  <= AND_Rd_Rm;
                    op_type <= ARITH_RGM_DST;
                    Rm_l := data(5 downto 3);
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- EOR
                  when "0001" =>
                    opcode  <= EOR_Rd_Rm;
                    op_type <= ARITH_RGM_DST;
                    Rm_l := data(5 downto 3);
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- 0100000CCCSSSDDD LSL, LSR, ASR

                  -- LSL
                  when "0010" =>
                    opcode  <= LSL_Rd_Rs;
                    op_type <= ARITH_SRC_DST;
                    Rm_l := (others => '0');
                    Rn_l := (others => '0');
                    Rs_l := data(5 downto 3);
                    Rd_l := data(2 downto 0);

                  -- LSR
                  when "0011" =>
                    opcode  <= LSR_Rd_Rs;
                    op_type <= ARITH_SRC_DST;
                    Rm_l := (others => '0');
                    Rn_l := (others => '0');
                    Rs_l := data(5 downto 3);
                    Rd_l := data(2 downto 0);

                  -- ASR
                  when "0100" =>
                    opcode  <= ASR_Rd_Rs;
                    op_type <= ARITH_SRC_DST;
                    Rm_l := (others => '0');
                    Rn_l := (others => '0');
                    Rs_l := data(5 downto 3);
                    Rd_l := data(2 downto 0);

                  -- 010000CCCCMMMDDD ADC, SBC

                  -- ADC
                  when "0101" =>
                    opcode  <= ADC_Rd_Rm;
                    op_type <= ARITH_RGM_DST;
                    Rm_l := data(5 downto 3);
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- SBC
                  when "0110" =>
                    opcode  <= SBC_Rd_Rm;
                    op_type <= ARITH_RGM_DST;
                    Rm_l := data(5 downto 3);
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- 0100000111SSSDDD ROR

                  -- ROR
                  when "0111" =>
                    opcode  <= ROR_Rd_Rs;
                    op_type <= ARITH_SRC_DST;
                    Rm_l := (others => '0');
                    Rn_l := (others => '0');
                    Rs_l := data(5 downto 3);
                    Rd_l := data(2 downto 0);

                  -- 0100001000NNNMMM TST

                  -- TST
                  when "1000" =>
                    opcode  <= TST_Rm_Rn;
                    op_type <= TEST_RGN_RGM;
                    Rm_l := data(2 downto 0);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

                  -- 0100001001MMMDDD NEG, ORR, MUL, MVN

                  -- NEG
                  when "1001" =>
                    opcode  <= NEG_Rd_Rm;
                    op_type <= ARITH_RGM_DST;
                    Rm_l := data(5 downto 3);
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- 010000101CNNNMMM CMP, CMN

                  -- CMP
                  when "1010" =>
                    opcode  <= CMP_Rm_Rn;
                    op_type <= TEST_RGN_RGM;
                    Rm_l := data(2 downto 0);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

                  -- CMN
                  when "1011" =>
                    opcode  <= CMN_Rm_Rn;
                    op_type <= TEST_RGN_RGM;
                    Rm_l := data(2 downto 0);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

                  -- 010000110CMMMDDD ORR, MUL

                  -- ORR
                  when "1100" =>
                    opcode  <= ORR_Rd_Rm;
                    op_type <= ARITH_RGM_DST;
                    Rm_l := data(5 downto 3);
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- MUL
                  when "1101" =>
                    opcode  <= MUL_Rd_Rm;
                    op_type <= ARITH_RGM_DST;
                    Rm_l := data(5 downto 3);
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- 0100001110NNNMMM BIC

                  -- BIC
                  when "1110" =>
                    op_type <= TEST_RGN_RGM;
                    opcode  <= BIC_Rn_Rm;
                    Rm_l := data(2 downto 0);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

                  -- 0100001111MMMDDD MVN

                  -- MVN
                  when others =>
                    op_type <= ARITH_RGM_DST;
                    opcode  <= MVN_Rd_Rm;
                    Rm_l := data(5 downto 3);
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                end case;

              -- 01000100HHMMMDDD ADD
              -- 01000101HHNNNDDD CMP
              -- 01000110HHMMMDDD MOV
              when "001" =>
                case data(9 downto 8)
                is

                  -- 01000100HHMMMDDD ADD

                  -- ADD
                  when "00"   =>
                    opcode  <= ADD_Rd_Rm;
                    op_type <= ARITH_HFLAGS;
                    Rm_l := data(5 downto 3);
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- 01000101HHNNNDDD CMP

                  -- CMP
                  when "01"   =>
                    opcode  <= CMP_Rm_Rn_2;
                    op_type <= TEST_HFLAGS;
                    Rm_l := data(2 downto 0);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

                  -- 01000110HHMMMDDD MOV

                  -- MOV
                  when "10"   =>
                    opcode  <= MOV_Rd_Rm;
                    op_type <= ARITH_HFLAGS;
                    Rm_l := data(5 downto 3);
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- 01000111CHMMM000 BX, BLX
                  when others =>
                    case data(7)
                    is

                      -- 01000111CHMMM000 BX, BLX

                      -- BX
                      when '0' =>
                        opcode  <= BX_Rm;
                        op_type <= TEST_HFLAGS;
                        Rm_l := data(5 downto 3);
                        Rn_l := (others => '0');
                        Rs_l := (others => '0');
                        Rd_l := (others => '0');

                      -- BLX
                      when others =>
                        opcode  <= BLX_Rm;
                        op_type <= TEST_HFLAGS;
                        Rm_l := data(5 downto 3);
                        Rn_l := (others => '0');
                        Rs_l := (others => '0');
                        Rd_l := (others => '0');

                    end case;
                end case;

              -- 01001DDDIIIIIIII LDR

              -- LDR
              when "010" =>
                opcode  <= LDR_Rd_IPC;
                op_type <= LOAD_DST_IM8;
                Rm_l := (others => '0');
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(10 downto 8);

              -- LDR (again, HDL has no flow-through in case statements)
              when "011" =>
                opcode  <= LDR_Rd_IPC;
                op_type <= LOAD_DST_IM8;
                Rm_l := (others => '0');
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(10 downto 8);

              -- 0101CCCMMMNNNDDD STR, STRH, STRB, LDRSB, LDR, LDRH, LDRB, LDRSH
              when others =>
                case data(11 downto 9)
                is

                  -- STR
                  when "000"  =>
                    opcode  <= STR_Rd_Rn_Rm;
                    op_type <= STORE_RGM_RGN_DST;
                    Rm_l := data(8 downto 6);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- STRH
                  when "001"  =>
                    opcode  <= STRH_Rd_Rn_Rm;
                    op_type <= STORE_RGM_RGN_DST;
                    Rm_l := data(8 downto 6);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- STRB
                  when "010"  =>
                    opcode  <= STRB_Rd_Rn_Rm;
                    op_type <= STORE_RGM_RGN_DST;
                    Rm_l := data(8 downto 6);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- LDRSB
                  when "011"  =>
                    opcode  <= LDRSB_Rd_Rn_Rm;
                    op_type <= LOAD_RGM_RGN_DST;
                    Rm_l := data(8 downto 6);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- LDR
                  when "100"  =>
                    opcode  <= LDR_Rd_Rn_Rm;
                    op_type <= LOAD_RGM_RGN_DST;
                    Rm_l := data(8 downto 6);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- LDRH
                  when "101"  =>
                    opcode  <= LDRH_Rd_Rn_Rm;
                    op_type <= LOAD_RGM_RGN_DST;
                    Rm_l := data(8 downto 6);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- LDRB
                  when "110"  =>
                    opcode  <= LDRB_Rd_Rn_Rm;
                    op_type <= LOAD_RGM_RGN_DST;
                    Rm_l := data(8 downto 6);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                  -- LDRSH
                  when others =>
                    opcode  <= LDRSH_Rd_Rn_Rm;
                    op_type <= LOAD_RGM_RGN_DST;
                    Rm_l := data(8 downto 6);
                    Rn_l := data(5 downto 3);
                    Rs_l := (others => '0');
                    Rd_l := data(2 downto 0);

                end case;

            end case;

          -- 011CCIIIIINNNDDD STR, LDR, STRB, LDRB
          when "011"  =>
            case data(12 downto 11)
            is

              -- STR
              when "00"   =>
                opcode  <= STR_Rd_Rn_I;
                op_type <= STORE_IM5_RGN_DST;
                Rm_l := (others => '0');
                Rn_l := data(5 downto 3);
                Rs_l := (others => '0');
                Rd_l := data(2 downto 0);

              -- LDR
              when "01"   =>
                opcode  <= LDR_Rd_Rn_I;
                op_type <= LOAD_IM5_RGN_DST;
                Rm_l := (others => '0');
                Rn_l := data(5 downto 3);
                Rs_l := (others => '0');
                Rd_l := data(2 downto 0);

              -- STRB
              when "10"   =>
                opcode  <= STRB_Rd_Rn_I;
                op_type <= STORE_IM5_RGN_DST;
                Rm_l := (others => '0');
                Rn_l := data(5 downto 3);
                Rs_l := (others => '0');
                Rd_l := data(2 downto 0);

              -- LDRB
              when others =>
                opcode  <= LDRB_Rd_Rn_I;
                op_type <= LOAD_IM5_RGN_DST;
                Rm_l := (others => '0');
                Rn_l := data(5 downto 3);
                Rs_l := (others => '0');
                Rd_l := data(2 downto 0);
            end case;

          -- 100CCIIIIINNNDDD STRH, LDRH
          -- 100CCDDDIIIIIIII STR, LDR
          when "100"  =>
            case data(12 downto 11)
            is

              -- 100CCIIIIINNNDDD STRH, LDRH

              -- STRH
              when "00"   =>
                opcode  <= STRH_Rd_Rn_I;
                op_type <= STORE_IM5_RGN_DST;
                Rm_l := (others => '0');
                Rn_l := data(5 downto 3);
                Rs_l := (others => '0');
                Rd_l := data(2 downto 0);

              -- LDRH
              when "01"   =>
                opcode  <= LDRH_Rd_Rn_I;
                op_type <= LOAD_IM5_RGN_DST;
                Rm_l := (others => '0');
                Rn_l := data(5 downto 3);
                Rs_l := (others => '0');
                Rd_l := data(2 downto 0);

              -- 100CCDDDIIIIIIII STR, LDR

              -- STR
              when "10"   =>
                opcode  <= STR_Rd_I;
                op_type <= STORE_DST_IM8;
                Rm_l := (others => '0');
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(10 downto 8);

              -- LDR
              when others =>
                opcode  <= LDR_Rd_ISP;
                op_type <= LOAD_DST_IM8;
                Rm_l := (others => '0');
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(10 downto 8);

            end case;

          -- 1010CDDDIIIIIIII ADD, ADD
          -- 1011CCCCIIIIIIII SUB, BKPT
          -- 1011C10FIIIIIIII PUSH, POP
          when "101"  =>
            case data(12 downto 11)
            is

              -- 1010CDDDIIIIIIII ADD, ADD

              -- ADD
              when "00"   =>
                opcode  <= ADD_Rd_IPC;
                op_type <= ARITH_DST_IM8;
                Rm_l := (others => '0');
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(10 downto 8);

              -- ADD
              when "01"   =>
                opcode  <= ADD_Rd_ISP;
                op_type <= ARITH_DST_IM8;
                Rm_l := (others => '0');
                Rn_l := (others => '0');
                Rs_l := (others => '0');
                Rd_l := data(10 downto 8);

              -- 1011CCCCIIIIIIII SUB, BKPT
              -- 1011C10FIIIIIIII PUSH, POP
              when others =>
                case data(11 downto 9)
                is

                  -- 101100001IIIIIII SUB

                  -- SUB
                  when "000" =>
                    opcode  <= SUB_I;
                    op_type <= ARITH_IM8;
                    Rm_l := (others => '0');
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

                  -- 1011C10FIIIIIIII PUSH, POP

                  -- PUSH
                  when "010" =>
                    opcode  <= PUSH_RL_LR;
                    op_type <= PUSH_POP;
                    Rm_l := (others => '0');
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

                  -- POP
                  when "110" =>
                    opcode  <= POP_RL_PC;
                    op_type <= PUSH_POP;
                    Rm_l := (others => '0');
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

                  -- 10111111IIIIIIII BKPT

                  -- BKPT
                  when others =>
                    opcode  <= BKPT_I;
                    op_type <= ARITH_IM8;
                    Rm_l := (others => '0');
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

              end case;
            end case;

          -- 1100CNNNIIIIIIII STMIA, LDMIA
          -- 1101CCCCIIIIIIII B_COND, SWI
          when "110"  =>
            case data(12 downto 11)
            is

              -- 1100CNNNIIIIIIII STMIA, LDMIA

              -- STMIA
              when "00"   =>
                opcode  <= STMIA_RN_RL;
                op_type <= STORE_REGLIST;
                Rm_l := (others => '0');
                Rn_l := data(10 downto 8);
                Rs_l := (others => '0');
                Rd_l := (others => '0');

              -- LDMIA
              when "01"   =>
                opcode  <= LDMIA_RN_RL;
                op_type <= LOAD_REGLIST;
                Rm_l := (others => '0');
                Rn_l := data(10 downto 8);
                Rs_l := (others => '0');
                Rd_l := (others => '0');

              -- 1101CCCCIIIIIIII B_COND, SWI
              when others =>
                case data(11 downto 8)
                is

                  -- SWI
                  when "1111" =>
                    opcode  <= SWI_I;
                    op_type <= ARITH_IM8;
                    Rm_l := (others => '0');
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

                  -- B_COND
                  when others =>
                    opcode  <= B_COND_I;
                    op_type <= ARITH_IM8;
                    Rm_l := (others => '0');
                    Rn_l := (others => '0');
                    Rs_l := (others => '0');
                    Rd_l := (others => '0');

                end case;
            end case;

          -- 111CCIIIIIIIIIII B_ADDR, BLX, BLX+, BL
          when others =>

            -- these are the same for all of these branch instructions
            op_type <= ARITH_IM11;
            Rm_l := (others => '0');
            Rn_l := (others => '0');
            Rs_l := (others => '0');
            Rd_l := (others => '0');

            case data(12 downto 11)
            is

              -- B_ADDR
              when "00"   =>
                opcode  <= B_I;

              -- BLX
              when "01"   =>
                opcode  <= BLX_L_I;

              -- BLX+
              when "10"   =>
                opcode  <= BLX_H_I;

              -- BL
              when others =>
                opcode  <= BL_I;

            end case;
        end case;
      end if;

      -- load up register addresses
      Rm   <= Rm_l;
      Rn   <= Rn_l;
      Rs   <= Rs_l;
      Rd   <= Rd_l;

      -- let the state machine know decode work is done
      decode_ack <= '1';

    end if DECODE_EVENT;

    -- reset state machine outputs
    CLEAR_FLAGS_EVENT : if state = DO_CLEAR_FLAGS
    then
      decode_ack <= '0';
    end if;

  end process DATA_DECODER;

end IMP;

