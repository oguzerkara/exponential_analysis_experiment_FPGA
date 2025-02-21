library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity e_exponential_smoothing is
	 generic (
		  DATA_IN_LEN 	  	 : integer := 64;
		  ADDRESS_LEN  	 : integer := 10;
		  NUM_DATA			 : integer := 1024;
		  DATA_PROCESS_LEN : integer := 32
	);
    port (
        clk           : in  std_logic;
        reset         : in  std_logic;
		  process_start : in std_logic;
        processed_out : out std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);  -- Smoothed value
		  process_done  : out std_logic;
		  
        ram_data_out  : in std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);  -- receive content from RAM	in other entity	  
		  ram_address	 : out std_logic_vector(( ADDRESS_LEN - 1 ) downto 0);  -- send content to ram in other entity
		  -- ram_data_in	 : out std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);
		  ram_wren		 : out std_logic;
		  exsm_out_rden : out std_logic;
		  ram_rden		 : out std_logic
    );
end entity e_exponential_smoothing;

architecture behavioral of e_exponential_smoothing is

	component e_fp_op is
		 generic (
		 	IEEE754_FP_LEN : integer := DATA_PROCESS_LEN;
			alpha_bits : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);  -- 0.8 in IEEE 754
			minus_alpha: std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0)
			);
		 port (
			  clk       : in  std_logic;                     -- Clock
			  in_dataa     : in  std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0); -- Input A
			  in_datab     : in  std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0); -- Input B
			  reset     : in  std_logic;                     -- Reset
			  start     : in  std_logic;                     -- Start signal
			  done      : out std_logic;                     -- Done signal
			  result    : out std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0)  -- Result output
		 );
	end component;

    -- Signals
    signal ram_data     : std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);  -- RAM output data
    signal date_field   : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);  -- Date (first 32 bits)
    signal value_field  : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);  -- Float value (last 32 bits)
    signal smoothed_val : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);  -- Smoothed result
    signal prev_val     : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0) := (others => '0'); -- Previous smoothed value
    signal read_counter : integer range 0 to NUM_DATA := 0;
	 signal next_smoothed_val : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);
	 signal next_dsp_dataa : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);
	 signal next_dsp_datab : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);
	 signal next_prev_val : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);
	 signal next_value_field : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);


	 -- Signals for DSP Component
	 signal dsp_dataa     : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);
	 signal dsp_datab     : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);
	 signal dsp_reset     : std_logic;
	 signal dsp_start     : std_logic := '0';
	 signal dsp_done      : std_logic;
	 signal dsp_result    : std_logic_vector(( DATA_PROCESS_LEN - 1 ) downto 0);
	 

    -- State Definitions
	type state_type is (IDLE, ST_WAIT, LOAD, START_FP_OP, WAIT_FP_OP);
	signal current_state, next_state : state_type := IDLE;

begin
	e_fp_op_inst : e_fp_op
	    generic map (
				  IEEE754_FP_LEN => DATA_PROCESS_LEN,
				  alpha_bits 	 => x"3f4ccccd", -- 0.8
				  minus_alpha	 => x"3e4ccccd"  -- o.2
			 )		 
		 port map (
			  clk       => clk,       -- Connect to system clock
			  in_dataa     => dsp_dataa,     -- Input A (e.g., current value)
			  in_datab     => dsp_datab,     -- Input B (e.g., alpha or 1-alpha)
			  reset     => dsp_reset,     -- Reset signal
			  start     => dsp_start,     -- Start signal
			  done		=> dsp_done,
			  result    => dsp_result     -- Result of computation
		 );

process(clk, reset, current_state)
begin
		if rising_edge(clk) then
			 if reset = '0' then
				  current_state <= IDLE;
				  read_counter <= 0;
				  process_done <= '0';
			 else
				  current_state <= next_state;
				  smoothed_val <= next_smoothed_val;
				  dsp_dataa <= next_dsp_dataa;
				  dsp_datab <= next_dsp_datab;
				  prev_val	<= next_prev_val;
				  value_field <= next_value_field;
				  read_counter <= read_counter;
				  
				  case current_state is
					when LOAD =>
						if read_counter < (NUM_DATA-1) then
							ram_address <= std_logic_vector(to_unsigned(read_counter, ADDRESS_LEN));
							read_counter <= read_counter + 1; -- increment using variable assignment
						
						else
							 process_done <= '1';
						end if;
					when others =>
						process_done <= '0';
						
				  end case;
			 end if;
		end if;

end process;


process(current_state, process_start, dsp_done, smoothed_val,
				dsp_dataa, dsp_datab, prev_val, value_field, dsp_result, ram_data_out)
begin
    -- Default signal assignments
    dsp_start <= '0';
    ram_rden <= '0';
    ram_wren <= '0';
	 dsp_reset <= '1';
	 exsm_out_rden <= '0';
    
    next_state <= current_state;
	 next_smoothed_val <= smoothed_val;
	 next_dsp_dataa 	<=	dsp_dataa;
	 next_dsP_datab	<= dsp_datab;
	 next_prev_val		<= prev_val;
	 next_value_field <= value_field;
	 
	 
    case current_state is
        when IDLE =>
				dsp_reset <= '0';
				exsm_out_rden <= '0';
            if process_start = '1' then

					 dsp_reset <= '1';
					 ram_rden <= '1'; -- Enable RAM read
					 
					 dsp_start <= '1';
					 next_smoothed_val <= (others => '0');
					 next_dsp_dataa <= (others => '0');
					 next_dsp_datab <= (others => '0');
					 next_prev_val <= (others => '0');

                next_state <= ST_WAIT;
				 else
				    next_state <= IDLE;
            end if;
		  when ST_WAIT =>
				ram_rden <= '1'; -- Enable RAM read
				exsm_out_rden <= '0';
				next_state <= LOAD;
				
        when LOAD =>
					 ram_rden <= '1'; -- Enable RAM read
					 exsm_out_rden <= '0';
                next_value_field <= ram_data_out(( DATA_PROCESS_LEN - 1 ) downto 0); -- Extract value part
				    next_state <= START_FP_OP;


        when START_FP_OP =>
					 exsm_out_rden <= '0';
					 
                next_dsp_dataa <= value_field; -- Current value
                next_dsp_datab <= prev_val; -- Alpha used directly
                dsp_start <= '1'; -- Start alpha * value
					 
					 next_state <= WAIT_FP_OP;

        when WAIT_FP_OP =>
            if dsp_done = '1' then
					 exsm_out_rden <= '1';
                next_smoothed_val <= dsp_result; -- Store result
                next_prev_val <= dsp_result; -- Update previous value
                next_state <= ST_WAIT;
				 else
					 exsm_out_rden <= '0';
					 next_state <= WAIT_FP_OP;
            end if;


        when others =>
				exsm_out_rden <= '0';
            next_state <= IDLE;
    end case;
end process;


		 -- Output Assignment
		 processed_out <= smoothed_val;

end architecture behavioral;