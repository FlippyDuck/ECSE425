LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY processor IS
    PORT (
        clock : IN std_logic;
        reset : IN std_logic;

        inst_addr : OUT std_logic_vector(31 DOWNTO 0)
        inst_read : OUT std_logic;
        inst_readdata : IN std_logic_vector(31 DOWNTO 0)
        inst_waitrequest : IN std_logic;

        data_addr : OUT std_logic_vector(31 DOWNTO 0)
        data_read : OUT std_logic;
        data_readdata : IN std_logic_vector(31 DOWNTO 0)
        data_write : OUT std_logic;
        data_writedata : OUT std_logic_vector(31 DOWNTO 0)
        data_waitrequest : IN std_logic
    );
END processor;

ARCHITECTURE proc_arch OF processor IS

    TYPE t_register_bank IS ARRAY (31 DOWNTO 0) OF std_logic_vector(31 DOWNTO 0);

    SIGNAL register_bank : t_register_bank;

    SIGNAL fetch_stall : std_logic := '0';
    SIGNAL decode_stall : std_logic := '0';
    SIGNAL execute_stall : std_logic := '0';
    SIGNAL memory_stall : std_logic := '0';
    SIGNAL writeback_stall : std_logic := '0';

    SIGNAL program_counter : std_logic_vector(31 DOWNTO 0);
    SIGNAL instruction_register : std_logic_vector(31 DOWNTO 0);

    SIGNAL opcode : std_logic_vector(5 DOWNTO 0);
    SIGNAL 
BEGIN

    register_bank(0) <= (OTHERS => '0');

    fetch_process : PROCESS (clock)
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (reset = '1') THEN 
                program_counter <= (OTHERS => '0');
                instruction_register <= (OTHERS => '0');
            ELSE 
                inst_addr <= program_counter;
                inst_read <= '1'
                
            END IF;
        END IF;
    END PROCESS;


    decode_process : PROCESS (clock)
    BEGIN

    END PROCESS;


    execute_process : PROCESS (clock)
    BEGIN

    END PROCESS;


    memory_process : PROCESS (clock)
    BEGIN

    END PROCESS;

    
    writeback_process : PROCESS (clock)
    BEGIN

    END PROCESS;


END proc_arch;