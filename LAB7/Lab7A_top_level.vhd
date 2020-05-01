----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:	    Carl Betcher
-- 
-- Create Date:    21:10:34 04/16/2011 
-- Design Name: 	 Ethernet MAC Protocol
-- Module Name:    Lab7A_top_level - Behavioral 
-- Project Name:   Lab7
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
--    April 2015 - Revisions for multi-board use
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Lab7A_top_level is
	 Generic (debounceDELAY : integer := 640000); 
														-- debounceDELAY = 20 mS / clk_period);
    Port ( 	LLC_PDU_data : OUT STD_LOGIC_VECTOR(7 downto 0);
				LLC_PDU_rdy : OUT STD_LOGIC;
				LLC_PDU_ack : IN STD_LOGIC;
				LLC_PDU_length : OUT STD_LOGIC_VECTOR(7 downto 0);
				btn : IN STD_LOGIC_VECTOR(1 downto 0);
				mclk : IN  STD_LOGIC);
end Lab7A_top_level;

architecture Behavioral of Lab7A_top_level is

	component debounce 
		 Generic ( DELAY : integer := 640000); -- DELAY = 20 mS / clk_period		
		 Port 	( sig_in 	: in  	std_logic;
					  clk 		: in  	std_logic;
					  sig_out 	: out  	std_logic);
	end component;

	component LLC_PDU_Gen 
		 Port ( rst : in  STD_LOGIC;
				  clk : in  STD_LOGIC;
				  gen_PDU : in  STD_LOGIC;
				  data_out : out  STD_LOGIC_VECTOR (7 downto 0);
				  data_ready : out  STD_LOGIC;
				  data_ack : in  STD_LOGIC;
				  PDU_length : out  STD_LOGIC_VECTOR (7 downto 0));
	end component;

	signal drst : std_logic;
	signal gen_PDU : std_logic;

begin

	-- Pushbutton debounce circuits
	RST_debounce: debounce 
	generic map ( DELAY => debounceDELAY )
	port map (	sig_in  => 	btn(0),
					clk     => 	mclk,
					sig_out => 	drst);

	Gen_PDU_debounce: debounce 
	generic map ( DELAY => debounceDELAY )
	port map (	sig_in  => 	btn(1),
					clk     => 	mclk,
					sig_out => 	gen_PDU);

	-- Logical Link Control Protocol Data Unit Generator
	LLC_PDU_GenA : LLC_PDU_Gen 
    Port map( 	rst 			=> drst,
					clk 			=> mclk,
					gen_PDU 		=> gen_PDU,
					data_out 	=> LLC_PDU_data,
					data_ready 	=> LLC_PDU_rdy,
					data_ack 	=> LLC_PDU_ack,
					PDU_length 	=> LLC_PDU_length);

end Behavioral;

