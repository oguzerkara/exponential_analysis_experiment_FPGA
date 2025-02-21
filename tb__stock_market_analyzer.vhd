library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end entity testbench;

architecture behavioral of testbench is

    -- Component Declaration for the DUT
    component tle_stock_market_analyzer
        generic (
            DATA_IN_LEN  : integer := 64;
            ADDRESS_LEN  : integer := 10;
            NUM_DATA     : integer := 1024;
            DATA_OUT_LEN : integer := 32
        );
        port (
            clk          : in  std_logic;
            reset        : in  std_logic;
            start        : in  std_logic;
            read_button  : in  std_logic;
            sel_pins     : in  std_logic_vector(9 downto 0);  -- Ensure correct naming
            digit0_segs  : out std_logic_vector(6 downto 0);
            digit1_segs  : out std_logic_vector(6 downto 0);
            digit2_segs  : out std_logic_vector(6 downto 0);
            digit3_segs  : out std_logic_vector(6 downto 0);
            digit4_segs  : out std_logic_vector(6 downto 0);
            digit5_segs  : out std_logic_vector(6 downto 0)
        );
    end component;

    -- Testbench Signals
    signal clk_tb          : std_logic := '0';
    signal reset_tb        : std_logic := '0';
    signal start_tb        : std_logic := '0';
    signal read_button_tb  : std_logic := '1';
    signal sel_sw_tb       : std_logic_vector(9 downto 0) := (others => '0');  
    signal digit0_segs_tb  : std_logic_vector(6 downto 0);
    signal digit1_segs_tb  : std_logic_vector(6 downto 0);
    signal digit2_segs_tb  : std_logic_vector(6 downto 0);
    signal digit3_segs_tb  : std_logic_vector(6 downto 0);
    signal digit4_segs_tb  : std_logic_vector(6 downto 0);
    signal digit5_segs_tb  : std_logic_vector(6 downto 0);

    -- Expected Segment Output (Active Low)
    constant expected_output : std_logic_vector(41 downto 0) := 
        "100000011110001111000100000001100000010010";

    -- Expected segment state for DISPLAY_RESULT
    constant expected_state : std_logic_vector(41 downto 0) := 
        "100011001000110001101000110010001110000111";

begin

    -- Instantiate the DUT
    uut: tle_stock_market_analyzer
        generic map (
            DATA_IN_LEN  => 64,
            ADDRESS_LEN  => 10,
            NUM_DATA     => 1024,
            DATA_OUT_LEN => 32
        )
        port map (
            clk          => clk_tb,
            reset        => reset_tb,
            start        => start_tb,
            read_button  => read_button_tb,
            sel_pins     => sel_sw_tb,  
            digit0_segs  => digit0_segs_tb,
            digit1_segs  => digit1_segs_tb,
            digit2_segs  => digit2_segs_tb,
            digit3_segs  => digit3_segs_tb,
            digit4_segs  => digit4_segs_tb,
            digit5_segs  => digit5_segs_tb
        );

    -- Clock Process (50 MHz, 20 ns period)
    clk_process: process
    begin
        while true loop
            clk_tb <= '0';
            wait for 10 ns;
            clk_tb <= '1';
            wait for 10 ns;
        end loop;
    end process;

    -- Test Stimulus
    stimulus: process
    begin
        -- Initial Reset
        reset_tb <= '0';
        start_tb <= '1';
        read_button_tb <= '1';
        sel_sw_tb <= "0000000000";  
        wait for 30 ns;  

        reset_tb <= '1';
        wait for 5000 ns;

        -- Set selection
        sel_sw_tb <= "0010011100";
        wait for 5000 ns;

        -- Start Process
        start_tb <= '0';
        wait for 5000 ns;
        start_tb <= '1';


		  
        -- Wait until segment outputs match DISPLAY_RESULT
        wait until (digit5_segs_tb & digit4_segs_tb & digit3_segs_tb &
                    digit2_segs_tb & digit1_segs_tb & digit0_segs_tb) = expected_state;
        report "DISPLAY_RESULT state reached!" severity note;
        sel_sw_tb <= "0000001100";
        wait for 5000 ns;
        -- Simulate Read Button Press
        read_button_tb <= '0';
        wait for 5000 ns;


        -- Compare expected output with actual segment outputs
        report "Checking segment outputs for sel_sw = 0000001100..." severity note;
        if (digit5_segs_tb & digit4_segs_tb & digit3_segs_tb &
                    digit2_segs_tb & digit1_segs_tb & digit0_segs_tb) /= expected_output then
            report "ERROR: Segment outputs do not match expected value!" severity error;
        else
            report "SUCCESS: Segment outputs match expected value!" severity note;
        end if;

        -- End Simulation
        report "Test Completed Successfully!" severity note;
		          read_button_tb <= '1';

        -- Wait for Display Mode Stability
        wait for 5000 ns;  
        wait;
    end process;

end architecture behavioral;
