----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:	    
-- 
-- Create Date:    20:47:35 04/18/2011 
-- Design Name: 	 LLC PDU Generator
-- Module Name:    LLC_PDU_Gen - Behavioral 
-- Project Name:   Lab7
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LLC_PDU_Gen is
    Port ( rst : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           gen_PDU : in  STD_LOGIC;
           data_out : out  STD_LOGIC_VECTOR (7 downto 0);
           data_ready : out  STD_LOGIC;
           data_ack : in  STD_LOGIC;
           PDU_length : out  STD_LOGIC_VECTOR (7 downto 0));
end LLC_PDU_Gen;

	architecture Behavioral of LLC_PDU_Gen is

	component Data_Buffer 
		 Port ( data_in : in  STD_LOGIC_VECTOR (7 downto 0);
				  data_out : out  STD_LOGIC_VECTOR (7 downto 0);
				  addr_in : in  unsigned (4 downto 0);
				  write_clk : in  STD_LOGIC;
				  write_enable : in  STD_LOGIC);
	end component;

	-- data_buffer constants
	-- these constants set the size of the data buffer 
	-- (32 memory locations deep by 8 bits wide)
	constant DATA_SIZE : integer := 8;
	constant ADDR_SIZE : integer := 5;
	constant MAX_ADDR : std_logic_vector (ADDR_SIZE-1 downto 0) := (others => '1');
	-- data_buffer interface signals
	signal buffer_data_in : std_logic_vector (DATA_SIZE-1 downto 0) := (others => '0');
	signal buffer_data_out : std_logic_vector (DATA_SIZE-1 downto 0);
	signal buffer_addr : unsigned (ADDR_SIZE-1 downto 0) := (others => '0');
	signal PDU_length_reg : unsigned (DATA_SIZE-1 downto 0) := (others => '0');

	-- random bit generator constants and signals
	constant SEED : std_logic_vector (DATA_SIZE-1 downto 0) 
											:= (DATA_SIZE-1 => '1', 0 => '1' , others => '0');		
	constant P : std_logic_vector(DATA_SIZE-1 downto 0) := "10111000"; 
											-- Primitive Polynomial for 8-bits
	signal shift_reg : std_logic_vector (DATA_SIZE-1 downto 0) := (others => '0');

	-- Signals for State Machine used to control the Data Buffer
	-- declare state and next_state
	type state_type is (st1_idle, st2_rst_addr, st3_wait, st4_gen_wclk, st5_incr_addr, 
	st6_rst_addr, st7_wait, st8_data_ready, st9_wait, st10_incr_addr);
	
								--##### INSERT YOUR STATE NAMES HERE ####--
	signal state, next_state : state_type; 
	-- declare state machine outputs
	signal rst_addr  : std_logic;  -- reset address register 
	signal incr_addr  : std_logic;  -- increment address register
	signal load_data_reg  : std_logic;  -- load data register
	signal buffer_we  : std_logic;  -- buffer write enable
	signal buffer_wclk  : std_logic;  -- buffer write clock
	signal load_PDU_length  : std_logic;  -- load PDU length register
	signal buffer_out_ready : std_logic; 
 
begin

	-- 32 x 8 bit RAM data buffer
	LLC_Data_Buffer : Data_Buffer
		 Port map ( data_in => buffer_data_in ,
						data_out => buffer_data_out ,
						addr_in => buffer_addr ,
						write_clk => buffer_wclk ,
						write_enable => buffer_we );

	-- (shift_reg)
	-- random number generator using
	-- 	linear feedback shift register
	-- borrow code from RBG in Lab 5 and modify
	-- size of shift_reg is DATA_SIZE (use range SIZE-1 downto 0)
	-- shift_reg is initialized to the SEED value at reset

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	
	--Fibonacci LSFR
	process(clk) 
		variable lsb_in : std_logic := '0';
	begin
		if rising_edge(clk) then
			if rst = '1' then
				shift_reg <= seed;
			else
				lsb_in := '0';
				for I in DATA_SIZE-1 downto 0 loop 
					lsb_in := lsb_in xor (shift_reg(I) and P(I));
				end loop;
				
				for I in DATA_SIZE-1 downto 1 loop
					shift_reg(I) <= shift_reg(I-1);
				end loop;
				shift_reg(0) <= lsb_in;
			end if;
		end if;
	end process;	


	-- (buffer_data_in) 
	-- buffer input data register 
	-- samples the random bit generator shift register 
	--    to load random data into the data buffer

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then
			if load_data_reg ='1' then 
				buffer_data_in <= shift_reg;
			else
				buffer_data_in <= buffer_data_in;
			end if;
		end if;
	end process;

	-- (buffer_addr) 
	-- buffer address register 
	-- reset at beginning of writes to the buffer
	-- incremented after each write cycle

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then
			if rst_addr = '1' then 
				buffer_addr <= to_unsigned(0, buffer_addr'length);
			elsif incr_addr = '1' then
				buffer_addr<= buffer_addr + to_unsigned(1, buffer_addr'length);
			else 
				buffer_addr <= buffer_addr;
			end if;
		end if;
	end process;
				

	-- (PDU_length_reg)
	-- PDU length register
	-- load this register when control signal load_PDU_length = '1'
	-- this register is one byte long, but we are limiting the number 
	-- 	of bytes of data to be in the range of 1 to 32
	-- therefore, load from the random number shift_reg bits
	-- load random number from bit 0 up to  bit ADDR_SIZE-1
	-- use modulo 2**ADDR_SIZE of the 8-bit random value
	--   OR
	-- if random value is zero, load with a value of 32 
	-- 	-set bit ADDR_SIZE to '1'
	-- 	-set bits above bit ADDR_SIZE to '0'

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin 
		if rising_edge(clk) then 
			--PDU_length_reg(7 downto 6) <= "00";
			--if load_PDU_length = '1' then 
			--	PDU_length_reg(ADDR_SIZE-1 downto 0) <= unsigned(shift_reg(ADDR_SIZE-1 downto 0));
			--	if unsigned(shift_reg(ADDR_SIZE-1 downto 0)) = to_unsigned(0, ADDR_SIZE) then
			--		PDU_length_reg(ADDR_SIZE) <= '1';
			--	else 
			--		PDU_length_reg(ADDR_SIZE) <= '0';
			--	end if;
		--	end if;
	--	end if;
			if load_PDU_length = '1' then
				PDU_length_reg <= unsigned(shift_reg) mod to_unsigned(2**ADDR_SIZE, DATA_SIZE) + 1;
			end if;
		end if;
		
	end process;

	-- Data Buffer Controller FSM

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then
			if rst = '1' then
				state <= st1_idle;
			else
				state <= next_state;
			end if;
		end if;
	end process;
	
	process(state, gen_pdu, data_ack, buffer_addr, PDU_length_reg) begin
		buffer_we <= '0';
		buffer_out_ready <= '0';
		incr_addr <= '0';
		load_data_reg <= '0';
		buffer_wclk <= '0';
		load_pdu_length <= '0';
		rst_addr <= '0';
		case state is 
			when st1_idle =>
				if gen_pdu = '1' then
					next_state <= st2_rst_addr;
				else
					next_state <= st1_idle;
				end if;
			
			when st2_rst_addr => 
				rst_addr <= '1';
				load_PDU_length <= '1';
				load_data_reg <= '1';
				buffer_we <= '1';
				next_state <= st3_wait;
				
			when st3_wait =>
				buffer_we <= '1';
				next_state <= st4_gen_wclk;
			
			when st4_gen_wclk => 
				buffer_we <= '1';
				buffer_wclk <= '1';
				if buffer_addr /= PDU_length_reg -1	then
					next_state <= st5_incr_addr;
				else
					next_state <= st6_rst_addr;
				end if;

			when st5_incr_addr =>
				incr_addr <= '1';
				load_data_reg <= '1';
				buffer_we <= '1';
				next_state <= st3_wait;
			
			when st6_rst_addr =>
				rst_addr <= '1';
				buffer_we <= '0';
				next_state <= st7_wait;
			
			when st7_wait =>
				next_state <= st8_data_ready;
			
			when st8_data_ready=>
				buffer_out_ready <= '1';
				if data_ack = '0' then
					next_state <= st8_data_ready;
				else
					next_state <= st9_wait;
				end if;
				
			when st9_wait=>
				if (buffer_addr /= PDU_length_reg -1) AND (data_ack = '0') then
					next_state <= st10_incr_addr;
				elsif data_ack = '1' then
					next_state <= st9_wait;
				elsif (buffer_addr = PDU_length_reg -1) AND (data_ack = '0') then
					next_state <= st1_idle;
				else 
					next_state <= st9_wait;
				end if;
			
			when st10_incr_addr =>
				incr_addr <= '1';
				next_state <= st7_wait;
		end case;
	end process;	
		
				
	

	-- Outputs generated from internal signals
	process (PDU_length_reg, buffer_data_out, buffer_out_ready)
	begin
		PDU_length <= std_logic_vector(PDU_length_reg);
		data_out <= buffer_data_out;
		data_ready <= buffer_out_ready;
	end process;

end Behavioral;
