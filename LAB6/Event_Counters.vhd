----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer: 		 Carl Betcher
-- 
-- Create Date:    21:39:22 03/22/2011 
-- Design Name: 	 Event Counters to count generated frame errors and detected 
--							frame errors for the CRC Error Detection Demo
-- Module Name:    Event_Counters - Behavioral 
-- Project Name: 	 Lab 6
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
--		March 2015 - Removed library package IEEE.STD_LOGIC_ARITH
--						 Replaced library package IEEE.STD_LOGIC_UNSIGNED 
--						 	with IEEE.NUMERIC_STD
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Event_Counters is
    Port ( generated_errors : in  STD_LOGIC;
           detected_errors : in  STD_LOGIC;
           count_gen_errors : out  STD_LOGIC_VECTOR (7 downto 0);
           count_det_errors : out  STD_LOGIC_VECTOR (7 downto 0);
           clk : in  STD_LOGIC;
           rst : in  STD_LOGIC);
end Event_Counters;

architecture Behavioral of Event_Counters is

	signal generated_errors_d1 : std_logic ;
	signal detected_errors_d1 : std_logic ;
	signal gen_error_cntr : unsigned(7 downto 0) := (others => '0');
	signal det_error_cntr : unsigned(7 downto 0) := (others => '0');

begin

	-- generated_errors delayed one clock cycle
	process (clk)
	begin
		if rising_edge(clk) then
			generated_errors_d1 <= generated_errors ;
		end if ;
	end process ;	

	-- detected_errors delayed one clock cycle
	process (clk)
	begin
		if rising_edge(clk) then
			detected_errors_d1 <= detected_errors ;
		end if ;
	end process ;	

	-- counter to count generated frame errors
	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				gen_error_cntr <= X"00" ;
			elsif (generated_errors and not(generated_errors_d1)) = '1' then
				gen_error_cntr <= gen_error_cntr + 1 ;
			else	
				gen_error_cntr <= gen_error_cntr ;
			end if ;	
		end if ;
	end process ;	

	-- counter to count detected frame errors
	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				det_error_cntr <= X"00" ;
			elsif (detected_errors and not(detected_errors_d1)) = '1' then
				det_error_cntr <= det_error_cntr + 1 ;
			else	
				det_error_cntr <= det_error_cntr ;
			end if ;	
		end if ;
	end process ;	

	count_gen_errors <= std_logic_vector(gen_error_cntr) ;
	count_det_errors <= std_logic_vector(det_error_cntr) ;

end Behavioral;

