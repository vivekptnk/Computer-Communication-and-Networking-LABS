------------------------------------------------------------------------
--  UART_Rx.vhd
------------------------------------------------------------------------
-- Description:  	Receiver function of the UART			
------------------------------------------------------------------------
-- Revision History:
--  01/30/15 Carl Betcher: 	Created
--  02/08/16 Carl Betcher:    Changed the reset of the flag register 
--										with RD and RST from asynchronous to 
--										synchronous
--										Removed the MUX from the FSM by adding
--										a rxShift state
--										
--										
--										
------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_Rx is
    Port ( 
    	rClk 	: in  std_logic;		--Receive Clock
    	RXD 	: in  std_logic;		--Receive data
		RD		: in  std_logic;		--Read Strobe
		RST	: in  std_logic;		--Master Reset
		RDA	: out std_logic;		--Read Data Available
		PE		: out std_logic;		--Parity Error Flag
		FE		: out std_logic;		--Frame Error Flag
		OE		: out std_logic;		--Overwrite Error Flag
		DBOUT : out std_logic_vector (7 downto 0));	--Data Bus out
end UART_Rx;

architecture Behavioral of UART_Rx is

------------------------------------------------------------------------
-- Type Declarations for State Machines
------------------------------------------------------------------------
	--Receiver states
	type rxState_type is (					  
		rxIdle,			--Idle state
		rxEightDelay,	--Delays for 8 clock cycles
		rxGetData,		--Shifts in the 8 data bits, and checks parity
		rxShift,      --Shift rdSReg when in this state
		rxCheckStop	--Sets framing error flag if Stop bit is wrong
	);

------------------------------------------------------------------------
-- Constant and Signal Declarations
------------------------------------------------------------------------
	signal rdReg	:  std_logic_vector(7 downto 0)  := "00000000";
							--Receive data holding register
	signal rdSReg	:  std_logic_vector(9 downto 0)  := "1111111111";
							--Receive data shift register
	signal dataCtr :  std_logic_vector(3 downto 0)	:= "0000";				
							--Counts the number of read data bits
	signal ctr		:  std_logic_vector(3 downto 0)	:= "0000";				
							--counter used for delay times in receive
	signal parError:  std_logic;				--Parity error bit
	signal frameError: std_logic;				--Frame error bit
	signal ctrRST	:  std_logic := '0';		
							--resets ctr, counter used for delay times
	signal rShift	:  std_logic := '0';		
							--enables shifting of rdSReg and increments dataCtr
	signal dataRST :  std_logic := '0';		--resets dataCtr
	signal CE	:  std_logic;					
							--Clock enable (internal) for rdReg and 
							--flag registers
	signal FEint	:  std_logic;			--Internal Frame Error signal
	signal PEint	:  std_logic;			--Internal Parity Error signal
	signal OEint	:  std_logic;			--Internal Overwrite Error signal
	signal RDAint	:  std_logic := '0';		
							--Internal Read Data Available signal

	signal rxState	:  rxState_type	:= rxIdle; 
							--Current state of Receive state machine
	signal rxNext	:  rxState_type;					
							--Next state of Receive state machine
	
------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

	-- Data Path --
	--This process is a counter clocked with rClk used to control the
	--timing for receiving serial data
	process (rClk)			   							
		begin
			if rising_edge(rClk) then
				if ctrRST = '1' then
					ctr <= (others => '0');
				else
					ctr <= std_logic_vector(unsigned(ctr) + 1);
				end if;
			end if;
		end process;

 	--This process is the received data output register
	process (rClk)
		begin
			if rising_edge(rClk) then
				if RST = '1' then
					rdReg <= (others => '0');
				elsif CE = '1' then
					rdReg(7 downto 0) <= rdSReg (7 downto 0);
				end if;				
			end if;
		end process;

	DBOUT <= rdReg;  --Output rdReg on DBOUT
		
	--This process is the receiver shift register
	process (rClk)
		begin
			if rising_edge(rClk) then
				if rShift = '1' then
					rdSReg <= (RXD & rdSReg(9 downto 1));
				end if;
			end if;
		end process;

	--Generate frame error if 10th bit received is not '1'
	frameError <= not rdSReg(9); 
	
	--Computation for parity error detection
	parError <= not ( rdSReg(8) xor (((rdSReg(0) xor rdSReg(1)) 
					xor (rdSReg(2) xor rdSReg(3))) xor ((rdSReg(4) 
					xor rdSReg(5)) xor (rdSReg(6) xor rdSReg(7)))) );

	--This process defines the counter (dataCtr)
	--to count the number of shifts of data
 	process (rClk)
		begin
			if rising_edge(rClk) then
				if dataRST = '1' then
					dataCtr <= "0000";
				elsif rShift = '1' then
					dataCtr <= std_logic_vector(unsigned(dataCtr) + 1);
				end if;
			end if;
		end process;

  	--Receiver Finite State Machine--
	--State register
	process (rClk)
		begin
			if rising_edge(rClk) then
				if RST = '1' then
					rxState <= rxIdle;
				else	
					rxState <= rxNext;
				end if;	
			end if;
		end process;
			
	--This process is the logic that determines the next state
	--and the FSM outputs
	process (rxState, ctr, RXD, FEint, dataCtr)
		begin   
			--default output values
			rShift <= '0';
			dataRST <= '0';
			CE <= '0';
			ctrRST <= '0';
			case rxState is
				when rxIdle =>
					if RXD = '0' and FEint = '0' then
						ctrRST <= '1';
						rxNext <= rxEightDelay;
					else
						ctrRST <= '0';
						rxNext <= rxIdle;
					end if;
				
				when rxEightDelay => 	--Delay 8 periods of rClk  
												--so that data is sampled 
												--in the center of each bit
					if ctr = "0111" then
						ctrRST <= '1';		--Reset "ctr" counter
					   dataRST <= '1';   --Reset "dataCtr" counter
						rxNext <= rxGetData;
					else
						ctrRST <= '0';
						dataRST <= '0';
						rxNext <= rxEightDelay;
					end if;
				
				when rxGetData =>	--Sample RXD every 16 rClk's
					if ctr = "1110" then
						rxNext <= rxShift;
					elsif dataCtr = "1010" then  --Done when dataCtr = 10
						rxNext <= rxCheckStop;
					else
						rxNext <= rxGetData;
					end if;
				
				when rxShift =>     
					ctrRST <= '1';		--Reset "ctr" counter
					rShift <= '1';		--Shift rdSReg
					rxNext <= rxGetData;
				
				when rxCheckStop =>
					CE <= '1';      	-- Load rdReg and flag registers
					rxNext <= rxIdle;									
			end case;		
		end process;

 	--This process controls the error flags--
	process (rClk, RST)
		begin
			if RST = '1' then  --flags are cleared asynchronously with RST
				FEint <= '0';
				OEint <= '0';
				RDAint <= '0';
				PEint <= '0';
			elsif rising_edge(rClk) then
				if RD = '1' then  --flags are cleared synchronously with RD
					FEint <= '0';
					OEint <= '0';
					RDAint <= '0';
					PEint <= '0';
				elsif CE = '1' then	--flags are updated when CE = '1'
					FEint <= frameError;	--frame error flag
					OEint <= RDAint;		--overwrite error flag
												--(rdReg overwritten before it is read)
					RDAint <= '1';	 		--set read data available flag
					PEint <= parError;	--parity error flag
				else							--else hold current value
					FEint <= FEint;
					OEint <= OEint;				
					RDAint <= RDAint;
					PEint <= PEint;				
				end if;				
			end if;
		end process;

	--Connect internal flag signals to the flag outputs--
	RDA <= RDAint; --read data available flag
	FE <= FEint;	--frame error flag
	OE <= OEint;   --overwrite error flag
	PE <= PEint;   --parity error flag
		
end Behavioral;