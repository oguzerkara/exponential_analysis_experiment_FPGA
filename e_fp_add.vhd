library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity e_fp_add is
    generic (
        G_EXP_BITS  : integer := 8;   -- Exponent width for single precision
        G_FRAC_BITS : integer := 23;  -- Fraction (mantissa) width for single precision
        CYCLES      : integer := 5    -- Number of cycles for computation
    );
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        start  : in  std_logic;  -- Start signal
        in_a   : in  std_logic_vector((1+G_EXP_BITS+G_FRAC_BITS)-1 downto 0);
        in_b   : in  std_logic_vector((1+G_EXP_BITS+G_FRAC_BITS)-1 downto 0);
		  rst_to_idle : in std_logic;
        done   : out std_logic;  -- Done signal
        result : out std_logic_vector((1+G_EXP_BITS+G_FRAC_BITS)-1 downto 0)
    );
end entity e_fp_add;

architecture Behavioral of e_fp_add is

    constant EXP_BIAS : integer := 127;

    -- Signals for internal processing
    signal exp_a, exp_b               : unsigned(G_EXP_BITS-1 downto 0);
    signal frac_a, frac_b             : unsigned(G_FRAC_BITS downto 0); 
    signal aligned_frac_a, aligned_frac_b : unsigned(G_FRAC_BITS downto 0);
    signal exp_diff                    : integer;
    signal larger_exp                  : unsigned(G_EXP_BITS-1 downto 0);

    signal sum_frac       : unsigned(G_FRAC_BITS+1 downto 0);
    signal final_exp      : unsigned(G_EXP_BITS-1 downto 0);
    signal final_sign     : std_logic;
    signal normalized_frac: unsigned(G_FRAC_BITS downto 0);

    -- State Machine
    type state_type is (IDLE, COMPUTE, COMPUTE_DONE);
    signal current_state, next_state : state_type := IDLE;

    -- Cycle counter for multi-cycle computation
    signal cycle_counter : integer range 0 to CYCLES := 0;

begin
    -- 1- STATE REGISTER
    process(clk, reset)
    begin
        if reset = '0' then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- 2- NEXT STATE LOGIC
    process(current_state, start, cycle_counter, rst_to_idle)
    begin
        -- Default state
        next_state <= current_state;

        case current_state is
            when IDLE =>
                if start = '1' then
                    next_state <= COMPUTE;
                else	
						  next_state <= IDLE;
					 end if;

            when COMPUTE =>
                if cycle_counter = CYCLES - 1 then -- CYCLES are intended to lenghten each process
                    next_state <= COMPUTE_DONE; -- Move to DONE after required cycles
                else
                    next_state <= COMPUTE;
                end if;

            when COMPUTE_DONE =>
                if rst_to_idle = '1' then
                    next_state <= IDLE; -- Return to IDLE after start signal goes low
					 else 
						  next_state <= COMPUTE_DONE;
					 end if;

            when others =>
                next_state <= IDLE;
        end case;
    end process;

    -- 3- OUTPUT & COMPUTATION PROCESS
    process(clk, reset)
    begin
        if reset = '0' then
            done <= '0';
            result <= (others => '0');
            cycle_counter <= 0;
        elsif rising_edge(clk) then
            case current_state is

                when IDLE =>
                    done <= '0';
                    cycle_counter <= 0;

                when COMPUTE =>
                    done <= '0';
                    if cycle_counter < CYCLES - 1 then
                        cycle_counter <= cycle_counter + 1; -- Increment counter
                    end if;

                    -- Perform computation steps (same as before):
                    -- Extract exponent fields
                    exp_a <= unsigned(in_a(30 downto 23));
                    exp_b <= unsigned(in_b(30 downto 23));

                    -- Build fraction with implied leading 1
                    frac_a <= "1" & unsigned(in_a(22 downto 0));
                    frac_b <= "1" & unsigned(in_b(22 downto 0));

                    -- Align exponents
                    if to_integer(exp_a) > to_integer(exp_b) then
                        exp_diff <= to_integer(exp_a) - to_integer(exp_b);
                        larger_exp <= exp_a;
                        aligned_frac_a <= frac_a;
                        aligned_frac_b <= shift_right(frac_b, exp_diff);
                    else
                        exp_diff <= to_integer(exp_b) - to_integer(exp_a);
                        larger_exp <= exp_b;
                        aligned_frac_b <= frac_b;
                        aligned_frac_a <= shift_right(frac_a, exp_diff);
                    end if;

                    -- Assume same sign for simplicity (both positive)
                    final_sign <= '0';

                    -- Add fractions
                    sum_frac <= unsigned(('0' & aligned_frac_a)) + unsigned(('0' & aligned_frac_b));

                    -- Normalize result
                    if (sum_frac(G_FRAC_BITS+1) = '1') then
                        normalized_frac <= sum_frac(G_FRAC_BITS+1 downto 1);
                        final_exp <= larger_exp + 1;
                    else
                        normalized_frac <= sum_frac(G_FRAC_BITS downto 0);
                        final_exp <= larger_exp;
                    end if;

                when COMPUTE_DONE =>
                    done <= '1'; -- Signal computation is complete
						  cycle_counter <= 0;

                    result <= final_sign 
                              & std_logic_vector(final_exp) 
                              & std_logic_vector(normalized_frac(G_FRAC_BITS-1 downto 0));

                when others =>
                    done <= '0';

            end case;
        end if;
    end process;

end Behavioral;
