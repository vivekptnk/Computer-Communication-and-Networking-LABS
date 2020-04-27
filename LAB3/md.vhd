--------------------------------------------------------------------------------
-- Company: 		Binghamton University
-- Engineer:      
--
--    File Name:  md.vhd
--      Version:  2.0
--         Date:  February 13, 2016
--  Description:  Manchester decoder Chip
--
library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ManchDecoder is
port (rst, clk, manin : in std_logic;
		nrz_out : out std_logic );
end ManchDecoder;

architecture Behavioral of ManchDecoder is

	-- Assume a data rate such that the bit period is 32 CLK periods.
	-- A 6-bit counter (clkdiv) is used for timing.
	-- The Manchester signal (manin) will represent a series of 1s until the start 
	-- bit occurs. While the data is 1s, the rising edge is the Manchester "clock".
	-- "clkdiv" is loaded with 48 when Manchester clock is detected, 
	-- to represent 1/2 of bit period before the next data bit begins.
	--
	-- Manchester Clock:
	--          --------          --------          --------          --------
	--         |        |        |        |        |        |        |        |
	-- --------          --------          --------          --------          -
	-- Manchester Signal:
	--          --------          -----------------          --------          -
	--         |        |        |                 |        |        |        |
	-- --------          --------                   --------          --------
	-- data bits        |<--     1     -->|<-- start bit -->|<-- data bit --->|
	--
	-- Manchester Clock Detect:
	--         |                 |                          |                 |
	-- -------- ----------------- -------------------------- ----------------- -
	-- value of clkdiv:
	--        48      63/0      48      63/0      16      31/0      16       31/0
	--
	-- Value of clkdiv at sample points (1/4 & 3/4 at counts 8 & 24 respectively):
	--                      8                 8        24        8        24	
	--
	-- data_frame:
	--                                                   ----------------------
	--                                                  |
	-- -------------------------------------------------
	
	-- Constants
	constant CLKDIV_INIT : unsigned (5 downto 0) := "110000"; 		
																	-- start ctr at -1/2 period (48)
	constant CLKDIV_14 : unsigned (5 downto 0) := "001000";  		
																	-- 1/4 data bit period (8)
	constant CLKDIV_34 : unsigned (5 downto 0) := "011000";			
																	-- 3/4 data bit period (24)
	constant DECODE_DATA_BIT : unsigned (5 downto 0) := "011010";	
																	-- sample decoded data bit (26)
	constant END_OF_BIT : unsigned (5 downto 0) := "011111";	
																	-- end of bit period (31)
	constant BITS_IN_FRAME : integer := 11; -- number of bits in a frame

	-- Signals
	signal manclk_det : std_logic := '0'; -- detect rising edge of manin
	
	-- Registers
	signal manin_d1 : std_logic := '0';   -- manin delayed by one clk period
	signal manin_d2 : std_logic := '0';   -- manin delayed by two clk periods
	signal manin_s14 : std_logic := '0';  
										-- sample 1/4 data bit period into next data bit
	signal manin_s34 : std_logic := '1';  
										-- sample 3/4 data bit period into next data bit
	signal nrz_out_reg : std_logic := '1'; -- decoded NRZ output register
	
	-- Counters
	signal clkdiv : unsigned (5 downto 0) := (others => '0'); 
														-- counter for decode timing
	signal bit_counter : unsigned (3 downto 0) := (others => '0');
										-- counter that counts the number of bits decoded

	-- Declarations for Start Detect FSM
	type start_bit_decoder is (wait_for_s14_1, wait_for_s34_0, start_bit_det);
	-- State Register and Next-State Logic				
	signal state, next_state : start_bit_decoder;
	-- FSM Output
	signal data_frame : std_logic  := '0'; -- decoding character frame

begin

	-- Process for "manin_d1" and "manin_d2":
	-- To recover manchester clock during periods of no data (sequence of 1s),
	--    need to detect the rising edge of "manin".
	-- First, two registers (manin_d1, manin_d2) are used to delay manin for one 
	-- 	and two periods of clk.
	-- These signals are used for detecting rising edge of manchester data signal.
	
	--##### INSERT YOUR CODE HERE #####--
	process(clk) begin
		if rising_edge(clk) then
			manin_d2 <= manin_d1;
			manin_d1 <= manin;
		end if;
	end process;

	-- Signal assignment statement for manclk_det:
	-- Detect the rising edge of manchester data signal from manin_d1 and manin_d2.
	-- Uses combinational logic only.

	--##### INSERT YOUR CODE HERE #####--
	manclk_det <= (manin_d1) and (not manin_d2);

	-- Look for first "zero" or start bit in the input signal and generate "data_frame"
	-- (implemented in the next four processes)

	-- Process for "clkdiv":
	-- "clkdiv" is a 6-bit counter that counts up with each system clock 
	-- If a start bit has not yet been detected (data_frame = '0') 
	-- 	and if the manchester clock is detected (manclk_det = '1'), 
	-- 	the counter is set to the constant "CLKDIV_INIT" (48) which is 
	--    1/2 data bit period before the next data bit begins. 
	-- 	When the next data bit begins, the counter will roll over to zero.
	-- If data_frame = 1, meaning the start bit has been detected, 
	-- 	the counter is set to zero when the counter reaches a count of 31, 
	-- 	the point in time where one data bit ends and the
	--    next data bit begins.
	-- Otherwise, the counter is incremented.

	--##### INSERT YOUR CODE HERE #####--
	process(clk) begin
		if rising_edge(clk) then
			if data_frame = '0' and manclk_det = '1' then
				clkdiv <= CLKDIV_INIT;
			elsif data_frame = '1' then
				clkdiv <= clkdiv + to_unsigned(1,clkdiv'length);
				if clkdiv = to_unsigned(31, clkdiv'length) then
					clkdiv <= to_unsigned(0,clkdiv'length);
				end if;
			else
				clkdiv <= clkdiv + to_unsigned(1, clkdiv'length);
				if clkdiv = to_unsigned(63, clkdiv'length) then
					clkdiv <= to_unsigned(0, clkdiv'length);
				end if;
			end if;
		end if;
	end process;

	-- Processes for "manin_s14" & "manin_s34":
	-- The Manchester input (using manin_d1) is sampled at 1/4 & 3/4 of Manchester 
	--    clock period and save in registers manin_s14 & manin_s34, repectively.
	-- The sample points are 1/4 & 3/4 of the data period relative to the start of the 
	--    data bit.  clkdiv counts from 0 to 31 for a data bit period (same as 
	--		Manchester clock period).  Therefore, 1/4 period would be a count of 8 and 
	--		3/4 period would be a count of 24.  Constants are declared above.
	-- Registers are initialized at reset to the opposite values from those for  
	--    the start bit, and are also initialized if clkdiv = CLKDIV_INIT 
	--    (i.e. whenever clkdiv is initialized).

	--##### INSERT YOUR CODE HERE #####--
	process(clk) begin
		if rising_edge(clk) then
			if RST = '1' or clkdiv = CLKDIV_INIT then
				manin_s14 <= '0';
				manin_s34 <= '1';
			elsif clkdiv = CLKDIV_14 then
				manin_s14 <= manin_d1;
			elsif clkdiv = CLKDIV_34 then
				manin_s34 <= manin_d1;
			end if;
		end if;
	end process;

	-- Start Detect FSM
	-- Detects the start bit and sets the output signal, "data_frame",  
	--    to '1' for the duration of the 11 bits of the character transfer.
	-- The state register is defined by the signal "state".
	-- The manin_s14 and manin_s34 signals are used for detection of the start bit.
	-- When bit_counter = BITS_IN_FRAME AND clkdiv = DECODE_DATA_BIT, 
	-- 	the data_frame ends.
	-- FSM State Register

	--##### INSERT YOUR CODE HERE #####--
	process(clk) begin 
		if rising_edge(clk) then 
			if RST = '1' then
				state <= wait_for_s14_1;
			else 
				state <= next_state;
			end if;
		end if;
	end process;

	-- FSM Next State and Output Logic

	--##### INSERT YOUR CODE HERE #####--
	process(state, manin_s14, manin_s34, bit_counter) begin
	data_frame <= '0';
	case state is 
		when wait_for_s14_1 =>
			if manin_s14 = '0' then
				next_state <= wait_for_s14_1;
			else
				next_state <= wait_for_s34_0;
			end if;
			
		when wait_for_s34_0 =>
			if manin_s34 = '0' then
				next_state <= start_bit_det;
			else
				next_state <= wait_for_s34_0;
			end if;
		
		when start_bit_det =>
			data_frame <= '1';
			if bit_counter = BITS_IN_FRAME and clkdiv = DECODE_DATA_BIT then
				next_state <= wait_for_s14_1;
			else
				next_state <= start_bit_det;
			end if;
		
		end case;
	end process;
	
	

	-- Process for "nrz_out_reg":
	-- While the data_frame is active, this register samples the decoded data 
	--    at time "DECODE_DATA_BIT" of the "clkdiv" counter.
	-- Puts the decoded data into the "nrz_out_reg".
	-- The nrz_out will be at a high level when there is no data.

	--##### INSERT YOUR CODE HERE #####--
	process(clk) begin
		if rising_edge(clk) then
			if data_frame = '1' then
				if clkdiv = DECODE_DATA_BIT then
					nrz_out_reg <= manin_s34;
				end if;
			else 
				nrz_out_reg <= '1';
			end if;
		end if;
	end process;

	-- Process for "bit_counter":
	-- This counter counts the number of data bits decoded
	-- The process for "data_frame" (in the FSM) is modified to reset
	-- 	it when the "bit_counter" reaches BITS_IN_FRAME
	--    hint: wait until clkdiv = DECODE_DATA_BIT so that the full 
	--					11'th bit is provided
	--          this wouldn't matter if 11th bit is correct stop bit
	--				but if it were erroniously a zero, need to be sure nrz 
	-- 				data reproduces that error
	-- This counter is reset when "data_frame" is '0'

	--##### INSERT YOUR CODE HERE #####--
	process(clk) begin
		if rising_edge(clk) then
			if RST = '1' or data_frame = '0' then
				bit_counter <= to_unsigned(15, bit_counter'length);
			elsif clkdiv = DECODE_DATA_BIT then
				bit_counter <= bit_counter + to_unsigned(1, bit_counter'length);
			end if;
		end if;
	end process;
	

	-- Connect "nrz_out_reg" to the "nrz" output port

	--##### INSERT YOUR CODE HERE #####--
	nrz_out <= nrz_out_reg;

end Behavioral;