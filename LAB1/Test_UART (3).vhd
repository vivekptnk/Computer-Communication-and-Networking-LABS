--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   18:13:10 01/28/2020
-- Design Name:   
-- Module Name:   U:/EECE359 Labs/Lab1/Test_UART.vhd
-- Project Name:  Lab1
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: UART
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY Test_UART IS
END Test_UART;
 
ARCHITECTURE behavior OF Test_UART IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT UART
    PORT(
         TXD : OUT  std_logic;
         RXD : IN  std_logic;
         CLK : IN  std_logic;
         DBIN : IN  std_logic_vector(7 downto 0);
         DBOUT : OUT  std_logic_vector(7 downto 0);
         RDA : OUT  std_logic;
         TBE : OUT  std_logic;
         RD : IN  std_logic;
         WR : IN  std_logic;
         PE : OUT  std_logic;
         FE : OUT  std_logic;
         OE : OUT  std_logic;
         RST : IN  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal RXD : std_logic := '0';
   signal CLK : std_logic := '0';
   signal DBIN : std_logic_vector(7 downto 0) := (others => '0');
   signal RD : std_logic := '0';
   signal WR : std_logic := '0';
   signal RST : std_logic := '0';

 	--Outputs
   signal TXD : std_logic;
   signal DBOUT : std_logic_vector(7 downto 0);
   signal RDA : std_logic;
   signal TBE : std_logic;
   signal PE : std_logic;
   signal FE : std_logic;
   signal OE : std_logic;

	
   -- Clock period definitions
   constant CLK_period : time := 31.25 ns;
   
	constant T_ERROR : real := 1.08;
	constant rdata_period : time:= T_ERROR*104167 ns;
	shared variable DELAY : integer := 5;
	shared variable rx_frame : std_logic_vector(10 downto 0);
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: UART PORT MAP (
          TXD => TXD,
          RXD => RXD,
          CLK => CLK,
          DBIN => DBIN,
          DBOUT => DBOUT,
          RDA => RDA,
          TBE => TBE,
          RD => RD,
          WR => WR,
          PE => PE,
          FE => FE,
          OE => OE,
          RST => RST
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;
 

	RD_process :process
	begin
		wait until RDA = '1';
			report "RECEIVED DATA IS AVAILABLE ON DBOUT";
			if DBOUT = rx_frame(8 downto 1) then
				report "DBOUT MATCHES DATA SENT TO RXD";
			else
				report "DBOUT DOES NOT MATCH DATA SENT TO RXD" severity error;
			end if;
		wait for rdata_period*DELAY;
		if pe = '1' then report "PARITY ERROR FLAG IS SET"; end if;
		if fe = '1' then report "FRAME ERROR FLAG IS SET"; end if;
		if oe = '1' then report "OVERWRITE ERROR FLAG IS SET"; end if;
		RD <= '1';
		wait for 40 us;
		RD <= '0';
	end process;


   -- Stimulus process
   stim_proc: process
	procedure transmit_data(data: in  std_logic_vector (7 downto 0)) is
	begin
			while TBE = '0' loop
				wait for CLK_period;
			end loop;
			DBIN <= data; 
				wait for CLK_period;
				WR <= '1';
				wait for 40 us;
				WR <= '0';
				report "TEST BENCH WROTE DATA TO DBIN";
	end procedure;
	procedure receive_data(frame: in std_logic_vector(10 downto 0)) is
	begin
			for I in frame'low to frame'high loop
				RXD <= frame(I);
				if I = frame'high then
							report"TEST BENCH SENT FRAME TO UART RX";
				end if;
				wait for rdata_period;
			end loop;
			RXD <= '1';
	end procedure;
   begin		
		RXD <= '1';
		RST <= '1';
      -- hold reset state for 100 ns.
      wait for 15 us;
		RST <= '0';
      wait for CLK_period*10;
	transmit_data("10101010");
	transmit_data("01010101");
	transmit_data("01100111");
	wait for rdata_period*10;
	receive_data("11101010100");
	wait for rdata_period*10;
	receive_data("10101110100");
	wait for rdata_period*10;
	receive_data("01101010100");
	wait for rdata_period*10;
	receive_data("10111110100");
	wait for rdata_period*10;
	DELAY := 25;
	receive_data("10101111110");
	wait for rdata_period*10;
	receive_data("10100011110");
      wait;
   end process;

END;
