LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY bmux IS 
PORT (
    a : IN std_logic;
    b : IN std_logic;
    sel : IN std_logic;
    x : OUT std_logic
    );
END bmux;

ARCHITECTURE arch OF bmux IS 
BEGIN 
    x <= b WHEN sel = '1' ELSE a;
END arch;

