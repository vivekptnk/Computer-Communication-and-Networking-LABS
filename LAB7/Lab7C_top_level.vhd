----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:		 Carl Betcher
-- 
-- Create Date:    21:10:34 04/16/2011 
-- Design Name: 	 Ethernet MAC Protocol
-- Module Name:    Lab7C_top_level - Behavioral 
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

entity Lab7C_top_level is
	 Generic (debounceDELAY : integer := 640000); -- debounceDELAY = 20 mS / clk_period);
    Port ( 	manin : IN STD_LOGIC;
				manout : OUT STD_LOGIC;
				dclk_in : IN STD_LOGIC;
				frame_in : IN STD_LOGIC;
				nrz_in  : IN  STD_LOGIC;
				dclk_out : OUT STD_LOGIC;
				frame_out : OUT STD_LOGIC;
				nrz_out : OUT  STD_LOGIC;
				mclk : IN  STD_LOGIC;
				rst : IN  STD_LOGIC);
end Lab7C_top_level;

architecture Behavioral of Lab7C_top_level is

	component debounce 
		 Generic ( DELAY : integer := 640000); -- DELAY = 20 mS / clk_period		
		 Port 	( sig_in 	: in  	std_logic;
					  clk 		: in  	std_logic;
					  sig_out 	: out  	std_logic);
	end component;

	component manchencoder is
		Port (rst,clk 	: in std_logic;
				dclk_in 	: in std_logic;
				frame_in	: in std_logic;
				nrz_in 	: in std_logic;
				manout 	: out std_logic);
	end component;

	component manchdecoder is
		Port (rst,clk 	: in std_logic ;
				manin 	: in std_logic ;
				dclk_out : out std_logic ;
				frame_out : out std_logic ;
				nrz_out 	: out std_logic ) ;
	end component ;

	signal drst : std_logic;

begin

	RST_debounce: debounce 
	generic map ( DELAY => debounceDELAY )
	port map (	sig_in => 	rst,
					clk    => 	mclk,
					sig_out => 	drst);

	ManEncoder: manchencoder port map	(	rst 		=> drst,
														clk 		=> mclk,
														dclk_in 	=> dclk_in,
														frame_in => frame_in,
														nrz_in 	=> nrz_in,
														manout	=> manout);

	ManDecoder: manchdecoder port map (	rst		 => drst,
													clk		 => mclk,
													manin		 => manin,
													dclk_out  => dclk_out,
													frame_out => frame_out,
													nrz_out	 => nrz_out);

end Behavioral;