library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg_7seg is
  function char_to_7seg(c : character) return std_logic_vector(6 downto 0);
end package pkg_7seg;

package body pkg_7seg is

  function char_to_7seg(c : character) return std_logic_vector(6 downto 0) is
    variable segments : std_logic_vector(6 downto 0);
  begin
    -- For demonstration, assume active low 7-segment (0=ON, 1=OFF).
    -- We map each letter to a pattern. (You can fill out more.)
    -- segments = g f e d c b a
    case c is
      when 'A' => segments := "0001000"; -- Example pattern for 'A'
      when 'B' => segments := "1100000"; 
      when 'C' => segments := "0110001";
      when 'D' => segments := "1000010";
      when 'E' => segments := "0110000";
      when 'F' => segments := "0111000";
		when 'I' => segments := "1001111";
      when 'L' => segments := "1110001";
      when 'O' => segments := "1100010";
		when 'P' => segments := "0011000";
      when 'R' => segments := "1111010";
      when 'S' => segments := "0101000";
      when 'T' => segments := "1110000";
      when 'W' => segments := "1100011";
      when 'M' => segments := "1011000";
      when ' ' => segments := "1111111"; -- blank/off
      when others =>
        segments := "1111111"; -- default = blank/off
    end case;
    return segments;
  end function char_to_7seg;

end package body pkg_7seg;
