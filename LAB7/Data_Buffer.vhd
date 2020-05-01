----------------------------------------------------------------------------------
-- Company: 		 Binghamton University
-- Engineer:	    
-- Create Date:    21:11:54 04/18/2011 
-- Design Name:    Data Buffer using Distributed RAM
-- Module Name:    Data_Buffer - Behavioral 
-- Revision: 
-- Revision 0.01 - File Created
--		05-16-2017 - Added bufg to write_clk input using the buffer_type attribute	
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Data_Buffer is
    generic (word_size: natural := 8; address_size: natural := 5 );
	 Port ( write_clk : in  STD_LOGIC;
           write_enable : in  STD_LOGIC;
			  addr_in : in  UNSIGNED (address_size-1 downto 0);
           data_in : in  STD_LOGIC_VECTOR (word_size-1 downto 0);
           data_out : out  STD_LOGIC_VECTOR (word_size-1 downto 0)
         );
	 -- The following attributes add a clock buffer to the write_clk signal
	 -- to eliminate potential clock skew issues. 	
	 attribute buffer_type : string ;
	 attribute buffer_type of write_clk : signal is "bufg";
end Data_Buffer;

architecture Behavior of Data_Buffer is

-- #####    INSERT YOUR CODE TO DESIGN THE Data_Buffer BY INFERENCE    #####
type regfile_t is array (0 to 2 ** address_size - 1) of std_logic_vector(word_size - 1 downto 0);
signal regfile : regfile_t := (others=>(others=>'0'));

begin

process(write_clk) begin
	if rising_edge(write_clk) then
		if write_enable = '1' then
			regfile(to_integer(addr_in)) <= data_in;
		end if;
	end if;
end process;

data_out <= regfile(to_integer(addr_in));
end Behavior;
