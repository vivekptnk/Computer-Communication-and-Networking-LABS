----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:		 
-- 
-- Create Date:    13:14:57 04/27/2011 
-- Design Name: 	 Ethernet MAC Protocol
-- Module Name:    MAC_Frame_Dec - Behavioral 
-- Project:			 Lab7
-- Description: 
-- Revision: 
-- Revision 0.01 - File Created
-- Revision 1.00 - April 17, 2014
--                 Corrected ordering of received bits to begin with bit 0.
--                 Defined "reverse" function to reverse ordering of bits when
--						 read from shift register.
--						 CRC_frame_in was beginning too late and clipping off the first 
--						 bit of the frame going into the CRC.  Used data_sr /= SFD as  
--                 input to FSM to move up timing of CRC_frame_in.
-- Revision 1.01 - April 5, 2018
--						 Restructured the FSM and added more comments
--						 Replaced unused signals for dclk, data, and frame outputs of
--  					 the CRC module with "open"
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;



entity MAC_Frame_Dec is
    Port ( clk : in  STD_LOGIC;
           rst : in  STD_LOGIC;
           dclk_in : in  STD_LOGIC;
           data_in : in  STD_LOGIC;
           frame_in : in  STD_LOGIC;
           MAC_addr_in : in  STD_LOGIC_VECTOR (7 downto 0);
           dclk_out : out  STD_LOGIC;
           data_out : out  STD_LOGIC_VECTOR (7 downto 0);
           dest_addr_out : out  STD_LOGIC_VECTOR (7 downto 0);
			  CRC_error_out : out STD_LOGIC);
end MAC_Frame_Dec;

architecture Behavioral of MAC_Frame_Dec is

	component CRC 
		 Generic ( fcs_length : integer ); 
		 Port ( P : std_logic_vector (fcs_length downto 0);
				  data_in : in  STD_LOGIC;
				  dclk_in : in  STD_LOGIC;
				  frame_in : in  STD_LOGIC;
				  data_out : out  STD_LOGIC;
				  dclk_out : out  STD_LOGIC;
				  frame_out : out  STD_LOGIC;
				  error_out : out  STD_LOGIC;
				  mode : in  STD_LOGIC;
				  clk : in  STD_LOGIC;
				  rst : in  STD_LOGIC);
	end component;

	-- define value of start of frame delimiter
	constant SFD : std_logic_vector (7 downto 0) := "10101011";
	-- define maximum shift count for input data shift register bit counter
	constant SHIFT_MAX : unsigned (2 downto 0) := "110";
	-- define length of frame check sequence to be added to end of data 
	--	being transmitted
	constant FCS_LENGTH : integer := 8;
	-- define the predetermined divisor for the CRC 
	constant P : std_logic_vector (FCS_LENGTH downto 0) := "100011101";

	signal dclk_in_d1 : std_logic; 
													-- dclk_in delayed one clock cycle
	signal dclk_rise : std_logic; 
													-- rising edge detect for dclk_in
	signal data_sr : std_logic_vector(7 downto 0); 
													-- shift register for input data
	signal shift_count : unsigned(2 downto 0); 
													-- shift counter for input data shift register
	signal byte_count : unsigned(5 downto 0); 
													-- byte counter for oounting multi-byte fields
	signal dest_addr_reg : std_logic_vector(7 downto 0); 
													-- register for destination address
	signal source_addr_reg : std_logic_vector(7 downto 0); 
													-- register for source address
	signal PDU_length_reg : unsigned(7 downto 0) := (others => '0'); 
													-- register for LLC PDU data length
	signal PDU_data_reg : std_logic_vector(7 downto 0) := (others => '0'); 
													-- register for LLC PDU data
	signal CRC_dclk_in : std_logic; 
	signal CRC_error : std_logic; 
	signal CRC_error_d1 : std_logic; 
	signal CRC_error_reg : std_logic;

	-- Declare signals for state machine
	type state_type is (st1_idle, st2_wait_SFD, st3_shift_dest_addr, 
								st4_load_dest_addr, st5_shift_source_addr, 
								st6_load_source_addr, st7_shift_length, st8_load_length,
								st9_shift_data, st10_load_data, st11_shift_CRC, 
								st12_terminate); 
	signal state, next_state : state_type; 

	-- Declare state machine output signals
	signal en_shift_ctr : std_logic; -- enable shift register shift counter
	signal en_byte_ctr : std_logic; -- enable byte counter
	signal load_dest_addr : std_logic;  -- load the destination address register
	signal load_source_addr : std_logic; -- load the source address register
	signal load_PDU_length : std_logic; -- load the LLC PDU data length register
	signal load_PDU_data : std_logic; -- load the LLC PDU data
	signal ignore_error : std_logic; -- ignore error if frame was terminated
	signal CRC_frame_in : std_logic; -- frame input signal for the CRC

begin

	-- CRC error detection
	CRC_Error_Det : CRC 
		 Generic map ( FCS_LENGTH )
		 Port map ( 
				  P => P,	
				  data_in => data_in,
				  dclk_in => CRC_dclk_in,
				  frame_in => CRC_frame_in,
				  data_out => open, 
				  dclk_out => open, 
				  frame_out => open, 
				  error_out => CRC_error,
				  mode => '0',
				  clk => clk,
				  rst => rst);

	-- data_clk_in for CRC_Error_Det
	CRC_dclk_in <= dclk_rise;

	-- generate delayed CRC_error
	process (clk)
	begin
		if rising_edge(clk) then
			CRC_error_d1 <= CRC_error;
		end if;
	end process;
	
	-- (CRC_error_reg)
	-- CRC_error_reg captures error detected by the CRC
	process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				CRC_error_reg <= '0';
			elsif CRC_frame_in = '0' 
				and  (CRC_error = '1' and CRC_error_d1 = '0') -- rising edge of CRC_error 
				and ignore_error = '0' then
				CRC_error_reg <= '1';
			elsif CRC_frame_in = '1' then
				CRC_error_reg <= '0';
			else
				CRC_error_reg <= CRC_error_reg;
			end if;	
		end if;
	end process;
	
	-- (dclk_rise)
	-- rising edge detect of dclk_in
	process (clk)
	begin
		if rising_edge(clk) then
			dclk_in_d1 <= dclk_in;
			dclk_rise <= dclk_in and not dclk_in_d1;
		end if;
	end process;
	
	-- (data_sr)
	-- input data shift register
	-- shift data_in into data_sr with dclk_rise

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin 
		if rising_edge(clk) then
			if dclk_rise = '1' then
				--for I in 7 downto 1 loop 
					--data_sr(I) <= data_sr(I-1);
				--end loop;
				data_sr <= data_in & data_sr(7 downto 1);
				--data_sr <= data_sr(6 downto 0) & data_in ;
			end if;
		end if;
	end process;

	-- (shift_count)
	-- shift counter for MAC packet shift register 
	-- when en_shift_ctr is low, zero counter
	--	when enabled, increment with dclk_rise

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then
			if en_shift_ctr = '0' then
				shift_count <= to_unsigned(0, shift_count'length);
			elsif dclk_rise = '1' then
				shift_count <= shift_count + to_unsigned(1, shift_count'length);
			end if;
		end if;
	end process;

	-- (byte_count)
	-- byte counter for counting multi-byte fields 
	-- when en_byte_ctr is low, zero counter
	-- increment with dclk_rise when shift register has finished 
	--		shifting in each byte of data

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then
			if en_byte_ctr = '0' then
				byte_count <= (others => '0');
			elsif dclk_rise = '1' and shift_count = to_unsigned(6, shift_count'length) then
				byte_count <= byte_count + to_unsigned(1, byte_count'length);
			end if;
		end if;
	end process;

	-- (dest_addr_reg)
	-- destination address register
	-- reset clears the register
	-- loads when destination address is received
	-- LSB should be on the right

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin 	
		if rising_edge(clk) then
			if rst = '1' then
				dest_addr_reg <= (others=>'0');
			elsif load_dest_addr = '1' then
				dest_addr_reg <= (data_sr);
			else 
				dest_addr_reg <= dest_addr_reg;
			end if;
		end if;
	end process;

	-- (source_addr_reg)
	-- source address register
	-- reset clears the register
	-- loads when source address is received
	-- LSB should be on the right

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin 	
		if rising_edge(clk) then
			if rst = '1' then
				source_addr_reg <= (others=>'0');
			elsif load_source_addr = '1' then
				source_addr_reg <=(data_sr);
			else 
				source_addr_reg <= source_addr_reg;
			end if;
		end if;
	end process;

	-- (PDU_length_reg)
	-- PDU length register
	-- loads when PDU length is received
	-- LSB should be on the right

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin 	
		if rising_edge(clk) then
			if rst = '1' then
				PDU_length_reg <= (others=>'0');
			elsif load_PDU_length = '1' then
				PDU_length_reg <= unsigned(data_sr);
			else
				PDU_length_reg <= PDU_length_reg;
			end if;
		end if;
	end process;

	-- (PDU_data_reg)
	-- PDU data register
	-- loads each time a byte of the PDU data field is received
	-- LSB should be on the right

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin 	
		if rising_edge(clk) then
			if rst = '1' then
				PDU_data_reg <= (others=>'0');
			elsif load_PDU_data = '1' then
				PDU_data_reg <=(data_sr);
			end if;
		end if;
	end process;
	  
	-- (data_out)
	-- output the received LLC data
	data_out <= PDU_data_reg;

	-- (dclk_out)
	-- dclk_out is generated when the PDU_data_reg is loaded
	-- need one register delay for dclk_out
	-- 	to match delay of PDU data through its register
	process (clk)
	begin
		if rising_edge(clk) then
			dclk_out <= load_PDU_data;
		end if;
	end process;
	
	-- (dest_addr_out)
	dest_addr_out <= dest_addr_reg;
	-- (CRC_error_out)
	CRC_error_out <= CRC_error_reg;
		
	-- MAC Frame Decoder Controller FSM

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin 
		if rising_edge(clk) then
			if rst='1' then
				state <= st1_idle;
			else
				state <= next_state;
			end if;
		end if;
	end process;
	
	
	process(state, frame_in, data_in, mac_addr_in, dest_addr_reg, dclk_rise, pdu_length_reg, data_sr, shift_count, byte_count) begin
		en_shift_ctr <= '0';
		en_byte_ctr <= '0';
		load_dest_addr  <= '0';
		load_source_addr  <= '0';
		load_PDU_length <= '0';
		load_PDU_data <= '0';
		CRC_frame_in <= '0';
		ignore_error <= '0';
		next_state <= state;
		case state is 
			when st1_idle => 
				if frame_in = '1'  then
					next_state <= st2_wait_SFD;
				else
					next_state <= st1_idle;
				end if;
			
			when st2_wait_SFD =>
				--en_shift_ctr <= '1';
				--en_byte_ctr <= '1';
				if data_sr(7)='1' and data_sr(6) = '1' and dclk_rise  = '1' then
					next_state <= st3_shift_dest_addr;
				else
					next_state <= st2_wait_SFD;
				end if;
			
			when st3_shift_dest_addr => 
				en_shift_ctr <= '1';
				CRC_frame_in <= '1';
				if shift_count = to_unsigned(6, shift_count'length) and dclk_rise = '1' then
					next_state <= st4_load_dest_addr;
				else 
					next_state <= st3_shift_dest_addr;
				end if;
			
			when st4_load_dest_addr =>
				en_shift_ctr <= '1';
				load_dest_addr <= '1';
				CRC_frame_in <= '1';
				next_state <= st5_shift_source_addr;
			
			when st5_shift_source_addr =>
				en_shift_ctr <= '1';
				CRC_frame_in <= '1';
				if dest_addr_reg /= MAC_addr_in then
					next_state <= st12_terminate;
				elsif shift_count = to_unsigned(6, shift_count'length) and dclk_rise = '1' then
					next_state <= st6_load_source_addr;
				else
					next_state <= st5_shift_source_addr;
				end if;
			
			when st6_load_source_addr=>
				en_shift_ctr <= '1';
				load_source_addr <= '1';
				CRC_frame_in <= '1';
				next_state <= st7_shift_length;

			when st7_shift_length=>
				en_shift_ctr <= '1';
				CRC_frame_in <= '1';
				if shift_count = to_unsigned(6, shift_count'length) and dclk_rise = '1' then
					next_state <= st8_load_length;
				else
					next_state <= st7_shift_length;
				end if;
			
			when st8_load_length=>
				en_shift_ctr <= '1';
				load_PDU_length <= '1';
				CRC_frame_in <= '1';
				next_state <= st9_shift_data;
			
			when st9_shift_data=>
				en_shift_ctr <= '1';
				en_byte_ctr <= '1';
				CRC_frame_in <= '1';
				--if byte_count > to_unsigned(0, byte_count'length) or shift_count > to_unsigned(6, 3) then	
				--	CRC_frame_in <= '1';
				--else
				--	CRC_frame_in <= '0';
				--end if;
				
				--if PDU_length_reg = to_unsigned(0, PDU_length_reg'length) and dclk_rise = '1' then
				--	next_state <= st12_terminate;
				if shift_count = to_unsigned(6, shift_count'length) and dclk_rise = '1' then
					next_state <= st10_load_data;
				else
					next_state <= st9_shift_data;
				end if;
			
			when st10_load_data=>
				en_shift_ctr <= '1';
				en_byte_ctr <= '1';
				CRC_frame_in <= '1';
				load_PDU_data <= '1';
				if byte_count = unsigned(PDU_length_reg(5 downto 0))then
					next_state <= st11_shift_CRC;
				else
					next_state <= st9_shift_data;
				end if;
			
			when st11_shift_crc=>
				en_shift_ctr <= '1';
				CRC_frame_in <= '1';
				if shift_count = to_unsigned(6, shift_count'length) and dclk_rise = '1' then
					next_state <= st1_idle;
				else
					next_state <= st11_shift_crc;
				end if;
			
			when st12_terminate=>
				ignore_error <= '1';
				en_shift_ctr <= '1';
				if frame_in = '0' then	
					next_state <= st1_idle;
				else
					next_state <= st12_terminate;
				end if;
			
			when others =>
				next_state <= st1_idle;
				
		end case;
	end process;

end Behavioral;