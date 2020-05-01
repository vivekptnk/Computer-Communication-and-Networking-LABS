--------------------------------------------------------------------------------
-- Company: 		Binghamton University
-- Engineer:		Carl Betcher
--
-- Create Date:   21:31:25 04/16/2011
-- Design Name:   Lab 7B Testbench
-- Module Name:   Test_Lab7B.vhd
-- Project Name:  Lab7
-- Target Device:  
-- Tool versions:  
-- Description:   
-- VHDL Test Bench Created by ISE for module: Lab7B_top_level
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- 					Run the test bench for 200 - 750 usec 
-- 					(depends upon amount of data in the two frames)
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY Test_Lab7B IS
END Test_Lab7B;
 
ARCHITECTURE behavior OF Test_Lab7B IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT Lab7B_top_level
	 GENERIC (debounceDELAY : integer := 640000); 
    PORT(
				dclk_out : out  STD_LOGIC;
				data_out : out  STD_LOGIC;
				frame_out : out  STD_LOGIC;
				sw : IN STD_LOGIC_VECTOR(7 downto 4);	
				btn : IN STD_LOGIC_VECTOR(1 downto 0);
				mclk : IN  std_logic
        );
    END COMPONENT;
    
   --Inputs
   signal mclk : std_logic := '0';
	signal sw : std_logic_vector(7 downto 4) := "0000" ;
	signal btn : std_logic_vector(1 downto 0) := "00" ;

 	--Outputs
	signal dclk_out : std_logic := '0';
	signal data_out : std_logic := '0';
	signal frame_out : std_logic := '0';

   -- Clock period definitions
--	constant mclk_period : time := 20 ns;    -- Basys2
	constant mclk_period : time := 31.25 ns; -- Papilio
	
	constant txdata_period : time := mclk_period*32; 
									-- period of each data bit sent
									-- is the period of 32 system clocks

BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: Lab7B_top_level 
	GENERIC MAP ( debounceDELAY => 3 )  
	PORT MAP (
			dclk_out => dclk_out,
			data_out => data_out,
			frame_out => frame_out,
			sw  => sw,
         btn => btn,
         mclk => mclk
        );

   -- Clock process definitions
   mclk_process :process
   begin
		mclk <= '0';
		wait for mclk_period/2;
		mclk <= '1';
		wait for mclk_period/2;
   end process;
 
 	-- External connections

   -- Stimulus process

   stim_proc: process
	
   begin	
		sw <= "0110" ;
      -- generate reset
		btn(0) <= '0' ;
      wait for mclk_period*5;	
		btn(0) <= '1' ;
      wait for mclk_period*5;	
		btn(0) <= '0' ;

      wait for mclk_period*24;	

		-- Generate LLC PDU (push button 1)
		btn(1) <= '1' ;
      wait for mclk_period*5;	
		btn(1) <= '0' ;

		-- Wait for MAC Frame to complete
		wait until rising_edge(frame_out);
		wait until falling_edge(frame_out);

      wait for 10 us;	

		-- Generate LLC PDU (push button 1)
		btn(1) <= '1' ;
      wait for mclk_period*5;	
		btn(1) <= '0' ;

      wait;
   end process;

END;