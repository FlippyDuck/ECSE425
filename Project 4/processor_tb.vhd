LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
USE ieee.std_logic_textio.ALL;
USE work.register_pkg.ALL;
USE work.mem_pkg.ALL;

ENTITY processor_tb IS
END processor_tb;

ARCHITECTURE behavior OF processor_tb IS
    COMPONENT processor IS
        PORT (
            clock : IN std_logic;
            reset : IN std_logic;

            inst_addr : OUT std_logic_vector(31 DOWNTO 0);
            inst_read : OUT std_logic;
            inst_readdata : IN std_logic_vector(31 DOWNTO 0);
            inst_waitrequest : IN std_logic;

            data_addr : OUT std_logic_vector(31 DOWNTO 0);
            data_read : OUT std_logic;
            data_readdata : IN std_logic_vector(31 DOWNTO 0);
            data_write : OUT std_logic;
            data_writedata : OUT std_logic_vector(31 DOWNTO 0);
            data_waitrequest : IN std_logic;

            register_output : OUT t_register_bank
        );
    END COMPONENT;

    COMPONENT cache IS
        GENERIC (
            ram_size : INTEGER := 32768
        );
        PORT (
            clock : IN std_logic;
            reset : IN std_logic;

            -- Avalon interface --
            s_addr : IN std_logic_vector (31 DOWNTO 0);
            s_read : IN std_logic;
            s_readdata : OUT std_logic_vector (31 DOWNTO 0);
            s_write : IN std_logic;
            s_writedata : IN std_logic_vector (31 DOWNTO 0);
            s_waitrequest : OUT std_logic;

            m_addr : OUT INTEGER RANGE 0 TO ram_size - 1;
            m_read : OUT std_logic;
            m_readdata : IN std_logic_vector (7 DOWNTO 0);
            m_write : OUT std_logic;
            m_writedata : OUT std_logic_vector (7 DOWNTO 0);
            m_waitrequest : IN std_logic
        );
    END COMPONENT;

    COMPONENT memory IS
        GENERIC (
            ram_size : INTEGER := 32768;
            mem_delay : TIME := 10 ns;
            clock_period : TIME := 1 ns
        );
        PORT (
            clock : IN STD_LOGIC;
            writedata : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
            address : IN INTEGER RANGE 0 TO ram_size - 1;
            memwrite : IN STD_LOGIC;
            memread : IN STD_LOGIC;
            readdata : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
            waitrequest : OUT STD_LOGIC;

            meminitializer : IN MEM (ram_size - 1 DOWNTO 0);
            memout : OUT MEM (ram_size - 1 DOWNTO 0)
        );
    END COMPONENT;

    --test signals 
    SIGNAL clk : std_logic := '0';
    CONSTANT clk_period : TIME := 1 ns;
    CONSTANT ram_size : INTEGER := 32768;

    SIGNAL rst_processor : std_logic := '0';
    SIGNAL rst_cache : std_logic := '0';

    SIGNAL register_sigs : t_register_bank;

    --processor and instruction cache signals
    SIGNAL p2ic_addr : std_logic_vector (31 DOWNTO 0);
    SIGNAL p2ic_read : std_logic;
    SIGNAL ic2p_readdata : std_logic_vector (31 DOWNTO 0);
    SIGNAL ic2p_waitrequest : std_logic;

    --processor and data cache signals
    SIGNAL p2dc_addr : std_logic_vector (31 DOWNTO 0);
    SIGNAL p2dc_read : std_logic;
    SIGNAL dc2p_readdata : std_logic_vector (31 DOWNTO 0);
    SIGNAL p2dc_write : std_logic;
    SIGNAL p2dc_writedata : std_logic_vector (31 DOWNTO 0);
    SIGNAL dc2p_waitrequest : std_logic;

    --instruction cache and instruction memory signals
    SIGNAL ic2m_addr : INTEGER RANGE 0 TO ram_size - 1;
    SIGNAL ic2m_read : std_logic;
    SIGNAL m2ic_readdata : std_logic_vector (7 DOWNTO 0);
    SIGNAL ic2m_write : std_logic;
    SIGNAL ic2m_writedata : std_logic_vector (7 DOWNTO 0);
    SIGNAL m2ic_waitrequest : std_logic;

    SIGNAL imem_initializer : MEM (ram_size - 1 DOWNTO 0);
    SIGNAL imem_out : MEM (ram_size - 1 DOWNTO 0);

    --data cache and instruction memory signals
    SIGNAL dc2m_addr : INTEGER RANGE 0 TO ram_size - 1;
    SIGNAL dc2m_read : std_logic;
    SIGNAL m2dc_readdata : std_logic_vector (7 DOWNTO 0);
    SIGNAL dc2m_write : std_logic;
    SIGNAL dc2m_writedata : std_logic_vector (7 DOWNTO 0);
    SIGNAL m2dc_waitrequest : std_logic;

    SIGNAL dmem_initializer : MEM (ram_size - 1 DOWNTO 0);
    SIGNAL dmem_out : MEM (ram_size - 1 DOWNTO 0);

    --memory IO signals
    -- SIGNAL input2im_addr: INTEGER RANGE 0 TO 32767;
    -- SIGNAL imem_addr: INTEGER RANGE 0 TO 32767;

    -- SIGNAL input2dm_addr: INTEGER RANGE 0 TO 32767;
    -- SIGNAL dmem_addr: INTEGER RANGE 0 TO 32767;

    -- SIGNAL input2im_write: std_logic;
    -- SIGNAL im_write: std_logic;

    -- SIGNAL input2im_writedata: std_logic_vector(7 downto 0);
    -- SIGNAL im_writedata: std_logic_vector(7 downto 0);

    -- SIGNAL input2dm_read: std_logic;
    -- SIGNAL dm_read: std_logic;

    -- SIGNAL input2dm_readdata: std_logic_vector(7 downto 0);
    -- SIGNAL dm_readdata: std_logic_vector(7 downto 0);

BEGIN

    dut : processor
    PORT MAP(
        clock => clk,
        reset => rst_processor,

        inst_addr => p2ic_addr,
        inst_read => p2ic_read,
        inst_readdata => ic2p_readdata,
        inst_waitrequest => ic2p_waitrequest,

        data_addr => p2dc_addr,
        data_read => p2dc_read,
        data_readdata => dc2p_readdata,
        data_write => p2dc_write,
        data_writedata => p2dc_writedata,
        data_waitrequest => dc2p_waitrequest,

        register_output => register_sigs
    );

    incache : cache
    PORT MAP(
        clock => clk,
        reset => rst_cache,

        s_addr => p2ic_addr,
        s_read => p2ic_read,
        s_readdata => ic2p_readdata,
        s_write => '0',
        s_writedata => (OTHERS => '0'),
        s_waitrequest => ic2p_waitrequest,

        m_addr => ic2m_addr,
        m_read => ic2m_read,
        m_readdata => m2ic_readdata,
        m_write => ic2m_write,
        m_writedata => ic2m_writedata,
        m_waitrequest => m2ic_waitrequest
    );

    inmem : memory
    PORT MAP(
        clock => clk,
        writedata => ic2m_writedata,
        address => ic2m_addr,
        --address => ic2m_addr,
        memwrite => ic2m_write,
        memread => ic2m_read,
        readdata => m2ic_readdata,
        waitrequest => m2ic_waitrequest,

        meminitializer => imem_initializer,
        memout => imem_out
    );

    datcache : cache
    PORT MAP(
        clock => clk,
        reset => rst_cache,

        s_addr => p2dc_addr,
        s_read => p2dc_read,
        s_readdata => dc2p_readdata,
        s_write => p2dc_write,
        s_writedata => p2dc_writedata,
        s_waitrequest => dc2p_waitrequest,

        m_addr => dc2m_addr,
        m_read => dc2m_read,
        m_readdata => m2dc_readdata,
        m_write => dc2m_write,
        m_writedata => dc2m_writedata,
        m_waitrequest => m2dc_waitrequest
    );

    datmemory : memory
    PORT MAP(
        clock => clk,
        writedata => dc2m_writedata,
        address => dc2m_addr,
        --address => dc2m_addr,
        memwrite => dc2m_write,
        memread => dc2m_read,
        readdata => m2dc_readdata,
        waitrequest => m2dc_waitrequest,

        meminitializer => dmem_initializer,
        memout => dmem_out
    );

    clk_process : PROCESS
    BEGIN
        clk <= '0';
        WAIT FOR clk_period/2;
        clk <= '1';
        WAIT FOR clk_period/2;
    END PROCESS;

    test_process : PROCESS
        CONSTANT filename : STRING := "Assembler/program.txt"; -- use more than once

        FILE file_pointer : text;
        FILE file_memory : text;
        FILE file_registers : text;

        VARIABLE line_input : line;
        VARIABLE line_vector : std_logic_vector(31 DOWNTO 0);
        VARIABLE filestatus : file_open_status;
        VARIABLE line_number : INTEGER;

        VARIABLE out_line : line;
        CONSTANT out_width : NATURAL := 32;
        VARIABLE outputline : std_logic_vector (31 DOWNTO 0);
    BEGIN

        -- imem_addr <= input2im_addr;
        -- dmem_addr <= input2dm_addr;

        -- imem_write <= input2im_write;
        -- imem_writedata <= input2im_writedata;

        -- dm_read <= input2dm_read;
        -- rst_processor <= '1';
        -- line_number := 0;
        --read from binary into and place into in cache
        file_open(filestatus, file_pointer, filename, READ_MODE);
        file_open(file_memory, "memory.txt", WRITE_MODE);
        file_open(file_registers, "register_file.txt", WRITE_MODE);

        REPORT filename & LF & HT & "file_open_status = " & file_open_status'image(filestatus);
        ASSERT filestatus = OPEN_OK REPORT "file_open_status /= file_ok" SEVERITY FAILURE; -- end simulation

        FOR i IN 0 TO 32767 LOOP
            dmem_initializer(i) <= (others => '0');
        END LOOP;

        line_number := 0;
        WHILE NOT ENDFILE (file_pointer) LOOP
            readline(file_pointer, line_input);
            REPORT line_input.ALL;
            read(line_input, line_vector);

            imem_initializer(line_number + 0) <= line_vector(7 DOWNTO 0);
            imem_initializer(line_number + 1) <= line_vector(15 DOWNTO 8);
            imem_initializer(line_number + 2) <= line_vector(23 DOWNTO 16);
            imem_initializer(line_number + 3) <= line_vector(31 DOWNTO 24);
            line_number := line_number + 1;
            -- WAIT UNTIL falling_edge(clk); -- once per clock
            -- readline (file_pointer, line_input);
            -- REPORT line_input.ALL;
            -- read (line_input, line_content);
            -- input2im_addr <= line_number * 4;
            -- input2im_writedata <= line_content (7 DOWNTO 0);
            -- input2im_write <= '1';

            -- WAIT UNTIL rising_edge(m2ic_waitrequest);
            -- ic2m_write <= '0';

            -- WAIT FOR clk_period;
            -- input2im_addr <= line_number * 4 + 1;
            -- input2im_writedata <= line_content (15 DOWNTO 8);
            -- input2im_write <= '1';

            -- WAIT UNTIL rising_edge(m2ic_waitrequest);
            -- input2im_write <= '0';

            -- WAIT FOR clk_period;
            -- input2im_addr <= line_number * 4 + 2;
            -- input2im_writedata <= line_content (23 DOWNTO 16);
            -- input2im_write <= '1';

            -- WAIT UNTIL rising_edge(m2ic_waitrequest);
            -- input2im_write <= '0';

            -- WAIT FOR clk_period;
            -- input2im_addr <= line_number * 4 + 3;
            -- input2im_writedata <= line_content (31 DOWNTO 24);
            -- input2im_write <= '1';

            -- WAIT UNTIL rising_edge(m2ic_waitrequest);
            -- input2im_write <= '0';
        END LOOP;

        WAIT UNTIL falling_edge(clk); -- the last datum can be used first
        file_close (file_pointer);
        REPORT filename & " closed.";

        --execute
        -- imem_addr <= ic2m_addr;
        -- dmem_addr <= dc2m_addr;

        -- imem_write <= ic2m_write;
        -- imem_writedata <= ic2m_writedata;

        -- dm_read <= input2dm_read;
        -- rst_processor <= '0';
        -- WAIT FOR clk_period * 10000;

        -- --output
        -- imem_addr <= input2im_addr;
        -- dmem_addr <= input2dm_addr;

        -- imem_write <= input2im_write;
        -- imem_writedata <= input2im_writedata;

        -- dm_read <= input2dm_read;

        WAIT FOR clk_period * 2;
        rst_processor <= '1';
        WAIT FOR clk_period;
        rst_processor <= '0';

        WAIT FOR clk_period * 10000;

        FOR i IN 0 TO 31 LOOP
            write(out_line, register_sigs(i));
            writeline(file_registers, out_line);
        END LOOP;

        rst_processor <= '1';
        
        FOR i IN 0 TO ram_size LOOP
            outputline(7 DOWNTO 0) := dmem_out(0);
            outputline(15 DOWNTO 8) := dmem_out(1);
            outputline(23 DOWNTO 16) := dmem_out(2);
            outputline(31 DOWNTO 24) := dmem_out(3);
            write(out_line, outputline);
            writeline(file_memory, out_line);
        END LOOP;

        -- FOR I IN 0 TO 4095 LOOP
        --     WAIT UNTIL falling_edge(clk); -- once per clock
        --     dmem_addr <= I * 4;
        --     dc2m_read <= '1';

        --     WAIT UNTIL rising_edge(m2dc_waitrequest);
        --     outputline (7 DOWNTO 0) := m2dc_readdata;
        --     dc2m_read <= '0';

        --     WAIT FOR clk_period;
        --     dmem_addr <= I * 4 + 1;
        --     dc2m_read <= '1';

        --     WAIT UNTIL rising_edge(m2dc_waitrequest);
        --     outputline (15 DOWNTO 8) := m2dc_readdata;
        --     dc2m_read <= '0';

        --     WAIT FOR clk_period;
        --     dmem_addr <= I * 4 + 2;
        --     dc2m_read <= '1';

        --     WAIT UNTIL rising_edge(m2dc_waitrequest);
        --     outputline (23 DOWNTO 16) := m2dc_readdata;
        --     dc2m_read <= '0';

        --     WAIT FOR clk_period;
        --     dmem_addr <= I * 4 + 3;
        --     dc2m_read <= '1';

        --     WAIT UNTIL rising_edge(m2dc_waitrequest);
        --     outputline (31 DOWNTO 24) := m2dc_readdata;
        --     dc2m_read <= '0';

        --     write(v_OLINE, outputline, right, c_WIDTH);
        --     writeline(file_RESULTS, v_OLINE);
        -- END LOOP;

        WAIT UNTIL falling_edge(clk);
        file_close(file_memory);
        file_close(file_registers);
        REPORT "output_results.txt closed.";
        WAIT;
    END PROCESS;

END;