library ieee;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

-- Do not modify the port map of this structure
entity comments_fsm is
port (clk : in std_logic;
      reset : in std_logic;
      input : in std_logic_vector(7 downto 0);
      output : out std_logic
  );
end comments_fsm;

architecture behavioral of comments_fsm is
    -- The ASCII value for the '/', '*' and end-of-line characters
    constant SLASH_CHARACTER : std_logic_vector(7 downto 0) := "00101111";
    constant STAR_CHARACTER : std_logic_vector(7 downto 0) := "00101010";
    constant NEW_LINE_CHARACTER : std_logic_vector(7 downto 0) := "00001010";

    -- state(0) = prev char was slash
    -- state(1) = prev char was star
    -- state(2) = inside comment
    -- state(3) = multiline comment
    signal state : std_logic_vector(3 downto 0) := "0000";
begin

    output <= state(2);
    -- Insert your processes here
    process (clk, reset)
    begin
        if (reset = '1') then 
            state <= "000";
        end if;

        if (rising_edge(clk)) then 
            if (input = SLASH_CHARACTER) then
                if (state(3) = '1' and state(1) = '1') then 
                    state <= "0000";
                elsif (state(2) = '0') then 
                    if (state(0) = '1') then 
                        state(2) <= '1';
                    else 
                        state(0) <= '1';
                    end if;
                end if;
            elsif (input = STAR_CHARACTER) then 
                if (state(0) = '1') then 
                    state(2) <= '1';
                    state(3) <= '1';
                else
                    state(1) <= '1';
                end if;
            elsif (input = NEW_LINE_CHARACTER) then 
                if (state(2) = '1' and state(3) = '0') then 
                    state <= "0000";
                end if;
            else 
                state(0) <= '0';
                state(1) <= '0';
            end if;

        end if;

    end process;

end behavioral;