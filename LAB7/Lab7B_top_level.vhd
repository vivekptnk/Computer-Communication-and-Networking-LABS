----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:	    Carl Betcher
-- 
-- Create Date:    21:10:34 04/16/2011 
-- Design Name: 	 Ethernet MAC Protocol
-- Module Name:    Lab7B_top_level - Behavioral 
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

entity Lab7B_top_level is
	 Generic (debounceDELAY : integer := 640000); 
														-- debounceDELAY = 20 mS / clk_period);
    Port ( 	dclk_out : out  STD_LOGIC;
				data_out : out  STD_LOGIC;
				frame_out : out  STD_LOGIC;
				sw : IN STD_LOGIC_VECTOR(7 downto 4);	
				btn : IN STD_LOGIC_VECTOR(1 downto 0);
				mclk : IN  STD_LOGIC);
end Lab7B_top_level;

architecture Behavioral of Lab7B_top_level is

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

	component MAC_Frame_Gen 
		 Port ( rst : in  STD_LOGIC;
				  clk : in  STD_LOGIC;
				  data_in : in  STD_LOGIC_VECTOR (7 downto 0);
				  data_ready : in  STD_LOGIC;
				  data_ack : out  STD_LOGIC;
				  PDU_length : in  STD_LOGIC_VECTOR (7 downto 0);
				  source_addr : in  STD_LOGIC_VECTOR (7 downto 0);
				  dest_addr : in  STD_LOGIC_VECTOR (7 downto 0);
				  dclk_out : out  STD_LOGIC;
				  data_out : out  STD_LOGIC;
				  frame_out : out  STD_LOGIC);
	end component;

	constant LLC_PDU_LENGTH_SIZE : integer := 8;
	constant LLC_PDU_DATA_SIZE : integer := 8;

	signal drst : std_logic;
	signal gen_PDU : std_logic;
	signal LLC_PDU_rdy : std_logic;
	signal LLC_PDU_ack : std_logic;
	signal LLC_PDU_length : std_logic_vector(LLC_PDU_LENGTH_SIZE-1 downto 0);
	signal LLC_PDU_data : std_logic_vector(LLC_PDU_DATA_SIZE-1 downto 0);
	signal MAC_dest_addr : std_logic_vector(7 downto 0);

begin

	-- Pushbutton debounce circuits
	RST_debounce: debounce 
	generic map ( DELAY => debounceDELAY )
	port map (	sig_in => 	btn(0),
					clk    => 	mclk,
					sig_out => 	drst);

	Gen_PDU_debounce: debounce 
	generic map ( DELAY => debounceDELAY )
	port map (	sig_in => 	btn(1),
					clk    => 	mclk,
					sig_out => 	gen_PDU);

	-- Logical Link Control Protocol Data Unit Generator
	LLC_PDU_GenA : LLC_PDU_Gen 
    Port map( 	rst 			=> drst,
					clk 			=> mclk,
					gen_PDU 		=> gen_PDU,
					data_out 	=> LLC_PDU_data,
					data_ready 	=> LLC_PDU_rdy,
					data_ack 	=> LLC_PDU_ack,
					PDU_length 		=> LLC_PDU_length);

	-- Media Access Control Protocol Frame Generator
	MAC_Frame_GenA : MAC_Frame_Gen 
    Port map( 	rst  			=> drst,
					clk 			=> mclk,
					data_in 		=> LLC_PDU_data,
					data_ready 	=> LLC_PDU_rdy,
					data_ack 	=> LLC_PDU_ack,
					PDU_length 	=> LLC_PDU_length,
					source_addr => "00000001",
					dest_addr 	=> MAC_dest_addr,
					dclk_out 	=> dclk_out,
					data_out 	=> data_out,
					frame_out 	=> frame_out );

	-- Destination address in MAC frame is Switches 7 downto 4
	MAC_dest_addr <= "0000" & sw(7 downto 4) ;
	
end Behavioral;