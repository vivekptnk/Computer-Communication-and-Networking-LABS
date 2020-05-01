----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:		 Carl Betcher
-- 
-- Create Date:    21:10:34 04/16/2011 
-- Design Name: 	 Ethernet MAC Protocol
-- Module Name:    Lab7D_top_level - Behavioral 
-- Project Name:	 Lab7
-- Description: 	 
--
-- Revision: 
-- Revision 0.01 - File Created
--    April 2015 - Revisions for multi-board use
--    			  - Added modulation to the HexDisp decimal point input to 
--						 make the dp blink to show CRC error detection
--    April 2018 - Revised code for use with Papilio Duo FPGA board with
--						 LogicStart Shield
--						 Deferred adding more board interface logic until part E
--							(e.g. HEXon7segDisp)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Lab7D_top_level is
	 Generic (debounceDELAY : integer := 640000); 
														-- debounceDELAY = 20 mS / clk_period);
    Port ( 	manout : OUT  std_logic;
				manin : IN  std_logic;
				sw : IN STD_LOGIC_VECTOR(7 downto 0);	
				btn : IN STD_LOGIC_VECTOR(1 downto 0);
				led : out  STD_LOGIC_VECTOR (7 downto 0);
				Last_LLC_data_reg : OUT std_logic_vector(7 downto 0);
				Last_MFD_data_reg : OUT std_logic_vector(7 downto 0);
			   MFD_CRC_Error_out : out std_logic;
				mclk : IN  STD_LOGIC);
end Lab7D_top_level;

architecture Behavioral of Lab7D_top_level is

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

	component MAC_Frame_Dec 
		 Port ( rst : in  STD_LOGIC;
				  clk : in  STD_LOGIC;
				  dclk_in : in  STD_LOGIC;
				  data_in : in  STD_LOGIC;
				  frame_in : in  STD_LOGIC;
				  MAC_addr_in : in  STD_LOGIC_VECTOR (7 downto 0);
				  dclk_out : out  STD_LOGIC;
				  data_out : out  STD_LOGIC_VECTOR (7 downto 0);
				  dest_addr_out : out  STD_LOGIC_VECTOR (7 downto 0);
				  CRC_Error_out : out STD_LOGIC);
	end component;

	component manchencoder is
		Port (rst,clk 	: in std_logic;
				dclk_in 	: in std_logic;
				frame_in	: in std_logic;
				nrz_in 	: in std_logic;
				manout 	: out std_logic);
	end component;

	component manchdecoder is
		Port (rst,clk 	: in std_logic;
				manin 	: in std_logic;
				dclk_out : out std_logic;
				frame_out : out std_logic;
				nrz_out 	: out std_logic );
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
	signal rx_MAC_addr : std_logic_vector(7 downto 0);
	signal dest_MAC_addr_out : STD_LOGIC_VECTOR (7 downto 0);

	signal tx_dclk : std_logic;
	signal tx_data : std_logic;
	signal tx_frame : std_logic;

	signal rx_dclk : std_logic;
	signal rx_data : std_logic;
	signal rx_frame : std_logic;
	
	signal MFD_dclk_out : std_logic;
	signal MFD_data_out : std_logic_vector(7 downto 0);

begin
	-- some I/O connections
	-- sw 4-7 is destination address in data frame
	MAC_dest_addr <= "0000" & sw(7 downto 4); 
	-- sw 0-3 is MAC address of receiver (MAC Frame Decoder)
	rx_MAC_addr   <= "0000" & sw(3 downto 0); 
	-- display intended destination address on leds 4-7
	led(7 downto 4) <= sw(7 downto 4); 
	-- display destination address received on leds 0-3
	led(3 downto 0) <= dest_MAC_addr_out(3 downto 0); 
	
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
					PDU_length 	=> LLC_PDU_length);

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
					dclk_out 	=> tx_dclk,
					data_out 	=> tx_data,
					frame_out 	=> tx_frame );

	-- Manchester Encoder
	EncoderA : manchencoder port map	(	rst 		=> drst,
													clk 		=> mclk,
													dclk_in 	=> tx_dclk,
													frame_in => tx_frame,
													nrz_in 	=> tx_data,
													manout	=> manout);

	-- Manchester Decoder
	DecoderB : manchdecoder port map (	rst		 => drst,
													clk		 => mclk,
													manin		 => manin,
													dclk_out  => rx_dclk,
													frame_out => rx_frame,
													nrz_out	 => rx_data);

	-- Media Access Control Protocol Frame Decoder
	MAC_Frame_DecB : MAC_Frame_Dec 
    Port map( 	rst  				=> drst,
					clk 				=> mclk,
					dclk_in 			=> rx_dclk,
					data_in 			=> rx_data,
					frame_in 		=> rx_frame,
					MAC_addr_in 	=> rx_MAC_addr,
					dclk_out 		=> MFD_dclk_out,
					data_out 		=> MFD_data_out,
					dest_addr_out 	=> dest_MAC_addr_out,
					CRC_Error_out 	=> MFD_CRC_Error_out);

	-- register to hold the last byte of LLC PDU Generator data
	process (mclk)
	begin
		if rising_edge(mclk) then
			if drst = '1' then
				Last_LLC_data_reg <= (others => '0');
			elsif LLC_PDU_rdy = '1' then
				Last_LLC_data_reg <= LLC_PDU_data;
			end if;	
		end if;	
	end process;
	
	-- register to hold the last byte of MAC Frame Decoder data
	process (mclk)
	begin
		if rising_edge(mclk) then
			if drst = '1' then
				Last_MFD_data_reg <= (others => '0');
			elsif MFD_dclk_out = '1' then
				Last_MFD_data_reg <= MFD_data_out;
			end if;	
		end if;	
	end process;
	
end Behavioral;