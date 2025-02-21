library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package pkg_7seg_encode is

  ----------------------------------------------------------------------------
  -- 7-seg patterns for letters (active low)
  ----------------------------------------------------------------------------
  constant seg_for_S   : std_logic_vector(6 downto 0) := "0010010"; 
  constant seg_for_E   : std_logic_vector(6 downto 0) := "0000110";
  constant seg_for_L   : std_logic_vector(6 downto 0) := "1000111";
  constant seg_for_C   : std_logic_vector(6 downto 0) := "1000110";
  constant seg_for_T   : std_logic_vector(6 downto 0) := "0000111";
  constant seg_for_W   : std_logic_vector(6 downto 0) := "1100011";
  constant seg_for_R   : std_logic_vector(6 downto 0) := "0101111";
  constant seg_for_I   : std_logic_vector(6 downto 0) := "1001111";
  constant seg_for_A   : std_logic_vector(6 downto 0) := "0100000";
  constant seg_for_D   : std_logic_vector(6 downto 0) := "0100001";
  constant seg_for_M   : std_logic_vector(6 downto 0) := "0001101";
  constant seg_for_O   : std_logic_vector(6 downto 0) := "0100011";
  constant seg_for_H   : std_logic_vector(6 downto 0) := "0001001";
  constant seg_for_P   : std_logic_vector(6 downto 0) := "0001100";
  constant seg_for_DASH: std_logic_vector(6 downto 0) := "0111111";
  constant seg_blank   : std_logic_vector(6 downto 0) := "1111111";  -- all segments off

  ----------------------------------------------------------------------------
  -- 7-seg patterns for decimal digits 0..9 (active low)
  ----------------------------------------------------------------------------
  constant seg_for_0 : std_logic_vector(6 downto 0) := "1000000"; -- 0
  constant seg_for_1 : std_logic_vector(6 downto 0) := "1111001"; -- 1
  constant seg_for_2 : std_logic_vector(6 downto 0) := "0100100"; -- 2
  constant seg_for_3 : std_logic_vector(6 downto 0) := "0110000"; -- 3
  constant seg_for_4 : std_logic_vector(6 downto 0) := "0011001"; -- 4
  constant seg_for_5 : std_logic_vector(6 downto 0) := "0010010"; -- 5
  constant seg_for_6 : std_logic_vector(6 downto 0) := "0000010"; -- 6
  constant seg_for_7 : std_logic_vector(6 downto 0) := "1111000"; -- 7
  constant seg_for_8 : std_logic_vector(6 downto 0) := "0000000"; -- 8
  constant seg_for_9 : std_logic_vector(6 downto 0) := "0010000"; -- 9

  ----------------------------------------------------------------------------
  -- Array type for 6 digits on the display
  ----------------------------------------------------------------------------
  type t_digit_array is array(0 to 5) of std_logic_vector(6 downto 0);

end package pkg_7seg_encode;

-----------------------------------------------------------------------------
-- Typically, for just constants and a type, we don't need a package body.
-- But if your tool requires it, you can add:
-----------------------------------------------------------------------------
package body pkg_7seg_encode is
  -- (No additional definitions needed here)
end package body pkg_7seg_encode;
