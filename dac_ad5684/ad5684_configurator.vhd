library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity ad5684_configurator is
generic (
	USE_SIM_SETTINGS : integer range 0 to 1 := 0 
); 
port (
	CLK_IN : in std_logic;
	RESET_IN : in std_logic;
	
	CHANNEL1_DATA_IN  : in std_logic_vector(11 downto 0);
	CHANNEL1_RD_EN_IN : in std_logic;
	CHANNEL1_WR_EN_IN : in std_logic;
	CHANNEL1_FIFO_EMPTY_OUT : out std_logic;
	CHANNEL1_FIFO_FULL_OUT : out std_logic;
	CHANNEL2_DATA_IN  : in std_logic_vector(11 downto 0);
	CHANNEL2_RD_EN_IN : in std_logic;
	CHANNEL2_WR_EN_IN : in std_logic;
	CHANNEL2_FIFO_EMPTY_OUT : out std_logic;
	CHANNEL2_FIFO_FULL_OUT : out std_logic;
	CHANNEL3_DATA_IN  : in std_logic_vector(11 downto 0);
	CHANNEL3_RD_EN_IN : in std_logic;
	CHANNEL3_WR_EN_IN : in std_logic;
	CHANNEL3_FIFO_EMPTY_OUT : out std_logic;
	CHANNEL3_FIFO_FULL_OUT : out std_logic;
	CHANNEL4_DATA_IN  : in std_logic_vector(11 downto 0);
	CHANNEL4_RD_EN_IN : in std_logic;
	CHANNEL4_WR_EN_IN : in std_logic;
	CHANNEL4_FIFO_EMPTY_OUT : out std_logic;
	CHANNEL4_FIFO_FULL_OUT : out std_logic;
	
	READY_OUT : out std_logic;
	
	DAC_SYNC_N_OUT : out std_logic;
	DAC_SCLK_OUT : out std_logic;
	DAC_RESET_N_OUT : out std_logic;
	DAC_SDIN_OUT : out std_logic;
	DAC_LDAC_N_OUT : out std_logic	
);
end ad5684_configurator;

architecture Behavioral of ad5684_configurator is

COMPONENT dac_fifo
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

type conf_states is (IDLE, ACTIVATE_CHANNEL, LOOP_TROUGH_BITS, CLEANUP);
signal conf_current_state, conf_next_state : conf_states;

signal bits_ctr : integer range 0 to 23 := 0;
signal data : std_logic_vector(23 downto 0);
signal saved_channel : std_logic_vector(3 downto 0);
signal channel1_q, channel2_q, channel3_q, channel4_q : STD_LOGIC_VECTOR(11 DOWNTO 0);

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
	
		data(23 downto 20) <= x"3"; -- write and update operation
		data(19 downto 16) <= saved_channel; -- channel nr
		case saved_channel is
			when "0001" => data(15 downto 4) <= channel1_q;
			when "0010" => data(15 downto 4) <= channel2_q;
			when "0100" => data(15 downto 4) <= channel3_q;
			when "1000" => data(15 downto 4) <= channel4_q;
			when others => data(15 downto 4) <= x"fff";
		end case;
		data(3 downto 0)   <= x"0"; -- reserved
		
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
		
		saved_channel <= CHANNEL4_RD_EN_IN & CHANNEL3_RD_EN_IN & CHANNEL2_RD_EN_IN & CHANNEL1_RD_EN_IN;
		
	end if;
end process;

DAC_SCLK_OUT <= CLK_IN;
DAC_RESET_N_OUT <= '1';
DAC_LDAC_N_OUT <= '1';

channel1_fifo : dac_fifo
	port map(rst    => RESET_IN,
		     wr_clk => CLK_IN,
		     rd_clk => CLK_IN,
		     din    => CHANNEL1_DATA_IN,
		     wr_en  => CHANNEL1_WR_EN_IN,
		     rd_en  => CHANNEL1_RD_EN_IN,
		     dout   => channel1_q,
		     full   => CHANNEL1_FIFO_FULL_OUT,
		     empty  => CHANNEL1_FIFO_EMPTY_OUT);
		     
channel2_fifo : dac_fifo
	port map(rst    => RESET_IN,
		     wr_clk => CLK_IN,
		     rd_clk => CLK_IN,
		     din    => CHANNEL2_DATA_IN,
		     wr_en  => CHANNEL2_WR_EN_IN,
		     rd_en  => CHANNEL2_RD_EN_IN,
		     dout   => channel2_q,
		     full   => CHANNEL2_FIFO_FULL_OUT,
		     empty  => CHANNEL2_FIFO_EMPTY_OUT);
		     
channel3_fifo : dac_fifo
	port map(rst    => RESET_IN,
		     wr_clk => CLK_IN,
		     rd_clk => CLK_IN,
		     din    => CHANNEL3_DATA_IN,
		     wr_en  => CHANNEL3_WR_EN_IN,
		     rd_en  => CHANNEL3_RD_EN_IN,
		     dout   => channel3_q,
		     full   => CHANNEL3_FIFO_FULL_OUT,
		     empty  => CHANNEL3_FIFO_EMPTY_OUT);
		     
channel4_fifo : dac_fifo
	port map(rst    => RESET_IN,
		     wr_clk => CLK_IN,
		     rd_clk => CLK_IN,
		     din    => CHANNEL4_DATA_IN,
		     wr_en  => CHANNEL4_WR_EN_IN,
		     rd_en  => CHANNEL4_RD_EN_IN,
		     dout   => channel4_q,
		     full   => CHANNEL4_FIFO_FULL_OUT,
		     empty  => CHANNEL4_FIFO_EMPTY_OUT);

end Behavioral;

