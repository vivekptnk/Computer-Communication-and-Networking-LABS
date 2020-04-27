----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer: 		 Carl Betcher
-- 
-- Create Date:    17:18:29 03/12/2011 
-- Design Name: 	 Control Logic for the CRC Error Detection Demo
-- Module Name:    Control_Logic - Behavioral 
-- Project Name:   Lab6
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Revision 0.01 - File Created
--          0.02 - April 2014 - When "stop" input is received, wait for current
--						 frame to complete before stopping
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Control_Logic is
	 Generic ( tx_frame_length : integer := 10;   -- defines data frame length
			     tx_frame_period : integer := 16;   -- defines frame rate 
				                                     -- (period between start of 
															    --  consecutive frames)		
				  dclk_half_period : integer := 16); -- defines 1/2 period of data 
				                                     -- clock as number of system clock 
															    -- periods
    Port    ( Start : in  STD_LOGIC;
              Stop : in  STD_LOGIC;
              tx_frame_out : out  STD_LOGIC;
			     dclk_out : out STD_LOGIC;
              clk : in  STD_LOGIC;
              rst : in  STD_LOGIC);
end Control_Logic;

architecture Behavioral of Control_Logic is

	constant dclk_ctr_size : integer := 10;  -- make the counter 10 bits
	signal dclk_ctr : std_logic_vector(dclk_ctr_size-1 downto 0) := (others => '0');

	constant frame_length_ctr_size : integer := 10;  -- make the counter 10 bits
	signal frame_length_ctr : std_logic_vector(frame_length_ctr_size-1 downto 0);

	constant frame_period_ctr_size : integer := 10;  -- make the counter 10 bits
	signal frame_period_ctr : std_logic_vector(frame_period_ctr_size-1 downto 0);

	signal dclk : std_logic := '0';
	signal dclk_d1 : std_logic := '0';
	signal dclk_d2 : std_logic := '0';
	signal dclk_fall : std_logic;
	
	-- controller FSM states
	type state_type is (Init, Wait_dclk_fall, Gen_frame, Wait_next);
	signal state, next_state : state_type;
	
	-- control signals for FSM
	-- control inputs
	signal frame_done, period_done : std_logic;
	-- control outputs
	signal tx_frame : std_logic ;
	signal clr_FL_ctr, clr_FP_ctr, en_FL_ctr, en_FP_ctr : std_logic ;
	signal stop_pending : std_logic ;
	signal rst_stop_pending : std_logic ;

begin

	-- counter for data clock period
	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' OR (dclk_ctr = std_logic_vector(to_unsigned
												 (dclk_half_period-1, dclk_ctr'length))) then
				dclk_ctr <= (others => '0') ;
			else
				dclk_ctr <= std_logic_vector(unsigned(dclk_ctr) +1) ;
			end if ;	
		end if ;	
	end process ;

	-- generate dclk
	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				dclk <= '0';
			elsif (dclk_ctr = std_logic_vector(to_unsigned
									(dclk_half_period-1, dclk_ctr'length))) then
				dclk <= not dclk ;
			end if ;	
		end if ;	
	end process ;

	-- generate signals for dclk edge detect
	process (clk)
	begin
		if rising_edge(clk) then
			dclk_d1 <= dclk ;
			dclk_d2 <= dclk_d1 ;
		end if ;	
	end process ;
	
	-- detect the falling edge of dclk
	dclk_fall <= (NOT dclk_d1) AND dclk_d2;

	-- counter for frame length
	process (clk)
	begin
		if rising_edge(clk) then
			if clr_FL_ctr = '1' then
				frame_length_ctr <= (others => '0');
			elsif en_FL_ctr = '1' AND dclk_fall = '1' then 
				frame_length_ctr <= std_logic_vector(unsigned(frame_length_ctr) +1);
			else
				frame_length_ctr <= frame_length_ctr;
			end if ;	
		end if ;	
	end process ;
	
	-- comparator for frame_done
	process (frame_length_ctr, dclk_fall)
	begin
		if dclk_fall = '1' AND
			frame_length_ctr = std_logic_vector(to_unsigned
									 (tx_frame_length-1,frame_length_ctr'length)) then
			frame_done <= '1';
		else
			frame_done <= '0';
		end if;	
	end process;

	-- counter for frame period
	process (clk)
	begin
		if rising_edge(clk) then
			if clr_FP_ctr = '1' then
				frame_period_ctr <= (others => '0');
			elsif en_FP_ctr = '1' AND dclk_fall = '1' then 
				frame_period_ctr <= std_logic_vector(unsigned(frame_period_ctr) + 1);
			else
				frame_period_ctr <= frame_period_ctr;
			end if ;	
		end if ;	
	end process ;

	-- comparator for period_done
	process (frame_period_ctr, dclk_fall)
	begin
		if --dclk_fall = '1' AND
			frame_period_ctr = std_logic_vector(to_unsigned
									 (tx_frame_period-1,frame_period_ctr'length)) then
			period_done <= '1';
		else
			period_done <= '0';
		end if;	
	end process;

	-- output dclk and frame signals
	dclk_out <= dclk_d2 ;
	tx_frame_out <= tx_frame ;
	
	-- stop pending
	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' OR rst_stop_pending = '1' then
				stop_pending <= '0' ;
			elsif stop = '1' then
				stop_pending <= '1' ;
			else
				stop_pending <= stop_pending ;
			end if ;		
		end if ;
	end process ;
	
	-- Controller FSM
	-- state register
	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state <= Init;
			else
				state <= next_state;
			end if;	
		end if;
	end process;
	
	-- next_state and output decode logic
	process (state, Start, Stop, dclk_fall, frame_done, period_done, stop_pending)
	begin
		-- default output values
	   clr_FL_ctr <= '0';
		clr_FP_ctr <= '0';
		en_FL_ctr <= '0';
		en_FP_ctr <= '0';
		tx_frame <= '0';
		rst_stop_pending <= '0';
		case state is 
			when Init =>
				clr_FL_ctr <= '1';  -- clear frame length counter
				clr_FP_ctr <= '1';  -- clear frame period counter	
				if Start = '1' then
					next_state <= Wait_dclk_fall;
				else
					next_state <= Init;
				end if;
			when Wait_dclk_fall =>
				clr_FL_ctr <= '1';  -- clear frame length counter
				clr_FP_ctr <= '1';  -- clear frame period counter	
				if dclk_fall = '1' then
					next_state <= Gen_frame;
				else
					next_state <= Wait_dclk_fall;
				end if;	
			when Gen_frame =>
				en_FL_ctr <= '1';   -- enable frame length counter
				en_FP_ctr <= '1';   -- enable frame period counter
				tx_frame <= '1';	  -- generate the frame output
				if frame_done = '1' then
					next_state <= Wait_next;
				else
					next_state <= Gen_frame;
				end if;
			when Wait_next =>
				clr_FL_ctr <= '1';  -- clear frame length counter
				en_FP_ctr <= '1';   -- enable frame period counter
				if stop_pending = '1' then
					rst_stop_pending <= '1';
					next_state <= Init;
				elsif period_done = '1' then
					next_state <= Wait_dclk_fall;
				else
					next_state <= Wait_next;
				end if;
		end case;		
	end process;
	
end Behavioral;

