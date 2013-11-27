library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.all;
use work.adc7864_types.all;
use work.general_functions.all;

entity adc7864_tb is
  port(
    BUSY     : out std_logic;   -- logic high when chip is converting 
    FRSTDATA : out std_logic;   -- goes logic high when converted data occurs on first register
    CONVST   : in std_logic;  --pulse on this line signalizing start of conversion
    CS       : in std_logic;  --cabel select    
    RD       : in std_logic;  --read enable
    WR       : in std_logic;  --write enable
    SL       : in std_logic_vector(3 downto 0); --selectline - 1 in vector means that the channel will be converted
    HSSEL    : in std_logic; -- hardware/software select ->selects way to create read out sequence
    STBY     : in std_logic; -- standby
    INTEXTCLK: in std_logic; --internal/external clock select
    DB       : out std_logic_vector(11 downto 0); --data out
    EOC      : out std_logic
    );
end adc7864_tb;

architecture adc7864_tb of adc7864_tb is

begin  -- adc7864_tb

  ADC_READOUT: process
    variable i : integer := 0;
    variable j : integer range 0 to 1023 := 0;
  begin
    BUSY <= '0';
    EOC <= '1';
    FRSTDATA <= '0';
    j := j + 1;
    wait for 5 us;
    
    wait until CONVST = '0';
    i := 0;
    while i < 4 loop
      if SL(i) = '1' then
        if i = 1 then
          FRSTDATA <= '1';
        end if;
        BUSY <= '1';
        wait for 500 ns;
        EOC <= '0';
        DB <= std_logic_vector(to_unsigned(j,12));
        wait until RD = '0';
        wait for 100 ns;
        EOC <= '1';
      end if;
      i := i + 1;
    end loop;
  end process ADC_READOUT;

end adc7864_tb;
