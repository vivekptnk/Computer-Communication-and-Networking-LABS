--------------------------------------------------------------------------------
-- Company: 		Binghamton University
-- Engineer:		Carl Betcher
--
-- Create Date:   21:31:25 04/16/2011
-- Design Name:   Lab 7A Testbench
-- Module Name:   Test_Lab7A.vhd
-- Project Name:  Lab7
-- Target Device:  
-- Tool versions:  
-- Description:   Test Bench for Part A of Lab 7
-- 
-- VHDL Test Bench Created by ISE for module: Lab7A_top_level
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- 					Run simulation for approx 30 us (Papilio) or 20 us (Basys2)
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.numeric_std.all;
 
ENTITY Test_Lab7A IS
END Test_Lab7A;
 
ARCHITECTURE behavior OF Test_Lab7A IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT Lab7A_top_level
	 GENERIC (debounceDELAY : integer := 640000); 
    PORT(
			LLC_PDU_data : OUT STD_LOGIC_VECTOR(7 downto 0);
			LLC_PDU_rdy : OUT STD_LOGIC;
			LLC_PDU_ack : IN STD_LOGIC;
			LLC_PDU_length : OUT STD_LOGIC_VECTOR(7 downto 0);
 			btn : IN STD_LOGIC_VECTOR(1 downto 0);
         mclk : IN  std_logic
        );
    END COMPONENT;
    
   --Inputs
   signal mclk : std_logic := '0';
   signal rst : std_logic := '0';
	signal data_ack : std_logic := '0';
	signal btn : std_logic_vector(1 downto 0) := "00";
   signal PDU_length : std_logic_vector(7 downto 0);

 	--Outputs
   signal data : std_logic_vector(7 downto 0);
   signal data_ready : std_logic;

   -- Clock period definitions
--	constant mclk_period : time := 20 ns;    -- Basys2
	constant mclk_period : time := 31.25 ns; -- Papilio
	
	constant txdata_period : time := mclk_period*32; 
									-- period of each data bit sent
									-- is the period of 32 system clocks

BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: Lab7A_top_level 
	GENERIC MAP ( debounceDELAY => 3 )  
	PORT MAP (
			LLC_PDU_data => data,
			LLC_PDU_rdy => data_ready,
			LLC_PDU_ack => data_ack,
			LLC_PDU_length => PDU_length,
         btn => btn,
         mclk => mclk
        );

   -- Clock process definitions
   mclk_process : process
   begin
		mclk <= '0';
		wait for mclk_period/2;
		mclk <= '1';
		wait for mclk_period/2;
   end process;

	-- Process that checks for valid PDU_length value after Gen_PDU rises
	assert_process: process
	begin
		wait until btn(1)'event and btn(1) = '1';
		wait for mclk_period*10;
		-- check for valid PDU length; report errors to console
		assert unsigned(PDU_length) /= 0 and unsigned(PDU_length) <= 32 
			report("PDU_length is outside range of 1 to 32") severity ERROR;
	end process;
 
  -- Stimulus process

   stim_proc: process
	
	-- procedure to generate data_ack handshake
	-- num_bytes parameter is PDU_length
	-- generates data_ack when data_ready = '1'
	procedure rx_LLC_data (num_bytes: in std_logic_vector(7 downto 0)) is
	variable byte_counter : integer;
	begin
		byte_counter := to_integer(unsigned(num_bytes));
		for i in 1 to 255 loop
			byte_counter := byte_counter - 1; -- count down from num_bytes
			wait until rising_edge(mclk);
			data_ack <= '1';
			wait until data_ready = '0';
			wait until rising_edge(mclk);
			data_ack <= '0';	
			exit when byte_counter = 0; -- exit when byte_counter reaches zero
			wait until data_ready = '1';
		end loop;
	end procedure;
	
   begin	
		-- initialization
		data_ack <= '0';
		btn(1) <= '0';
		-- generate reset
		btn(0) <= '0';
      wait for mclk_period*5;	
		btn(0) <= '1';
      wait for mclk_period*5;	
		btn(0) <= '0';

      wait for mclk_period*10;

      -- insert stimulus here 
		
		loop
			-- Generate LLC PDU (push button 1)
			btn(1) <= '1';
			wait for mclk_period*5;	
			btn(1) <= '0';
			-- Receive the LLC PDU data
			wait until data_ready = '1';
			wait for mclk_period*10;
			rx_LLC_data(PDU_length);
			-- wait for 10 clocks to separate frames in time
			wait for mclk_period*10;
		end loop;
		
      wait;
   end process;

END;
