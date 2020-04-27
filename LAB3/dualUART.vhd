-------------------------------------------------------------------------
-- dualUART.vhd
-------------------------------------------------------------------------
-- Author:  Carl Betcher
-------------------------------------------------------------------------
-- Description:  	This design demonstrates the functionality of a pair 
--						of UARTs communicating with each other using the FPGA
--						board.
-------------------------------------------------------------------------
-- Revision History:
--  	01/03/11 (CB) Created
--    02/06/15 (CB) Revised to use general FPGA board
--    02/06/16 (CB) Revised to have UART_FSM use RDA input
--    01/28/17 (CB) Modified debounce to have generic WIDTH that 
--						  specifies the width of the output pulse.
--						  This was needed to make the dRST signal a pulse
--						  that is the same width as the rCLK in the UART_Rx
-------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-------------------------------------------------------------------------
-- dualUART Entity
--
--	The daulUART entity consists of two UARTs which 
-- communicate with each other through the FPGA board I/O.
--	UART_A sends 8 bits of data input from the switches 
--	(SW0-7) out on Port A.  UART_B receives the data
--	on Port B and retransmits the data it just received
--	back out on Port B.  UART_A receives the data from
--	UART_B and displays the data on the LEDs.
--
--	The system is reset by RST which is input
--	from pushbutton BNT0
--
--	A data transaction is initiated by XMT_A which is input
--	from pushbutton BNT1
--
--	Note: External connections between the FPGA board ports 
--	are required.
-------------------------------------------------------------------------
entity dualUART is
	Generic (debounceDELAY : integer := 640000); -- debounceDELAY = 20 mS / clk_period);
	Port ( 	CLK		: in std_logic;
				RST		: in std_logic	:= '0';
				RXD_A		: in std_logic	:= '1';
				RXD_B		: in std_logic	:= '1';
				XMT_A		: in std_logic	:= '0';
				SW			: in std_logic_vector(7 downto 0) := "00000000";
				TXD_A		: out std_logic;
				TXD_B		: out std_logic;
				TXD_A_NRZ		: out std_logic;
				RXD_A_NRZ		: out std_logic;
				LED		: out std_logic_vector(7 downto 0));
end dualUART;

architecture Behavioral of dualUART is

	-------------------------------------------------------------------------
	-- Component, Type, and Signal declarations								
	-------------------------------------------------------------------------

	-------------------------------------------------------------------------
	-- Component Declaration - UART
	--
	-- This component is the UART that is to be used in this dualUART
	--	The UART code can be found in the UART.vhd file.
	-------------------------------------------------------------------------
	component UART
		Port (  	TXD 		: out		std_logic;
					RXD 		: in		std_logic;					
					CLK 		: in		std_logic;							
					DBIN 		: in		std_logic_vector (7 downto 0);
					DBOUT 	: out		std_logic_vector (7 downto 0);
					RDA		: inout	std_logic;							
					TBE		: out		std_logic;				
					RD			: in		std_logic;							
					WR			: in		std_logic;							
					PE			: out		std_logic;							
					FE			: out		std_logic;							
					OE			: out		std_logic;											
					RST		: in		std_logic);				
	end component;	

	-------------------------------------------------------------------------
	-- Component Declaration - UART_FSM
	--
	-- This component is the UART finite state machine used to 
	--	control the UART operation
	-------------------------------------------------------------------------
	COMPONENT UART_FSM
	PORT(
		CLK : IN std_logic;
		RST : IN std_logic;
		XMT : IN std_logic;
		RDA : in  STD_LOGIC;
		RD : OUT std_logic;
		WR : OUT std_logic
		);
	END COMPONENT;

	-------------------------------------------------------------------------
	-- Component Declaration - debounce
	--
	--	This component is the 'debounce' module used to generate
	--	a one clock cycle pulse from a momentary switch input.  
	--	The VHDL code can be found in the real_debounce.vhd file.
	-------------------------------------------------------------------------
	component debounce
	    Generic ( DELAY : integer := 640000; -- DELAY = 20 mS / clk_period
				     WIDTH : integer := 1);     
		 Port ( 	sig_in 	: in  	std_logic;
					clk 		: in  	std_logic;
					sig_out 	: out  	std_logic);
	end component;
	
	
-- VHDL Instantiation Created from source file ManchEncDec.vhd -- 22:14:43 02/11/2020
--
-- Notes: 
-- 1) This instantiation template has been automatically generated using types
-- std_logic and std_logic_vector for the ports of the instantiated module
-- 2) To use this template to instantiate this entity, cut-and-paste and then edit

	COMPONENT ManchEncDec
	PORT(
		rst : IN std_logic;
		clk : IN std_logic;
		nrz_in : IN std_logic;
		manin : IN std_logic;          
		manout : OUT std_logic;
		nrz_out : OUT std_logic
		);
	END COMPONENT;

	-------------------------------------------------------------------------
	-- Local Signal Declarations
	-------------------------------------------------------------------------
		signal dbInSig_A	:	std_logic_vector(7 downto 0); --Parallel data input for the UART_A
		signal dbInSig_B	:	std_logic_vector(7 downto 0); --Parallel data input for the UART_B
		signal dbOutSig_A	:	std_logic_vector(7 downto 0); --Parallel data output for the UART_A
		signal dbOutSig_B	:	std_logic_vector(7 downto 0); --Parallel data output for the UART_B
		signal rdaSig_A	:	std_logic; --Read Data Available signal from UART_A
		signal rdaSig_B	:	std_logic; --Read Data Available signal from UART_B
		signal rdSig_A		:	std_logic; --Read signal for UART_A
		signal wrSig_A		:	std_logic; --Write signal for UART_A
		signal rdSig_B		:	std_logic; --Read signal for UART_B
		signal wrSig_B		:	std_logic; --Write signal for UART_B
		signal dRST       :  std_logic; --'debounced' reset signal from pushbutton 0
		signal dXMT_A		:	std_logic; --'debounced' transmit cmd from pushbutton 1
		signal dXMT_B		:	std_logic; --'debounced' transmit cmd for UART_B
		signal txda_sig, txdb_sig, rxda_sig, rxdb_sig : std_logic;
begin
	------------------------------------------------------------------------
	-- dualUART Implementation
	------------------------------------------------------------------------

	-------------------------------------------------------------------------
	-- Instantiate two UARTs
	-- and map the ports with the appropriate signals
	-------------------------------------------------------------------------
	--##### MAP PORTS TO SIGNALS BELOW #####
	UART_A: UART port map (	TXD 	=> txda_sig,
									RXD 	=> rxda_sig  ,
									CLK 	=> CLK  ,
									DBIN 	=> dbInSig_A  ,
									DBOUT	=> dbOutSig_A   ,
									RDA	=> rdaSig_A   ,
									TBE	=> open,	
									RD		=> rdSig_A    ,
									WR		=> wrSig_A    ,
									PE		=> open,
									FE		=> open,
									OE		=> open,
									RST 	=> dRST    );
	
	--##### MAP PORTS TO SIGNALS BELOW #####
	UART_B: UART port map (	TXD 	=> txdb_sig    ,
									RXD 	=> rxdb_sig   ,
									CLK 	=> CLK    ,
									DBIN 	=> dbInSig_B   ,
									DBOUT	=> dbOutSig_B    ,
									RDA	=> rdaSig_B    ,
									TBE	=> open,	
									RD		=> rdSig_B    ,
									WR		=> wrSig_B   ,
									PE		=> open,
									FE		=> open,
									OE		=> open,
									RST 	=> dRST    );
												
												
	MED_A: ManchEncDec PORT MAP(
		rst => rst,
		clk => clk ,
		nrz_in => txda_sig,
		manout => TXD_A ,
		manin => RXD_A ,
		nrz_out => rxda_sig
	);
	
	MED_B: ManchEncDec PORT MAP(
		rst => rst ,
		clk => clk ,
		nrz_in => txdb_sig ,
		manout => TXD_B ,
		manin => RXD_B,
		nrz_out => rxdb_sig 
	);
	
	TXD_A_NRZ <= txda_sig;
	RXD_A_NRZ <= rxda_sig;
	
	

	-------------------------------------------------------------------------
	-- Instantiate two copies of UART_FSM and map the ports to the signals
	-- which connect the FSMs with their respective UARTs.
	-------------------------------------------------------------------------
	--##### MAP PORTS TO SIGNALS BELOW #####
	UART_A_FSM: UART_FSM PORT MAP(
		CLK => CLK    ,
		RST => dRST    ,
		XMT => dXMT_A    ,
		RDA => rdaSig_A    ,
		RD  => rdSig_A    ,
		WR  => wrSig_A
	);

	--##### MAP PORTS TO SIGNALS BELOW #####
	UART_B_FSM: UART_FSM PORT MAP(
		CLK => CLK    ,
		RST => dRST    ,
		XMT => dXMT_B    , 
		RDA => rdaSig_B    ,
		RD  => rdSig_B    ,
		WR  => wrSig_B
	);
	
	

	-------------------------------------------------------------------------
	-- Instantiate two debounce components and map their ports to the 
	-- signals needed to provide for debouncing of the two momentary switch
	-- input signals.  
	-------------------------------------------------------------------------
	RST_debounce: debounce 
		generic map ( DELAY => debounceDELAY, WIDTH => 208 )
		port map (	sig_in => 	RST,
						clk    => 	CLK,
						sig_out => 	dRST);

	XMT_A_debounce: debounce 
		generic map ( DELAY => debounceDELAY )
		port map (	sig_in => 	XMT_A,
						clk    => 	CLK,
						sig_out => 	dXMT_A);

	-------------------------------------------------------------------------
	-- Instantiate a third debounce component  
	-- This one is used to create the UART_B WR input from the rising edge
	-- of the RDA output of UART_B. Note, DELAY is set to 1. 
	-------------------------------------------------------------------------
	XMT_B_debounce: debounce 
		generic map ( DELAY => 1 )
		port map (	sig_in => 	rdaSig_B,
						clk    => 	CLK,
						sig_out => 	dXMT_B);

	------------------------------------------------------------------------
	-- Use switches to supply data to the parallel input of UART_A
	------------------------------------------------------------------------
	--##### ENTER YOUR CODE HERE #####
		dbInSig_A <= SW;
	

	------------------------------------------------------------------------
	-- Connect data output of UART_B to data input of UART_B.
	-- UART_B echos the data it receives on its RXD input back out on its
	-- TXD output.
	------------------------------------------------------------------------
	--##### ENTER YOUR CODE HERE #####
		dbInSig_B <= dbOutSig_B;

	------------------------------------------------------------------------
	-- Display data received by UART_A on the LEDs
	------------------------------------------------------------------------
	--##### ENTER YOUR CODE HERE #####
		LED <= dbOutSig_A;
	
	

end Behavioral;