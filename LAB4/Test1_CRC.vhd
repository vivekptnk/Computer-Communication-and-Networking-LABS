--------------------------------------------------------------------------------
-- Company: 		Binghamton University
-- Engineer:      Carl Betcher
--
-- Create Date:   16:31:46 03/02/2011
-- Design Name:   Test Bench 1 for Cyclic Redundancy Check (CRC) Error Detection Code
-- Module Name:   Test1_CRC.vhd
-- Project Name:  Lab4
-- Target Device:  
-- Tool versions:  
-- Description:   This test verifies both the generation and checker functions of the
--                CRC using two different data patterns.  The checker is tested with 
--						and without an error in the data. The second error generated is an
--						undetectable burst error with the same pattern as the predetermined
--						divisor.
--						Run simulation for 150 microseconds.
-- 
-- VHDL Test Bench Created by ISE for module: CRC
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
--		2/21/2015  - Added clock period constants for Papilio One
--					  - Updated gen_CRC_input procedure to have just one parameter (data)
--					    and to determine the length of the data vector rather than
--                 a parameter specifying the length
--		2/27/2016  - Wrote procedure to capture the output of the CRC consisting of 
--							data with FCS
--					  - Wrote process to use new procedure to capture the data generated
--					    	so that the gen_CRC_input procedure can use that data to test
--					  		the error checking capability and further verify the generated 
--							data
--					  - Modified the gen_CRC_input procedure to allow introducing an error
--							pattern into the data.
--               - Changed the test patterns
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY Test1_CRC IS
END Test1_CRC;
 
ARCHITECTURE behavior OF Test1_CRC IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT CRC
 	 Generic ( fcs_length : integer ); 
    PORT(
			P : std_logic_vector (fcs_length downto 0);
			data_in : IN  std_logic;
			dclk_in : IN  std_logic;
         frame_in : IN  std_logic;
         data_out : OUT  std_logic;
         dclk_out : OUT  std_logic;
         frame_out : OUT  std_logic;
         error_out : OUT  std_logic;
         mode : IN  std_logic;
         clk : IN  std_logic;
         rst : IN  std_logic
        );
    END COMPONENT;
    
	--Constants
	
	-- fcs_length defines the length of frame check sequence (FCS)
	constant fcs_length : integer := 5;
--	constant fcs_length : integer := 3;
	
   --Inputs
	
	-- P defines the predetermined divisor for the CRC 
	signal P : std_logic_vector (fcs_length downto 0) := "110101";
--	signal P : std_logic_vector (fcs_length downto 0) := "1011";
	
   signal data_in : std_logic := '0';
   signal dclk_in : std_logic := '0';
   signal frame_in : std_logic := '0';
   signal mode : std_logic := '0';
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';

 	--Outputs
	
   signal data_out : std_logic;
   signal dclk_out : std_logic;
   signal frame_out : std_logic;
   signal error_out : std_logic;

   -- Clock period definitions
	
--	-- Clock periods for Basys2
--	constant clk_period : time := 20 ns;   -- period of system clock
--	constant dclk_period : time := 640 ns; -- period of one data bit
 
	-- Clock Periods for Papilio
	constant clk_period : time := 31.25 ns; -- period of system clock
	constant dclk_period : time := 1000 ns; -- period of one data bit

	-- variable used to capture the serial output data of the CRC	
	shared variable CRC_output_data : std_logic_vector(14 downto 0);
	
	-- these signals are provided so that the values of the the captured CRC data,
	--    error pattern, and the data to be transmitted with errors
	--		can be viewed on the waveform viewer for debug purposes
	signal CRC_output_data_sig : std_logic_vector(14 downto 0) := (others => '0');
	signal error_pattern_sig : std_logic_vector(14 downto 0) := (others => '0');
	signal transmit_frame_sig : std_logic_vector(14 downto 0) := (others => '0');
	
BEGIN
 
	-- INSTANTIATION OF UNIT UNDER TEST (UUT)
   uut: CRC
		GENERIC MAP (fcs_length => fcs_length)
		PORT MAP (
			 P => P,
          data_in => data_in,
			 dclk_in => dclk_in,
          frame_in => frame_in,
          data_out => data_out,
			 dclk_out => dclk_out,
          frame_out => frame_out,
          error_out => error_out,
          mode => mode,
          clk => clk,
          rst => rst
        );

   -- CLK CLOCK PROCESS
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
	-- DCLK CLOCK PROCESS
   dclk_process :process
   begin
		dclk_in <= '0';
		wait for dclk_period/2;
		dclk_in <= '1';
		wait for dclk_period/2;
   end process;
 
	-- PROCESS TO CAPTURE CRC OUTPUT DATA
	capture_proc: process
	--	procedure to capture CRC serial output data
	procedure capture_CRC_output (data: out std_logic_vector) is
	variable I : integer;
	begin
		wait until frame_out = '1' and frame_out'event;
		wait until dclk_out = '1' and dclk_in'event;
		for I in data'range loop
			data(I) := data_out;
			wait until dclk_in = '1' and dclk_in'event;
			end loop;
	end procedure;
	begin
		capture_CRC_output (CRC_output_data);
		CRC_output_data_sig <= CRC_output_data;
	end process capture_proc;

   -- STIMULUS PROCESS
   stim_proc: process
	--	procedure to generate CRC serial input data
	-- data parameter is data to be input to the CRC
	-- error parameter is error pattern to be applied to the data
	procedure gen_CRC_input (data: in std_logic_vector; error: in std_logic_vector) is
	begin
		wait until dclk_in = '0' and dclk_in'event;  -- wait for falling edge of dclk
		frame_in <= '1';										-- set frame input to '1'
		for I in data'range loop
			data_in <= data(I) xor error(I);   		-- put next data bit on data_in
																-- induce error if error bit is '1'
			wait until dclk_in = '0' and dclk_in'event;-- wait for falling edge of dclk
			end loop;
		frame_in <= '0';               				-- set frame input to '0'
		data_in <= '0';                 				-- set data_in to '0'
	end procedure;
   begin		
      -- GENERATE RESET
      rst <= '1';
		wait for 100 ns;	
      rst <= '0';
      wait for clk_period*10;

		report "CRC TEST 1 STARTED";
		
		-- GENERATE DATA WITH FCS
		-- set mode for FCS generation	
		mode <= '1';
      wait for dclk_period*3;
		-- generate a k-bit data sequence to generate a corresponding FCS 
		gen_CRC_input("1010001101","0000000000");
      wait for dclk_period*3;
		
		-- CHECK DATA WITH FCS FOR ERRORS - NO ERRORS
		-- set mode for error detection
		mode <= '0';
      wait for dclk_period*2;
		-- generate data sequence using captured CRC output for previous FCS generation
		error_pattern_sig <= "000000000000000"; -- no errors
		wait for dclk_period;
		transmit_frame_sig <= CRC_output_data_sig XOR error_pattern_sig;
		gen_CRC_input(CRC_output_data, error_pattern_sig);
      wait for dclk_period*3;
		wait until dclk_in = '1' and dclk_in'event;
		assert error_out = '0' 
		report "Detected an error when there should not have been an error" 
					severity ERROR;
		
		-- CHECK DATA WITH FCS FOR ERRORS - SINGLE BIT ERROR
		-- set mode for error detection
		mode <= '0';
      wait for dclk_period*2;
		-- generate data sequence using captured CRC output for previous FCS generation
		-- insert a single bit error
		error_pattern_sig <= "000001000000000"; -- single bit error
		wait for dclk_period;
		transmit_frame_sig <= CRC_output_data_sig XOR error_pattern_sig;
		gen_CRC_input(CRC_output_data_sig, error_pattern_sig);
      wait for dclk_period*3;
		wait until dclk_in = '1' and dclk_in'event;
		assert error_out = '1' 
		report "Did not detected error in data" severity ERROR;
		
		-- GENERATE DATA WITH FCS - DIFFERENT DATA PATTERN
		-- set mode for FCS generation	
		mode <= '1';
      wait for dclk_period*3;
		-- generate a k-bit data sequence to generate a corresponding FCS 
		gen_CRC_input("0011000111","0000000000");
		wait for dclk_period*3;
		
		-- CHECK DATA WITH FCS FOR ERRORS - NO ERRORS
		-- set mode for error detection
		mode <= '0';
      wait for dclk_period*2;
		-- generate data sequence using captured CRC output for previous FCS generation
		error_pattern_sig <= "000000000000000"; -- no error
		wait for dclk_period;
		transmit_frame_sig <= CRC_output_data_sig XOR error_pattern_sig;
		gen_CRC_input(CRC_output_data, error_pattern_sig);
      wait for dclk_period*3;
		wait until dclk_in = '1' and dclk_in'event;
		assert error_out = '0' 
		report "Detected an error when there should not have been an error" 
					severity ERROR;
		
		-- CHECK DATA WITH FCS FOR ERRORS - UNDETECTABLE BURST ERROR PATTERN
		-- set mode for error detection
		mode <= '0';
      wait for dclk_period*2;
		-- generate data sequence using captured CRC output for previous FCS generation
		-- insert a single bit error
		error_pattern_sig <= "000011010100000"; -- error pattern cannot be detected
		wait for dclk_period;
		transmit_frame_sig <= CRC_output_data_sig XOR error_pattern_sig;
		gen_CRC_input(CRC_output_data, error_pattern_sig);
      wait for dclk_period*3;
		wait until dclk_in = '1' and dclk_in'event;
		assert error_out = '0' 
		report "This error pattern should not be detectable by the CRC" severity ERROR;
		
		-- CHECK DATA WITH FCS FOR ERRORS - DETECTABLE BURST ERROR PATTERN
		-- set mode for error detection
		mode <= '0';
      wait for dclk_period*2;
		-- generate data sequence using captured CRC output for previous FCS generation
		-- insert a single bit error
		error_pattern_sig <= "001011010100000"; -- error pattern should be detected
		wait for dclk_period;
		transmit_frame_sig <= CRC_output_data_sig XOR error_pattern_sig;
		gen_CRC_input(CRC_output_data, error_pattern_sig);
		wait until dclk_in = '1' and dclk_in'event;
      wait for dclk_period*3;
		assert error_out = '1' 
		report "Did not detected error in data" severity ERROR;

		report "CRC TEST 1 COMPLETED";

      wait;
   end process;

END;
