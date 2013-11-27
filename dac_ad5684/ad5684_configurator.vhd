
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;
library work;
use work.all;
use work.dac5684_types.all;

entity ad5684_configurator is
generic (
	USE_SIM_SETTINGS : integer range 0 to 1 := 0 
); 
port (
	CLK_IN : in std_logic;          --not faster than 50MHz - DAC limitation
	RESET_IN : in std_logic;
        CHANNEL_RESET_IN  : in std_logic_vector(3 downto 0);
        CHANNEL_DATA_IN  : in dac_data_array;
        CHANNEL_RD_EN_IN : in std_logic_vector(3 downto 0);
	CHANNEL_WR_EN_IN : in std_logic_vector(3 downto 0);
	CHANNEL_FIFO_EMPTY_OUT : out std_logic_vector(3 downto 0);
	CHANNEL_FIFO_FULL_OUT : out std_logic_vector(3 downto 0);
        CHANNEL_FIFO_ALMOST_EMPTY_OUT : out std_logic_vector(3 downto 0);
        CHANNEL_FIFO_ALMOST_FULL_OUT : out std_logic_vector(3 downto 0);   
        CHANNEL_RD_DATA_COUNT : out dac_data_cntr_array;
        CHANNEL_WR_DATA_COUNT : out dac_data_cntr_array;
	
	READY_OUT : out std_logic;
	
	DAC_SYNC_N_OUT : out std_logic;
	DAC_SCLK_OUT : out std_logic;
	DAC_RESET_N_OUT : out std_logic;
	DAC_SDIN_OUT : out std_logic;
	DAC_LDAC_N_OUT : out std_logic	
);
end ad5684_configurator;

architecture Behavioral of ad5684_configurator is

  component dac_adc_fifo
    port (
      rst               : in  std_logic;
      wr_clk            : in  std_logic;
      rd_clk            : in  std_logic;
      din               : in  std_logic_vector(17 downto 0);
      wr_en             : in  std_logic;
      rd_en             : in  std_logic;
      prog_empty_thresh : in  std_logic_vector(11 downto 0);
      prog_full_thresh  : in  std_logic_vector(11 downto 0);
      dout              : out std_logic_vector(17 downto 0);
      full              : out std_logic;
      almost_full       : out std_logic;
      empty             : out std_logic;
      almost_empty      : out std_logic;
      rd_data_count     : out std_logic_vector(11 downto 0);
      wr_data_count     : out std_logic_vector(11 downto 0);
      prog_full         : out std_logic;
      prog_empty        : out std_logic);
  end component;
  
type conf_states is (IDLE, ACTIVATE_CHANNEL, LOOP_TROUGH_BITS, CLEANUP);
signal conf_current_state, conf_next_state : conf_states;

signal bits_ctr : integer range 0 to 23 := 0;
signal data : std_logic_vector(23 downto 0);
signal saved_channel : std_logic_vector(3 downto 0);
signal channel : dac_data_array;
signal load_dac : std_logic;
signal dummy_sim_data : std_logic_vector(23 downto 0);
begin

  process(CLK_IN)
  begin
    if rising_edge(CLK_IN) then
      if (RESET_IN = '1') then
        conf_current_state <= IDLE;
      else
        conf_current_state <= conf_next_state;
      end if;
    end if;
  end process;

  process(conf_current_state, saved_channel, bits_ctr)
  begin
    case conf_current_state is
      when IDLE =>
        if (saved_channel /= "0000") then
          conf_next_state <= ACTIVATE_CHANNEL;
        else
          conf_next_state <= IDLE;
        end if;
        
      when ACTIVATE_CHANNEL =>
        conf_next_state <= LOOP_TROUGH_BITS;
        
      when LOOP_TROUGH_BITS =>
        if (bits_ctr = 23) then
          conf_next_state <= CLEANUP;
        else
          conf_next_state <= LOOP_TROUGH_BITS;
        end if;
        
      when CLEANUP =>
        
        conf_next_state <= IDLE;
        
    end case;
  end process;

  process(CLK_IN)
  begin
    if rising_edge(CLK_IN) then
      if (conf_current_state = IDLE or conf_current_state = CLEANUP) then
        bits_ctr <= 0;
      elsif (conf_current_state = LOOP_TROUGH_BITS and bits_ctr < 23) then
        bits_ctr <= bits_ctr + 1;
      else
        bits_ctr <= bits_ctr;
      end if;
    end if;
  end process;

  process(CLK_IN)
  begin
    if rising_edge(CLK_IN) then
      
      data(23 downto 20) <= x"3";           -- write and update operation
      data(19 downto 16) <= saved_channel;  -- channel nr
      case saved_channel is
        when "0001" => data(15 downto 4) <= channel(0);
        when "0010" => data(15 downto 4) <= channel(1);
        when "0100" => data(15 downto 4) <= channel(2);
        when "1000" => data(15 downto 4) <= channel(3);
        when others => data(15 downto 4) <= x"fff";
      end case;
      data(3 downto 0) <= x"0";             -- reserved

      if (conf_current_state = LOOP_TROUGH_BITS) then
        DAC_SYNC_N_OUT <= '0';
      else
        DAC_SYNC_N_OUT <= '1';
      end if;

      DAC_SDIN_OUT <= data(23 - bits_ctr);

      if (conf_current_state = IDLE) then
        READY_OUT <= '1';
      else
        READY_OUT <= '0';
      end if;

      saved_channel <= CHANNEL_RD_EN_IN;

      if (conf_current_state = CLEANUP) then
        load_dac <= '1';
      else
        load_dac <= '0';
      end if;
      
    end if;
  end process;

  DAC_SCLK_OUT    <= CLK_IN;
  DAC_RESET_N_OUT <= '1';
  DAC_LDAC_N_OUT  <= load_dac;--'1';
-----------------------------------------------------????????????????????????????????????????????????????/
-----------------------------------------------------should be a pulse 15ns min

  DAC_FIFOS : for i in 0 to 3 generate
     dac_adc_fifo_2: dac_adc_fifo
      port map (
        rst               => CHANNEL_RESET_IN(i),       
        wr_clk            => CLK_IN,
        rd_clk            => CLK_IN,
        din               => "00" & x"0" & CHANNEL_DATA_IN(i),
        wr_en             => CHANNEL_WR_EN_IN(i),
        rd_en             => CHANNEL_RD_EN_IN(i),
        prog_empty_thresh => (others => '0'),--prog_empty_thresh,
        prog_full_thresh  => (others => '1'),--prog_full_thresh,
        dout(11 downto 0) => channel(i),
        dout(17 downto 12) => dummy_sim_data((i+1)*6-1 downto i*6),
        full              => CHANNEL_FIFO_FULL_OUT(i),
        almost_full       => CHANNEL_FIFO_ALMOST_FULL_OUT(i),
        empty             => CHANNEL_FIFO_EMPTY_OUT(i),
        almost_empty      => CHANNEL_FIFO_ALMOST_EMPTY_OUT(i),
        rd_data_count     => CHANNEL_RD_DATA_COUNT(i),
        wr_data_count     => CHANNEL_WR_DATA_COUNT(i),
        prog_full         => open,
        prog_empty        => open);
  end generate DAC_FIFOS;
  
end Behavioral;

