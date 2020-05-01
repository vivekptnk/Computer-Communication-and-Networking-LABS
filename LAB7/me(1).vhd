----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:		 
-- 
-- Create Date:    April 5, 2015 
-- Design Name: 	 Ethernet MAC Protocol
-- Module Name:    manchencoder - Behavioral 
-- Project Name:   Lab7
-- Target Devices: 
-- Tool versions: 
-- Description: 	 Manchester Encoder
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity manchencoder is
	port (rst, clk, nrz_in, frame_in, dclk_in : in std_logic;
			manout   : out std_logic);
end manchencoder;

architecture behavioral of manchencoder is

begin

-- Generate Manchester data signal from nrz_in and dclk_in
-- Output a zero level when frame_in is inactive
-- Synchronize output with clk

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then 
			if rst='1' then 
				manout <= '0';
			elsif frame_in = '0' then
				manout <= '0';
			else
				manout <= not(nrz_in) xor dclk_in;
			end if;
		end if;
	end process;
	
	
end behavioral;