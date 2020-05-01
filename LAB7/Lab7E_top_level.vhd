----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:		 Carl Betcher
-- 
-- Create Date:    21:10:34 04/16/2011 
-- Design Name: 	 Ethernet MAC Protocol
-- Module Name:    Lab7E_top_level - Behavioral 
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
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Lab7E_top_level is
	 Generic (debounceDELAY : integer := 640000); 
														-- debounceDELAY = 20 mS / clk_period);
    Port ( 	D1_manout : OUT  std_logic;
				D3_MAC_frame : out STD_LOGIC;
				D5_MAC_data : out STD_LOGIC;
				D11_manin : IN  std_logic;
				DIR_UP : in  STD_LOGIC := '0';
				DIR_DOWN : in  STD_LOGIC := '0';
				SW : in  STD_LOGIC_VECTOR (7 downto 0) := "00000000";
				LED : out  STD_LOGIC_VECTOR (7 downto 0);
				Seg7_SEG : out  STD_LOGIC_VECTOR (6 downto 0);
				Seg7_AN: out  STD_LOGIC_VECTOR (4 downto 0);
				Seg7_DP : out  STD_LOGIC;
				mclk : IN  STD_LOGIC);
end Lab7E_top_level;

architecture Behavioral of Lab7E_top_level is

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
		Port (rst, clk, dclk_in, frame_in, nrz_in 	: in std_logic;
				manout 	: out std_logic);
	end component;

	component manchdecoder is
		Port (rst, clk, manin 	: in std_logic;
				dclk_out, frame_out, nrz_out 	: out std_logic );
	end component;

	component HEXon7segDisp 
		 Port ( hex_data_in0 : in  STD_LOGIC_VECTOR (3 downto 0);
				  hex_data_in1 : in  STD_LOGIC_VECTOR (3 downto 0);
				  hex_data_in2 : in  STD_LOGIC_VECTOR (3 downto 0);
				  hex_data_in3 : in  STD_LOGIC_VECTOR (3 downto 0);
				  dp_in : in  STD_LOGIC_VECTOR (2 downto 0);
				  seg_out : out  STD_LOGIC_VECTOR (6 downto 0);
				  an_out : out  STD_LOGIC_VECTOR (3 downto 0);
				  dp_out : out  STD_LOGIC;
				  clk : in  STD_LOGIC);
	end component;

	constant LLC_PDU_LENGTH_SIZE : integer := 8;
	constant LLC_PDU_DATA_SIZE : integer := 8;

	signal btn : STD_LOGIC_VECTOR (1 downto 0) := (others => '0');
	signal drst : std_logic;
	signal gen_PDU : std_logic;
	signal LLC_PDU_rdy : std_logic;
	signal LLC_PDU_ack : std_logic;
	signal LLC_PDU_length : std_logic_vector(LLC_PDU_LENGTH_SIZE-1 downto 0);
	signal LLC_PDU_data : std_logic_vector(LLC_PDU_DATA_SIZE-1 downto 0);
	signal MAC_dest_addr : std_logic_vector(7 downto 0);
	signal rx_MAC_addr : std_logic_vector(7 downto 0);

	signal tx_dclk : std_logic;
	signal tx_data : std_logic;
	signal tx_frame : std_logic;

	signal rx_dclk : std_logic;
	signal rx_data : std_logic;
	signal rx_frame : std_logic;

	signal MFD_dclk_out : std_logic;
	signal MFD_data_out : std_logic_vector(LLC_PDU_DATA_SIZE-1 downto 0);
	signal dest_MAC_addr_out : std_logic_vector(7 downto 0);
	signal MFD_CRC_Error_out : std_logic;

	signal Last_LLC_data_reg : std_logic_vector(LLC_PDU_DATA_SIZE-1 downto 0);
	signal Last_MFD_data_reg : std_logic_vector(LLC_PDU_DATA_SIZE-1 downto 0);

	signal Mod_Cntr : unsigned(24 downto 0);
	signal Mod_Error : std_logic;

begin
	-- Map Push Buttons: | DIR_DOWN |  DIR_UP  |
	--         Button #: |  btn(0)  |  btn(1)  | 
	--         Function: |  Reset   | Gen_PDU  |  
	btn <= DIR_UP & DIR_DOWN;

	-- some I/O connections
	-- SW 4-7 is destination address in data frame
	MAC_dest_addr <= "0000" & SW(7 downto 4); 
	-- SW 0-3 is MAC address of receiver (MAC Frame Decoder)
	rx_MAC_addr   <= "0000" & SW(3 downto 0); 
	-- display intended destination address on LEDs 4-7
	LED(7 downto 4) <= SW(7 downto 4); 
	-- display destination address received on LEDs 0-3
	LED(3 downto 0) <= dest_MAC_addr_out(3 downto 0); 
	-- output the MAC frame generated to Pmod ja3
	D3_MAC_frame <= tx_frame;
	-- output the MAC data generated to Pmod ja4	
	D5_MAC_data <= tx_data; 
	
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
													manout	=> D1_manout);

	-- Manchester Decoder
	DecoderB : manchdecoder port map (	rst		 => drst,
													clk		 => mclk,
													manin		 => D11_manin,
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
			else
				Last_LLC_data_reg <= Last_LLC_data_reg;
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
			else
				Last_MFD_data_reg <= Last_MFD_data_reg;
			end if;	
		end if;	
	end process;
	
	-- Counter to provide modulation of dp signal into the HexDisp
	process (mclk)
	begin
		if rising_edge(mclk) then
			if drst = '1' then
				Mod_Cntr <= (others => '0');
			else
				Mod_Cntr <= Mod_Cntr + 1;
			end if;	
		end if;	
	end process;
	
	-- Modulate CRC error signal
	Mod_Error <= MFD_CRC_Error_out AND Mod_Cntr(24);
	
	-- Seven segment display driver
	HexDisp : HEXon7segDisp 
	port map (  hex_data_in0 => Last_LLC_data_reg(7 downto 4),
					hex_data_in1 => Last_LLC_data_reg(3 downto 0),
					hex_data_in2 => Last_MFD_data_reg(7 downto 4),
					hex_data_in3 => Last_MFD_data_reg(3 downto 0),
					dp_in(0) => Mod_Error,
					dp_in(1) => Mod_Error,
					dp_in(2) => '0',
					seg_out => Seg7_SEG,
					an_out => Seg7_AN(3 downto 0),
					dp_out => Seg7_DP,
					clk => mclk
					);
	Seg7_AN(4) <= '1'; -- keep anode 4 off
	
end Behavioral;