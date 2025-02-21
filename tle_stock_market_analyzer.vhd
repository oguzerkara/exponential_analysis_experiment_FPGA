library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tle_stock_market_analyzer is
	 generic (
		  DATA_IN_LEN  : integer := 64;
		  ADDRESS_LEN  : integer := 10;
		  NUM_DATA		: integer := 1024;
		  DATA_OUT_LEN : integer := 32
	);
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
		  start			: in 	std_logic;
		  read_button  : in  std_logic;
		  
		  sel_pins		: in  std_logic_vector(9 downto 0);
		  
		  digit0_segs : out std_logic_vector(6 downto 0);  -- Right-most or left-most digit
        digit1_segs : out std_logic_vector(6 downto 0);
        digit2_segs : out std_logic_vector(6 downto 0);
        digit3_segs : out std_logic_vector(6 downto 0);
        digit4_segs : out std_logic_vector(6 downto 0);
        digit5_segs : out std_logic_vector(6 downto 0)
    );
end entity tle_stock_market_analyzer;

architecture behavioral of tle_stock_market_analyzer is

    -- Component Declarations
	 
	 component e_exponential_smoothing
		  generic (
			   DATA_IN_LEN 	  	 : integer := DATA_IN_LEN;
			   ADDRESS_LEN  	 : integer := ADDRESS_LEN;
			   NUM_DATA			 : integer := NUM_DATA;
			   DATA_PROCESS_LEN : integer := DATA_OUT_LEN
		 );
		  port (
				clk			  : in std_logic;
				reset			  : in std_logic;
				process_start : in std_logic;
				process_done  : out std_logic;
				processed_out : out std_logic_vector(( DATA_OUT_LEN - 1 ) downto 0);  -- Smoothed value
				
			   ram_data_out  : in std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);
			   ram_address	  : out std_logic_vector(( ADDRESS_LEN - 1 ) downto 0);
			   --ram_data_in	  : out std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);
			   ram_wren		  : out std_logic;
				exsm_out_rden : out std_logic;
			   ram_rden		  : out std_logic				
				);
	end component;
				
    component e_write_and_read_ram
		  generic (
			  NUM_DATA		 : integer := NUM_DATA;
			  DATA_IN_LEN		 : integer := DATA_IN_LEN;
			  DATA_OUT_LEN	 : integer := DATA_OUT_LEN;
			  ADDRESS_LEN	 : integer := ADDRESS_LEN
			);
        port (
            clk           : in  std_logic;
            reset         : in  std_logic;
            write_done    : out std_logic;
            read_done     : out std_logic;
				
			   select_data	  : in std_logic_vector(2 downto 0);
			   ram_data_out  : in std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);
			   ram_data_o    : out std_logic_vector((DATA_OUT_LEN -1 ) downto 0);		  
			   ram_address	  : out std_logic_vector(( ADDRESS_LEN - 1 ) downto 0);
			   ram_data_in	  : out std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);
			   ram_wren		  : out std_logic;
				wr_out_rden	  : out std_logic;
			   ram_rden		  : out std_logic	
        );
	end component;

    component config_ram_in
        port (
            address : in  std_logic_vector(( ADDRESS_LEN - 1 ) downto 0);
            clock   : in  std_logic;
            data    : in  std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);
            rden    : in  std_logic;
            wren    : in  std_logic;
            q       : out std_logic_vector(( DATA_IN_LEN - 1 ) downto 0)
        );
    end component;

    component config_ram_out
        port (
            address : in  std_logic_vector(( ADDRESS_LEN - 1 ) downto 0);
            clock   : in  std_logic;
            data    : in  std_logic_vector(( DATA_OUT_LEN - 1 ) downto 0);
            rden    : in  std_logic;
            wren    : in  std_logic;
            q       : out std_logic_vector(( DATA_OUT_LEN - 1 ) downto 0)
        );
    end component;
	 
	 component e_7seg_display 
		  port (
			 clk          : in  std_logic;
			 reset        : in  std_logic;
			 display_mode : in  std_logic_vector(2 downto 0);
			 display_q 	  : in std_logic_vector(31 downto 0);
			 seg_out      : out std_logic_vector(7*6 - 1 downto 0)  
		  );
	end component;

	 -- Signals for proper Pin assignments
	 signal sel_data      : std_logic_vector(2 downto 0);
	 signal sel_process   : std_logic_vector(2 downto 0);
	 -- Signals for RAM Interface
    signal mux_ram_address  : std_logic_vector(( ADDRESS_LEN - 1 ) downto 0);
    --signal mux_ram_data_in  : std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);
    signal mux_ram_data_out : std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);
    signal mux_ram_wren     : std_logic;
    signal mux_ram_rden     : std_logic;

	 -- Signals for output RAM 
	 signal ram_out_addr		 : std_logic_vector((ADDRESS_LEN - 1) downto 0);
	 signal ram_out_data		 : std_logic_vector((DATA_OUT_LEN - 1) downto 0);
	 signal ram_out_rden		 : std_logic;
	 signal ram_out_wren		 : std_logic;
	 signal ram_out_q			 : std_logic_vector((DATA_OUT_LEN - 1) downto 0);
    -- Signals from e_write_and_read_ram
    signal e_rnw_ram_address  : std_logic_vector(( ADDRESS_LEN - 1 ) downto 0);
    signal e_rnw_ram_data_in  : std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);
    signal e_rnw_ram_data_out : std_logic_vector(( DATA_IN_LEN - 1 ) downto 0) := (others => '0');
    signal e_rnw_ram_wren     : std_logic;
    signal e_rnw_ram_rden     : std_logic;
	 signal ram_write_done		: std_logic;
	 signal internal_ram_read_done : std_logic;
	 signal w_r_out_rden 		: std_logic;
	 signal w_r_data_out   		: std_logic_vector((DATA_OUT_LEN -1 ) downto 0);
    -- Signals from p_exponential_smoothing
    signal e_expsm_ram_address  : std_logic_vector(( ADDRESS_LEN - 1 ) downto 0);
    -- signal e_expsm_ram_data_in  : std_logic_vector(( DATA_IN_LEN - 1 ) downto 0);
    signal e_expsm_ram_data_out : std_logic_vector(( DATA_IN_LEN - 1 ) downto 0) := (others => '0');
    signal e_expsm_ram_wren     : std_logic;
    signal e_expsm_ram_rden     : std_logic;
	 signal ex_sm_out_rden		  : std_logic;
	 signal smoothed_out 		  : std_logic_vector(( DATA_OUT_LEN - 1 ) downto 0);  -- Smoothed value


	 -- 7 Segemnt signals
	 signal display_mode : std_logic_vector(2 downto 0) := "000";
	 signal display_ram_data : std_logic_vector(31 downto 0);
	 signal seg_all      : std_logic_vector(7*6 - 1 downto 0); 
    -- Control Signals
	 signal start_smooth_process : std_logic := '0';
    --signal read_done     		  : std_logic;
	 signal smooth_process_done  : std_logic;
    signal mux_select   		  : std_logic := '0'; 
    -- '0' => e_write_and_read_ram, 
    -- '1' => e_exponential_smoothing
    signal write_counter_wr  : integer range 0 to NUM_DATA := 0;
	 signal write_counter_es  : integer range 0 to NUM_DATA := 0;
    -- State Definitions
	 type state_type is (IDLE, SEL, RAM_PROCESS, EXPONENTIAL_SMOOTHING, DISPLAY_RESULT, DISPLAY_INT_RESULT);
	 signal current_state, next_state : state_type := IDLE;

	 signal which_data, which_data_next     : std_logic_vector(2 downto 0) := (others => '0');
	 signal which_process, which_process_next : std_logic_vector(2 downto 0) := (others => '0');
	 signal ram_out_rden_next : std_logic := '0';
	 signal display_ram_data_next : std_logic_vector(31 downto 0);

	 -- signal display_pins, display_pins_next : std_logic_vector(9 downto 0) := (others => '0');

begin

	 sel_data      <= sel_pins(9 downto 7);  -- leftmost 3 bits
    sel_process   <= sel_pins(6 downto 4);  -- next 3 bits
    -- Instantiate p_exponential_smoothing
    e_es_inst : e_exponential_smoothing
		  generic map ( 
				DATA_IN_LEN 		=> DATA_IN_LEN,
				ADDRESS_LEN  		=> ADDRESS_LEN,
				NUM_DATA				=> NUM_DATA,
				DATA_PROCESS_LEN  => DATA_OUT_LEN
			)
        port map (
            clk           => clk,
            reset         => reset,
				process_start => start_smooth_process,
            process_done  => smooth_process_done,
            processed_out => smoothed_out,
            ram_address   => e_expsm_ram_address,
            -- ram_data_in   => e_expsm_ram_data_in,
            ram_wren      => e_expsm_ram_wren,
            ram_rden      => e_expsm_ram_rden,
            ram_data_out  => e_expsm_ram_data_out,
				exsm_out_rden => ex_sm_out_rden
        );
		  
    -- Instantiate e_write_and_read_ram
    e_wr_inst : e_write_and_read_ram
		  generic map ( 
				NUM_DATA => NUM_DATA,
			   DATA_IN_LEN	=> DATA_IN_LEN,
				DATA_OUT_LEN => DATA_OUT_LEN,
			   ADDRESS_LEN => ADDRESS_LEN
				)
        port map (
            clk           => clk,
            reset         => reset,
				select_data		  => which_data,
            write_done    => ram_write_done,
            read_done     => internal_ram_read_done,
            ram_address   => e_rnw_ram_address,
            ram_data_in   => e_rnw_ram_data_in,
            ram_wren      => e_rnw_ram_wren,
            ram_rden      => e_rnw_ram_rden,
            ram_data_out  => e_rnw_ram_data_out,
				wr_out_rden	  => w_r_out_rden,
				ram_data_o	  => w_r_data_out
        );
	
    -- Multiplexing Logic for RAM Access
    mux_ram_address   <= e_rnW_ram_address  when mux_select = '0' else e_expsm_ram_address;
    -- mux_ram_data_in   <= e_rnW_ram_data_in  when mux_select = '0' else e_expsm_ram_data_in;
    mux_ram_wren      <= e_rnW_ram_wren     when mux_select = '0' else e_expsm_ram_wren;
    mux_ram_rden      <= e_rnW_ram_rden     when mux_select = '0' else e_expsm_ram_rden;
	 e_rnW_ram_data_out <= mux_ram_data_out when mux_select='0' else (others => '0');
	 e_expsm_ram_data_out <= mux_ram_data_out when mux_select='1' else (others => '0');
    -- Instantiate RAM
    ram_inst : config_ram_in
        port map (
            address => mux_ram_address,
            clock   => clk,
            data    => e_rnw_ram_data_in, --mux_ram_data_in,
            rden    => mux_ram_rden,
            wren    => mux_ram_wren,
            q       => mux_ram_data_out
        );
    ram_out_inst : config_ram_out
        port map (
            address => ram_out_addr,
            clock   => clk,
            data    => ram_out_data,
            rden    => ram_out_rden,
            wren    => ram_out_wren,
            q       => ram_out_q
        );
		  
	 -- Instantiate e_7seg_display
	 e_7seg_inst : e_7seg_display
	   port map(
		  clk          => clk,
		  reset        => reset,
		  display_mode => display_mode,
		  display_q 	=> display_ram_data,
		  seg_out      => seg_all
	   );

		  
	process (clk, reset, current_state, w_r_out_rden, ex_sm_out_rden) 
	begin 
		if rising_edge(clk) then 
			if reset = '0' then 
				current_state <= IDLE;
			   which_data        <= (others => '0');
			   which_process     <= (others => '0');
				ram_out_addr 		<= (others => '0');
				write_counter_wr	<= 0;
				write_counter_es	<= 0;
			else 
				current_state <= next_state;
				which_data	  <= which_data_next;
				which_process <= which_process_next;
				ram_out_rden  <= ram_out_rden_next;
				display_ram_data <= display_ram_data_next;
				
				case current_state is
				-- Write  the outputs of write and read process to Output RAM
					when RAM_PROCESS => 
						if w_r_out_rden = '1' then
							if write_counter_wr <= (NUM_DATA-1)  then
								ram_out_addr <= std_logic_vector(to_unsigned(write_counter_wr, ADDRESS_LEN));
								ram_out_data <= w_r_data_out;
								write_counter_wr <= write_counter_wr + 1;
							end if;
						end if;
					when EXPONENTIAL_SMOOTHING => 
						if ex_sm_out_rden = '1' then
							if write_counter_es <= (NUM_DATA-1)  then
								ram_out_addr <= std_logic_vector(to_unsigned(write_counter_es, ADDRESS_LEN));
								ram_out_data <= smoothed_out;
								write_counter_es <= write_counter_es + 1;
							end if;
						end if;
					when DISPLAY_RESULT =>	
						ram_out_addr <= sel_pins;
					when DISPLAY_INT_RESULT =>
						ram_out_addr <= sel_pins;
						
					when others =>
						null; 
				end case;
			end if;
		 end if;
	end process;
	
	process(current_state, internal_ram_read_done,sel_data, sel_process, ram_out_rden, display_ram_data,
				ram_out_q, start, ram_write_done, smooth_process_done, which_process, which_data, read_button)
	begin
		mux_select <= '0';
		start_smooth_process <= '0';
		ram_out_wren <= '0';
		
		next_state <= current_state;
		which_data_next <= which_data;
		which_process_next <= which_process;
		ram_out_rden_next <= ram_out_rden;
		display_ram_data_next <= display_ram_data;
		display_mode <= "000";  -- SELECT

		case current_state is
			when IDLE => 
				mux_select <= '0';
				start_smooth_process <= '0';
				ram_out_wren <= '0';
				which_data_next <= ( others => '0');
				which_process_next <= (others => '0');
				ram_out_rden_next <= '0';
				display_ram_data_next <= (others => '0');
				
				display_mode <= "000";  -- SELECT
				next_state <= SEL;
			when SEL =>
				ram_out_wren <= '0';
				display_mode <= "000";  -- SELECT
				if start = '0' then
					which_data_next <= sel_data;
					which_process_next <= sel_process;
					next_state <= RAM_PROCESS;
				else
					next_state         <= SEL;
				end if;
			when RAM_PROCESS =>
				 ram_out_wren <= '1';
				 if ram_write_done = '0' then
				    display_mode <= "001";  -- WRITE
					 mux_select <= '0';
					 start_smooth_process <= '0';
					 next_state <= RAM_PROCESS;
				 else
					 display_mode <= "010";  -- READ
					if internal_ram_read_done = '1' then 
						mux_select <= '1';
						next_state <= EXPONENTIAL_SMOOTHING;
					 else 
						mux_select <= '0';
						start_smooth_process <= '0';
						next_state <= RAM_PROCESS;
					end if;
				 end if;
			when EXPONENTIAL_SMOOTHING => 
					mux_select <= '1';
					ram_out_wren <= '1';
					if which_process(0) = '1' then
						start_smooth_process <= '1';
						display_mode <= "011";  -- SMOOTH
						if smooth_process_done = '1' then
							next_state <= DISPLAY_RESULT;
						else 
							next_state <= EXPONENTIAL_SMOOTHING;
						end if;
					 else 
						next_State <= DISPLAY_RESULT;
					 end if;
			when DISPLAY_RESULT =>
					ram_out_wren <= '0';
					ram_out_rden_next<= '1';
					display_mode <= "100";  -- COMPLT
							
					if read_button = '0' then
						display_mode <= "111"; -- will read the output data
						display_ram_data_next <= ram_out_q;
						next_state <= DISPLAY_INT_RESULT; 
					else
						next_state <= DISPLAY_RESULT;
					end if;	
			when DISPLAY_INT_RESULT =>
			 		ram_out_wren <= '0';
					ram_out_rden_next<= '1';
					if read_button = '0' then
						display_mode <= "111";
						display_ram_data_next <= ram_out_q;
						next_State <= DISPLAY_INT_RESULT;
					else 
						next_State <= DISPLAY_RESULT;
					end if;

		end case;
	end process;
	digit0_segs <= seg_all(6  downto 0);
   digit1_segs <= seg_all(13 downto 7);
   digit2_segs <= seg_all(20 downto 14);
   digit3_segs <= seg_all(27 downto 21);
   digit4_segs <= seg_all(34 downto 28);
   digit5_segs <= seg_all(41 downto 35);


end architecture behavioral;
