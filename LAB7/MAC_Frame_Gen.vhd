----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:	    
-- 
-- Create Date:    20:40:33 04/18/2011 
-- Design Name:    Ethernet MAC Frame Generator
-- Module Name:    MAC_Frame_Gen - Behavioral 
-- Project Name:   Lab7
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Revision 1.00 - April 17, 2014
--                 Corrected ordering of transmitted bits to begin with bit 0
--                 for all fields except preamble and SFD
--                 Defined "reverse" function to reverse ordering of bits when
--						 loaded into shift register
-- Revision 1.01 - April 13, 2016
--						 Added option to generate load_packet_sr signal in the FSM
--						 instead of a separate process.
-- Revision 1.02 - April 18, 2016
--						 Corrected Mealy output load_packet_sr to be always generated
--						 by dclk_rise and not dclk_fall.
--						 Declared a new signal for the FSM output called 
--						 load_packet_sr_FSM.
--						 Declared a constant, SEL_load_packet_sr, to select which
--						 method to use to generate the load_packet_sr signal.
-- Revision 1.03 - April 5, 2018
--						 Restructured the FSM and added more comments. Removed code to
--						 output load_packet_sr_FSM in the st8_send_FCS state since
--                 the FCS comes from the CRC, not the MAC_packet_sr shift 
--						 register
--					  - May 6, 2018
--						 Added clarifications to comments
-- Revision 1.04 - April 13, 2019
--               - Changed shift direction of MAC_packet_sr and eliminated the 
--						 need for the "reverse" function
-- Additional Comments: 
--
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity MAC_Frame_Gen is
    Port ( rst : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           data_in : in  STD_LOGIC_VECTOR (7 downto 0);
           data_ready : in  STD_LOGIC;
           data_ack : out  STD_LOGIC := '0';
           PDU_length : in  STD_LOGIC_VECTOR (7 downto 0);
           source_addr : in  STD_LOGIC_VECTOR (7 downto 0);
           dest_addr : in  STD_LOGIC_VECTOR (7 downto 0);
           dclk_out : out  STD_LOGIC := '0';
           data_out : out  STD_LOGIC := '0';
           frame_out : out  STD_LOGIC := '0');
end MAC_Frame_Gen;

architecture Behavioral of MAC_Frame_Gen is

	component CRC 
		 generic ( fcs_length : integer ); 
		 port ( P : std_logic_vector (fcs_length downto 0);
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

	-- PREAMBLE and SFD data patterns in reverse order since LSB is sent first
	constant PREAMBLE : std_logic_vector (7 downto 0) := "01010101";
	constant SFD : std_logic_vector (7 downto 0) := "11010101";
	constant PREAMBLE_SIZE : integer := 7; -- Number of bytes in preamble
	constant SHIFT_MAX : integer := 7; -- Maximum shift count
	
	-- define length of frame check sequence 
	--		to be added to end of data being transmitted
	constant fcs_length : integer := 8;
	-- define the predetermined divisor for the CRC 
	constant P : std_logic_vector (fcs_length downto 0) := "100011101";

	-- counter to generate timing for MAC frame generation
	signal clkdiv : unsigned (4 downto 0) := "00000";
	signal clkdiv4_d1 : std_logic; -- clkdiv bit 4 delayed one system clock cycle
	signal clkdiv4_d2 : std_logic; -- clkdiv bit 4 delayed two system clock cycles
	signal clkdiv4_d3 : std_logic; -- clkdiv bit 4 delayed three system clock cycles
	
	signal dclk_rise : std_logic;  -- rising edge of the data clock
	signal dclk_rise_d1 : std_logic; -- dclk_rise delayed one system clock cycle
	signal dclk_fall : std_logic;  -- falling edge of the data clock
	
	signal MAC_packet_sr : std_logic_vector(7 downto 0) := (others => '0'); 
											 -- MAC packet shift register
	signal packet_sr_data : std_logic_vector(7 downto 0); 
											 -- MAC packet shift register input data
	signal shift_count : unsigned(2 downto 0) := (others => '0'); 
											 -- shift counter for MAC packet shift register
	signal byte_count : unsigned(5 downto 0) := (others => '0'); 
											 -- byte counter for oounting multi-byte fields
													
	signal data_ack_i : std_logic; -- internal data acknowledge
	signal load_packet_sr : std_logic; -- load data into the MAC packet shift register
	
	signal CRC_data_in : std_logic;    -- CRC input data
	signal CRC_data_in_d1 : std_logic; -- CRC_data_in delayed one system clock cycle
	signal CRC_data_in_d2 : std_logic; -- CRC_data_in delayed two system clock cycles
	signal CRC_frame_in : std_logic;   -- frame for CRC excludes preamble and SFD
	signal CRC_dclk_in : std_logic; 	  -- CRC input dclk
	signal CRC_data_out : std_logic;   -- CRC output data
	signal CRC_dclk_out : std_logic;   -- CRC output dclk
	signal CRC_frame_out : std_logic;  -- CRC output frame
	
	signal frame_out_i_d1 : std_logic; -- frame_out_i delayed 1 system clock cycle
	signal frame_out_i_d2 : std_logic; -- frame_out_i delayed 2 system clock cycles
	signal frame_out_i_d3 : std_logic; -- frame_out_i delayed 3 system clock cycles

	-- Declare signal for FSM state register
	type state_type is (st1_idle, st2_send_preamble, st3_send_SFD, 
								st4_send_dest_addr, st5_send_source_addr, st6_send_length, 
								st7_send_PDU_data, st8_send_FCS); 
	signal state, next_state : state_type; 
	
	-- Declare state machine output signals
	signal en_shift_ctr : std_logic; -- enable shift register shift counter
	signal en_byte_ctr : std_logic; -- enable byte counter
	signal frame_out_i : std_logic; -- frame output internal signal
	--signal sel_preamble : std_logic;  -- select preamble
	--signal sel_SFD : std_logic;  -- select SFD
	--signal sel_dest_addr : std_logic;  -- select destination address
	--signal sel_source_addr : std_logic;  -- select source address
	--signal sel_length : std_logic;  -- select length
	--signal sel_PDU_data : std_logic;  -- select PDU data
	signal enable_CRC : std_logic; -- frame for CRC excludes preamble and SFD
	signal load_packet_sr_FSM : std_logic; -- USE ONLY IF signal is generated by FSM

begin

	-- Instantiated CRC module used to generate the FCS for the generated frame
	FCS_Gen : CRC 
		 Generic map ( fcs_length )
		 Port map ( 
				  P => P,	
				  data_in => CRC_data_in,
				  dclk_in => CRC_dclk_in,
				  frame_in => CRC_frame_in,
				  data_out => CRC_data_out,
				  dclk_out => CRC_dclk_out,
				  frame_out => CRC_frame_out,
				  error_out => open, 
				  mode => '1',
				  clk => clk,
				  rst => rst);
	
	-- (clkdiv)
	-- Clock divider counter used to set the MAC packet data rate
	-- the rate of dclk will be that of bit four of clkdiv
	process (clk)
	begin
		if rising_edge(clk) then
			clkdiv <= clkdiv + 1;
		end if;
	end process;

	-- generate delayed versions of clkdiv:
	-- 								clkdiv4_d1, clkdiv4_d2, clkdiv4_d3
	process (clk)
	begin
		if rising_edge(clk) then
			clkdiv4_d1 <= clkdiv(4);
			clkdiv4_d2 <= clkdiv4_d1;
			clkdiv4_d3 <= clkdiv4_d2;
		end if;
	end process;
	
	-- generate dclk_rise, dclk_rise_d1
	process (clk)
	begin
		if rising_edge(clk) then
			dclk_rise <= clkdiv(4) and (not clkdiv4_d1);
			dclk_rise_d1 <= dclk_rise;
		end if;
	end process;
	
	-- generate dclk_fall
	process (clk)
	begin
		if rising_edge(clk) then
			dclk_fall <= (not clkdiv(4)) and clkdiv4_d1;
		end if;
	end process;
	
	-- (packet_sr_data)
	-- MUX that selects parallel input data for MAC packet shift register

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	with state select
		packet_sr_data <= (sfd) when st3_send_SFD,
								(dest_addr) when st4_send_dest_addr,
								(source_addr) when st5_send_source_addr,
								(PDU_length) when st6_send_length,
								(data_in) when st7_send_PDU_data,
								(preamble) when others;
								
								

	-- (load_packet_sr)
	-- process to generate the load signal for packet shift register
	-- this signal loads the MAC_packet_sr shift register
	--		with each byte of data (selected by the above MUX) before it is 
	--		shifted out at the rate set by dclk
	-- load_packet_sr must occur exactly when the signal which shifts the
	--    MAC_packet_sr shift register occurs.  This is because we want to
	--    load the shift register with a byte of data and then start
	--    shifting exactly one dclk cycle later.  This will make all of the
	--    eight data bits have exactly the same period.
	-- It is loaded for the first time right before the frame is started
	--		(frame_out_i = '0') and data from the LLC layer is ready.  
	-- After the first time, the load_packet_sr is loaded every time
	-- 	the shift counter reaches the count of 7
	--	Synchronize load_packet_sr with with dclk_rise.
	-- ALTERNATIVELY, this signal can be generated in the FSM
	-- 	as a Mealy output (use a different name).  
	-- 	But, need to synchronize it to clk here.

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then
			if (shift_count = to_unsigned(0,3) or (frame_out_i = '0' and data_ready = '1')) and dclk_rise = '1' then
				load_packet_sr <= '1';
			else
				load_packet_sr <= '0';
			end if;
		end if;
	end process;
	
	-- (MAC_packet_sr)
	-- MAC packet shift register
	-- This register shifts out a byte of data after the data is loaded
	-- A byte of data is first parallel loaded into the register
	-- Then the data is shifted out on the rise of dclk 
	--		(use dclk rise delayed 1 clock cycle)

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin 
		if rising_edge(clk) then
			if load_packet_sr = '1' then
				MAC_packet_sr <= packet_sr_data;
			elsif dclk_rise_d1 = '1' then 
				if frame_out_i = '1' then 
					MAC_packet_sr <= '0' & MAC_packet_sr (7 downto 1);
					--for i in MAC_packet_sr'length-1 downto 1 loop 
						--MAC_packet_sr(i) <= MAC_packet_sr(i-1);
					--end loop;
					--MAC_packet_sr(0) <= '0';
				end if;
			end if;
		end if;
	end process;
	
	-- (CRC_data_in)
	-- CRC data input is connected to the output of the MAC_packet_sr

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	CRC_data_in <= MAC_packet_sr(0);

	-- (shift_count)
	-- Shift counter for MAC packet shift register 
	-- Resets to zero when not enabled
	-- Increments on the rise of dclk
	-- 3-bit counter rolls over to zero after counting up to seven

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then
			if en_shift_ctr = '0' then
				shift_count <= to_unsigned(0, shift_count'length);
			elsif dclk_rise_d1 = '1' then
				shift_count <= shift_count + to_unsigned(1, shift_count'length);
			end if;
		end if;
	end process;

	-- (byte_count)
	-- Byte counter for counting multi-byte fields
	-- Resets to zero when not enabled
	-- Incremented when byte of data is finished shifting 
	--		out of the MAC_packet_sr.  This can be determined with
	--    the shift counter and dclk.

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then
			if en_byte_ctr = '0' then
				byte_count <= to_unsigned(0, byte_count'length);
			elsif shift_count = to_unsigned(0, 3) and dclk_rise_d1 = '1' then	
				byte_count <= byte_count + to_unsigned(1, byte_count'length);
			end if;
		end if;
	end process;

	-- (data_ack_i)
	-- PDU data handshake logic
	-- when data_ready is high and the MAC_packet_sr is loaded with
	--		a byte for the data field of the MAC frame, the data_ack_i is
	--		activated and held high until the data_ready goes low.

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then
			if data_ready = '1' and load_packet_sr = '1' and (state=st6_send_length or state=st7_send_PDU_data) then
				data_ack_i <= '1';
			else
				data_ack_i <= '0';
			end if;
		end if;
	end process;

	-- (CRC_frame_in)
	-- Create CRC_frame_in by syncing enable_CRC with dclk_rise_d1
	-- The signal becomes active when enable_CRC is active and 
	--    dclk_rise_d1 is active and goes inactive when enable_CRC
	--    is inactive and dclk_rise_d1 is active. For other conditions
	--    it holds its current value.

	--###########################################################--
	--#####             INSERT YOUR CODE HERE               #####--
	--###########################################################--
	process(clk) begin
		if rising_edge(clk) then
			if dclk_rise_d1 = '1' then
				CRC_frame_in <= enable_CRC;
			end if;
		end if;
	end process;
	
	-- create delayed frame_out_i and CRC_data_in signals
	process (clk)
	begin
	if rising_edge(clk) then
		frame_out_i_d1 <= frame_out_i;
		frame_out_i_d2 <= frame_out_i_d1;
		frame_out_i_d3 <= frame_out_i_d2;
		CRC_data_in_d1 <= CRC_data_in;
		CRC_data_in_d2 <= CRC_data_in_d1;
	end if;
	end process;
	
	-- (data_out)
	-- Output the complete MAC frame serial data
	-- Uses CRC_data_in delayed to match the delay of the CRC as the
	-- 	source of the preamble and SFD fields.
	--	Then, uses CRC_data_out for the remaining fields of the frame.
	-- Synchronized to clk
	process (clk)
	begin
		if rising_edge(clk) then
			data_out <= (CRC_data_in_d2 and 
								not CRC_frame_out and frame_out_i_d3) 
														or 
									(CRC_frame_out and CRC_data_out);
		end if;
	end process;
	
	-- (dclk_out)
	-- Output the MAC frame data clock 
	-- Uses the CRC_dclk_out
	-- Uses frame_out_i_d3 with CRC_frame_out to hold the dclk_out at zero
	--		outside of the frame.
	-- Synchronized to clk 
	process (clk)
	begin
		if rising_edge(clk) then
			dclk_out <= CRC_dclk_out and (CRC_frame_out or frame_out_i_d3);
		end if;
	end process;
	
	-- (frame_out)
	-- Output the MAC frame signal
	-- Uses frame_out_i_d3 with CRC_frame_out to generate frame_out for 
	--		the entire frame
	-- combine frame signals using logic to frame the
	--   entire MAC frame, and use delays to align frame_out with
	--   data_out and dclk_out signals.
	-- Synchronized to clk 
	process (clk) begin
		if rising_edge(clk) then
			frame_out <= CRC_frame_out or frame_out_i_d3;  
		end if;
	end process;
	
	-- (CRC_dclk_in)
	-- generate input clock for CRC
	-- CRC_dclk_in is the clkdiv4_d3 signal inverted
	CRC_dclk_in <= not clkdiv4_d3;
	
	--(data_ack)
	-- output data acknowledge
	data_ack <= data_ack_i;

   -- MAC Frame Generator Controller FSM

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
	
	process(state, dclk_rise, dclk_fall, data_ready, byte_count, shift_count, pdu_length) begin
		frame_out_i <= '1';
		enable_crc <= '0';
		en_shift_ctr <= '0';
		en_byte_ctr <= '0';
		case state is
			when st1_idle=>
				frame_out_i <= '0';
				if data_ready = '1' and dclk_rise = '1' then
					next_state <= st2_send_preamble;
				else
					next_state <= st1_idle;
				end if;
			
			when st2_send_preamble=>
				en_shift_ctr <= '1';
				en_byte_ctr <= '1';
				if byte_count = to_unsigned(7, byte_count'length) and shift_count = to_unsigned(0, 3) and dclk_fall = '1' then
					next_state <= st3_send_SFD;
				else
					next_state <= st2_send_preamble;
				end if;
				
			when st3_send_SFD=>
				en_shift_ctr <= '1';
				if shift_count = to_unsigned(0, 3) and dclk_fall = '1' then
					next_state <= st4_send_dest_addr;
				else
					next_state <= st3_send_SFD;
				end if;
			
			when st4_send_dest_addr=>
				en_shift_ctr <= '1';
				enable_crc <= '1';
				if shift_count = to_unsigned(0, 3) and dclk_fall = '1' then
					next_state <= st5_send_source_addr;
				else
					next_state <= st4_send_dest_addr;
				end if;
				
			when st5_send_source_addr=>
				en_shift_ctr <= '1';
				enable_crc <= '1';
				if shift_count = to_unsigned(0,3) and dclk_fall = '1' then
					next_state <= st6_send_length;
				else
					next_state <= st5_send_source_addr;
				end if;
				
			when st6_send_length=>
				en_shift_ctr <= '1';
				enable_crc <= '1';
				if shift_count = to_unsigned(0, 3) and dclk_fall = '1' then
					next_state <= st7_send_PDU_data;
				else
					next_state <= st6_send_length;
				end if;
			
			when st7_send_PDU_data=>
				en_shift_ctr <= '1';
				en_byte_ctr <= '1';
				enable_crc <= '1';
				if byte_count = unsigned(PDU_length) and shift_count = to_unsigned(0, 3) and dclk_fall = '1' then
					next_state <= st8_send_FCS;
				else
					next_state <= st7_send_PDU_data;
				end if;
			
			when st8_send_FCS=>
				en_shift_ctr <= '1';
				en_byte_ctr <= '0';
				frame_out_i <= '0';
				if shift_count = to_unsigned(0, 3) and dclk_fall = '1' then
					next_state <= st1_idle;
				else
					next_state <= st8_send_FCS;
				end if;
		end case;
	end process;

end Behavioral;