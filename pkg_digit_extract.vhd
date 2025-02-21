library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library ieee_proposed;
use ieee_proposed.fixed_float_types.all;  
use ieee_proposed.fixed_pkg.all;          
use ieee_proposed.float_pkg.all;
library work;
use work.pkg_7seg_encode.all;  -- For DIGIT_LUT, seg_for_DASH, etc.

package pkg_digit_extract is

  -- Assuming t_digit_array is defined in pkg_7seg_encode
  function extract_3digit_integer(x : signed(15 downto 0)) return t_digit_array;

  function extract_3digit_fraction(x : unsigned(15 downto 0)) return t_digit_array;

end package pkg_digit_extract;


package body pkg_digit_extract is
    type seg_vector_array_t is array (0 to 15) of 
        std_logic_vector(6 downto 0);
    constant DIGIT_LUT : seg_vector_array_t := (
        0  => seg_for_0,
        1  => seg_for_1,
        2  => seg_for_2,
        3  => seg_for_3,
        4  => seg_for_4,
        5  => seg_for_5,
        6  => seg_for_6,
        7  => seg_for_7,
        8  => seg_for_8,
        9  => seg_for_9,
        10 => seg_blank,
        11 => seg_blank,
        12 => seg_blank,
        13 => seg_blank,
        14 => seg_blank,
        15 => seg_blank
    );

  ----------------------------------------------------------------------------
  -- Optimized extract_3digit_integer function
  ----------------------------------------------------------------------------
  function extract_3digit_integer(x : signed(15 downto 0)) return t_digit_array is
      variable d_array      : t_digit_array := (others => seg_blank);
      variable tmp          : integer := to_integer(x);
      variable negative     : boolean := false;
      variable hundreds_val : integer := 0;
      variable tens_val     : integer := 0;
      variable ones_val     : integer := 0;
  begin
      -- a) Saturate to ±999
      if tmp > 999 then
          tmp := 999;
      elsif tmp < -999 then
          tmp := -999;
      end if;

      -- b) Record sign, then make it positive
      if tmp < 0 then
          negative := true;
          tmp := -tmp;  -- now tmp is positive
      end if;

      -- c) Extract hundreds without loop
      if tmp >= 900 then
          hundreds_val := 9;
          tmp := tmp - 900;
      elsif tmp >= 800 then
          hundreds_val := 8;
          tmp := tmp - 800;
      elsif tmp >= 700 then
          hundreds_val := 7;
          tmp := tmp - 700;
      elsif tmp >= 600 then
          hundreds_val := 6;
          tmp := tmp - 600;
      elsif tmp >= 500 then
          hundreds_val := 5;
          tmp := tmp - 500;
      elsif tmp >= 400 then
          hundreds_val := 4;
          tmp := tmp - 400;
      elsif tmp >= 300 then
          hundreds_val := 3;
          tmp := tmp - 300;
      elsif tmp >= 200 then
          hundreds_val := 2;
          tmp := tmp - 200;
      elsif tmp >= 100 then
          hundreds_val := 1;
          tmp := tmp - 100;
      else
          hundreds_val := 0;
      end if;

      -- d) Extract tens without loop
      if tmp >= 90 then
          tens_val := 9;
          tmp := tmp - 90;
      elsif tmp >= 80 then
          tens_val := 8;
          tmp := tmp - 80;
      elsif tmp >= 70 then
          tens_val := 7;
          tmp := tmp - 70;
      elsif tmp >= 60 then
          tens_val := 6;
          tmp := tmp - 60;
      elsif tmp >= 50 then
          tens_val := 5;
          tmp := tmp - 50;
      elsif tmp >= 40 then
          tens_val := 4;
          tmp := tmp - 40;
      elsif tmp >= 30 then
          tens_val := 3;
          tmp := tmp - 30;
      elsif tmp >= 20 then
          tens_val := 2;
          tmp := tmp - 20;
      elsif tmp >= 10 then
          tens_val := 1;
          tmp := tmp - 10;
      else
          tens_val := 0;
      end if;

      -- e) The remainder is the ones digit
      ones_val := tmp;

      -- Assign digits to the array
      if negative then
          d_array(5) := seg_for_DASH;  -- sign in leftmost digit
      else
          d_array(5) := DIGIT_LUT(hundreds_val);
      end if;

      d_array(4) := DIGIT_LUT(tens_val);
      d_array(3) := DIGIT_LUT(ones_val);

      return d_array;
  end function;


  ----------------------------------------------------------------------------
  -- Optimized extract_3digit_fraction function
  ----------------------------------------------------------------------------
function extract_3digit_fraction(x : unsigned(15 downto 0))
  return t_digit_array is
    -- Use a 32-bit unsigned to hold the product and rounding constant.
    variable temp_int   : unsigned(31 downto 0);
    variable scaled_int : integer range 0 to 1000;
    variable d_array    : t_digit_array := (others => seg_blank);
    variable tmp_int    : integer;
begin
    -- Multiply by 1000 and add 32768 for rounding.
    temp_int := resize(x* to_unsigned(1000, 32) + to_unsigned(32768, 32), 32) ;
    -- Instead of dividing by 65536, shift right by 16 bits.
    scaled_int := to_integer(temp_int srl 16);
    
    if scaled_int > 999 then
       scaled_int := 999;
    end if;
    
    tmp_int := scaled_int / 100;
    d_array(2) := DIGIT_LUT(tmp_int);  -- hundreds digit
    
    tmp_int := (scaled_int / 10) mod 10;
    d_array(1) := DIGIT_LUT(tmp_int);  -- tens digit
    
    tmp_int := scaled_int mod 10;
    d_array(0) := DIGIT_LUT(tmp_int);  -- ones digit
    
    return d_array;
end function;

end package body pkg_digit_extract;
