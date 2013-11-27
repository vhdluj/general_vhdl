library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package adc7864_types is
  type adc_data_array is array (0 to 3) of std_logic_vector(11 downto 0);
end adc7864_types;
