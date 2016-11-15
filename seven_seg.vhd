---------------------------------------------------------------------------------------------
-- 4x7 Segment Multiplexer
-- 1 14bit input in to write 4 decimals out
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity SevenSegmentDisplay is
    Port (
        input : in STD_LOGIC_VECTOR (13 downto 0);
        sign : in STD_LOGIC;
        segout : out STD_LOGIC_VECTOR (6 downto 0);
        an : out STD_LOGIC_VECTOR (3 downto 0);
        clk : in STD_LOGIC
    );
end SevenSegmentDisplay;

architecture Behavioral of SevenSegmentDisplay is
    component clk200Hz
      port (clk_in: in STD_LOGIC;
      clk_out: out STD_LOGIC);
    end component;

    signal seven_segment_clk : STD_LOGIC;
    signal selectseg : integer range 0 to 3 := 0;
    signal bcd_decoder : STD_LOGIC_VECTOR(3 downto 0);
    signal bcd : STD_LOGIC_VECTOR(15 downto 0);
begin

    doubledabble: process(input)
      variable temp : STD_LOGIC_VECTOR (13 downto 0);
      variable unsigned_bcd : UNSIGNED (15 downto 0) := (others => '0'); --Unsigned for shifting stuff

      begin
        unsigned_bcd := (others => '0');
        temp(13 downto 0) := input(13 downto 0);
        
        -- Handle up to 14 bits, for 2^14 so we can display up to 9999
        for i in 0 to 13 loop
        
          if unsigned_bcd(3 downto 0) > 4 then 
            unsigned_bcd(3 downto 0) := unsigned_bcd(3 downto 0) + 3;
          end if;
          
          if unsigned_bcd(7 downto 4) > 4 then 
            unsigned_bcd(7 downto 4) := unsigned_bcd(7 downto 4) + 3;
          end if;
        
          if unsigned_bcd(11 downto 8) > 4 then  
            unsigned_bcd(11 downto 8) := unsigned_bcd(11 downto 8) + 3;
          end if;
        
          if unsigned_bcd(15 downto 12) > 4 then  
            unsigned_bcd(15 downto 12) := unsigned_bcd(15 downto 12) + 3;
          end if;

          unsigned_bcd := unsigned_bcd(14 downto 0) & temp(13);
        
          temp := temp(12 downto 0) & '0';
        
        end loop;
        --convert output back to standard logic vector for use elsewhere
        bcd <= STD_LOGIC_VECTOR(unsigned_bcd(15 downto 0)); 
      end process doubledabble;  

    --Multiplexer
    Seven_Seg_Multiplexer: process (bcd, selectseg)
       begin
           case selectseg is
                when 0 => bcd_decoder <= bcd(3 downto 0); an <= "1110";
                when 1 => bcd_decoder <= bcd(7 downto 4); an <= "1101";
                when 2 => bcd_decoder <= bcd(11 downto 8); an <= "1011";
                when 3 => bcd_decoder <= bcd(15 downto 12); an <= "0111";
           end case;
       end process;  
 
    --BCD to 7seg decoder      
    decoder_7seg: process(bcd_decoder,selectseg,input) 
       begin
            if(selectseg=3) then  --negative sign handler
              case sign is
                when '1' => segout <="0111111";
                when others => segout <="1111111";
              end case;                 
            else
                case bcd_decoder is
                    when "0000" => segout <="1000000";
                    when "0001" => segout <="1111001";
                    when "0010" => segout <="0100100";
                    when "0011" => segout <="0110000";
                    when "0100" => segout <="0011001";
                    when "0101" => segout <="0010010";
                    when "0110" => segout <="0000010";
                    when "0111" => segout <="1111000";
                    when "1000" => segout <="0000000";
                    when "1001" => segout <="0010000";
                    when others => segout <="1111111";
                end case; 
            end if;
    end process;     

    --Select line clock
    clk_divider_1: clk200Hz port map (clk_in=>clk, clk_out=>seven_segment_clk);
    Seven_Seg_Select_Driver: process (seven_segment_clk)
       begin
           if rising_edge(seven_segment_clk) then
                if selectseg=3 then
                    selectseg <= 0;
                else
                    selectseg <= selectseg+1;
                end if;
           end if;

       end process;

end Behavioral;

