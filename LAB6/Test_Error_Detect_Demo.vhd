--------------------------------------------------------------------------------
-- Company: 		Binghamton University
-- Engineer:		Carl Betcher
--
-- Create Date:   19:35:48 03/12/2011
-- Design Name:   Error Detection Performance of CRC Codes
-- Module Name:   Test_Error_Detect_Demo
-- Project Name:  Lab6
-- Target Device:  
-- Tool versions:  
-- Description:   Test bench 
-- 
-- VHDL Test Bench Created by ISE for module: Error_Detect_Demo
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY Test_Error_Detect_Demo IS
END Test_Error_Detect_Demo;
 
ARCHITECTURE behavior OF Test_Error_Detect_Demo IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT Error_Detect_Demo
	 GENERIC (debounceDELAY : integer := 640000; 
				 frame_error_rate : std_logic_vector (3 downto 0) := "1111" ); 
				-- Frame error rate is given by 
				--		(0.67108864 x 2**value) error frames per second	
				--	frame_error_rate := "1111" for simuation (max error rate)
    PORT(   								
         clk : IN  std_logic;
			DIR_LEFT : in  STD_LOGIC := '0';
			DIR_RIGHT : in  STD_LOGIC := '0';
			DIR_UP : in  STD_LOGIC := '0';
			DIR_DOWN : in  STD_LOGIC := '0';
			SW : in  STD_LOGIC_VECTOR (7 downto 0) := "00000000";
			LED : out  STD_LOGIC_VECTOR (7 downto 0);
			Seg7_SEG : out  STD_LOGIC_VECTOR (6 downto 0);
			Seg7_AN: out  STD_LOGIC_VECTOR (4 downto 0);
			Seg7_DP : out  STD_LOGIC;
         testsig_data : OUT  std_logic; 				
         testsig_error_frame : OUT  std_logic;		
         testsig_data_with_errors : OUT  std_logic;	
         testsig_error_detect : OUT  std_logic;		
			testsig_bit_errors : OUT std_logic			
        );
    END COMPONENT;
    
   --Inputs
   signal clk : std_logic := '0';
	signal DIR_LEFT  : STD_LOGIC := '0';
	signal DIR_RIGHT : STD_LOGIC := '0';
	signal DIR_UP    : STD_LOGIC := '0';
	signal DIR_DOWN  : STD_LOGIC := '0';
   signal SW : std_logic_vector(7 downto 0) := (others => '0');

 	--Outputs
   signal LED : std_logic_vector(7 downto 0);
   signal Seg7_SEG : std_logic_vector(6 downto 0);
   signal Seg7_AN : std_logic_vector(4 downto 0);
   signal Seg7_DP : std_logic;
   signal testsig_data : std_logic;
   signal testsig_error_frame : std_logic;
   signal testsig_data_with_errors : std_logic;
   signal testsig_error_detect : std_logic;
	signal testsig_bit_errors : std_logic;
	
	signal btn : std_logic_vector(3 downto 0);

   -- Clock period definitions
   constant clk_period : time := 31.25 ns;
 
	-- Test Data
	type test_vector is record
		buttons : std_logic_vector(3 downto 0);
		switches : std_logic_vector(7 downto 0);
	end record;

	type test_data_array is array (natural range <>) of test_vector;
	constant test_data : test_data_array :=
		(  ("0000", "00000000" ),  
			("0001", "00000000" ),  -- reset
			("0000", "00000000" ),  
			("0010", "10011001" ),  -- start
											-- error pattern 1
			("0000", "11010100" ),  -- error pattern 2
			("0000", "00101011" ),  -- error pattern 3
			("1000", "00000000" ),  -- random error pattern 1
			("0000", "00000000" ),  -- random error pattern 2
			("0000", "00000000" ),  -- random error pattern 3
			("0100", "00000000" ),  -- stop
			("0000", "00000000" )  );

BEGIN
	-- Instantiate the Unit Under Test (UUT)
   uut: Error_Detect_Demo 
	GENERIC MAP ( debounceDELAY => 3,  
							-- make debounce delay small in simulation
							-- debounceDELAY = 20 mS / clk_period)
					  frame_error_rate => "1111" ) 
							-- Frame error rate is given by (0.67108864 x 2**value) 
							--		error frames per second	
							--	Use frame_error_rate := "1111" for simuation
							-- 	(max error rate)
	PORT MAP (
					 clk => clk,
					 DIR_LEFT  => DIR_LEFT,   
                DIR_RIGHT => DIR_RIGHT,
                DIR_UP    => DIR_UP,   
                DIR_DOWN  => DIR_DOWN, 
					 SW => SW,
					 LED => LED,
					 Seg7_SEG =>Seg7_SEG,
					 Seg7_AN => Seg7_AN,
					 Seg7_DP => Seg7_DP,
					 testsig_data => testsig_data,
					 testsig_error_frame => testsig_error_frame,
					 testsig_data_with_errors => testsig_data_with_errors,
					 testsig_error_detect => testsig_error_detect,
					 testsig_bit_errors => testsig_bit_errors
				  );

 	-- Map Push Buttons: | DIR_DOWN | DIR_LEFT | DIR_RIGHT |   DIR_UP   |
	--         Button #: |  btn(0)  |  btn(1)  |  btn(2)   |   btn(3)   |
	--         Function: |  Reset   |  Start   |   Stop    | Error Mode |
	DIR_DOWN <= btn(0); DIR_LEFT <= btn(1); DIR_RIGHT <= btn(2); DIR_UP <= btn(3);

  -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
	-- process to report results of each error frame
	process
	begin
		wait until falling_edge(testsig_error_frame);
		wait for 200 ns;
		assert testsig_error_detect = '0' report "Error Detected" severity warning;
		assert testsig_error_detect = '1' report "Error Not Detected" severity warning;
	end process;
	
   -- Stimulus process
   stim_proc: process
   begin		

-- starting conditions
		-- btn = "0000" and SW = "00000000"
		btn <= test_data(0).buttons;	SW <= test_data(0).switches;
      wait for 100 ns;	
		-- press reset button
		btn <= test_data(1).buttons;	SW <= test_data(1).switches;
		assert btn(0) = '0' report "Reset Button Pressed" severity note;
      -- hold reset state for 20 us and release
      wait for 20 us;	
		btn <= test_data(2).buttons;	SW <= test_data(2).switches;
      wait for 2 us;

		-- press start button and set error pattern 1 in switches
		-- sequence through remaining switch test patterns except last two
		for i in 3 to test_data'right-2 loop
			btn <= test_data(i).buttons;	SW <= test_data(i).switches;
			assert false report "New Error Pattern" severity note;
			wait for 100 ns;
			assert btn(1) = '0' report "Start Button Pressed" severity note;
			wait until falling_edge(testsig_error_frame);
			wait for 100 ns;
		end loop;	
		
      -- press stop pushbutton
      wait for 20 us;	
		btn <= test_data(test_data'right-1).buttons;	
		SW <= test_data(test_data'right-2).switches;
		assert false report "Stop Button Pressed" severity note;
      wait for 40 us;	
      -- release stop pushbutton
		btn <= test_data(test_data'right).buttons;	
		SW <= test_data(test_data'right-2).switches;

      wait;
   end process;

END;





