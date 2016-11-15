--Ultrasonic Rangefinder -> ADC -> 7 segment display
-- by James Martin
-- for Basys 3 dev board
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

--------------------------------------------------------

entity toplevel is
    Port ( sw : in STD_LOGIC_VECTOR (15 downto 0);
           led : out STD_LOGIC_VECTOR (15 downto 0);
           seg : out STD_LOGIC_VECTOR (6 downto 0);
           an : out STD_LOGIC_VECTOR (3 downto 0);
           JXADC : in STD_LOGIC_VECTOR (7 downto 0);
           ultrasonicrxpin : out STD_LOGIC;
           clk : in STD_LOGIC
          );
end toplevel;

--------------------------------------------------------

architecture Behavioral of toplevel is

    component SevenSegmentDisplay
        Port (
            input : in STD_LOGIC_VECTOR (13 downto 0);
            sign : in STD_LOGIC;
            segout : out STD_LOGIC_VECTOR (6 downto 0);
            an : out STD_LOGIC_VECTOR (3 downto 0);
            clk : in STD_LOGIC
        );
    end component; 

    COMPONENT xadc_wiz_0
      PORT (
        di_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        daddr_in : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
        den_in : IN STD_LOGIC;
        dwe_in : IN STD_LOGIC;
        drdy_out : OUT STD_LOGIC;
        do_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        dclk_in : IN STD_LOGIC;
        reset_in : IN STD_LOGIC;
        vp_in : IN STD_LOGIC;
        vn_in : IN STD_LOGIC;
        vauxp6 : IN STD_LOGIC;
        vauxn6 : IN STD_LOGIC;
        channel_out : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
        eoc_out : OUT STD_LOGIC;
        alarm_out : OUT STD_LOGIC;
        eos_out : OUT STD_LOGIC;
        busy_out : OUT STD_LOGIC
      );
    END COMPONENT;

    component clock20hz
      port (clk_in: in STD_LOGIC;
      clk_out: out STD_LOGIC);
    end component;

--------------------------------------------------------
  
  -- Digital filter settings for the ultrasonic samples
  constant SAMPLE_FIFO_LENGTH   : integer := 20;
  constant MEDIAN_FILTER_LENGTH : integer :=  4;
  constant DISTANCE_FIFO_LENGTH : integer := 20;

  -- ADC signals
  signal adc_data_ready: STD_LOGIC;
  signal adc_data: STD_LOGIC_VECTOR(15 downto 0);
  type ultrasonic_samplearray is array (0 to SAMPLE_FIFO_LENGTH-1) of STD_LOGIC_VECTOR(11 downto 0);
  signal ultrasonic_samples : ultrasonic_samplearray; 
  signal ultrasonic_raw_avg : STD_LOGIC_VECTOR(11 downto 0);
 
  -- Display signals
  signal displayout: std_logic_vector(13 downto 0) := "00000001010110"; 
  signal displaysign: STD_LOGIC;
  
  -- Clock signals
  signal clk20hz: STD_LOGIC;
  signal counter1hz: integer range 0 to 100000000;
  signal clk1hz: STD_LOGIC;
  
  -- Derived distance/velocity/acceleration signalss
  type distance_samplearray is array (0 to DISTANCE_FIFO_LENGTH-1) of unsigned(8 downto 0);
  signal distancesamples : distance_samplearray;
  signal currentdistance: unsigned(8 downto 0);
  signal currentvelocity: unsigned(8 downto 0);
  signal pastvelocity: unsigned(8 downto 0);
  signal currentaccel: unsigned(8 downto 0);
  signal velsign: STD_LOGIC;
  signal accsign: STD_LOGIC;

--------------------------------------------------------
begin
  ultrasonicrxpin<= 'Z'; -- Set up ADC recieve pin for input
  
---- Map components ----
  clkdivider: clock20hz port map (clk_in=>clk, clk_out=>clk20hz);
  sevenseg_1: SevenSegmentDisplay port map (input=>displayout,segout=>seg,an=>an,clk=>clk,sign=>displaysign);

xadc : xadc_wiz_0
  PORT MAP (
  di_in => (others => '0'),
  daddr_in => "0010110",
  den_in => '1',
  dwe_in => '0',
  drdy_out => adc_data_ready,
  do_out => adc_data,
  dclk_in => clk,
  reset_in => '0',
  vp_in => '0',
  vn_in => '0',
  vauxp6 => JXADC(0),
  vauxn6 => JXADC(4),
  channel_out => open,
  eoc_out => open,
  alarm_out => open,
  eos_out => open,
  busy_out => open
);
---- End map components ----

ADCREAD: process(adc_data_ready, clk20hz)
    variable temp: unsigned(23 downto 0);
begin
    --ADC Samples 100.81 KSPS, set to average 256 samples, 
    -- decimate by taking samples from the adc at 20hz, nearly the sensor update freq of 20.408hz
    if(rising_edge(clk20hz)) then
        if(adc_data_ready='1') then
               ultrasonic_samples(1 to SAMPLE_FIFO_LENGTH-1) <= ultrasonic_samples(0 to SAMPLE_FIFO_LENGTH-2);
               temp:=(unsigned(adc_data(15 downto 4)) *38/1000);--unsigned(adc_data(15 downto 4))*156+unsigned(adc_data(15 downto 6))*156;--(unsigned(adc_data(15 downto 4)) *38/1000);
               ultrasonic_samples(0) <= std_logic_vector(temp(11 downto 0));--std_logic_vector(temp(23 downto 11));
        end if;
    end if;
end process;

-- LPF the ADC samples
MEDIAN_FILTER: process(ultrasonic_samples, clk20hz)
  variable temp: STD_LOGIC_VECTOR(11 downto 0);
  variable temp2: STD_LOGIC_VECTOR(8 downto 0);
  variable sum1: unsigned(12 downto 0);
  variable medindex: integer range 0 to 127;
  type medcountarray is array (0 to SAMPLE_FIFO_LENGTH-1) of integer range 0 to 127; 
  variable count: medcountarray;
begin
    if(rising_edge(clk20hz)) then
        sum1:=(others=>'0');
        medindex:=0;
        for I in 0 to MEDIAN_FILTER_LENGTH-1 loop
            temp:=ultrasonic_samples(I);
            for II in 0 to MEDIAN_FILTER_LENGTH-1 loop
                if(ultrasonic_samples(II) = temp) then
                    sum1:=1+sum1;
                end if;
            end loop;
            count(I):=to_integer(sum1);
        end loop;
        
        for I in 1 to MEDIAN_FILTER_LENGTH-1 loop
          if(count(medindex)<count(I))then
            medindex:=I;
          end if;
        end loop;
        temp2:="0"&ultrasonic_samples(medindex)(7 downto 0);
        currentdistance<=unsigned(temp2);
        
        distancesamples(1 to DISTANCE_FIFO_LENGTH-1) <= distancesamples(0 to DISTANCE_FIFO_LENGTH-2);
        distancesamples(0) <= unsigned(temp2);
   end if;
end process;

clk1hz_divider: process (clk) begin
    if rising_edge(clk) then
        if (counter1hz = 100000000-1) then
            clk1hz <= NOT(clk1hz);
            counter1hz <= 0;
        else
            counter1hz <= counter1hz + 1;
        end if;
    end if;
end process;
    
--Velocity calculation, uses samples 1 sec apart so /\t=1
process(distancesamples,clk20hz) 
begin
        if(rising_edge(clk20hz)) then
            pastvelocity<=currentvelocity;
            if(distancesamples(0) >= distancesamples(19)) then
                currentvelocity<=(distancesamples(0) - distancesamples(19));
                velsign<='0';
            else
                currentvelocity<=(distancesamples(19) - distancesamples(0));
                velsign<='1';
            end if;

        end if;
end process;

--Acceleration calculation
process(counter1hz) 
begin
        if(rising_edge(clk1hz)) then
            if(currentvelocity >= pastvelocity) then
                currentaccel<=(currentvelocity-pastvelocity);
                accsign<='0';
            else
                currentaccel<=(pastvelocity - currentvelocity);
                accsign<='1';
            end if;
        end if;
end process;

-- Choose what value to display based on user input switches
process(sw,currentdistance,currentvelocity,currentaccel) 
    variable displaytemp : std_logic_vector(13 downto 0):=(others => '0');
begin
        if(sw(0) = '0' and sw(1) = '0') then
           displaytemp:="00000"&std_logic_vector(currentdistance);
           displaysign<='0';
        elsif(sw(0) = '1' and sw(1) = '0') then
           displaytemp:="00000"&std_logic_vector(currentvelocity);
           displaysign<=velsign;
        elsif(sw(0) = '0' and sw(1) = '1') then
           displaytemp:="00000"&std_logic_vector(currentaccel);
           displaysign<=accsign;
        end if;  
        
        displayout<=displaytemp;           
end process;

-- Debug low quality switches by displaying which are closed
led(14 downto 0)<=sw(14 downto 0);

end Behavioral;