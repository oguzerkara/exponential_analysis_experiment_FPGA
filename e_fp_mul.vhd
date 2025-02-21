library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity e_fp_mul is
    generic (
        G_EXP_BITS  : integer := 8;   -- Exponent bits for single precision
        G_FRAC_BITS : integer := 23;  -- Fraction bits for single precision
        CYCLES      : integer := 4     -- Number of cycles for computation
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        start       : in  std_logic; -- Start signal
        in_a        : in  std_logic_vector((1+G_EXP_BITS+G_FRAC_BITS)-1 downto 0); -- 32-bit float
        in_b        : in  std_logic_vector((1+G_EXP_BITS+G_FRAC_BITS)-1 downto 0); -- 32-bit float
        rst_to_idle : in  std_logic;
        done        : out std_logic; -- Done signal
        result      : out std_logic_vector((1+G_EXP_BITS+G_FRAC_BITS)-1 downto 0)
    );
end entity e_fp_mul;

architecture Behavioral of e_fp_mul is
    constant EXP_BIAS : integer := 127;

    ----------------------------------------------------------------------------
    -- Internal signals to hold inputs once we leave IDLE
    ----------------------------------------------------------------------------
    signal in_a_reg, in_b_reg : std_logic_vector((1+G_EXP_BITS+G_FRAC_BITS)-1 downto 0);

    ----------------------------------------------------------------------------
    -- Extracted fields (latched from in_a_reg, in_b_reg)
    ----------------------------------------------------------------------------
    signal sign_a, sign_b : std_logic;
    signal exp_a, exp_b   : unsigned(G_EXP_BITS-1 downto 0);
    signal frac_a, frac_b : unsigned(G_FRAC_BITS downto 0);  -- 1 + 23 bits

    ----------------------------------------------------------------------------
    -- Intermediate result signals
    ----------------------------------------------------------------------------
    signal result_sign    : std_logic;
    signal result_exp     : unsigned(G_EXP_BITS-1 downto 0);
    signal product        : unsigned((G_FRAC_BITS+1)*2-1 downto 0); -- 47 downto 0
    signal norm_frac      : unsigned(G_FRAC_BITS downto 0);

    ----------------------------------------------------------------------------
    -- Final latched result before driving out
    ----------------------------------------------------------------------------
    signal final_result   : std_logic_vector((1+G_EXP_BITS+G_FRAC_BITS)-1 downto 0);

    ----------------------------------------------------------------------------
    -- State Definitions
    ----------------------------------------------------------------------------
    type state_type is (IDLE, COMPUTE, COMPUTE_DONE);
    signal current_state, next_state : state_type := IDLE;

    ----------------------------------------------------------------------------
    -- Additional signals
    ----------------------------------------------------------------------------
    signal compute_counter      : integer range 0 to CYCLES := 0;
    signal computation_finished : std_logic := '0';

begin

    ----------------------------------------------------------------------------
    -- State Machine: Current State Register
    ----------------------------------------------------------------------------
    process(clk, reset)
    begin
        if (reset = '0') then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- State Machine: Next State Logic
    ----------------------------------------------------------------------------
    process(current_state, start, computation_finished, rst_to_idle)
    begin
        next_state <= current_state;  -- Default to remain in same state
        case current_state is

            when IDLE =>
                if (start = '1') then
                    next_state <= COMPUTE;  -- Start computation
                else
                    next_state <= IDLE;
                end if;

            when COMPUTE =>
                if (computation_finished = '1') then
                    next_state <= COMPUTE_DONE;
                else
                    next_state <= COMPUTE;  -- Remain until finished
                end if;

            when COMPUTE_DONE =>
                if (rst_to_idle = '1') then
                    next_state <= IDLE;     -- Return to IDLE when signaled
                else
                    next_state <= COMPUTE_DONE;
                end if;

            when others =>
                next_state <= IDLE;

        end case;
    end process;

    ----------------------------------------------------------------------------
    -- Main Synchronous Process:
    --   1) Latch inputs in IDLE
    --   2) Perform multiplications & normalizations in COMPUTE
    --   3) Output final result in COMPUTE_DONE
    ----------------------------------------------------------------------------
    process(clk, reset)
        -- Declare variables at the beginning of the process
        variable temp_exp_var : integer := 0;
    begin
        if (reset = '0') then
            done                 <= '0';
            result               <= (others => '0');
            final_result         <= (others => '0');
            compute_counter      <= 0;
            computation_finished <= '0';

            -- Clear intermediate signals
            in_a_reg     <= (others => '0');
            in_b_reg     <= (others => '0');
            product      <= (others => '0');
            norm_frac    <= (others => '0');
            result_exp   <= (others => '0');
            result_sign  <= '0';

        elsif rising_edge(clk) then

            case current_state is

                ----------------------------------------------------------------------------
                -- IDLE State
                ----------------------------------------------------------------------------
                when IDLE =>
                    done                 <= '0';
                    compute_counter      <= 0;
                    computation_finished <= '0';

                    -- Latch inputs when start = '1' (transition to COMPUTE)
                    if (start = '1') then
                        in_a_reg <= in_a;
                        in_b_reg <= in_b;
                    end if;

                ----------------------------------------------------------------------------
                -- COMPUTE State
                ----------------------------------------------------------------------------
                when COMPUTE =>
                    if (compute_counter = CYCLES) then
                        computation_finished <= '1';
                    else
                        compute_counter      <= compute_counter + 1;                     
                        computation_finished <= '0';
                        done                 <= '0';

                        --------------------------------------------------------------------
                        -- 1) Extract sign, exponent, fraction (from latched inputs)
                        --------------------------------------------------------------------
                        sign_a <= in_a_reg(31);
                        sign_b <= in_b_reg(31);

                        exp_a  <= unsigned(in_a_reg(30 downto 23));
                        exp_b  <= unsigned(in_b_reg(30 downto 23));

                        frac_a <= "1" & unsigned(in_a_reg(22 downto 0));
                        frac_b <= "1" & unsigned(in_b_reg(22 downto 0));

                        --------------------------------------------------------------------
                        -- 2) Determine result sign
                        --------------------------------------------------------------------
                        result_sign <= sign_a xor sign_b;

                        --------------------------------------------------------------------
                        -- 3) Add exponents and subtract bias
                        --------------------------------------------------------------------
                        temp_exp_var := (to_integer(exp_a) + to_integer(exp_b)) - EXP_BIAS;

                        --------------------------------------------------------------------
                        -- 4) Multiply mantissas (24 bits each -> 48 bits)
                        --------------------------------------------------------------------
                        product <= unsigned(frac_a) * unsigned(frac_b);

                        --------------------------------------------------------------------
                        -- 5) Normalize the product
                        --    If the top bit is '1' at product(47), that means it is >= 2.0
                        --    So we shift down one bit and increment exponent.
                        --    Otherwise product(46) is the integer bit of 1.xxxxx
                        --------------------------------------------------------------------
                        if product(47) = '1' then
                            norm_frac <= product(47 downto 24);  -- top 24 bits
                            temp_exp_var := temp_exp_var + 1;
                        else
                            norm_frac <= product(46 downto 23);  -- next 24 bits
                        end if;

                        --------------------------------------------------------------------
                        -- 6) Compute exponent (repack into unsigned with G_EXP_BITS)
                        --    Handle potential exponent overflow/underflow
                        --------------------------------------------------------------------
                        if (temp_exp_var > (2**G_EXP_BITS - 2)) then
                            -- Exponent overflow, set to maximum
                            result_exp <= (others => '1');
                        elsif (temp_exp_var < 0) then
                            -- Exponent underflow, set to zero (denormalized number)
                            result_exp <= (others => '0');
                        else
                            result_exp <= to_unsigned(temp_exp_var, G_EXP_BITS);
                        end if;

                        --------------------------------------------------------------------
                        -- 7) (Temporary) Construct final_result internally
                        --    DO NOT drive 'result' yet to avoid flicker.
                        --------------------------------------------------------------------
                        final_result <= result_sign 
                                        & std_logic_vector(result_exp) 
                                        & std_logic_vector(norm_frac(G_FRAC_BITS-1 downto 0));

                    end if;  -- end if compute_counter = CYCLES

                ----------------------------------------------------------------------------
                -- COMPUTE_DONE State
                ----------------------------------------------------------------------------
                when COMPUTE_DONE =>
                    -- Now we drive out the final result *once* and assert 'done'
                    done   <= '1';
                    result <= final_result;  -- Only here do we update 'result' port

                    -- Clear or reset the internal counters and signals as needed
                    compute_counter      <= 0;
                    computation_finished <= '0';

                ----------------------------------------------------------------------------
                -- Safety net (others)
                ----------------------------------------------------------------------------
                when others =>
                    done                 <= '0';
                    compute_counter      <= 0;
                    computation_finished <= '0';

            end case;
        end if;
    end process;

end Behavioral;
