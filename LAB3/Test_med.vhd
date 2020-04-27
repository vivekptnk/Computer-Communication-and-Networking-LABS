--------------------------------------------------------------------------------
-- Company: 		Binghamton University
-- Engineer:      Carl Betcher
--
-- Create Date:   14:45:52 02/18/2011
-- Design Name:   
-- Module Name:   Test_med.vhd
-- Project Name:  Lab3
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: manchencdec
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY Test_med IS
END Test_med;
 
ARCHITECTURE behavior OF Test_med IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
    COMPONENT manchencdec
    PORT(
         rst     : IN  std_logic;
         clk     : IN  std_logic;
  			manout  : OUT std_logic;
			manin   : IN  std_logic;
         nrz_in  : IN  std_logic;
         nrz_out : OUT  std_logic
        );
    END COMPONENT;

   --Inputs
   signal rst : std_logic := '0';
   signal clk : std_logic := '0';
   signal nrz_in : std_logic := '1';
	signal manin : std_logic := '1';

 	--Outputs
   signal nrz_out : std_logic;
	signal manout : std_logic;

   -- Clock period definitions
--	constant clk_period : time := 20 ns;    -- Basys2
   constant clk_period : time := 31.25 ns; -- Papilio

	constant rdata_period : time := 32*clk_period; -- period of each data bit sent
																  -- is the period of 32 system
																  -- clocks		

BEGIN
	-- Instantiate the Unit Under Test (UUT)
   uut: manchencdec PORT MAP (
          rst => rst,
          clk => clk,
          nrz_in => nrz_in,
 			 manout => manout,
			 manin => manin,
          nrz_out => nrz_out
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
	-- External connections
	manin <= manout ;

   -- Stimulus process
   stim_proc: process
	
	procedure rxd_data (data: in std_logic_vector(10 downto 0)) is
	begin
		for I in 0 to 10 loop
			nrz_in <= data(I);
			wait for rdata_period;
			end loop;
		nrz_in <= '1';
		wait for rdata_period*5; -- wait period before next transmission 
	end procedure;
	
   begin	
		nrz_in <= '1' ;
      -- hold reset state for 100 ns.
		rst <= '1' ;
      wait for 100 ns;	
		rst <= '0' ;

      wait for clk_period*10;

      -- insert stimulus here 
		
		-- generate serial data input
		wait for rdata_period*2;  
		rxd_data("11101010100");   -- Valid data
		wait for 40 ns;
		rxd_data("10101110100");	-- Valid data	
		wait for 80 ns;
		rxd_data("01101010100");   -- Frame error
		wait for 120 ns;
		rxd_data("10101010100");   -- Parity error

      wait;
   end process;

END;