----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer: 		 Carl Betcher
-- 
-- Create Date:    15:11:59 03/09/2011 
-- Design Name: 	 CRC Error Detection Demo	
-- Module Name:    Error_Detect_Demo - Behavioral 
-- Project Name:   Lab6
-- Target Devices: 
-- Description: 
--
-- Revision 0.01 - File Created
--          0.02 - April 2014 - When "stop" button input is received, wait for 
--						 current frame to complete before stopping
--				0.03 - 2018-03-16 - Revised to use with Papilio Duo FPGA Board
--										  with LogicStart Shield
--				0.04 - 2018-03-22 - Fix connections for Hex_Disp0,1,2,3 to work
--										  properly with HEXon7segDisp that was modified
--										  for use with Papilio Duo with LogicStart Shield	
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Error_Detect_Demo is
	Generic (debounceDELAY : integer := 640000; -- debounceDELAY = 20 mS / clk_period);
				frame_error_rate : std_logic_vector (3 downto 0) := "0100" ); 
				-- Frame error rate is given by (0.67108864 x 2**value) error frames 
				-- 	per second	
				--	frame_error_rate := "1111" for simuation (max error rate)
				-- frame_error_rate := "0100"; -- Use for operation with FPGA board
	Port  ( 	clk : in  STD_LOGIC := '0';
				DIR_LEFT : in  STD_LOGIC := '0';
				DIR_RIGHT : in  STD_LOGIC := '0';
				DIR_UP : in  STD_LOGIC := '0';
				DIR_DOWN : in  STD_LOGIC := '0';
				SW : in  STD_LOGIC_VECTOR (7 downto 0) := "00000000";
				LED : out  STD_LOGIC_VECTOR (7 downto 0);
				Seg7_SEG : out  STD_LOGIC_VECTOR (6 downto 0);
				Seg7_AN: out  STD_LOGIC_VECTOR (4 downto 0);
				Seg7_DP : out  STD_LOGIC;
				testsig_data : OUT  std_logic; 				-- data without errors
				testsig_error_frame : OUT  std_logic;		-- generate frame error
				testsig_data_with_errors : OUT  std_logic;	-- data with errors injected
				testsig_error_detect : OUT  std_logic;		-- error detection error output
				testsig_bit_errors : OUT std_logic			-- signal showing position 
				);														-- 	of error bits
end Error_Detect_Demo;

architecture Behavioral of Error_Detect_Demo is

	component HEXon7segDisp 
		 Port ( hex_data_in0 : in  STD_LOGIC_VECTOR (3 downto 0);
				  hex_data_in1 : in  STD_LOGIC_VECTOR (3 downto 0);
				  hex_data_in2 : in  STD_LOGIC_VECTOR (3 downto 0);
				  hex_data_in3 : in  STD_LOGIC_VECTOR (3 downto 0);
				  dp_in : in  STD_LOGIC_VECTOR (2 downto 0);
				  seg_out : out  STD_LOGIC_VECTOR (6 downto 0);
				  an_out : out  STD_LOGIC_VECTOR (3 downto 0);
				  dp_out : out  STD_LOGIC;
				  clk : in  STD_LOGIC);
	end component;
	
	component debounce 
		 Generic ( DELAY : integer := 640000); -- DELAY = 20 mS / clk_period		
		 Port ( 	sig_in 	: in  	std_logic;
					clk 		: in  	std_logic;
					sig_out 	: out  	std_logic);
	end component;

	component RandBitGen 
		 Generic (size : integer := 4						-- length of LFSR
					 );
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

	component Control_Logic is
	 Generic ( tx_frame_length : integer; 
				  tx_frame_period : integer;
				  dclk_half_period : integer);		
		 Port ( Start : in  STD_LOGIC;
				  Stop : in  STD_LOGIC;
				  tx_frame_out : out  STD_LOGIC;
				  dclk_out : out  STD_LOGIC;
				  clk : in  STD_LOGIC;
				  rst : in  STD_LOGIC);
	end component;

	component Frame_Error_Gen is
		Generic ( frame_length : integer );			
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
				  pass_thru_data : out STD_LOGIC;
				  clk : in  STD_LOGIC;
				  rst : in  STD_LOGIC);
	end component;

	component Output_Port is
		 Port ( sig_in : in  STD_LOGIC_VECTOR (4 downto 0);
				  sig_out : out  STD_LOGIC_VECTOR (4 downto 0);
				  clk : in  STD_LOGIC);
	end component;

	component Event_Counters is
		 Port ( generated_errors : in  STD_LOGIC;
				  detected_errors : in  STD_LOGIC;
				  count_gen_errors : out  STD_LOGIC_VECTOR (7 downto 0);
				  count_det_errors : out  STD_LOGIC_VECTOR (7 downto 0);
				  clk : in  STD_LOGIC;
				  rst : in  STD_LOGIC);
	end component;

	-- parameters for Control_Logic
	constant data_frame_length : integer := 10 ; 
						-- number of data bit periods in a frame
	constant frame_period : integer := data_frame_length + 13 ; 
						-- number of data bit periods between start of 
						-- 	consecutive frames
	constant dclk_half_period : integer := 16 ; 
						-- number of sytem clocks for 1/2 data bit period
	
	-- parameters for RandBitGenA
	constant RBGsize : integer := 8 ;
	constant RBG_P   : std_logic_vector (RBGsize downto 1) := "10111000" ;
	constant RBGseed : std_logic_vector (RBGsize downto 1) := "10000001" ;

	-- CRC parameters - mapped to FCS_Gen and Error_Detect CRC modules
	constant FCS_length : integer := 5 ;
--	constant FCS_length : integer := 4 ;
	constant P : std_logic_vector (fcs_length downto 0) := "110101" ;
--	constant P : std_logic_vector (fcs_length downto 0) := "10011" ;

	signal btn : STD_LOGIC_VECTOR (3 downto 0) := "0000";
	signal drst : std_logic ;
	signal hex_disp0 : std_logic_vector (3 downto 0) ;
	signal hex_disp1 : std_logic_vector (3 downto 0) ;
	signal hex_disp2 : std_logic_vector (3 downto 0) ;
	signal hex_disp3 : std_logic_vector (3 downto 0) ;

	-- Control_Logic signals
	signal ctrl_dclk : std_logic ; 		-- data clock output
	signal ctrl_frame : std_logic ; 		-- data frame output
	signal dstart : std_logic ; 			-- debounced start input
	signal dstop : std_logic ; 			-- debounced stop input

	-- Random Bit Generator signals
	signal rbg_data_out : std_logic ;	-- data output
	signal rbg_dclk_out : std_logic ;	-- data clock output
	signal rbg_frame_out : std_logic ;	-- data frame output
	
	-- FCS_Gen signals
	signal FCSGen_data_out : std_logic ;	-- data output
	signal FCSGen_dclk_out : std_logic ;	-- data clock output
	signal FCSGen_frame_out : std_logic ;	-- data frame output
	signal FCSGen_error_out : std_logic ;  -- error out (not used)

	-- Frame_Error generator signals
	signal Frame_Error_data_out : std_logic ;		-- data output with errors
	signal Frame_Error_dclk_out : std_logic ;		-- data clock output
	signal Frame_Error_frame_out : std_logic ;	-- data frame output
	signal gen_frame_error : std_logic ;			-- frame error output
	signal bit_errors : std_logic ;					-- bit errors
	signal data_wo_errors : std_logic ;				-- data output without errors

	-- Error_Detect signals
	signal ErrDet_data_out : std_logic ; 	-- data output (not used)
	signal ErrDet_dclk_out : std_logic ;	-- data clock output (not used)
	signal ErrDet_frame_out : std_logic ; 	-- data frame output (not used)
	signal ErrDet_error_out : std_logic ; 	-- error output

begin

	-- Map Push Buttons: | DIR_DOWN | DIR_LEFT | DIR_RIGHT |   DIR_UP   |
	--         Button #: |  btn(0)  |  btn(1)  |  btn(2)   |   btn(3)   |
	--         Function: |  Reset   |  Start   |   Stop    | Error Mode |
	btn <= DIR_UP & DIR_RIGHT & DIR_LEFT & DIR_DOWN;

	HEXon7segDispA : HEXon7segDisp
	port map (  hex_data_in0 => hex_disp0,
					hex_data_in1 => hex_disp1,
					hex_data_in2 => hex_disp2,
					hex_data_in3 => hex_disp3,
					dp_in => "000",  -- no decimal point
					seg_out => Seg7_SEG,
					an_out => Seg7_AN(3 downto 0),
					dp_out => Seg7_DP,
					clk => clk
					);
				
	Seg7_AN(4) <= '1';  -- 7 Seg Display Anode 4 is not used

	RST_debounce: debounce 
	generic map ( DELAY => debounceDELAY )
	port map (	sig_in => btn(0), 	clk => clk, 	sig_out => drst);

	Start_debounce: debounce 
	generic map ( DELAY => debounceDELAY )
	port map (	sig_in => btn(1), 	clk => clk,		sig_out => dstart);

	Stop_debounce: debounce 
	generic map ( DELAY => debounceDELAY )
	port map (	sig_in => btn(2),		clk => clk,		sig_out => dstop);

	Control : Control_Logic 
	generic map ( data_frame_length, frame_period, dclk_half_period )		
	port map  ( Start 		 => dstart,
					Stop  		 => dstop,
					tx_frame_out => ctrl_frame,
					dclk_out 	 => ctrl_dclk,
					clk   		 => clk,
					rst   		 => drst
					);

	RandBitGenA : RandBitGen 
	generic map ( RBGsize )
	port map ( 	P 			 => RBG_P,
					seed 		 => RBGseed,
					frame_in  => ctrl_frame,
					dclk_in 	 => ctrl_dclk,
					data_out  => rbg_data_out,
					dclk_out  => rbg_dclk_out,
					frame_out => rbg_frame_out,
					clk   	 => clk,
					rst   	 => drst
					);

	FCS_Gen : CRC 
	generic map ( FCS_length )
	port map ( P => P,
				  data_in => rbg_data_out,
				  dclk_in => rbg_dclk_out,
				  frame_in => rbg_frame_out,
				  data_out => FCSGen_data_out,
				  dclk_out => FCSGen_dclk_out,
				  frame_out => FCSGen_frame_out,
				  error_out => FCSGen_error_out, 
				  mode => '1', -- FCS generation mode
				  clk => clk,
				  rst => drst
				  );

	Frame_Error : Frame_Error_Gen 
	generic map ( data_frame_length + FCS_length )			
	port map ( frame_error_rate => frame_error_rate,
				  error_pattern => SW, -- 8 Slide Switches on FPGA Board
				  error_mode_ctrl => btn(3),
				  data_in => FCSGen_data_out,
				  dclk_in => FCSGen_dclk_out,
				  frame_in => FCSGen_frame_out,
				  data_out => Frame_Error_data_out,
				  dclk_out => Frame_Error_dclk_out,
				  frame_out => Frame_Error_frame_out,
				  frame_error => gen_frame_error,
				  bit_errors => bit_errors,
				  pass_thru_data => data_wo_errors,
				  clk => clk,
				  rst => drst
				  );

	Error_Detect : CRC 
	generic map ( FCS_length )
	port map ( P => P,
	           data_in => Frame_Error_data_out,
				  frame_in => Frame_Error_frame_out,
				  dclk_in => Frame_Error_dclk_out,
				  data_out => ErrDet_data_out,
				  frame_out => ErrDet_frame_out,
				  dclk_out => ErrDet_dclk_out,
				  error_out => ErrDet_error_out, 
				  mode => '0', -- error detect mode
				  clk => clk,
				  rst => drst
				  );

	Counters : Event_Counters 
	port map ( generated_errors => gen_frame_error,
				  detected_errors => ErrDet_error_out,
				  count_gen_errors(3 downto 0) => hex_disp1,
				  count_gen_errors(7 downto 4) => hex_disp0,
				  count_det_errors(3 downto 0) => hex_disp3,
				  count_det_errors(7 downto 4) => hex_disp2,
				  clk => clk,
				  rst => drst
				  );

	Output_Connector : Output_Port 
	port map ( sig_in(0) => data_wo_errors,
				  sig_in(1) => gen_frame_error, 	
				  sig_in(2) => Frame_Error_data_out, 	
				  sig_in(3) => ErrDet_error_out, 	
				  sig_in(4) => bit_errors, 	
				  sig_out(0) => testsig_data,
				  sig_out(1) => testsig_error_frame,
				  sig_out(2) => testsig_data_with_errors,
				  sig_out(3) => testsig_error_detect,
				  sig_out(4) => testsig_bit_errors,
				  clk => clk
				  );

	-- display count of errors not detected on LEDs
	process (clk, hex_disp3, hex_disp2, hex_disp1, hex_disp0)
	begin
		if rising_edge(clk) then
			-- display undetected errors = generated errors - detected errors
			LED <= std_logic_vector(unsigned(hex_disp0 & hex_disp1) 
															- unsigned(hex_disp2 & hex_disp3));
		end if ;		
	end process ; 

end Behavioral;