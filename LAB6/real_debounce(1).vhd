----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09/24/2014 
-- Design Name: 
-- Module Name:    debounce - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:    A real debounce circuit that waits a DELAY before accepting
--						 the change in level of the input signal, thus filtering out
--						 any instabilities of the signal level
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity debounce is
	 Generic ( DELAY : integer := 640000 -- DELAY = 20 mS / clk_period
			);
    Port ( clk : in  STD_LOGIC;
			  sig_in : in  STD_LOGIC;
			  sig_out : out  STD_LOGIC
			);
end debounce;

architecture Behavioral of debounce is

	type state_type is (S1, S2, S3, S4, S5);
	signal state : state_type := S1;
	signal next_state : state_type;
	
	signal timer : integer range 0 to DELAY := 0; 
	signal ld_timer : std_logic;
	signal en_timer : std_logic;
	signal timer_eq_0 : std_logic;
	
begin

	process(clk)
	begin
		if rising_edge(clk) then
			if ld_timer = '1' then
				timer <= DELAY; 
			elsif en_timer = '1' then
				timer <= timer - 1;
			else
				timer <= timer;
			end if;
		end if;
	end process;

	process(timer)
	begin
		if timer = 0 then
			timer_eq_0 <= '1';
		else	
			timer_eq_0 <= '0';
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			state <= next_state;
		end if;
	end process;

	process(state,sig_in,timer_eq_0)
	begin
		ld_timer <= '0';
		en_timer <= '0';
		sig_out <= '0';
		case(state) is
			when S1 =>
				ld_timer <= '1';
				if sig_in = '1' then next_state <= S2; 
				else next_state <= S1; end if;
			when S2 =>
				en_timer <= '1';
				if sig_in = '0' then next_state <= S1; 
				elsif timer_eq_0 = '1' then next_state <= S3; 
				else next_state <= S2; end if;
			when S3 =>
				sig_out <= '1';
				next_state <= S4; 
			when S4 =>
				ld_timer <= '1';
				if sig_in = '0' then next_state <= S5; 
				else next_state <= S4; end if;
			when S5 =>
				en_timer <= '1';
				if sig_in = '1' then next_state <= S4; 
				elsif timer_eq_0 = '1' then next_state <= S1; 
				else next_state <= S5; end if;
		end case;
					
	end process;
 
end Behavioral;

