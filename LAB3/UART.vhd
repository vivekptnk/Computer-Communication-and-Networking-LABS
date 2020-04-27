------------------------------------------------------------------------
--  UART.vhd
------------------------------------------------------------------------
-- Author:  Dan Pederson
--          Copyright 2004 Digilent, Inc.
------------------------------------------------------------------------
-- Description:  	This file defines a UART which tranfers data from 
--				      serial form to parallel form and vice versa.			
------------------------------------------------------------------------
-- Revision History:
--  07/15/04 (Created) DanP
--	 02/25/08 (Created) ClaudiaG: made use of the baudDivide constant
--											in the Clock Dividing Processes
--  11/28/11 Carl Betcher: 	Eliminated synthesis warnings; fixed problem
--					   				recovering from frame error; added internal
--					   				signals for outputs that need to be fed back
--					   				into the device logic eliminating the need to
--					   				use "inout" signal type
--  01/29/15 Carl Betcher:    Updated code to use IEEE.NUMERIC_STD package
--                            instead of IEEE.STD_LOGIC_UNSIGNED
--  01/30/15 Carl Betcher:		Created Rx and Tx components to make UART
--                            functionality easier to analyze
------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART is
    Port ( 
		TXD 	: out std_logic;								--Transmit data
    	RXD 	: in  std_logic;								--Receive data
    	CLK 	: in  std_logic;								--Master Clock
		DBIN 	: in  std_logic_vector (7 downto 0);	--Data Bus in
		DBOUT : out std_logic_vector (7 downto 0);	--Data Bus out
		RDA	: out std_logic;								--Read Data Available
		TBE	: out std_logic;								--Transfer Buffer Empty
		RD		: in  std_logic;								--Read Strobe
		WR		: in  std_logic;								--Write Strobe
		PE		: out std_logic;								--Parity Error Flag
		FE		: out std_logic;								--Frame Error Flag
		OE		: out std_logic;								--Overwrite Error Flag
		RST	: in  std_logic);								--Master Reset
end UART;

architecture Behavioral of UART is
------------------------------------------------------------------------
-- Constraint Declarations
------------------------------------------------------------------------
	--declare attribute to assign clock buffers
	attribute buffer_type : string;

------------------------------------------------------------------------
-- Component Declarations
------------------------------------------------------------------------
	COMPONENT UART_Tx
	PORT(
		CLK : IN std_logic;
		tClk : IN std_logic;
		DBIN : IN std_logic_vector(7 downto 0);
		WR : IN std_logic;
		RST : IN std_logic;          
		TBE : OUT std_logic;
		TXD : OUT std_logic
		);
	END COMPONENT;

	COMPONENT UART_Rx
	PORT(
		rClk : IN std_logic;
		RXD : IN std_logic;
		RD : IN std_logic;
		RST : IN std_logic;          
		RDA : OUT std_logic;
		PE : OUT std_logic;
		FE : OUT std_logic;
		OE : OUT std_logic;
		DBOUT : OUT std_logic_vector(7 downto 0)
		);
	END COMPONENT;

------------------------------------------------------------------------
-- Constant and Signal Declarations
------------------------------------------------------------------------
	-- Baud rate divisor constant is function of BAUD rate and CLK frequency
	-- baudDivide = (CLK Freq/(BAUDx32)) - 1 
--	constant baudDivide : std_logic_vector(8 downto 0) := "000000000"; 	
	constant baudDivide : std_logic_vector(8 downto 0) := "001100111"; 	
					-- Papilio One --															
					--For a baud rate of 9600, and a CLK frequency = 32 MHz,
					--baudDivide = (32MHz/(9600x32)) - 1 = 103
					
--	constant baudDivide : std_logic_vector(7 downto 0) := "010100010"; 	
					-- Basys2 --																
					--For a baud rate of 9600, and a CLK frequency = 50 MHz, 
					--baudDivide = (50MHz/(9600x32)) - 1 = 162
																								
	signal clkDiv	:  std_logic_vector(8 downto 0)	:= "000000000";--used for rClk
	signal rClkDiv :  std_logic_vector(3 downto 0)	:= "0000";	--used for tClk
	signal rClk		:  std_logic := '0';						--Receiving Clock
	attribute buffer_type of rClk : signal is "bufg";  --use clock buffer on rClk		
	signal tClk		:  std_logic;								--Transmitting Clock
	attribute buffer_type of tClk : signal is "bufg";  --use clock buffer on tClk
	signal clkDiv_eq_baudDivide : std_logic;				--comparator output
		
------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin
	
	--Clock Dividing Functions--
	process (clkDiv)			--compare clkDiv with baudDivide constant
	begin
		if (unsigned(clkDiv) = unsigned(baudDivide)) then
			clkDiv_eq_baudDivide <= '1';
		else
			clkDiv_eq_baudDivide <= '0';
		end if;
	end process;
	
	process (CLK)	    		--set up clock divide for rClk
		begin
			if rising_edge(clk) then
				if clkDiv_eq_baudDivide = '1' then
					clkDiv <= "000000000";
				else
					clkDiv <= std_logic_vector(unsigned(clkDiv) + 1);
				end if;
			end if;
		end process;

	process (CLK)				--define rClk
		begin
			if rising_edge(clk) then
				if clkDiv_eq_baudDivide = '1' then
					rClk <= not rClk;
				end if;
			end if;
		end process;

	process (rClk)	  			--set up clock divide for tClk
		begin
			if rising_edge(rClk) then
				rClkDiv <= std_logic_vector(unsigned(rClkDiv) + 1);
			end if;
		end process;

	tClk <= rClkDiv(3);		--define tClk

	-- Instantiated UART Transmitter Component
	Inst_UART_Tx: UART_Tx PORT MAP(
		CLK => CLK,
		tClk => tClk,
		DBIN => DBIN,
		WR => WR,
		RST => RST,
		TBE => TBE,
		TXD => TXD
	);

	-- Instantiated UART Receiver Component
	Inst_UART_Rx: UART_Rx PORT MAP(
		rClk => rClk,
		RXD => RXD,
		RD => RD,
		RST => RST,
		RDA => RDA,
		PE => PE,
		FE => FE,
		OE => OE,
		DBOUT => DBOUT
	);
			
end Behavioral;













