LIBRARY ieee;
USE IEEE.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY pipeline IS
    PORT (
        clk : IN std_logic;
        a, b, c, d, e : IN INTEGER;
        op1, op2, op3, op4, op5, final_output : OUT INTEGER
    );
END pipeline;

ARCHITECTURE behavioral OF pipeline IS
    SIGNAL reg1, reg2, reg3, reg4, reg5 : INTEGER;
BEGIN
    -- todo: complete this
    op1 <= reg1;
    op2 <= reg2;
    op3 <= reg3;
    op4 <= reg4;
    op5 <= reg5;

    PROCESS (clk)
    BEGIN
        if (rising_edge(clk)) then 
            reg1 <= a + b;
            reg2 <= reg1 * 42;
            reg3 <= c * d;
            reg4 <= a - e;
            reg5 <= reg3 * reg4;
            final_output <= reg2 - reg5;
        end if;
    END PROCESS;

END behavioral;