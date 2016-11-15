library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clock20hz is
    Port (
        clk_in : in  STD_LOGIC;
        clk_out : out STD_LOGIC
    );
end clock20hz;

architecture Behavioral of clock20hz is
    signal clkout : std_logic :='0';
    signal counter : integer range 0 to 5000000-1 := 0;
begin
    frequency_divider: process (clk_in) begin
        if rising_edge(clk_in) then
            if (counter = 5000000-1) then
                clkout <= NOT(clkout);
                counter <= 0;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;
    
    clk_out <= clkout;
end Behavioral;