--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   14:48:53 03/10/2020
-- Design Name:   
-- Module Name:   /home/ise/ise_projects/Lab5/TestRandBitGen.vhd
-- Project Name:  Lab5
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: RandBitGen
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
use IEEE.NUMERIC_STD.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY TestRandBitGen IS
END TestRandBitGen;
 
ARCHITECTURE behavior OF TestRandBitGen IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
	 constant TEST_NUMBER : integer := 3;
	 constant LARGEST_SIZE : integer := 8;
	 
	 type param_set is record 
		RBGsize : integer;
		RBG_P : std_logic_vector(LARGEST_SIZE downto 1);
		RBGseed : std_logic_vector(LARGEST_SIZE downto 1);
		FRAME_LENGTH : integer;
		NUM_FRAMES : integer;
	end record;
	
	type param_array_type is array (positive range <>) of param_set;
	
	constant PARAM_ARRAY : param_array_type := 
		(
			(4, "00001100", "00001001", 15, 2),
			(5, "00010100", "00010001", 31, 2),
			(8, "10111000", "10000001", 8, 6)
			
		);
 
    COMPONENT RandBitGen
    PORT(
         P : IN  std_logic_vector(4 downto 1);
         seed : IN  std_logic_vector(4 downto 1);
         frame_in : IN  std_logic;
         dclk_in : IN  std_logic;
         data_out : OUT  std_logic;
         dclk_out : OUT  std_logic;
         frame_out : OUT  std_logic;
         clk : IN  std_logic;
         rst : IN  std_logic
        );
    END COMPONENT;
    
	signal size : integer := PARAM_ARRAY(TEST_NUMBER).RBGsize;
   --Inputs
   signal P : std_logic_vector(4 downto 1) := (others => '0');
   signal seed : std_logic_vector(4 downto 1) := (others => '0');
   signal frame_in : std_logic := '0';
   signal dclk_in : std_logic := '0';
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';

 	--Outputs
   signal data_out : std_logic;
   signal dclk_out : std_logic;
   signal frame_out : std_logic;

   -- Clock period definitions
   constant clk_period : time := 32.5 ns;
	constant dclk_period : time := 32*clk_period;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: RandBitGen PORT MAP (
          P => P,
          seed => seed,
          frame_in => frame_in,
          dclk_in => dclk_in,
          data_out => data_out,
          dclk_out => dclk_out,
          frame_out => frame_out,
          clk => clk,
          rst => rst
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
	
	dclk_process : process
	begin 
		dclk_in <= '0';
		wait for dclk_period/2;
		dclk_in <= '1';
		wait for dclk_period/2;
	end process;
 
	-- frame_out/dclk_out timing check
	frame_out_timing: process
		variable time1 : time;
		variable time2 : time;
		variable time3 : time;
	begin
		report "BEGIN TEST";
		for i in 1 to PARAM_ARRAY(TEST_NUMBER).NUM_FRAMES loop
			-- frame_out rise to dclk_out rise timing check
			wait until frame_out'event and frame_out = '1';
			time1 := now;
			wait until dclk_out'event and dclk_out = '1';
			time2 := now;
			time3 := time2 - time1;
			assert time3 = 500000 ps
				report "Delay from rise of frame_out to rise of dclk_out is " & time'image(time3) & ". Should be 500000 ps" severity error;
				
			-- frame_out fall to dclk_out rise timing check
			wait until frame_out'event and frame_out = '0'; 
			time1 := now;
			wait until dclk_out'event and dclk_out = '1';
			time2 := now;
			time3 := time2 - time1;
			assert time3 = 500000 ps
				report "Delay from fall of frame_out to rise of dclk_out is " & time'image(time3) & ". Should be 500000 ps" severity error;
		end loop;
		report "TEST IS FINISHED";
		wait;
		end process;
		
		-- data_out/dclk_out timing check
		data_out_timing: process
			variable time1 : time;
			variable time2 : time;
			variable time3 : time;
		begin
			wait until rst'event and rst = '0';
			loop
			-- data_out rise or fall to dclk_out rise timing check
			wait until data_out'event; time1 := now;
			wait until dclk_out'event and dclk_out = '1'; time2 := now;
			time3 := time2 - time1;
			assert time3 = 500000 ps
				report "Delay from data_out transition to rise of dclk_out is " & time'image(time3) & ". Should be 500000 ps" severity  error;
			end loop;
		end process;
				
   -- Stimulus process
	
	stim_proc: process
	begin
		P <= std_logic_vector(resize(unsigned(PARAM_ARRAY(TEST_NUMBER).RBG_P),PARAM_ARRAY(TEST_NUMBER).RBGsize));
		seed <= std_logic_vector(resize(unsigned(PARAM_ARRAY(TEST_NUMBER).RBGseed),PARAM_ARRAY(TEST_NUMBER).RBGsize));
	
      -- hold reset state for 100 ns.
		rst <= '1';
      wait for 50 ns;	
		rst <= '0';

      wait for clk_period*5;
		
      -- insert stimulus here 
		for I in PARAM_ARRAY(TEST_NUMBER).NUM_FRAMES downto 1 loop 
			wait until falling_edge(dclk_in);
			frame_in <= '1';
			wait for dclk_period * PARAM_ARRAY(TEST_NUMBER).FRAME_LENGTH;
			frame_in <= '0';
			wait for dclk_period * 5;
		end loop;
      wait;
   end process;

END;
