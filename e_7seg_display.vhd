library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- floating point and fixed point operations
library ieee_proposed;
use ieee_proposed.fixed_float_types.all;  
use ieee_proposed.fixed_pkg.all;          
use ieee_proposed.float_pkg.all;  
-- 7-seg pattern definitions
library work;
use work.pkg_7seg_encode.all;
-- Digit-extraction functions
use work.pkg_digit_extract.all;

entity e_7seg_display is
   port(
      clk          : in  std_logic;
      reset        : in  std_logic;
      display_mode : in  std_logic_vector(2 downto 0);
      display_q    : in  std_logic_vector(31 downto 0);   -- Float input (IEEE-754)

      seg_out      : out std_logic_vector(7*6 - 1 downto 0)  -- 6 digits × 7 segments
   );
end entity e_7seg_display;

architecture behavioral of e_7seg_display is

   -- Internal signals
   -- Pipeline Stage 1
   signal mode_reg1    : std_logic_vector(2 downto 0) := (others => '0');
   signal data_reg1    : std_logic_vector(31 downto 0) := (others => '0');

   -- 16.16 "sfixed":  sign + 15 integer bits + 16 fraction bits
   signal flt_in    : float32;                  -- from float_pkg
   signal sfix_16_16: sfixed(15 downto -16);    -- from fixed_pkg
   signal fp_fixed_out : std_logic_vector(31 downto 0);

   -- Pipeline Stage 2
   signal mode_reg2      : std_logic_vector(2 downto 0) := (others => '0');
   signal digits_reg2    : t_digit_array := (others => seg_blank);

   -- The final registered output (6 digits)
   signal seg_array_reg  : std_logic_vector(7*6 - 1 downto 0) := (others => '1');

begin
   flt_in <= to_float(data_reg1);         -- interpret bits as float32
	process(clk) begin
		if rising_edge(clk) then
		sfix_16_16 <= to_sfixed(flt_in, 15, -16,
										fixed_saturate,  
										fixed_round      
									  );
		end if;
	end process;
	fp_fixed_out(31 downto 16) <= to_slv(sfix_16_16(15 downto 0)); -- Integer part
	fp_fixed_out(15 downto 0)  <= to_slv(sfix_16_16(-1 downto -16)); -- Fractional part

   -- Main Synchronous Process
   process(clk)
      -- Local variables for stage 2
      variable int_digits  : t_digit_array := (others => seg_blank);
      variable frac_digits : t_digit_array := (others => seg_blank);
      variable out_digits  : t_digit_array := (others => seg_blank);

   begin
      if rising_edge(clk) then

         if reset = '0' then
            -- stage 1
            mode_reg1 <= (others => '0');
            data_reg1 <= (others => '0');

            -- stage 2
            mode_reg2   <= (others => '0');
            digits_reg2 <= (others => seg_blank);

            seg_array_reg <= (others => '1');

         else
            -- Stage 1: Latch inputs for the IP
            mode_reg1 <= display_mode;
            data_reg1 <= display_q;

            -- Stage 2: read IP, do digit extraction if mode=111
            mode_reg2 <= mode_reg1;
            out_digits := (others => seg_blank);

            if mode_reg1 = "111" then
               -- (A) 16.16 fixed => top 16 bits integer, bottom 16 bits fraction
               int_digits  := extract_3digit_integer(signed(fp_fixed_out(31 downto 16)));
               frac_digits := extract_3digit_fraction(unsigned(fp_fixed_out(15 downto 0)));

               -- (B) Combine (INT + FRAC) into 6 digits:
               --    digits(5..3) = integer, digits(2..0) = fraction
               out_digits(5) := int_digits(5);
               out_digits(4) := int_digits(4);
               out_digits(3) := int_digits(3);
               out_digits(2) := frac_digits(2);
               out_digits(1) := frac_digits(1);
               out_digits(0) := frac_digits(0);
            end if;

            digits_reg2 <= out_digits;

            -- Build final 6-digit output depending on mode
            case mode_reg2 is

               when "000" =>
                  seg_array_reg <= seg_for_S & seg_for_E & seg_for_L &
                                   seg_for_E & seg_for_C & seg_for_T;

               when "001" =>
                  seg_array_reg <= seg_for_W & seg_for_W & seg_for_R &
                                   seg_for_I & seg_for_T & seg_for_E;

               when "010" =>
                  seg_array_reg <= seg_for_R & seg_for_E & seg_for_A &
                                   seg_for_D & seg_blank & seg_for_DASH;

               when "011" =>
                  seg_array_reg <= seg_for_S & seg_for_M & seg_for_O &
                                   seg_for_O & seg_for_T & seg_for_H;

               when "100" =>
                  seg_array_reg <= seg_for_C & seg_for_O & seg_for_M &
                                   seg_for_P & seg_for_L & seg_for_T;

               when "111" =>
                  seg_array_reg <= digits_reg2(5) & digits_reg2(4) &
                                   digits_reg2(3) & digits_reg2(2) &
                                   digits_reg2(1) & digits_reg2(0);

               when others =>
                  seg_array_reg <= seg_blank & seg_blank & seg_blank &
                                   seg_blank & seg_blank & seg_blank;
            end case;

         end if; -- reset=0 check
      end if; -- rising_edge
   end process;

   -- output to top-level
   seg_out <= seg_array_reg;

end architecture behavioral;
