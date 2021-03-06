library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.all;
use work.adc7864_types.all;
use work.general_functions.all;

entity adc7864 is
port(
	--CHIP INTERFACE
    BUSY     : in std_logic;   -- logic high when chip is converting 
    FRSTDATA : in std_logic;   -- goes logic high when converted data occurs on first register
    CONVST   : out std_logic;  --pulse on this line signalizing start of conversion
    CS       : out std_logic;  --cabel select    
	RD       : out std_logic;  --read enable
	WR       : out std_logic;  --write enable
	SL       : out std_logic_vector(3 downto 0); --selectline - 1 in vector means that the channel will be converted
    HSSEL    : out std_logic; -- hardware/software select ->selects way to create read out sequence
    STBY     : out std_logic; -- standby
    INTEXTCLK: out std_logic; --internal/external clock select
--    CLKIN    : in  std_logic; -- clock
    DB       : in std_logic_vector(11 downto 0); --data out
    EOC      : in std_logic;   -- end of conversion (goes high each time after conversion on the channel is ready)
    
    RESET    : in std_logic;-- reset is done when clock is locked
    --USER INTERFACE
    CLK100   : in std_logic;
    DATA_CH : out adc_data_array;
    DV      : out std_logic_vector(3 downto 0);
    CNVST    : in std_logic;            --from user starts conversion
    CHSEL    : in std_logic_vector(3 downto 0); 
    READY    : out std_logic            --to user - ADC can make new sample...
);
end adc7864;

architecture Behavioral of adc7864 is

  component pulse_generator
    generic (
      PULSE_TYPE : string;
      DATA_WIDTH : integer);
    port (
      CLK       : in  std_logic;
      SIGNAL_IN : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      PULSE_OUT : out std_logic_vector(DATA_WIDTH-1 downto 0));
  end component;
  
signal current_state, chsel_saved : std_logic_vector(3 downto 0) := (others => '0');
signal data : adc_data_array;

signal counter : std_logic_vector(8 downto 0)  :=  (others  => '0');
signal conversion : std_logic  := '0';

signal ready_sgn : std_logic  := '0';
signal firstData : std_logic  := '0';
signal eoc_sgn   : std_logic  := '0';
signal convst_sgn: std_logic  := '0';
signal busy_sgn  : std_logic  := '0';
signal dv_from_adc : std_logic_vector(3 downto 0);
signal eoc_q : std_logic := '0';
signal eoc_qq: std_logic := '0';

signal incomingData : std_logic_vector(11 downto 0) := (others => '0');

signal cnt_RD : std_logic_vector(2 downto 0) := (others => '0');
signal rd_sgn : std_logic := '0';


type state_s is (idle,convHolder, w84conv1,w84conv2,w84conv3,w84conv4, read1, read2, read3, read4, finish);
signal state : state_s;

attribute keep : string;
attribute keep of data, current_state, conversion : signal  is "true";
attribute keep of ready_sgn, firstData, eoc_sgn, convst_sgn,busy_sgn, incomingData, rd_sgn : signal is "true";


begin
--SETTING UP PORTS________________________________________________________
SL  <= chsel_saved;      --selecting channels for conversion 1111 means all 4 channels selected
HSSEL  <= '0';     --select hardware read sequence
STBY  <= '1';      --switch off standby mode
INTEXTCLK  <= '0'; --choose external clock
conversion    <=  CNVST;
CS  <= '0';
DATA_CH  <= data;
WR <= '1'; --we do not write to the chip (write is needed for progam sequence
 
firstData <=   FRSTDATA;     
busy_sgn <= BUSY;       
CONVST  <= convst_sgn;            
eoc_sgn  <= EOC;       
READY <= ready_sgn;
incomingData <= DB;

--````````````````````````````````````````````````````````````````````````
EOC_Proc : process (CLK100) is
begin
	if rising_edge(CLK100) then
          eoc_q <= EOC;
          eoc_qq <= eoc_q;
        end if;
end process EOC_Proc;

SAVE_CHANNEL_ENABLE : process (CLK100)
begin
  if rising_edge(CLK100) then
    if state = IDLE then
      chsel_saved <= CHSEL;
    else
      chsel_saved <= chsel_saved;
    end if;
  end if;
end process SAVE_CHANNEL_ENABLE;


MainPrc : process (CLK100, RESET) is
begin
	if RESET = '1' then
		state  <= idle;
		ready_sgn <= '0';
		counter  <= (others => '0');
		current_state  <= X"0";
	elsif rising_edge(CLK100) then
		ready_sgn <= '0';
		counter  <= (others => '0');
		convst_sgn <= '1';
		case state is 
			when idle =>
				current_state  <= X"0";
				ready_sgn  <= '1';
				if(conversion = '0' and  chsel_saved /= x"0") then
					state  <= convHolder;
				else
					state  <= idle;
				end if;
			when convHolder => 
			    current_state  <= X"1";
			    counter  <= counter +1;
				if(counter < 6) then
				  convst_sgn <= '0';
				  state  <= convHolder;
                                else
				  convst_sgn <= '1';
				  state  <= w84conv1;
				end if;	
			when w84conv1 =>
				current_state  <= X"2";
				if(eoc_qq = '0') then --first channel 
					state  <= read1;
                                elsif chsel_saved(0) = '0' then
                                  	state  <= w84conv2;
				else
					state  <= w84conv1;
				end if;
			when read1 =>
			    current_state  <= X"3";
				if(eoc_qq = '0') then --first channel 
					state  <= read1;
				else
					state  <= w84conv2;
				end if;
			when w84conv2  => 
				current_state  <= X"4";
				if(eoc_qq = '0') then
					state  <=  read2;
                                elsif chsel_saved(1) = '0' then
                                        state  <= w84conv3;
				else
					state  <= w84conv2;
				end if;
			when read2  =>
				current_state  <= X"5";
				if(eoc_qq = '0') then
					state  <= read2;
				else
					state  <= w84conv3;
				end if;
			when w84conv3  =>
				current_state  <= X"6";
				if(eoc_qq = '0') then
					state  <= read3;
                                elsif chsel_saved(2) = '0' then
                                  	state  <= w84conv4;
				else
					state  <= w84conv3;
				end if;
			when read3  =>
				current_state  <= X"7"; 
				if(eoc_qq = '0') then
					state  <= read3;
				else
					state  <= w84conv4;
				end if;	
			when w84conv4  => 
				current_state  <= X"8";
				if(eoc_qq = '0') then
					state  <= read4;
                                elsif chsel_saved(3) = '0' then
                                  	state  <= finish;
				else
					state  <= w84conv4;
				end if;
			when read4  => 
				current_state  <= X"9";
				if(eoc_qq = '0') then
					state  <= read4;
				else
					state  <= finish;
				end if;
			when finish => --wait for 340 ns = time needed for aquisition
				current_state  <= X"A";
				counter  <= counter +1;
				if(counter < 34) then
					state  <= finish;
				else
					state  <= idle;
				end if;
		end case;
	end if;
end process MainPrc;
RD <= rd_sgn;

ReadSignalProc : process(clk100)
begin
	if rising_edge(CLK100) then
		if RESET='1' or eoc_sgn = '1' then
			rd_sgn <= '1';
			cnt_RD  <= (others => '0');
		else
			if(eoc_sgn <= '0' and cnt_RD < 5) then
				cnt_RD <= cnt_RD + 1 ;
				rd_sgn <= '0';
			else
				rd_sgn  <= '1';
                        end if;
		end if;
	end if;
end process ReadSignalProc;


ReadInData : process (CLK100, RESET) is
begin
  if rising_edge(CLK100) then
	if    (state = read1 and rd_sgn = '0') then
		data(0)  <= DB;
		dv_from_adc(0)   <= '1';
	elsif (state = read2 and rd_sgn = '0') then
		data(1)  <= DB;
		dv_from_adc(1)   <= '1';
	elsif (state = read3 and rd_sgn = '0') then
		data(2)  <= DB;
		dv_from_adc(2)   <= '1';
	elsif (state = read4 and rd_sgn = '0') then
		data(3)  <= DB;
		dv_from_adc(3)   <= '1';	
	else
		data <= data;
                dv_from_adc <= (others => '0');
	end if;
  end if;
end process ReadInData;

pulse_generator_1: pulse_generator
  generic map (
    PULSE_TYPE => "rising",
    DATA_WIDTH => 4)
  port map (
    CLK       => CLK100,
    SIGNAL_IN => dv_from_adc,
    PULSE_OUT => DV);

end Behavioral;

