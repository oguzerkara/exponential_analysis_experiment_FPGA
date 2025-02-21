library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity e_fp_op is
    generic (
		  IEEE754_FP_LEN : integer := 32;
        alpha_bits  : std_logic_vector(31 downto 0) := x"3f4ccccd";  -- 0.8 in IEEE 754
        minus_alpha : std_logic_vector(31 downto 0) := x"3e4ccccd"   -- 0.2
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;                     -- Reset
        start    : in  std_logic;                     -- Start signal
        in_dataa : in  std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0); -- IEEE754 Input A
        in_datab : in  std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0); -- IEEE754 Input B

        done     : out std_logic;                     -- Done signal
        result   : out std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0)  -- IEEE754 Result
    );
end entity e_fp_op;

architecture Structural of e_fp_op is

    -- Sub-entity Components
    component e_fp_add
        generic (
            G_EXP_BITS : integer := 8;
            G_FRAC_BITS: integer := 23;
            CYCLES     : integer := 4  
        );
        port (
            clk   : in  std_logic;
            reset : in  std_logic;
            start : in  std_logic;

				rst_to_idle : in std_logic;			
            in_a  : in  std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
            in_b  : in  std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
            done  : out std_logic;
            result: out std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0)
        );
    end component;

    component e_fp_mul
        generic (
            G_EXP_BITS : integer := 8;
            G_FRAC_BITS: integer := 23;
            CYCLES     : integer := 4  
        );
        port (
            clk   : in  std_logic;
            reset : in  std_logic;
            start : in  std_logic;

				rst_to_idle : in std_logic;						
            in_a  : in  std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
            in_b  : in  std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
            done  : out std_logic;
            result: out std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0)
        );
    end component;

    component e_fp_mul_minusalpha
        generic (
            G_EXP_BITS : integer := 8;
            G_FRAC_BITS: integer := 23;
            CYCLES     : integer := 4  
        );
        port (
            clk   : in  std_logic;
            reset : in  std_logic;
            start : in  std_logic;

				rst_to_idle : in std_logic;							
            in_a  : in  std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
            in_b  : in  std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
            done  : out std_logic;
            result: out std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0)
        );
    end component;

    -- Signals for sub-entity connections
    signal add_result               : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal mul_result_alpha         : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal mul_result_minusalpha    : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);

    signal internal_in_dataa        : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal internal_in_datab        : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal in_add_a                 : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal in_add_b                 : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);

    signal add_done                 : std_logic;
    signal mul_done_alpha           : std_logic;
    signal mul_done_minusalpha      : std_logic;   

    -- Sub-entity start signals
    signal start_add_reg, start_mul_reg, start_mulminus_reg: std_logic := '0';
    signal next_start_add, next_start_mul, next_start_mulminus: std_logic;
	 signal to_idle_mul, to_idle_mulminus, to_idle_add	: std_logic	:= '0';
	 signal next_to_idle_mul, next_to_idle_mulminus, next_to_idle_add : std_logic;

    -- Internal higher-level entity (e_exponential_smoothing) signals for controlling the final result
    signal next_internal_in_dataa   : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal next_internal_in_datab   : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal next_in_add_a            : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal next_in_add_b            : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal next_result              : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal next_done                : std_logic;
    signal internal_result          : std_logic_vector((IEEE754_FP_LEN - 1 ) downto 0);
    signal internal_done            : std_logic;

    -- FSM for the top-level operation
    type state_type is (IDLE, LOAD, START_MULS, WAIT_MULS, START_ADD, WAIT_ADD, COMPUTE_DONE);
    signal current_state, next_state: state_type := IDLE;

begin

    -- Sub-entity Instantiations
    -- Floating-point Adder
    u_e_fp_add: e_fp_add
        generic map (
            G_EXP_BITS => 8,
            G_FRAC_BITS => 23,
            CYCLES => 5
        )
        port map (
            clk    => clk,
            reset  => reset,
            start  => start_add_reg,      -- Registered sub-block start
            in_a   => in_add_a,
            in_b   => in_add_b,
            done   => add_done,
				rst_to_idle => to_idle_add,
            result => add_result
        );

    -- Floating-point Multiply (alpha * dataa)
    u_fp_mul: e_fp_mul
        generic map (
            G_EXP_BITS => 8,
            G_FRAC_BITS => 23,
            CYCLES => 4
        )
        port map (
            clk    => clk,
            reset  => reset,
            start  => start_mul_reg,      -- Registered sub-block start
            in_a   => internal_in_dataa,
            in_b   => alpha_bits,
            done   => mul_done_alpha,
				rst_to_idle => to_idle_mul,
            result => mul_result_alpha
        );

    -- Floating-point Multiply (minus_alpha * datab)
    u_fp_mul_minusalpha: e_fp_mul_minusalpha
        generic map (
            G_EXP_BITS => 8,
            G_FRAC_BITS => 23,
            CYCLES => 4
        )
        port map (
            clk    => clk,
            reset  => reset,
            start  => start_mulminus_reg, -- Registered sub-block start
            in_a   => internal_in_datab,
            in_b   => minus_alpha,
            done   => mul_done_minusalpha,
				rst_to_idle => to_idle_mulminus,
            result => mul_result_minusalpha
        );

    -- Clocked Process: State and Registered Signals
    process(clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                current_state        <= IDLE;
                internal_done        <= '0';
                internal_result      <= (others => '0');

                -- Internal data signals
                internal_in_dataa    <= (others => '0');
                internal_in_datab    <= (others => '0');
                in_add_a             <= (others => '0');
                in_add_b             <= (others => '0');

                -- Register the sub-block start signals
                start_add_reg        <= '0';
                start_mul_reg        <= '0';
                start_mulminus_reg   <= '0';
					 
					 to_idle_add			 <= '0';
					 to_idle_mul			 <= '0';
					 to_idle_mulminus		 <= '0';					 
            else
                current_state        <= next_state;
                internal_done        <= next_done;
                internal_result      <= next_result;

                internal_in_dataa    <= next_internal_in_dataa;
                internal_in_datab    <= next_internal_in_datab;
                in_add_a             <= next_in_add_a;
                in_add_b             <= next_in_add_b;

                -- Update sub-block starts from combinational
                start_add_reg        <= next_start_add;
                start_mul_reg        <= next_start_mul;
                start_mulminus_reg   <= next_start_mulminus;
					 
					 to_idle_add			 <= next_to_idle_add;
					 to_idle_mul			 <= next_to_idle_mul;
					 to_idle_mulminus		 <= next_to_idle_mulminus;
            end if;
        end if;
    end process;

    -- Combinational Process: Next-State and Output Logic
    process(current_state, start, mul_done_alpha, mul_done_minusalpha, add_done, in_add_a, 
            add_result, in_dataa, in_datab, mul_result_alpha, mul_result_minusalpha, in_add_b,
            internal_in_dataa, internal_in_datab, internal_done, internal_result)
    begin
        -- Default next signals
        next_internal_in_dataa <= internal_in_dataa;
        next_internal_in_datab <= internal_in_datab;
        next_in_add_a          <= in_add_a;
        next_in_add_b          <= in_add_b;

        next_done              <= internal_done;
        next_result            <= internal_result;

        -- By default, do NOT trigger sub-block starts
        next_start_add         <= '0';
        next_start_mul         <= '0';
        next_start_mulminus    <= '0';

		  next_to_idle_add		 <= '0';
		  next_to_idle_mul		 <= '0';
		  next_to_idle_mulminus	 <= '0';		  
        -- Next-state default
        next_state <= current_state;

        case current_state is
            -- IDLE
            when IDLE =>
                -- Clear data
                next_internal_in_dataa <= (others => '0');
                next_internal_in_datab <= (others => '0');
                next_result            <= (others => '0'); 
                next_done              <= '0';

				    next_to_idle_add		   <= '0';
				    next_to_idle_mul		   <= '0';
				    next_to_idle_mulminus  <= '0';	
                if start = '1' then
                    -- Begin operation
                    next_state <= LOAD;
                else
                    next_state <= IDLE;
                end if;

            -- LOAD
            when LOAD =>
                -- Move input data to internal registers
                next_internal_in_dataa <= in_dataa;
                next_internal_in_datab <= in_datab;

                -- Next, we want to do the multiplications
                next_state <= START_MULS;

            -- START_MULS
            when START_MULS =>
                -- Fire off both multiplications in parallel
                next_start_mul      <= '1';
                next_start_mulminus <= '1';
					 next_start_add <= '0';

                -- Move to wait for them to finish
                next_state <= WAIT_MULS;

            -- WAIT_MULS
            when WAIT_MULS =>
					 next_start_add <= '0';
					 next_start_mul      <= '0';
                next_start_mulminus <= '0';
                if mul_done_alpha = '1' and mul_done_minusalpha = '1' then
                    -- Both multiplications done, set up add inputs
                    next_in_add_a <= mul_result_alpha;
                    next_in_add_b <= mul_result_minusalpha;

                    next_state    <= START_ADD;
                else
                    next_state <= WAIT_MULS;
                end if;

            -- START_ADD
            when START_ADD =>
                -- Fire off the addition
                next_start_add <= '1';
                next_state     <= WAIT_ADD;

            -- WAIT_ADD
            when WAIT_ADD =>
					next_start_add <= '0';
					 next_start_mul      <= '0';
                next_start_mulminus <= '0';
					 
                if add_done = '1' then
                    next_done   <= '1';
                    next_result <= add_result;

                    -- Operation complete
                    next_state <= COMPUTE_DONE;
                else
                    next_state <= WAIT_ADD;
                end if;

            -- COMPUTE_DONE
            when COMPUTE_DONE =>
                -- Possibly remain here or go back to IDLE automatically
					 next_to_idle_add		 <= '1';
					 next_to_idle_mul		 <= '1';
					 next_to_idle_mulminus	 <= '1';	
					 
                --next_done   <= '1';
					 --if start = '0' then
					 next_done   <= '1';
					 next_state <= IDLE;

					 --else
						--  next_state <= COMPUTE_DONE;
					 --end if;

            when others =>
                next_state <= IDLE;
        end case;
    end process;

    -- External Outputs
    --------------------------------------------------------------------------
    done   <= internal_done;
    result <= internal_result;

end Structural;
