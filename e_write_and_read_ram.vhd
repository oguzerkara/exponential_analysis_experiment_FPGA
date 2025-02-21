library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity e_write_and_read_ram is
	generic (
		  NUM_DATA		 : integer := 1024;
		  DATA_IN_LEN		 : integer := 64;
		  DATA_OUT_LEN	 : integer := 32;
		  ADDRESS_LEN	 : integer := 10
	);
    port(
        clk           : in  std_logic;
        reset         : in  std_logic;
		  select_data	 : in std_logic_vector(2 downto 0);

        write_done    : out std_logic;
        read_done     : out std_logic;
		  
        ram_data_out  : in std_logic_vector((DATA_IN_LEN -1 ) downto 0);
		  ram_data_o    : out std_logic_vector((DATA_OUT_LEN -1) downto 0);		  
		  ram_address	 : out std_logic_vector((ADDRESS_LEN -1 ) downto 0);
		  ram_data_in	 : out std_logic_vector((DATA_IN_LEN -1 ) downto 0);
		  ram_wren		 : out std_logic;
		  wr_out_rden	 : out std_logic;
		  ram_rden		 : out std_logic
    );
end entity e_write_and_read_ram;

architecture behavioral of e_write_and_read_ram is

    -- Component Declarations
    component config_rom_AAPL
        port (
            address : in  std_logic_vector((ADDRESS_LEN -1 ) downto 0);
            clock   : in  std_logic;
            q       : out std_logic_vector((DATA_IN_LEN -1 ) downto 0)
        );
    end component;

    component config_rom_NVDA
        port (
            address : in  std_logic_vector((ADDRESS_LEN -1 ) downto 0);
            clock   : in  std_logic;
            q       : out std_logic_vector((DATA_IN_LEN -1 ) downto 0)
        );
    end component;

    component config_rom_BTCUSD
        port (
            address : in  std_logic_vector((ADDRESS_LEN -1 ) downto 0);
            clock   : in  std_logic;
            q       : out std_logic_vector((DATA_IN_LEN -1 ) downto 0)
        );
    end component;

    -- State Definitions
    type state_type is (IDLE, WRITE, READ, READ_END);
    signal current_state, next_state : state_type := IDLE;

    -- Signals for Interconnection
    signal rom_data       : std_logic_vector((DATA_IN_LEN -1 ) downto 0);
	 signal rom_data_aapl  : std_logic_vector((DATA_IN_LEN -1 ) downto 0);
    signal rom_data_nvda  : std_logic_vector((DATA_IN_LEN -1 ) downto 0);
    signal rom_data_btc   : std_logic_vector((DATA_IN_LEN -1 ) downto 0);

    signal rom_address      : std_logic_vector((ADDRESS_LEN -1 ) downto 0) := (others => '0');
	 signal rom_address_aapl : std_logic_vector((ADDRESS_LEN -1 ) downto 0) := (others => '0');
	 signal rom_address_nvda : std_logic_vector((ADDRESS_LEN -1 ) downto 0) := (others => '0');
	 signal rom_address_btc  : std_logic_vector((ADDRESS_LEN -1 ) downto 0) := (others => '0');
	 
    signal write_counter  : integer range 0 to NUM_DATA := 0;
    signal read_counter   : integer range 0 to NUM_DATA := 0;

    signal write_complete : std_logic := '0';
    signal read_complete  : std_logic := '0';

begin
	
    -- Instantiate ROM
    rom_AAPL_inst : config_rom_AAPL
        port map (
            address => rom_address_aapl,
            clock   => clk,
            q       => rom_data_aapl
        );
		  
    rom_NVDA_inst : config_rom_NVDA
        port map (
            address => rom_address_nvda,
            clock   => clk,
            q       => rom_data_nvda
        );
		  
    rom_BTC_inst : config_rom_BTCUSD
        port map (
            address => rom_address_btc,
            clock   => clk,
            q       => rom_data_btc
        );
		  
	rom_address_aapl <= rom_address when select_data = "000" else (others => '0');
	rom_address_nvda <= rom_address when select_data = "001" else (others => '0');
	rom_address_btc  <= rom_address when select_data = "010" else (others => '0');
	
	with select_data select
	
		rom_data <= rom_data_aapl when "000",
								 rom_data_nvda when "001",
								 rom_data_btc when "010",
								 (others => '0') when others;
		
	-- Sequential Process for WRITE and READ Operations
	process(clk, reset, current_state)
	begin
		 if rising_edge(clk) then
			  if reset = '0' then
					write_counter <= 0;
					read_counter <= 0;
					write_complete <= '0';
					read_complete <= '0';
			  else
					current_state <= next_state; -- Update current state

					case current_state is
						 when WRITE =>
							  if write_counter <= (NUM_DATA-1) then
									rom_address <= std_logic_vector(to_unsigned(write_counter, ADDRESS_LEN));
									ram_address <= std_logic_vector(to_unsigned(write_counter, ADDRESS_LEN)); -- Match RAM address to write_counter
									ram_data_in <= rom_data;
									write_counter <= write_counter + 1;
									write_complete <= '0';
									read_complete <= '0';
							  else
									write_complete <= '1';
									read_complete <= '0';
							  end if;

						 when READ =>
							  if read_counter <= (NUM_DATA-1) then
									ram_address <= std_logic_vector(to_unsigned(read_counter, ADDRESS_LEN));
									ram_data_o	<= ram_data_out((DATA_OUT_LEN -1) downto 0);								
									read_counter <= read_counter + 1;
									read_complete <= '0';
									write_complete <= '1';
							  else
									read_complete <= '1';
									write_complete <= '1';
							  end if;
						 when READ_END =>
								read_complete <= '1';
								write_complete <= '1';
								

						 when others =>
							  write_complete <= '0';
							  read_complete <= '0';
					end case;
			  end if;
		 end if;
	end process;


    -- Combinational Process: Define state transitions and next state logic
    process(current_state, write_complete, read_complete)
    begin
        next_state <= current_state; -- Default assignment
        ram_wren <= '0'; -- Default
        ram_rden <= '0'; -- Default
		  wr_out_rden <= '0';

        case current_state is
            when IDLE =>
                ram_wren <= '0';
                ram_rden <= '0';
					 wr_out_rden <= '0';

                if write_complete = '0' then
                    next_state <= WRITE;
                elsif read_complete = '0' then
                    next_state <= READ;
                else
                    next_state <= IDLE;
                end if;

            when WRITE =>
				
                ram_wren <= '1';
					 wr_out_rden <= '0';

                if write_complete = '1' then
                    next_state <= IDLE;
                else
                    next_state <= WRITE;
                end if;

            when READ =>
                ram_rden <= '1';
					 wr_out_rden <= '1';

                if read_complete = '1' then
                    next_state <= READ_END;
                else
                    next_state <= READ;
                end if;
				when READ_END =>
					 ram_rden <= '0';
					 wr_out_rden <= '0';
					 next_state <= READ_END;

            when others =>
                next_state <= IDLE;
                ram_wren <= '0';
                ram_rden <= '0';
					 wr_out_rden <= '0';
        end case;
    end process;


    -- Output Assignments
    write_done <= write_complete;
	 read_done <= read_complete;

end architecture behavioral;
