----------------------------------------------------------------------------------
-- Company:			 Binghamton University 
-- Engineer: 
-- 
-- Create Date:    11:52:01 02/08/2013 
-- Module Name:    UART_FSM - Behavioral 
-- Project Name: 	 Lab2 (Dual UART)
-- Description: 	 Fininte State Machine for UART
--
-- Revision History: 
--    02/06/16 (CB) Add RDA input and use to generate RD to acknowledge the 
--						  received data.
--    01/28/17 (CB) Added another state and eliminated the Mealy output so
--						  that the FSM is purely Moore.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_FSM is
    Port ( CLK : in  STD_LOGIC;  -- clock input
           RST : in  STD_LOGIC;  -- reset input
           XMT : in  STD_LOGIC;  -- transmit command input
			  RDA : in  STD_LOGIC;  -- receive data available input
           RD : out  STD_LOGIC;	-- read (acknowledge) output
           WR : out  STD_LOGIC); -- write command output
end UART_FSM;

architecture Behavioral of UART_FSM is

	-- declare state register
	type UART_State is (stRx, stRxACK, stTx, stRxTx);
	signal stCur	:	UART_State := stRX;
	signal stNext	:	UART_State;

begin
	-- State Register Process
	--##### WRITE YOUR CODE HERE #####--
	process(RST,CLK) 
	begin
		if RST = '1' then 
			stCur <= stRx;
		elsif rising_edge(CLK) then 
			stCur <= stNext;
		end if;
	end process;
		
	--	Process to generate Next State and Outputs 
	--##### WRITE YOUR CODE HERE #####--
	process(stCur, XMT, RDA)
	begin 
		RD <= '0';
		WR <= '0';
		case stCur is
			when stRx =>
				if RDA = '1' and XMT = '1' then
					stNext <= stRxTx;
				elsif XMT = '1' then 
					stNext <= stTx;
				elsif RDA = '1' then 
					stNext <= stRxACK;	
				else 
					stNext <= stRx;
				end if;
				
			when stRxACK =>
				WR <= XMT;
				RD <= '1';
				if RDA = '0' and XMT = '1' then
					stNext <= stTx;
				elsif RDA = '1' and XMT = '1' then 
					stNext <= stRxACK;
				else
					stNext <= stRx;
				end if;
				
			when stTx =>
				WR <= '1';
				if RDA = '1' then 
					stNext <= stRxACK;
				else 
					stNext <= stRx;
				end if;
			
			when stRxTx =>
				RD <= '1';
				WR <= '1';
				if RDA = '1' then 
					stNext <= stRxACK;
				elsif XMT = '1' then
					stNext <= stTx;
				else
					stNext <= stRx;
				end if;
				
		end case;
	end process;
end Behavioral;

