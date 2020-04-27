----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer: 		 Carl Betcher
-- 
-- Create Date:    14:35:01 03/22/2011 
-- Design Name: 	 Synchronous Outputs Connectors
-- Module Name:    Output_Port - Behavioral 
-- Project Name:   Lab6
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Output_Port is
    Port ( sig_in : in  STD_LOGIC_VECTOR (4 downto 0);
           sig_out : out  STD_LOGIC_VECTOR (4 downto 0);
           clk : in  STD_LOGIC);
end Output_Port;

architecture Behavioral of Output_Port is

begin

	process (clk)
	begin
		if rising_edge(clk) then
			sig_out <= sig_in ;
		end if ;
	end process;

end Behavioral;

