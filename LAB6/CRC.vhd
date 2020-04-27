----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:       
-- 
-- Create Date:    12:45:44 03/02/2011 
-- Design Name: 	 Cyclic Redundancy Check (CRC) Error Detection Code
-- Module Name:    CRC - Behavioral 
-- Project Name:   Lab4
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
--		2/21/2015  - Minor updates to comments and signal names
--    2/27/2016  - updates to comments to correct errors and add clarity
--    4/10/2016  - updates to comments to correct errors and add clarity
--    3/25/2017  - added FSM Mealy output for frame_out to shorten it by 1 clk
-- Additional Comments: 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity CRC is
	 Generic ( fcs_length : integer := 5 ); 
    Port ( P : in std_logic_vector (fcs_length downto 0) ;
			  data_in : in  STD_LOGIC;
			  dclk_in : in STD_LOGIC;
           frame_in : in  STD_LOGIC;
           data_out : out  STD_LOGIC;
           dclk_out : out  STD_LOGIC;
			  frame_out : out  STD_LOGIC;
           error_out : out  STD_LOGIC;
           mode : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           rst : in  STD_LOGIC);
end CRC;

-- Definition of I/O
-- fcs_length	: 	defines length of frame check sequence to be generated and 
--						appended to end of data being transmitted
-- P				:  input that defines the predetermined divisor for the CRC 
-- data_in		: 	serial input data to be processed by the CRC
-- dclk_in		: 	input data clock; rising edge indicates the data is valid 
--						(sample point at center of bit)
-- frame_in		: 	this input is a '1' to indicate a data frame 
--					   ('0' means there is no data) 
-- data_out		: 	when mode = '1', outputs a frame of input data followed by its FCS 
-- dclk_out		: 	output data clock; rising edge indicates the data is valid
--						(center of bit period)
-- frame_out	:  this output is a '1' when a frame of data including its 
-- 					FCS is provided on the data_out output
-- error_out	: 	when mode = '0', this output is a '1' (error) if 
--						the C_reg does not contain all zeros (CRC remainder)  
--             	after a data frame is processed
-- mode			:	this defines whether the module is being used to generate a FCS 
--						or detect errors
--							mode = '0' -> error detection mode
--							mode = '1' -> FCS generation mode
-- clk			:	system clock
-- rst			:	system reset


architecture Behavioral of CRC is

	-- Refer to figures provided in the lab procedure
	-- This design is intended to be "scalable" by using a 
	--		generic parameter to define the FCS length
	-- The size of the predetermined divisor input, P, 
	--    is set by this parameter as well.

	-- registers to sync inputs to system clock and produce delays for edge detection
	signal dclk_in_d1 : std_logic ; -- dclk_in delayed one system clk
	signal dclk_in_d2 : std_logic ; -- dclk_in delayed two system clks
	signal data_in_d1 : std_logic ; -- data_in delayed one system clk
	signal data_in_d2 : std_logic ; -- data_in delayed two system clk
	signal frame_in_d1 : std_logic ; -- frame_in delayed one system clk
	
	-- shift register used for generating the FCS or checking data for errors
	signal C_reg : std_logic_vector (fcs_length - 1 downto 0) ;
	
	-- input to C_reg
	signal C_reg_in : std_logic ;
	-- shift clock enable for C_reg to provide proper timing
	signal shift_enable : std_logic ;
	
	-- register for the output of C_reg producing FCS
	signal C_reg_out : std_logic ;
	-- clock enable for the C_reg_out register to provide required synchronization
	signal C_reg_out_enable : std_logic ;
	
	-- MUX for data output register
	signal data_out_MUX : std_logic;

	-- FSM output signals
	signal reset_FBC, incr_FBC, clr_CReg, shift_Creg : std_logic;
	signal check_error, enable_error, FBC_eq_fcs_length : std_logic;
	signal DO_MUX_sel : std_logic_vector(1 downto 0);
		constant MUX_SEL_DATA : std_logic_vector(1 downto 0) := "01";
		constant MUX_SEL_CRC  : std_logic_vector(1 downto 0) := "10";
	
	-- FSM state register and next state decode
	type state_type is (Init, Gen, Gen_Calc, Shift_CRC, Det, 
									Det_Calc, Check_Remainder, Report_Error);
	signal state, next_state : state_type;
	
	-- register and clock signal for counter to count the FCS bits sent
	-- register for FCS bit counter
	signal fcs_bit_ctr : unsigned(5 downto 0) := (others => '0');	
	-- signal for FSC bit counter clock enable
	signal FBC_clk_en : std_logic;

begin

	-------------------------------
	-- SIGNAL CONDITIONING LOGIC --
	-------------------------------
	-- (data_in_d1, data_in_d2)
	-- sync data_in to system clock
	process (clk)
	begin
		if rising_edge(clk) then
			data_in_d1 <= data_in ;
			data_in_d2 <= data_in_d1 ;
		end if ;		
	end process ;

	-- (dclk_in_d1, dclk_in_d2)
	-- generate two delayed version of the dclk_in
	-- used for finding the clock edges
	process (clk)
	begin
		if rising_edge(clk) then
			dclk_in_d1 <= dclk_in ;
			dclk_in_d2 <= dclk_in_d1 ;
		end if ;
	end process ;	

	-- (frame_in_d1)
	-- sync frame_in to system clock
	process (clk)
	begin
		if rising_edge(clk) then
			frame_in_d1 <= frame_in ;
		end if ;		
	end process ;

	-- (shift_enable)
	-- generate the shift clock for the C_reg
	-- generate a pulse one system clock cycle wide by detecting
	-- 	the rising edge of the input data clock
	shift_enable <= dclk_in_d1 and not dclk_in_d2 ;

	-- (C_reg_out_enable)
	-- logic to generate clock for the C_reg output register 
	--    on the falling edge of dclk_in
	C_reg_out_enable <= (not dclk_in_d1) and dclk_in_d2; 

	-- (FBC_clk_en)
	-- clock enable for the FCS bit counter
	-- generate a pulse one system clock cycle wide by detecting
	-- 	the falling edge of the input data clock
	FBC_clk_en <= (not dclk_in_d1) and dclk_in_d2;
	
	-- (dclk_out)	
	-- generate the output data clock
	-- the data_out is delayed by 2 clk rises from the data_in
	-- this is because the FCS produced is delayed by 2 clk rises
	--    from the last bit of data_in
	-- so, use dclk_in_d2 for the output data clock
	dclk_out <= dclk_in_d2 ;
	

	------------------
	-- CRC DATAPATH --
	------------------
	-- (C_reg_in)
	-- defines the input to the C_reg 
	-- (refer to the CRC block diagrams in the procedure)
	-- use combinational logic only
	-- result should be a logic function of data_in_d1 and MSB of C_reg 
	-- use frame_in_d1 to hold the signal to zero outside of the data frame
	------------------------------------------------------------------
	--#####                 ENTER YOUR CODE HERE                 #####
	C_reg_in <= (data_in_d1 xor C_reg(fcs_length - 1)) and frame_in_d1;
	------------------------------------------------------------------

	-- (C_reg)
	-- Multi-function register for the C_reg
	-- C_reg needs to have the following functions:
	--		Clear 
	--		Shift
	-- Use clr_CReg signal to enable the clear function 
	-- The clear should have priority	
	-- Shifting is enabled with shift_Creg and shift_enable
	-- During the shift, apply the CRC algorithm to the bits of the C_reg
	-- Hint:  use an assignment statement to set bit 0, then use a "for loop"  
	-- 	to handle each subsequent bit of the C_Reg.  Use P, the predetermined  
	-- 	divisor, to establish which C_reg bits are to include an XOR of 
	--		C_reg_in with the previous C_reg bit
	------------------------------------------------------------------
	--#####                 ENTER YOUR CODE HERE                 #####
	process(clk) begin 
		if rising_edge(clk) then 
			if clr_CReg = '1' then 
				C_reg <= (others => '0');
			elsif (shift_Creg and shift_enable) = '1' then 
				C_Reg(0) <= C_reg_in;
				for I in fcs_length-1 downto 1 loop
					C_reg(I) <= (C_reg_in AND P(I)) xor (C_reg(I-1));
				--if P(I) = '1' then 
				--		C_Reg(I) <= C_Reg(I-1) xor C_reg_in;
				--	else
				--		C_Reg(I) <= C_Reg(I-1);
				--	end if;
				end loop;
				--C_Reg(0) <= C_reg_in;
			else
				C_Reg  <= C_Reg;
			end if;
		end if;
	end process;			
	------------------------------------------------------------------

	-- (C_reg_out)
	-- process for creating a C_reg_out register
	-- the FCS shifted out of the C_reg must have the same timeing 
	--    as input data being sent back out so that the output of 
	--		the data_out_MUX will be the input data immediately followed
	--		by the FCS
	-- therefore, need to synchronize the C_reg output to the falling
	--		edge of the dclk (use the C_reg_out_enable signal)
	------------------------------------------------------------------
	--#####                 ENTER YOUR CODE HERE                 #####
	process(clk) begin
		if rising_edge(clk) then
			if C_reg_out_enable = '1' then
				C_reg_out <= C_Reg(fcs_length - 1);
			else 
				C_reg_out <= C_reg_out;
			end if;
		end if;
	end process;
	------------------------------------------------------------------

	-- (data_out_MUX)
	-- data output mux
	-- selects the input data (data_in_d2) while data is being received, 
	--    then selects the C_reg_out register while the CRC is being shifted out 
	--    and '0' when there is no data to be output
	-- the timing of data_in is selected to match the delay produced by C_reg_out
	------------------------------------------------------------------
	--#####                 ENTER YOUR CODE HERE                 #####
	process(DO_MUX_sel, data_in_d2, C_reg_out) begin
		if DO_MUX_sel = "01" then 
			data_out_MUX <= data_in_d2;
		elsif DO_MUX_sel  = "10" then
			data_out_MUX <= C_reg_out;
		else 
			data_out_MUX <= '0';
		end if;
	end process;
	------------------------------------------------------------------

	-- (data_out)
	-- data output is the output of the data_out_MUX
	data_out <= data_out_MUX;
	
	-- (fcs_bit_ctr)
	-- counter that counts the FCS bits sent
	-- the counter is to be reset to zero using reset_FBC
	-- the counter counts up when enabled by incr_FBC and FBC_clk_en
	------------------------------------------------------------------
	--#####                 ENTER YOUR CODE HERE                 #####
	process(clk) begin 
		if rising_edge(clk) then 
			 if reset_FBC = '1' then 
				fcs_bit_ctr <= to_unsigned(0, fcs_bit_ctr'length);
			elsif (incr_FBC and FBC_clk_en) = '1' then
				fcs_bit_ctr <= fcs_bit_ctr + to_unsigned(1, fcs_bit_ctr'length);
			else 
				fcs_bit_ctr <= fcs_bit_ctr;
			end if;
		end if;
	end process;
			
	------------------------------------------------------------------

	-- (FBC_eq_fcs_length)
	-- comparator for FCS bit counter maximum count
	-- when fcs_bit_ctr equals the fcs_length, set this signal to '1', else '0'
	------------------------------------------------------------------
	--#####                 ENTER YOUR CODE HERE                 #####
	process(fcs_bit_ctr) begin
		if fcs_bit_ctr = fcs_length then 
			FBC_eq_fcs_length <= '1';
		else
			FBC_eq_fcs_length <= '0';
		end if;
	end process;
	------------------------------------------------------------------

	-- (error_out)
	-- generate error_out signal
	-- error_out is cleared to '0' when enable_error = '0'
	-- error_out is a '1' when the CRC remainder is not zero at the end of an 
	-- 	input data frame when performing error detection (mode = 0)
	-- Hint: two ways you can do this are
	--				1. use a local variable with a for loop to create a multiple 
	--					input OR-gate with the size depended upon fcs_length
	-- 			2.	type convert the C_reg to unsigned and compare it to zero
	process (clk)
		variable OR_C_reg : std_logic ;  -- optional
	begin
	------------------------------------------------------------------
	--#####                 ENTER YOUR CODE HERE                 #####
		if rising_edge(clk) then
			if enable_error = '0' then
				error_out <= '0';
			elsif check_error = '1' then
				OR_C_Reg := C_reg(0);
				for i in 1 to fcs_length-1 loop
					OR_C_Reg := OR_C_Reg or C_reg(i);
				end loop;
				error_out <= OR_C_Reg;
			end if;
		end if;
	------------------------------------------------------------------
	end process ;
	
	--------------------------
	-- CRC CONTROLLER (FSM) --
	--------------------------
	-- State Register
	------------------------------------------------------------------
	--#####                 ENTER YOUR CODE HERE                 #####
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then 
				state <= Init;
			else 
				state <= next_state;
			end if;
		end if;
	end process;
	
			
	------------------------------------------------------------------

	-- Next State and Output decode logic
	------------------------------------------------------------------
	--#####                 ENTER YOUR CODE HERE                 #####
	process(state, mode, frame_in_d1, FBC_eq_fcs_length) begin 
		clr_Creg <= '0';
		shift_Creg <= '0';
		check_error <= '0';
		frame_out <= '0';
		reset_FBC <= '0';
		enable_error <= '0';
		incr_FBC <= '0';
		DO_MUX_sel <= "00";
		case state is
			when Init =>
				clr_Creg <= '1';
				if mode = '1' then 
					next_state <= Gen;
				else
					next_state <= Det;
				end if;
			
			when Gen =>
				if mode = '0' then 
					next_state <= Det;
				elsif frame_in_d1 = '1' then 
					next_state <= Gen_Calc;
				else
					next_state <= Gen;
				end if;
			
			when Gen_Calc =>
				DO_MUX_sel <= "01";
				shift_Creg <= '1';
				reset_FBC <= '1';
				frame_out <= '1';
				if frame_in_d1 = '0' then 
					next_state <= Shift_CRC;
				else
					next_state <= Gen_Calc;
				end if;
			
			when Shift_CRC =>
				DO_MUX_sel <= "10";
				shift_Creg <= '1';
				incr_FBC <= '1';
				if FBC_eq_fcs_length = '1' then 
					frame_out <= '0';
					next_state <= Init;
				else 
					frame_out <= '1';
					next_state <= shift_CRC;
				end if;
			
			when Det =>
				if frame_in_d1 = '1' then 
					next_state <= Det_Calc;
				elsif mode = '1' then 
					next_state <= Gen;
				else 
					next_state <= Det;
				end if;
				
			when Det_Calc =>
				shift_Creg <= '1';
				if frame_in_d1 = '0' then 
					next_state <= Check_Remainder;
				else 
					next_state <= Det_Calc;
				end if;
			
			when Check_Remainder =>
				check_error <= '1';
				enable_error <= '1';
				clr_Creg <= '1';
				next_state <= Report_Error;
			
			when Report_Error =>
				enable_error <= '1';
				if frame_in_d1 = '1' then 
					next_state <= Det_Calc;
				elsif frame_in_d1 = '0' AND mode = '0' then 
					next_state <= Report_Error;
				else
					next_state <= Gen;
				end if;
			end case;
		end process;
					
		
	------------------------------------------------------------------

	
end Behavioral;