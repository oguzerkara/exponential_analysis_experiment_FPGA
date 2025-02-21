library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity config_fp_to_fxd is
   port(
      clk   : in  std_logic;
      reset : in  std_logic;
      a     : in  std_logic_vector(31 downto 0);  -- IEEE-754 float
      q     : out std_logic_vector(31 downto 0)   -- 16.16 fixed
   );
end entity config_fp_to_fxd;

architecture Minimal of config_fp_to_fxd is
   constant EXP_BIAS : integer := 127;

   signal sign_reg     : std_logic := '0';
   signal exponent_reg : integer range -255 to 255 := 0;
   signal frac24       : unsigned(23 downto 0) := (others => '0');
   signal tmp_fixed    : signed(31 downto 0) := (others => '0');
begin

   process(clk, reset)
      variable e : integer;
      variable s : std_logic;
      variable f : unsigned(23 downto 0);
      variable val : signed(47 downto 0);
   begin
      if reset = '0' then
         q <= (others => '0');
         sign_reg <= '0';
         exponent_reg <= 0;
         frac24 <= (others => '0');
         tmp_fixed <= (others => '0');

      elsif rising_edge(clk) then
         -- extract sign, exponent, fraction
         s := a(31);
         e := to_integer(unsigned(a(30 downto 23))) - EXP_BIAS;
         f := unsigned(a(22 downto 0));

         if (e /= -127) or (f /= 0) then
            frac24(23) <= '1';  -- normalized leading 1
         else
            frac24(23) <= '0';  -- zero/denormal
         end if;
         frac24(22 downto 0) <= f(22 downto 0);

         sign_reg <= s;
         exponent_reg <= e;

         -- Shift frac24 based on exponent => ~16.16
         val := signed(frac24) * 2**(exponent_reg);

         -- clamp to ±32768
         if val > to_signed(32767*65536, 48) then
            tmp_fixed <= to_signed(32767*65536, 32);
         elsif val < to_signed(-32768*65536, 48) then
            tmp_fixed <= to_signed(-32768*65536, 32);
         else
            tmp_fixed <= resize(val, 32);
         end if;

         if sign_reg = '1' then
            tmp_fixed <= -tmp_fixed;
         end if;

         q <= std_logic_vector(tmp_fixed);
      end if;
   end process;

end architecture Minimal;
