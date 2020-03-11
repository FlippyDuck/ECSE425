LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY vmux IS 
PORT (
    a : IN std_logic_vector(31 DOWNTO 0);
    b : IN std_logic_vector(31 DOWNTO 0);
    sel : IN std_logic;
    x : OUT std_logic_vector(31 DOWNTO 0)
    );
END vmux;

ARCHITECTURE arch OF vmux IS 
BEGIN 
    x <= b WHEN sel = '1' ELSE a;
END arch;
