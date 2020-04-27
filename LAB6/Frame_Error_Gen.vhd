----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer: 		 
-- 
-- Create Date:    20:10:32 03/20/2011 
-- Design Name:    Frame Error Generator for CRC Error Detection Demo
-- Module Name:    Frame_Error_Gen - Behavioral 
-- Project Name:   Lab6
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
--          0.02 - April 2014 - Removed "stop" input
--				0.03 - March 2015 - Replaced IEEE.STD_LOGIC_UNSIGNED package with
--												IEEE.NUMERIC_STD package
--										- Changed cntr type from SLV to UNSIGNED
--										- Removed "start" input
--				0.04 - April 2018 - Added frame_in_fall signal and used it in place
--										  of frame_in='0' as condition of transition from
--										  state 3 to state 4. This fixes slight timing issue
--										  with timing of falling edge of frame_error output
--										  of the FSM
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Frame_Error_Gen is
 	Generic ( frame_length : integer := 15 );			
   Port  ( frame_error_rate : in  STD_LOGIC_VECTOR (3 downto 0);
           error_pattern : in  STD_LOGIC_VECTOR (7 downto 0);
			  error_mode_ctrl : STD_LOGIC;
           data_in : in  STD_LOGIC;
           dclk_in : in  STD_LOGIC;
           frame_in : in  STD_LOGIC;
           data_out : out  STD_LOGIC;
           dclk_out : out  STD_LOGIC;
           frame_out : out  STD_LOGIC;
           frame_error : out  STD_LOGIC;
           bit_errors : out  STD_LOGIC;
           pass_thru_data : out  STD_LOGIC;
           clk : in  STD_LOGIC;
           rst : in  STD_LOGIC);
end Frame_Error_Gen;

architecture Behavioral of Frame_Error_Gen is

	component RandBitGen 
		 Generic (size : integer := 4);
		 Port ( P : in STD_LOGIC_VECTOR(size downto 1);   
				  seed : in STD_LOGIC_VECTOR(size downto 1);		
				  frame_in : in STD_LOGIC;
			     dclk_in : in STD_LOGIC;
			     data_out : out  STD_LOGIC;
			     dclk_out : out STD_LOGIC;	
			     frame_out : out STD_LOGIC;	
              clk : in  STD_LOGIC;
              rst : in  STD_LOGIC);
	end component;

	-- parameters for random bit generator
	constant RBGsize : integer := 8 ;
	constant RBG_P   : std_logic_vector (RBGsize downto 1) := "10111000" ;
	constant RBGseed : std_logic_vector (RBGsize downto 1) := "10000001" ;

	-- signal declarations
	signal error_mode : std_logic ; -- error_mode 
											  -- (0=pattern from switches, 1=random pattern)
	signal dclk_in_d1 : std_logic ; -- dclk_in delayed one system clk
	signal dclk_in_d2 : std_logic ; -- dclk_in delayed two system clks
	signal data_in_d1 : std_logic ; -- data_in delayed one clk cycle
	signal data_in_d2 : std_logic ; -- data_in delayed two clk cycles
	signal frame_in_d1 : std_logic ; -- frame_in delayed one system clk
	signal frame_in_d2 : std_logic ; -- frame_in delayed two system clks
	signal dclk_rise : std_logic ;   -- rising edge of dclk
	signal dclk_fall : std_logic ;   -- falling edge of dclk
	signal frame_in_rise : std_logic ;  -- rising edge of frame_in
	signal frame_in_fall : std_logic ;  -- falling edge of frame_in

	signal cntr : unsigned(25 downto 0):= (others => '0') ; 
											     -- counter used to set the frame error rate
	signal gen_error : std_logic ; -- indicates when to generate a frame with errors
	signal gen_error_d1 : std_logic ;  -- gen_error delayed one clk cycle
	signal gen_error_rise : std_logic; -- gen_error rising edge detect
	signal error_pattern_reg : std_logic_vector(frame_length - 1 downto 0); 
							-- contains error pattern to be applied to the error frame
	signal error_bit_reg : std_logic_vector(frame_length - 1 downto 0)
																					:= (others => '0'); 
							-- shift reg to shift error pattern to be XOR'd with data out
	
	-- output signals of optional Random Bit Generator that can be used 
	-- 	to generate error patterns
	signal RBG_out : std_logic ;
	signal RBG_dclk_out : std_logic ; -- dclk for error data
	signal RBG_frame_out : std_logic ;
	
	--declarations for state machine for controling error frames 
   type state_type is (st1_sync_gen_error, st2_load_error, 
									st3_start_errorframe, st4_stop_errorframe) ; 
   signal state, next_state : state_type ; 
	
	-- internal signals for outputs of state machine
	signal load_error_bit_reg : std_logic ;
	signal shift_error_bit_reg : std_logic ;
	signal frame_error_i : std_logic ; -- internal frame_error signal;
begin

	-- (dclk_in_d1, dclk_in_d2)
	-- generate two delayed version of the dclk_in
	-- for finding the clock edges
	process (clk)
	begin
		if (rising_edge(clk) ) then
			dclk_in_d1 <= dclk_in ;
			dclk_in_d2 <= dclk_in_d1 ;
		end if ;
	end process ;	

	-- (dclk_rise, dclk_fall)
	-- dclk rising and falling edge detects
	dclk_rise <= dclk_in_d1 AND (NOT dclk_in_d2);
	dclk_fall <= (NOT dclk_in_d1) AND dclk_in_d2;

	-- (frame_in_d1, frame_in_d2)
	-- generate two delayed version of the frame_in
	process (clk)
	begin
		if rising_edge(clk) then
			frame_in_d1 <= frame_in ;
			frame_in_d2 <= frame_in_d1 ;
		end if ;	
	end process ;

	-- (frame_in_rise)
	-- frame_in rising edge detect
	frame_in_rise <= frame_in_d1 AND (NOT frame_in_d2);
	
	-- (frame_in_fall)
	-- frame_in falling edge detect
	frame_in_fall <= (NOT frame_in_d1) AND frame_in_d2;
	
	-- (data_in_d1, data_in_d2)
	-- generate delayed versions of data_in
	process (clk)
	begin
		if rising_edge(clk) then
			data_in_d1 <= data_in ;
			data_in_d2 <= data_in_d1 ;
		end if ;
	end process ;
	
	-- generate dclk_out
	dclk_out <= dclk_in_d2 ;

	-- pass input data through without errors for comparison
	pass_thru_data <= data_in_d2 ;

	-- frame_out is just frame_in delayed
	frame_out <= frame_in_d2 ;

	-- (frame_error)
	-- frame_error output is internal frame error signal
	frame_error <= frame_error_i ;

	-- (cntr)
	-- up counter used to divide down the system clock
	process (clk)
	begin
		if rising_edge(clk) then
			cntr <= cntr + 1 ;
		end if ;
	end process ;	

	-- (gen_error)
	-- multilexer used to select the error rate 
	-- frame_error_rate input is used to select which output of the counter
	--    to use to provide desired frame error rate
	process(frame_error_rate, cntr)
	begin
		case frame_error_rate is
			when "0000" => gen_error <= '0'; 	  -- no errors
			when "0001" => gen_error <= cntr(25); -- 1 error every 1.34 seconds
			when "0010" => gen_error <= cntr(24); -- 1.5 errors/second
			when "0011" => gen_error <= cntr(23); -- 3 errors/second
			when "0100" => gen_error <= cntr(22); -- 6 errors/second
			when "0101" => gen_error <= cntr(21); -- 12 errors/second
			when "0110" => gen_error <= cntr(20); -- 24 errors/second
			when "0111" => gen_error <= cntr(19); -- 48 errors/second
			when "1000" => gen_error <= cntr(18); -- 95 errors/second
			when "1001" => gen_error <= cntr(17); -- 191 errors/second
			when "1010" => gen_error <= cntr(16); -- 381 errors/second
			when "1011" => gen_error <= cntr(15); -- 763 errors/second
			when "1100" => gen_error <= cntr(14); -- 1526 errors/second
			when "1101" => gen_error <= cntr(13); -- 3052 errors/second
			when "1110" => gen_error <= cntr(12); -- 6104 errors/second
			when "1111" => gen_error <= cntr(11); -- 12207 errors/second
			when others => gen_error <= '0';
		end case;
	end process;

	-- generate gen_error_d1 delayed one clock from gen_error 
	process (clk)
	begin
		if rising_edge(clk) then
			gen_error_d1 <= gen_error ;
		end if ;
	end process ;
	
	-- (gen_error_rise)
	-- gen_error rising edge detect
	gen_error_rise <= gen_error and not gen_error_d1 ;

	-- (error_mode)
	-- set error mode
	-- 	if rst = '1' (btn0) then set error_mode to '0'
	--		if error_mode_ctrl = '1' (btn3) then set error_mode to '1'
	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				error_mode <= '0' ;
			elsif error_mode_ctrl = '1' then
				error_mode <= '1' ;
			else
				error_mode <= error_mode ;
			end if ;	
		end if ;
	end process ;
	
	-- random bit generator for generating random bit error patterns
	RandBitGenB : RandBitGen
	generic map ( RBGsize )	
	port map ( 	P 			 	=> RBG_P,
					seed 		 	=> RBGseed,
					frame_in 	=> '1',
					dclk_in 		=> dclk_in,
					data_out  	=> RBG_out,
					dclk_out  	=> RBG_dclk_out,
					frame_out 	=> RBG_frame_out,
					clk   		=> clk,
					rst   		=> rst
					);

--##################################################################################
												--STUDENT CODE--
	-- (error_pattern_reg)
	-- process to insert an error pattern into the error pattern register.
	-- when mode = '0' the error_pattern from the switches is loaded into 
	--		the lower order bits of this register when dclk rises.
	--		The remaining bits are set to '0'.
	-- when mode = '1' the output of the RBG is shifted into bit 0 of this 
	-- 	register when dclk rises.

	-- ###########################################
	-- ########## INSERT YOUR CODE HERE ##########
	-- ###########################################
	process(clk) 
		begin
			if rising_edge(clk)then 
				if dclk_rise = '1' AND error_mode = '0' then
					error_pattern_reg(7 downto 0) <= error_pattern;
					error_pattern_reg(frame_length-1 downto 8) <= (others => '0');
				elsif dclk_rise = '1' AND error_mode = '1' then
					error_pattern_reg <= error_pattern_reg(frame_length-2 downto 0) & RBG_out;
				end if;
			end if;
	end process;
	

	-- (error_bit_reg)
	-- create the error bit register
	-- register has same number of bits as a data frame
	-- a '1' in this register signifies a bit error to be generated in an error frame
	-- this register is loaded with the contents of the "error_pattern_reg" 

	-- ###########################################
	-- ########## INSERT YOUR CODE HERE ##########
	-- ###########################################
	
	process(clk) 
	begin
		if rising_edge(clk) then
			if load_error_bit_reg='1' then
				error_bit_reg <= error_pattern_reg;
			elsif shift_error_bit_reg='1' and dclk_fall = '1' then
				error_bit_reg <= '0' & error_bit_reg(frame_length - 1 downto 1);
			else 
				error_bit_reg <= error_bit_reg;
			end if;
		end if;
	end process;
	

	-- (bit_errors)
	-- the output bit_errors is the output of the error_bit_reg shift register

	-- ###########################################
	-- ########## INSERT YOUR CODE HERE ##########
	-- ###########################################
	
	bit_errors <= error_bit_reg(0) AND frame_error_i;

	-- (data_out)
	-- insert errors into the data during the error frames
	-- otherwise, pass the data through unmodified
	-- bits of data_in (delayed) are XOR'd with corresponding bits in the 
	--    error_bit_reg as they are shifted out 

	-- ###########################################
	-- ########## INSERT YOUR CODE HERE ##########
	-- ###########################################
	
	data_out <= data_in_d2 XOR error_bit_reg(0) when frame_error_i = '1' else data_in_d2;

	-- FSM --
	-- (load_error_bit_reg, shift_error_bit_reg, frame_error_i)
	-- finite state machine to control error frames
	-- "error_frame" enables the insertion of errors into a frame of data
	-- 	and is generated on the rising edge of gen_error
	-- "load_error_bit_reg" loads the error_ pattern_reg into the error_bit_reg
	-- "shift_error_bit_reg" enables the shifting of the error bits out of the
	-- 	error_bit_reg during the error frame

	-- ###########################################
	-- ########## INSERT YOUR CODE HERE ##########
	-- ###########################################
	process(clk) begin 
		if rising_edge(clk) then 
			if rst = '1' then 
				state <= st1_sync_gen_error;
			else
				state <= next_state;
			end if;
		end if;
	end process;
	
	process(state, gen_error_rise, frame_in_rise, frame_in, gen_error, frame_in_fall) begin
		load_error_bit_reg <= '0';
		shift_error_bit_reg <= '0';
		frame_error_i <= '0';
		case state is
			when st1_sync_gen_error => 
				if gen_error_rise = '0' then
					next_state <= st1_sync_gen_error;
				else
					next_state <= st2_load_error;
				end if;
			
			when st2_load_error =>
				load_error_bit_reg <= '1';
				if frame_in_rise = '0' then
					next_state <= st2_load_error;
				else
					next_state <= st3_start_errorframe;
				end if;
				
			when st3_start_errorframe=>
				shift_error_bit_reg <= '1';
				frame_error_i <= '1';
				if frame_in_fall='1' then
					next_state <= st4_stop_errorframe;
				else
					next_state <= st3_start_errorframe;
				end if;
			
			when st4_stop_errorframe => 
				shift_error_bit_reg <= '1';
				if gen_error = '1' then
					next_state <= st4_stop_errorframe;
				else
					next_state <= st1_sync_gen_error;
				end if;
			end case;
		end process;

--##################################################################################

end Behavioral;

