--------------------------------------------------------------------------------
-- Company: 		Binghamton University
-- Engineer:		Carl Betcher
--
-- Create Date:   17:42:33 04/27/2011
-- Design Name:   Test Bench for Lab7 Part D
-- Module Name:   Test_Lab7D.vhd
-- Project Name:  Lab7
-- Description:   VHDL Test Bench Created by ISE for module: Lab7D_top_level
-- Revision:
-- Revision 0.01  File Created
-- Revision 0.02  April 5, 2018
--						Modified for Papilio Duo with LogicStart Shield
-- Notes:  			Run simulation for 1560 us (Papilio) or 1000 ns (Basys2)
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY Test_Lab7D IS
END Test_Lab7D;
 
ARCHITECTURE behavior OF Test_Lab7D IS 

    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT Lab7D_top_level
	 GENERIC (debounceDELAY : integer := 640000); 
    PORT(
          	manout : OUT  std_logic;
				manin : IN  std_logic;
				sw : IN STD_LOGIC_VECTOR(7 downto 0);	
				btn : IN STD_LOGIC_VECTOR(1 downto 0);
				led : out  STD_LOGIC_VECTOR (7 downto 0);
				Last_LLC_data_reg : OUT std_logic_vector(7 downto 0);
				Last_MFD_data_reg : OUT std_logic_vector(7 downto 0);
			   MFD_CRC_Error_out : out std_logic;
				mclk : IN  STD_LOGIC
        );
    END COMPONENT;
    
   --Inputs
   signal manin : std_logic := '0';
   signal sw : std_logic_vector(7 downto 0) := (others => '0');
	signal btn : STD_LOGIC_VECTOR(1 downto 0);
   signal mclk : std_logic := '0';

 	--Outputs
   signal manout : std_logic;
   signal led : std_logic_vector(7 downto 0) ;
   signal Last_LLC_data_reg : std_logic_vector(7 downto 0);
   signal Last_MFD_data_reg : std_logic_vector(7 downto 0);
   signal MFD_CRC_Error_out : std_logic := '0';

   -- Clock period definitions
	constant mclk_period : time := 31.25 ns; -- Papilio
	
BEGIN
	-- Instantiate the Unit Under Test (UUT)
   uut: Lab7D_top_level 
	GENERIC MAP ( debounceDELAY => 3 )  
	PORT MAP (	manout => manout,
					manin  => manin,
					led    => led,
					sw     => sw,
					btn    => btn,
					Last_LLC_data_reg => Last_LLC_data_reg,		      
					Last_MFD_data_reg => Last_MFD_data_reg,      
					MFD_CRC_Error_out => MFD_CRC_Error_out, 
					mclk   => mclk
				 );

   -- Clock process definitions
   mclk_process :process
   begin
		mclk <= '0';
		wait for mclk_period/2;
		mclk <= '1';
		wait for mclk_period/2;
   end process;
 
	-- External signal connections
--	manin <= transport manout after 100 us;
	manin <= manout;

   -- Stimulus process
   stim_proc: process
   begin
		-- sw inputs
		sw <= "00110011";
		
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
		
			-- wait for frame to complete (worst case);
			wait for mclk_period*50;				-- delay before generated frame begins
			wait for mclk_period*44*8*32;			-- generated frame duration:
															-- #bytes * #bits/byte * #clocks/bit
			wait for mclk_period*50;				-- delay after generated frame ends
			wait for mclk_period*44*8*32*0.1;	-- wait 10% of frame length before
															--  next frame starts

			wait for mclk_period*5;	
			
			sw(4) <= not sw(4); -- make destination address different than MAC address
									  -- every other frame
		end loop;

      wait;
   end process;
END;