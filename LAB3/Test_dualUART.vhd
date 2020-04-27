--------------------------------------------------------------------------------
-- Company: Binghamton University
-- Engineer: Vivek Pattanaik
--
-- Create Date:   03:10:46 02/04/2020
-- Design Name:   
-- Module Name:   /home/ise/ise_projects/lab2/Test_dualUART.vhd
-- Project Name:  lab2
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: dualUART
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
 
ENTITY Test_dualUART IS
END Test_dualUART;
 
ARCHITECTURE behavior OF Test_dualUART IS 
 
    -- Component Declaration for the Unit Under Test (UUT)

    COMPONENT dualUART
	 generic (debouncedelay : integer := 640000);
    PORT(
         CLK : IN  std_logic;
         RST : IN  std_logic;
         RXD_A : IN  std_logic;
         RXD_B : IN  std_logic;
         XMT_A : IN  std_logic;
         SW : IN  std_logic_vector(7 downto 0);
         TXD_A : OUT  std_logic;
         TXD_B : OUT  std_logic;
         LED : OUT  std_logic_vector(7 downto 0);
			TXD_A_NRZ : OUT std_logic;
			RXD_A_NRZ : OUT std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';
   signal RST : std_logic := '0';
   signal RXD_A : std_logic := '0';
   signal RXD_B : std_logic := '0';
   signal XMT_A : std_logic := '0';
   signal SW : std_logic_vector(7 downto 0) := (others => '0');

 	--Outputs
   signal TXD_A : std_logic;
   signal TXD_B : std_logic;
   signal LED : std_logic_vector(7 downto 0);
	signal TXD_A_NRZ : std_logic;
	signal RXD_A_NRZ : std_logic;

   -- Clock period definitions
   constant CLK_period : time := 31.25 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
	

   uut: dualUART 
   generic map (debouncedelay => 3)
	PORT MAP (
          CLK => CLK,
          RST => RST,
          RXD_A => RXD_A,
          RXD_B => RXD_B,
          XMT_A => XMT_A,
          SW => SW,
          TXD_A => TXD_A,
          TXD_B => TXD_B,
          LED => LED,
			 TXD_A_NRZ => TXD_A_NRZ,
			 RXD_A_NRZ => RXD_A_NRZ
        );
	
	-- connect the UARTs
		RXD_B <= TXD_A;
		RXD_A <= TXD_B;
		

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
 
      wait for CLK_period*10;
			
			SW <= "01010110";
			
			XMT_A <= '0';
			wait for 20 us;

      -- insert stimulus here 
			RST <= '1';
			wait for 20 us;
			
			RST <= '0';
			wait for 20 us;
			
			XMT_A <= '1';
			wait for 20 us;
			
			XMT_A <= '0';

      wait;
   end process;

END;
