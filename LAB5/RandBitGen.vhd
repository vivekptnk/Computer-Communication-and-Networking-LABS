----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer: 		 
-- 
-- Create Date:    21:59:24 03/09/2011 
-- Design Name: 	 Random Bit Generator
-- Module Name:    RandBitGen - Behavioral 
-- Project Name:   Lab5
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
--		03/07/2015 - Changed library package from IEEE.STD_LOGIC_UNSIGNED to
--						 IEEE.NUMERIC_STD.
--						 Changed shift_ctr type from std_logic_vector to unsigned.
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RandBitGen is
	 Generic (size : integer := 4);							-- length of LFSR
    Port ( P : in STD_LOGIC_VECTOR(size downto 1);    -- Primitive Polynomial
			  seed : in STD_LOGIC_VECTOR(size downto 1);	-- Seed Value
			  frame_in : in STD_LOGIC; 						-- Frame Input
			  dclk_in : in STD_LOGIC; 							-- Input Data Clock
			  data_out : out  STD_LOGIC; 						-- Data Output
			  dclk_out : out STD_LOGIC;						-- Output Data Clock
			  frame_out : out STD_LOGIC;						-- Frame Ouput
           clk : in  STD_LOGIC; 								-- System Clock
           rst : in  STD_LOGIC); 							-- System Reset
end RandBitGen;

architecture Behavioral of RandBitGen is

	-- synchronized inputs
	signal dclk_in_d1 : std_logic; -- dclk_in delayed one system clk
	signal dclk_in_d2 : std_logic; -- dclk_in delayed two system clks
	signal frame_in_d1 : std_logic; -- frame_in delayed one system clk
	signal frame_in_d2 : std_logic; -- frame_in delayed two system clks

	signal dclk_fall : std_logic; -- falling edge of dclk_in
	
	-- define shift register used for the random bit generator
	-- the generic "size" specifies the length of the shift register
	signal shift_reg_F : std_logic_vector (size downto 1); -- Fibonacci LFSR
	signal shift_reg_G : std_logic_vector (size downto 1); -- Galois LFSR

	-- shift counter used for test (will be optimized out by synthesis)
	signal shift_ctr : unsigned(size downto 0):= (others => '0');	
	
begin

	-- (dclk_in_d1, dclk_in_d2)
	-- generate two delayed versions of the dclk_in
	-- synchronized with clk
	process (clk)
	begin
		if rising_edge(clk) then
			dclk_in_d1 <= dclk_in;
			dclk_in_d2 <= dclk_in_d1;
		end if;
	end process;	

	-- (dclk_fall)
	-- detect falling edge of dclk_in
	-----------------------------------------------------------------------
	--##########             WRITE YOUR CODE HERE                ##########
	dclk_fall <= (not dclk_in_d1) and dclk_in_d2;
	-----------------------------------------------------------------------

	-- (frame_in_d1, frame_in_d2)
	-- generate two delayed versions of the frame_in
	-- synchronized with clk
	process (clk)
	begin
		if rising_edge(clk) then
			frame_in_d1 <= frame_in;
			frame_in_d2 <= frame_in_d1;
		end if;	
	end process;

	-- random bit generator linear feedback shift register
	-- shift register length is "size" (size downto 1)
	-- shift_reg is initialized to the seed value at reset
	-- implement one of the two types of LFSRs
	-- shift_reg is shifted when dclk falls and frame_in is a '1'
	-- 	(be sure to use synchronized inputs)
	-- choose to implement either the Galois LFSR or the Fibonacci LFSR

	-- (shift_reg_G)
	-- Galois LFSR
	-----------------------------------------------------------------------
	--##########             WRITE YOUR CODE HERE                ##########
	-----------------------------------------------------------------------
											--	OR --
	-- (shift_reg_F)
	-- Fibonacci LFSR
	-----------------------------------------------------------------------
	--##########             WRITE YOUR CODE HERE                ##########
	process(clk) 
		variable lsb_in : std_logic := '0';
	begin 
		if rising_edge(clk) then 
			if rst = '1' then 
				shift_reg_F <= seed;
			elsif dclk_fall = '1' and frame_in = '1' then 
				lsb_in := '0';
				for I in size downto 1 loop
					lsb_in := lsb_in xor (shift_reg_F(I) and P(I));
				end loop;
				
				for I in size downto 2 loop 
					shift_reg_F(I) <= shift_reg_F(I-1);
				end loop;
				
				shift_reg_F(1) <= lsb_in;
				
			else 
				shift_reg_F <= shift_reg_F;
			end if;
		end if;
	end process;
				
				
	-----------------------------------------------------------------------

	-- (shift_ctr)
	-- Shift counter - only used for simulation purposes 
	-- will be optimized out by synthesis
	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				shift_ctr <= (others => '0');
			elsif shift_ctr = (2**size)-1 and frame_in_d1 = '1' and dclk_fall = '1' then
				shift_ctr <= (0 => '1', others => '0');
			elsif frame_in_d1 = '1' and dclk_fall = '1' then 
				shift_ctr <= shift_ctr + 1; 
			else	
				shift_ctr <= shift_ctr;
			end if;	
		end if;		
	end process;
	
	-- (data_out)
	-- generate data_out from the random bit generator when enabled by frame_in
	-- use the bit of the LFSR according to the type you designed
	-- use the appropriate delayed frame_in so it aligns correctly with the
	--    shift register output in time
	-- data_out should be zero when no frame is being output
	-----------------------------------------------------------------------
	--##########             WRITE YOUR CODE HERE                ##########
	process(clk) begin 
		if rising_edge(clk) then 
			if rst='1' or frame_in_d2 = '0' then 
				data_out <= '0';
			else
				data_out <= shift_reg_F(size);
			end if;
		end if;
	end process;
	-----------------------------------------------------------------------

	-- (dclk_out)
	-- generate dclk_out, again choosing the appropriate timing
	-----------------------------------------------------------------------
	--##########             WRITE YOUR CODE HERE                ##########
	dclk_out <= dclk_in_d2;
	-----------------------------------------------------------------------

	-- (frame_out)
	-- generate frame_out, choosing the appropriate timing
	-----------------------------------------------------------------------
	--##########             WRITE YOUR CODE HERE                ##########
	frame_out <= frame_in_d2;
	-----------------------------------------------------------------------

end Behavioral;