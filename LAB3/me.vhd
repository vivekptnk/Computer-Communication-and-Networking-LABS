--------------------------------------------------------------------------------
-- Company: 		Binghamton University
-- Engineer:      
--
--    File Name:  me.vhd
--      Version:  2.0
--         Date:  February 13, 2016
--  Description:  Lab3 Part A Manchester Encoder
--
--  Revisions:    2/17/2016 cwb
--						Changed name of active_frame signal to processing_frame
--						for better clarity

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ManchEncoder is
	port (rst, clk, nrz_in : in std_logic;
			manout   : out std_logic);
end ManchEncoder;

architecture Behavioral of ManchEncoder is

	-- Constants
	constant SYNC_NRZ: unsigned (4 downto 0) := "11111";
													-- value of manchester_timer that determines 
													-- when to clock the nrz_sync_reg which is 
													-- at the start of a new Manchester clock 
													-- cycle

	-- Signals
	signal manclk : std_logic  := '0';  -- Manchester clock
	signal manclk_sync : std_logic :='0'; 
													-- indicates falling edge of manchester 
													-- clock
													-- this is time when one bit ends and 
													-- the next bit begins 
													
	signal en_sync_reg : std_logic;     -- enable for nrz_sync_reg
													-- generated on falling edge of manclk
													-- while the nrz frame is being processed
	
	-- Counters
	signal manchester_timer : unsigned (4 downto 0) := (others => '0'); 
													-- counter provides the timing for the 
													-- Manchester code on manout
	signal sampling_ctr : unsigned (4 downto 0) := (others => '0'); 
													-- this counter is synchronized to the 
													--  frame start bit received on nrz_in 
													-- counts 0 to 15 for each signal element  
													--  (or bit) of the NRZ frame
	signal num_bits_sampled : unsigned (3 downto 0) := (others => '0');
													-- counts number of bits sampled in the 
													-- NRZ frame
	
	-- Registers
	signal nrz_hold_reg : std_logic  := '1'; 
													-- samples and holds the value of the current
													-- nrz bit on nrz_in
	signal nrz_sync_reg : std_logic  := '0';  
													-- synchronizes the output of 
													-- nrz_hold_reg with the Manchester clock
	
	-- Declarations for the Encoder FSM
	type statetype is (Init, Start_Bit_Detect, Wait_to_Sample, Sample_NRZ, 
															Wait_EOB, End_of_Bit, Wait_for_Sync);
	-- State Register and Next-State Logic				-- (EOB = end of bit)
	signal state, next_state : statetype;

	-- FSM Outputs
	signal processing_frame : std_logic := '0'; 
													-- Indicates that the current frame is being 
													-- processed
													-- Used as input to nrz_sync_reg process
	signal en_sampling_ctr : std_logic; -- enable sampling_ctr
	signal clr_sampling_ctr : std_logic; -- clear sampling_ctr	
	signal en_num_bits : std_logic;     -- enable for num_bits_sampled counter	
	signal clr_num_bits : std_logic;    -- clear for num_bits_sampled counter
	signal en_hold_reg : std_logic;     -- enable for nrz_hold_reg	
	signal set_hold_reg : std_logic;    -- set for nrz_hold_reg	
	signal set_sync_reg : std_logic;    -- set for nrz_sync_reg	

begin

	-- Manchester Encoder FSM
	-- State Register

	--##### INSERT YOUR CODE HERE #####--
	process(rst,clk) 
	begin
		if rst = '1' then 
				state <= Init;
		elsif rising_edge(clk) then
				state <= next_state;
		end if;
	end process;
	
	-- Next State and Output Logic

	--##### INSERT YOUR CODE HERE #####--
	process(state,nrz_in)
	begin
			processing_frame <= '0';
			en_sampling_ctr <= '0';
			clr_sampling_ctr <= '0';
			en_num_bits <= '0';
			clr_num_bits <= '0';
			en_hold_reg <= '0';
			set_hold_reg <= '0';
			set_sync_reg <= '0';
			case state is
				when Init =>
					next_state <= Start_Bit_Detect;
					
				when Start_Bit_Detect =>
					set_hold_reg <= '1';
					set_sync_reg <= '1';
					clr_sampling_ctr <= '1';
					clr_num_bits <= '1';
					if nrz_in = '1' then
						next_state <= Start_Bit_Detect;
					else
						next_state <= Wait_to_Sample;
					end if;
					
				when Wait_to_Sample =>
					en_sampling_ctr <= '1';
					processing_frame <= '1';
					if sampling_ctr = "01111" then
						next_state <= Sample_NRZ;
					else 
						next_state <= Wait_to_Sample;
					end if;
					
				when Sample_NRZ => 
					en_hold_reg <= '1';
					en_sampling_ctr <= '1';
					en_num_bits <= '1';
					processing_frame <= '1';
					next_state <= Wait_EOB;
					
					
				when Wait_EOB => 
					en_sampling_ctr <= '1';
					processing_frame <= '1';
					if sampling_ctr = "11111" then
						next_state <= End_of_Bit;
					else
						next_state <= Wait_EOB;
					end if;
				
				when End_of_Bit =>
					processing_frame <= '1';
					en_sampling_ctr <= '1'; 
					if num_bits_sampled = sampling_ctr then
						next_state <= Wait_for_Sync;
					else 
						next_state <= Wait_to_Sample;
					end if;
					
				when Wait_for_Sync =>
					en_sampling_ctr <= '1';
					processing_frame <= '1';
					next_state <= Start_Bit_Detect;
			end case;
		end process;
	

	-- Datapath Components

	-- Process for "manchester_timer":
	-- Implements a clock divider counter used to generate the timing for 
	--    each Manchester clock cycle.
	-- Counts 0 to 31 for each bit of Manchester data produced by the encoder.

	--##### INSERT YOUR CODE HERE #####--
	process(clk) begin
		if rising_edge(clk) then
			if RST = '1' then
				manchester_timer <= to_unsigned(0, manchester_timer'length);
			else
				manchester_timer <= manchester_timer + to_unsigned(1, manchester_timer'length);
			end if;
		end if;
	end process;	
	
	-- Assignment statement for "manclk":
	-- Manchester clock (manclk) is a square wave (50% duty cycle) derived
	--    from the "manchester_timer".

	--##### INSERT YOUR CODE HERE #####--
	process(clk, manchester_timer) begin
		if rising_edge(clk) then
			if RST = '1' or manchester_timer <= to_unsigned(15, manchester_timer'length) then
				manclk <= '0';
			else
				manclk <= '1';
			end if;
		end if;
	end process;

	-- Process or Assignment Statement for "manclk_sync":
	-- Used to sample the NRZ bit value to at the beginning of a Manchester
	--    clock cycle.

	--##### INSERT YOUR CODE HERE #####--
	process(clk, manchester_timer) begin
		if rising_edge(clk) then
			if RST = '1' or manchester_timer /= to_unsigned(31, manchester_timer'length) then
				manclk_sync <= '0';
			else
				manclk_sync <= '1';
			end if;
		end if;
	end process;
	

	-- Process for "sampling_ctr":
	-- This ounter measures time from the detection of the start bit
	--    to the center of the start bit and then the time to the
	--    center of each subsequent bit of the frame.
	-- The counter is held cleared while waiting for the start bit.
	-- The counter will count from 0 to 31 for each bit period of nrz_in.

	--##### INSERT YOUR CODE HERE #####--
	process(clk, en_sampling_ctr) begin
		if rising_edge(clk) then
			if RST = '1' or clr_sampling_ctr = '1' then
				sampling_ctr <= to_unsigned(0, sampling_ctr'length);
			elsif en_sampling_ctr = '1' then
				sampling_ctr <= sampling_ctr + to_unsigned(1, sampling_ctr'length);
			end if;
		end if;
	end process;

	-- Process for "num_bits_sampled":
	-- This counter counts the number of bits of nrz data that are sampled.
	-- It is incremented when nrz bit is sampled.
	-- The counter is cleared when the 11 bits of NRZ data have been encoded. 

	--##### INSERT YOUR CODE HERE #####--
	process(clk, manchester_timer, en_num_bits, clr_num_bits) begin
		if rising_edge(clk) then
			if RST = '1' or clr_num_bits = '1' then
				num_bits_sampled <= to_unsigned(0, num_bits_sampled'length);
			elsif manchester_timer = to_unsigned(16, manchester_timer'length) and en_num_bits = '1' then
				num_bits_sampled <= num_bits_sampled + to_unsigned(1, num_bits_sampled'length);
			else 
				num_bits_sampled <= num_bits_sampled;
			end if;
		end if;
	end process;

	-- Process for "nrz_hold_reg":
	-- This register samples the value of nrz_in at the center of each bit.
	-- It is set to '1' by RST and before the beginning of each frame.

	--##### INSERT YOUR CODE HERE #####--
	process(clk) begin
		if rising_edge(clk) then
			if RST = '1' then
				nrz_hold_reg <= '1';
			elsif set_hold_reg = '1' then
				nrz_hold_reg <= '1';
			elsif en_hold_reg = '1' then
				nrz_hold_reg <= nrz_in;
			else 
				nrz_hold_reg <= nrz_hold_reg;
			end if;
		end if;
	end process;

	-- Process for "nrz_sync_reg":
	-- Once the start bit is detected and processing of the frame commences, 
	--		this register synchronizes the nrz_in samples captured 
	--		in "nrz_hold_reg" at the time of the falling edge of the 
	-- 	Manchester clock.
	-- When not processing a frame, "nrz_sync_reg" is set to '1'.

	--##### INSERT YOUR CODE HERE #####--
	en_sync_reg <= processing_frame and manclk_sync;
	process(clk) begin
		if rising_edge(clk) then
			if RST = '1'  or set_sync_reg = '1' or processing_frame = '0' then
				nrz_sync_reg <= '1';
			elsif en_sync_reg = '1' then
				nrz_sync_reg <= nrz_hold_reg;
			end if;
		end if;
	end process;

	-- Process for "manout":
	-- Generates the Manchester data output (manout) from the synchronized 
	--   NRZ data (nrz_sync_reg) and the Manchster Clock (manclk). 
	--	It can be done using one or two logical operations. 
	-- Synchronize this register with clk.

	--##### INSERT YOUR CODE HERE #####--
	process(clk) begin 
		if rising_edge(clk) then 
			manout <= manclk xnor nrz_sync_reg;
		end if; 
	end process;
	

end Behavioral;

