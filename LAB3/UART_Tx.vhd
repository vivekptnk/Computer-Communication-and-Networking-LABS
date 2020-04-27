------------------------------------------------------------------------
--  UART_Tx.vhd
------------------------------------------------------------------------
-- Description:  	Transmit function of the UART			
------------------------------------------------------------------------
-- Revision History:
--  01/30/15 Carl Betcher: 	Created
------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_Tx is
    Port ( 
    	CLK 	: in  std_logic;							--Master Clock
    	tClk 	: in  std_logic;							--Transmit Clock
		DBIN 	: in  std_logic_vector (7 downto 0);--Data Bus in
		WR		: in  std_logic;							--Write Strobe
		RST	: in  std_logic;							--Master Reset
		TBE 	: out std_logic;							--Transfer Buffer Empty
		TXD 	: out std_logic);							--Transmit data
end UART_Tx;

architecture Behavioral of UART_Tx is
------------------------------------------------------------------------
-- Constraint Declarations
------------------------------------------------------------------------
	--declare attribute to assign clock buffers
	attribute buffer_type : string;

------------------------------------------------------------------------
-- Component Declarations
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Type Declarations for State Machines
------------------------------------------------------------------------

	--Transmitter states
	type txState_type is (
		txIdle,			--Idle state
		txTransfer,		--Load data into tx data shift register
		txShift			--Shift out tx data
		);

	--Transfer bus empty (TBE) states
	type tbeState_type is (
		tbeIdle,			--Idle state (TBE = '1')
		tbeResetTBE,	--Reset the TBE
		tbeWaitLoad,
		tbeWaitWrite
		);
		
------------------------------------------------------------------------
-- Constant and Signal Declarations
------------------------------------------------------------------------
	signal tdSReg  :  std_logic_vector(10 downto 0) := "11111111111";		
							--Transmit data shift register
	signal tCtr		:  std_logic_vector(3 downto 0)	:= "0000";				
							--counts transmitted bits
	signal load		:  std_logic := '0';	--loads the tdSReg with data
	signal shift	:  std_logic := '0';	--enables shifting of the tdSReg
	signal par		:  std_logic;			--parity value to be transmitted
   signal tClkRST	:  std_logic := '0';	--resets tCtr
	signal TBEint	:  std_logic;	--Internal Transfer Buffer Empty signal

	signal txState  :  txState_type 	:= txIdle;	
										 --Current state of Transfer state machine
	signal txNext   :  txState_type; 
										 --Next state of Transfer state machine
	signal tbeState :  tbeState_type := tbeIdle;
										 --Current state of TBE state machine
	signal tbeNext  :  tbeState_type;
										 --Next state of TBE state machine
	
------------------------------------------------------------------------
-- Module Implementation
------------------------------------------------------------------------
begin

	-- Data Path --
	--This process is a counter clocked with tClk that counts the number
	--of bits that have been transmitted
	process (tClk)	 										
		begin
			if rising_edge(tClk) then
				if tClkRST = '1' then
					tCtr <= "0000";
				else
					tCtr <= std_logic_vector(unsigned(tCtr) + 1);
				end if;
			end if;
		end process;

	--Compute the parity bit to be transmitted--
	par <=  not ( ((DBIN(0) xor DBIN(1)) xor (DBIN(2) xor DBIN(3))) 
			  xor ((DBIN(4) xor DBIN(5)) xor (DBIN(6) xor DBIN(7))) );

	--This process loads and shifts data out of the transmit shift register
	process (tClk)
		begin
			if rising_edge(tClk) then
				if RST = '1' then
					tdSReg <= "00000000001";
				elsif load = '1' then
					tdSReg (10 downto 0) <= ('1' & par & DBIN(7 downto 0) &'0');
				elsif shift = '1' then				  
					tdSReg (10 downto 0) <= ('1' & tdSReg(10 downto 1));
				end if;
			end if;
		end process;

	TXD <= tdSReg(0);   --Output tdSReg(0) to TXD
			
	-- Transmit Finite State Machine --
	--State Register
	process (tClk)
		begin
			if rising_edge(tClk) then
				if RST = '1' then
					txState <= txIdle;
				else	
					txState <= txNext;
				end if;	
			end if;
		end process;
		
	--This process is the logic that determines the next state
	--and the FSM outputs
	process (txState, tCtr, DBIN, TBEint, tclk)
		begin  
			--default outputs
			shift <= '0';
			load <= '0';
			tClkRST <= '0';
			case txState is			
				when txIdle =>
					
					if TBEint = '1' then --wait for TBE to go low
						txNext <= txIdle;
					else
						txNext <= txTransfer; 
					end if;	
					
				when txTransfer =>		--load the shift register (tdSReg)
					load <= '1';
					tClkRST <= '1';		
					txNext <= txShift;	
					
				when txShift =>			--shift data out on TXD
					shift <= '1';
					
					if tCtr = "1100" then	--done when tCtr = 12
						txNext <= txIdle;
					else
						txNext <= txShift;
					end if;
			end case;
		end process;						 	

	--TBE (Transfer Buffer Empty) State Machine--
	process (CLK)
		begin
			if rising_edge(CLK) then
				if RST = '1' then
					tbeState <= tbeIdle;
				else	
					tbeState <= tbeNext;
				end if;	
			end if;
		end process;

	--This process gererates the sequence of events needed to control the TBE flag--
	--The transfer buffer is the Tx shift register.  TBE goes to '0' when new data
	--is available on the DBIN bus and WR goes high.  When the data has been shifted
	--out of the transfer buffer, the TBE flag goes to '1' again.
	process (tbeState, CLK, WR, DBIN, load)
		begin

			case tbeState is

				when tbeIdle =>					--Waiting for new data on DBIN
					TBEint <= '1';					--Transfer Buffer is empty
					if WR = '1' then				--Wait for WR to go active
						tbeNext <= tbeResetTBE;
					else
						tbeNext <= tbeIdle;
					end if;
				
				when tbeResetTBE =>					
					TBEint <= '0';					--Transfer Buffer is not empty
					if load = '1' then			--Wait for load to go active
						tbeNext <= tbeWaitLoad;
					else
						tbeNext <= tbeResetTBE;
					end if;
				
				when tbeWaitLoad =>					
					TBEint <= '0';					--Transfer Buffer is not empty
					if load = '0' then			--Wait for load to go inactive
						tbeNext <= tbeWaitWrite;
					else
						tbeNext <= tbeWaitLoad;
					end if;

				when tbeWaitWrite =>				
					TBEint <= '0';					--Transfer Buffer is not empty
					if WR = '0' then 				--Wait for WR to go inactive
						tbeNext <= tbeIdle;
					else
						tbeNext <= tbeWaitWrite;
					end if;
				end case;
			end process;

	--Output the transfer buffer empty flag
	TBE <= TBEint;	
			
end Behavioral;