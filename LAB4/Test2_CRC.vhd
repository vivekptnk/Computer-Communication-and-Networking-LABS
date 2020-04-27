--------------------------------------------------------------------------------
-- Company: 		Binghamton University
-- Engineer:		Carl Betcher
--
-- Create Date:   16:31:46 03/02/2011
-- Design Name:   Test Bench 2 for Cyclic Redundancy Check (CRC) Error Detection Code
-- Module Name:   Test2_CRC.vhd
-- Project Name:  Lab4
-- Target Device:  
-- Tool versions:  
-- Description:   This test bench tests the CRC using all possible error patterns
--						and captures the undetected error patterns in a file
--
--						Run the simulation for 
--							Basys2:      6.5 milliseconds   
--							Papilio One: 7.5 milliseconds  
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
--    2/27/2016  - Implemented with new capture_CRC_output procedure and gen_CRC_input
--					    procedure from Test1_CRC test bench
--    2/17/2017  - Stimulus code now adapts to the frame size. The value of k (length
--                 of the data in a frame) can be changed without modifying stimulus 
--                 code. The data is now a new random pattern for each frame. For  
--						 every pass through the stimulus loop, (1) a frame is generated with
--						 the data plus FCS, (2) that frame is error checked, and (3) then 
--						 the frame is infected with an error pattern and checked again with
--						 the CRC. Added an assert in (2) to expect error_out=0.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
library std;
use std.textio.all; 
use ieee.math_real.all;

ENTITY Test2_CRC IS
END Test2_CRC;
 
ARCHITECTURE behavior OF Test2_CRC IS 
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
	-- number of bits of data to use in the transmitted frame
	constant k : integer := 5;
	
	-- fcs_length defines the length of frame check sequence (FCS) added to the data
		--constant fcs_length : integer := 6 ;
		--constant fcs_length : integer := 5 ;
		constant fcs_length : integer := 4 ;
		--constant fcs_length : integer := 3 ;
		--constant fcs_length : integer := 2 ;
		--constant fcs_length : integer := 1 ;
	
   --Inputs
	-- P defines the predetermined divisor for the CRC 
		--signal P : std_logic_vector (fcs_length downto 0) := "110101";
		signal P : std_logic_vector (fcs_length downto 0) := "10011";
		--signal P : std_logic_vector (fcs_length downto 0) := "11001";
		--signal P : std_logic_vector (fcs_length downto 0) := "1011";
		--signal P : std_logic_vector (fcs_length downto 0) := "111";
		--signal P : std_logic_vector (fcs_length downto 0) := "11";
	
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
 
	-- Variables
	shared variable FCS : std_logic_vector(fcs_length-1 downto 0) := (others => '0');
	shared variable data_value : std_logic_vector(k-1 downto 0);
	shared variable transmit_frame : std_logic_vector(k+fcs_length-1 downto 0);
	shared variable error_pattern : std_logic_vector(k+fcs_length-1 downto 0);
	shared variable frame_with_errors : std_logic_vector(k+fcs_length-1 downto 0);
	shared variable CRC_output_data : std_logic_vector(k+fcs_length-1 downto 0);

	-- Signals for displaying vaiable values on the waveform viewer for debug purposes
	signal transmit_frame_sig : std_logic_vector(k+fcs_length-1 downto 0)  
																	               := (others => '0');
	signal error_pattern_sig : std_logic_vector(k+fcs_length-1 downto 0)
																	               := (others => '0');
	signal frame_with_errors_sig : std_logic_vector(k+fcs_length-1 downto 0) 
																	               := (others => '0');
	signal CRC_output_data_sig : std_logic_vector(k+fcs_length-1 downto 0) 
																	               := (others => '0');


BEGIN
	-- Instantiate the Unit Under Test (UUT)
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

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
   dclk_process :process
   begin
		dclk_in <= '0';
		wait for dclk_period/2;
		dclk_in <= '1';
		wait for dclk_period/2;
   end process;
 

	-- PROCESS TO CAPTURE THE CRC OUTPUT DATA
	capture_proc: process

	--	PROCEDURE TO CAPTURE THE CRC SERIAL OUTPUT DATA
	procedure capture_CRC_output (data: out std_logic_vector(k+fcs_length-1 downto 0))
	is
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
	
		capture_CRC_output(CRC_output_data);
	
	end process capture_proc;


   -- STIMULUS PROCESS
   stim_proc: process
	
	--	PROCEDURE TO GENERATE CRC SERIAL INPUT DATA
	-- data parameter is data to be input to the CRC
	-- error parameter is error pattern to be applied to the data
	procedure gen_CRC_input (data:  in std_logic_vector; 
									 error: in std_logic_vector) is
	begin
		wait until dclk_in = '0' and dclk_in'event;  -- wait for falling edge of dclk
		frame_in <= '1';										-- set frame input to '1'
		for I in data'range loop
			data_in <= data(I) xor error(I);       -- put next data bit on data_in
																-- induce error if error bit is '1'
			wait until dclk_in = '0' and dclk_in'event;-- wait for falling edge of dclk
			end loop;
		frame_in <= '0';               				-- set frame input to '0'
		data_in <= '0';                 				-- set data_in to '0'
	end procedure;

	-- OPEN FILE TO WRITE UNDETECTED ERROR PATTERNS
   FILE error_to_file: TEXT is out "CRC_undetected_errors.txt";
   variable file_line : LINE;
	variable line_content : string(1 to error_pattern'length);	
	
	-- VARIABLE DECLARATIONS FOR RANDOM BIT GENERATOR
	variable seed1, seed2: positive;	-- Seed values for random generator
	variable rand: real;					-- Random real-number value in range 0 to 1.0
	variable int_rand: integer;		-- Random integer value in range 0..4095
	variable error_zeros : std_logic_vector(k-1 downto 0) := (others => '0');
												-- Used to specify no errors when 
												--     generating the FCS
												-- using the gen_CRC_input procedure
	
   begin		
      -- GENERATE RESET
      rst <= '1' ;
		wait for 100 ns;	
      rst <= '0' ;
      wait for clk_period*10;

		report "CRC TEST 2 STARTED";

		-- GENERATE INPUTS TO CRC AND CHECK ITS OUTPUTS
		-- generate the n-bit sequence with data + FCS 
		--     and insert all possible error combinations
		-- input each sequence with errors to the CRC
		-- capture the undetected error patterns
		
		report "TESTING FOR UNDETECTED ERROR PATTERNS"; 
		for I in 1 to 2**transmit_frame'length-1 loop -- I = all possible error patterns

			-- (1) generate a random k-bit data sequence and generate a corresponding FCS 
			mode <= '1' ;							-- set mode for FCS generation
			UNIFORM(seed1, seed2, rand); 		-- rand = random real number 0-1
			int_rand := integer(TRUNC(rand*real(2**k))); 
														-- scale rand to range of data_value
			data_value := std_logic_vector(to_unsigned(int_rand, data_value'LENGTH));
														-- random integer becomes 
														-- data to be transmitted
			wait for dclk_period*5;
			gen_CRC_input (data_value,error_zeros) ; 	-- input the data to the CRC
														-- output is captured in CRC_output_data
			wait for dclk_period*5;
			
			-- (2) generate a n-bit sequence with data + FCS
			mode <= '0' ;								-- set mode for error detection
			error_pattern := (others => '0');   -- no errors
			wait for dclk_period*5;
			-- data to transmit is last CRC generated frame
			transmit_frame := CRC_output_data;  
			-- input the transmitted frame to CRC for error detection
			gen_CRC_input (transmit_frame,error_pattern) ;	
			wait for dclk_period*4;
			-- message to console when error_out = '1'
			assert error_out = '0' 
				report "UNEXPECTED ERROR DETECTED BY CRC" severity error;
			wait for dclk_period*1;									

			-- (3) generate an error pattern and apply it to the transmit_frame
			error_pattern := std_logic_vector(to_unsigned(I,error_pattern'length));
			frame_with_errors := transmit_frame XOR error_pattern;
			-- next four lines allow display of the four variables on the waveform viewer
			CRC_output_data_sig <= CRC_output_data;
			transmit_frame_sig <= transmit_frame;
			error_pattern_sig <= error_pattern;
			frame_with_errors_sig <= frame_with_errors;
			-- input the frame with errors to the CRC
			gen_CRC_input (transmit_frame,error_pattern) ;
			wait for dclk_period*4;
			-- message to console when error_out = '0'
			assert error_out = '1' report "ERROR NOT DETECTED" severity note;
			-- if undetected error, then write error pattern to file
			if error_out = '0' then
				-- convert each bit value of pattern to character for writing to file.
				for J in 0 to error_pattern'length-1 loop
					if(error_pattern(J) = '0') then
						line_content(error_pattern'length-J) := '0';
					else
						line_content(error_pattern'length-J) := '1';
					end if;
				end loop;
				write(file_line,line_content); 			-- write to the row
				writeline(error_to_file, file_line); 	-- write row to output file
			else
				null;
			end if;
			wait for dclk_period*1;
		end loop;
		file_close(error_to_file);
		
		report "CRC TEST 2 COMPLETED";
		
		wait;
   end process;
END;
