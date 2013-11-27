library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package dac5684_types is
  
  type dac_data_array is array (0 to 3) of std_logic_vector(11 downto 0);
  type dac_data_cntr_array is array (0 to 3) of std_logic_vector(11 downto 0);
end dac5684_types;
