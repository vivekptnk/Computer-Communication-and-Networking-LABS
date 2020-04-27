--------------------------------------------------------------------------------
-- Company: 		Binghamton University
-- Engineer:      Carl Betcher
--
--    File Name:  med.vhd
--    Version:  2.0
--    Date:  February 13, 2016
--    Description:  Manchester Encoder/Decoder Module
--    Dependencies:  md.vhd, me.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ManchEncDec is
	PORT (rst,clk : in std_logic;
			nrz_in  : in std_logic;
			manout : out std_logic;
			manin  : in std_logic := '1';
			nrz_out : out std_logic);
end ManchEncDec;

architecture Behavioral of ManchEncDec is

	component ManchEncoder is
		Port (rst,clk 	: in std_logic;
				nrz_in 	: in std_logic;
				manout 	: out std_logic);
	end component;

	component ManchDecoder is
		Port (rst,clk 	: in std_logic;
				manin 	: in std_logic;
				nrz_out 	: out std_logic );
	end component;

	-- declare attribute to assign clock buffers
	attribute buffer_type : string;

	-- Baud rate divisor constant is function of BAUD rate and CLK frequency
	-- baudDivide = (CLK Freq/(BAUDx32)) - 1 
	
	-- baudDivide constant for simulation with Test_med.vhd test bench
	--constant baudDivide : unsigned(8 downto 0) := "000000000"; 

	-- baudDivide constant for simulation with Test_dualUART.vhd and
	-- for programming the FPGA board
	-- Papilio Duo FPGA Board --															
	constant baudDivide : unsigned(8 downto 0) := "001100111"; 	
					-- For a baud rate of 9600, and a CLK frequency = 32 MHz,
					-- baudDivide = (32MHz/(9600x32)) - 1 = 103
	-- Basys2 FPGA Board --																
--	constant baudDivide : unsigned(7 downto 0) := "010100010"; 	
					-- For a baud rate of 9600, and a CLK frequency = 50 MHz, 
					-- baudDivide = (50MHz/(9600x32)) - 1 = 162
																								
	signal clkDiv	:  unsigned(8 downto 0)	:= (others => '0'); -- Divide clk
	signal rClk		:  std_logic := '0';						-- Encoder/Decoder clock
	attribute buffer_type of rClk : signal is "bufg";  -- use clock buffer on rClk		
		
begin
   
	-- Clock Dividing Functions --
	process (CLK)	    		-- set up clock divide for rClk
	begin
		if rising_edge(clk) then
			if clkDiv = baudDivide then
				clkDiv <= (others => '0');
			else
				clkDiv <= clkDiv + 1;
			end if;
		end if;
	end process;

   -- When baudDivide is not zero, use this process
	gen_rclk1: if baudDivide /= 0 generate
		process (CLK)				-- define rClk to be one period of clkDiv
		begin
			if rising_edge(clk) then
				if clkDiv = baudDivide then
					rClk <= '1';
				elsif clkDiv = ('0' & baudDivide(baudDivide'left downto 1)) then	
					rClk <= '0';						-- half baudDivide (shift right one)
				else
					rClk <= rClk;
				end if;
			end if;
		end process;
	end generate gen_rclk1;
	
	-- When baudDivide = 0, connect system clock, clk, directly to the clock
	-- inputs of the encoder and decoder using the rClk signal
	gen_rclk2: if baudDivide = 0 generate
		rClk <= clk;				-- define rClk to be clk
	end generate gen_rclk2;
	
	-- Manchester Encoder
	ManEncoder: ManchEncoder port map	(	rst 		=> rst,
														clk 		=> rClk,
														nrz_in 	=> nrz_in,
														manout	=> manout);


	-- Manchester Decoder
	ManDecoder: ManchDecoder port map   (	rst		=> rst,
														clk		=> rClk,
														manin		=> manin,
														nrz_out	=> nrz_out);

end Behavioral;