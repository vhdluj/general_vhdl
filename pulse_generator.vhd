library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pulse_generator is
  
  generic (
    PULSE_TYPE : string  := "rising";
    DATA_WIDTH : integer := 1);
  port (
    CLK       : in  std_logic;
    SIGNAL_IN : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    PULSE_OUT : out std_logic_vector(DATA_WIDTH-1 downto 0));
end pulse_generator;

architecture pulse_generator of pulse_generator is
  signal signal_in_sync, signal_rising_edge_pulse, signal_falling_edge_pulse : std_logic_vector(DATA_WIDTH-1 downto 0);
begin  -- pulse_generator

  INDIVIDUAL_PULSES_GEN: for i in 0 to DATA_WIDTH-1 generate
    MAKE_PULSE: process (CLK)
  begin 
    if rising_edge(CLK) then
      if signal_in_sync(i) = '1' and SIGNAL_IN(i) = '0' then
        signal_in_sync(i) <= SIGNAL_IN(i);
        signal_rising_edge_pulse(i) <= '0';
        signal_falling_edge_pulse(i) <= '1';
      elsif signal_in_sync(i) = '0' and SIGNAL_IN(i) = '1' then
        signal_in_sync(i) <= SIGNAL_IN(i);
        signal_rising_edge_pulse(i) <= '1';
        signal_falling_edge_pulse(i) <= '0';
      else
        signal_in_sync(i) <= SIGNAL_IN(i);
        signal_rising_edge_pulse(i) <= '0';
        signal_falling_edge_pulse(i) <= '0';
      end if;
    end if;
  end process MAKE_PULSE;
  end generate INDIVIDUAL_PULSES_GEN;
  

  SELECT_RISING_EDGE: if PULSE_TYPE = "rising" generate
    PULSE_OUT <= signal_rising_edge_pulse;
  end generate SELECT_RISING_EDGE;

  SELECT_FALLING_EDGE: if PULSE_TYPE = "falling" generate
    PULSE_OUT <= signal_falling_edge_pulse;
  end generate SELECT_FALLING_EDGE;
  
end pulse_generator;
