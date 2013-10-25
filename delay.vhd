library IEEE;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity delay is
  generic (
    VECTOR_WIDTH : natural;
    DELAY_INT : integer range 0 to 31 := 1
    );
  port (
    CLK                         : in  std_logic;
    DELAY_VECTOR_IN             : in  std_logic_vector(VECTOR_WIDTH - 1 downto 0);
    DELAY_VECTOR_OUT            : out std_logic_vector(VECTOR_WIDTH - 1 downto 0)
  );
end delay;

architecture delay of delay is
  
  type signal_out_array_type is array (0 to DELAY_INT) of std_logic_vector(VECTOR_WIDTH-1 downto 0);
  signal signal_out_array : signal_out_array_type;

begin
  signal_out_array(0) <= DELAY_VECTOR_IN;
  DELAY_GEN: for i in 0 to DELAY_INT-1 generate
    MAKE_OUT_SIGNAL : process (CLK)
    begin
      if rising_edge(CLK) then
        signal_out_array(i+1) <= signal_out_array(i);
      end if;
    end process MAKE_OUT_SIGNAL;
  end generate DELAY_GEN;
  DELAY_VECTOR_OUT <= signal_out_array(DELAY_INT);

end delay;
