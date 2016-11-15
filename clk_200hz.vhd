library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk200Hz is
    Port (
        clk_in : in  STD_LOGIC;
        clk_out : out STD_LOGIC
    );
end clk200Hz;

architecture Behavioral of clk200Hz is
    signal clkout : std_logic :='0';
    signal counter : integer range 0 to 500000-1 := 0;
begin
    frequency_divider: process (clk_in) begin
        if rising_edge(clk_in) then
            if (counter = 250000-1) then
                clkout <= NOT(clkout);
                counter <= 0;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;
    
    clk_out <= clkout;
end Behavioral;


---------------------------------------------------------------------------------------------
