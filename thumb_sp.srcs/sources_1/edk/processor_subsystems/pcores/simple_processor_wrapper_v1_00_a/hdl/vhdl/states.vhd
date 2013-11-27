-- Filename:          states.vhd
-- Version:           1.00.a
-- Description:       Contains the ids used by the state_machine
-- Date Created:      Wed, Nov 13, 2013 20:59:21
-- Last Modified:     Tue, Nov 19, 2013 15:48:47
-- VHDL Standard:     VHDL'93
-- Author:            Sean McClain <mcclains@ainfosec.com>
-- Copyright:         (c) 2013 Assured Information Security, All Rights Reserved

-- states for the state machine
package states is
  constant DO_REG_FILE_RESET : integer          := 1;
  constant DO_ALU_RESET      : integer          := 2;
  constant DO_SEND_INST      : integer          := 3;
  constant DO_DECODE         : integer          := 4;
  constant DO_ALU_INPUT      : integer          := 5;
  constant DO_MATH           : integer          := 6;
  constant DO_LOAD_STORE     : integer          := 7;
  constant DO_SOFT_READ      : integer          := 8;
  constant DO_SOFT_WRITE     : integer          := 9;
  constant DO_CLEAR_FLAGS    : integer          := 10;
end package states;

package body states is

end package body states;
