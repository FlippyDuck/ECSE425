LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY cache IS
	GENERIC (
		ram_size : INTEGER := 32768;
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
END cache;

ARCHITECTURE arch OF cache IS

	-- declare signals here
	TYPE cache_data IS ARRAY (31 DOWNTO 0) OF std_logic_vector (127 DOWNTO 0);
	TYPE cache_info IS ARRAY (31 DOWNTO 0) OF std_logic_vector (7 DOWNTO 0);
	TYPE state_type IS {IDLE, MEMREAD, MEMWRITE, SENDING};
	
	SIGNAL data : cache_data;
	SIGNAL info : cache_info;

	SIGNAL read_address_reg : INTEGER RANGE 0 TO ram_size - 1;
	SIGNAL write_waitreq_reg : STD_LOGIC := '1';
	SIGNAL read_waitreq_reg : STD_LOGIC := '1';

	SIGNAL state : state_type;
BEGIN

	-- make circuits here
	cache_process : PROCESS (clock)
		VARIABLE idx : INTEGER RANGE 0 TO 31;
		VARIABLE offset : INTEGER RANGE 0 TO 3;
		VARIABLE counter : INTEGER RANGE 0 TO 3;
		VARIABLE address : INTEGER RANGE 0 TO ram_size - 1;
	BEGIN
		IF (rising_edge(clock)) THEN 
			IF (reset = '1') THEN 
				state <= IDLE;
				FOR i IN 0 TO 31 LOOP
					data(i) <= (others => '0')
					info(i) <= (others => '0')
				END LOOP;
				s_readdata <= (others => '0');
				s_waitrequest <= '1';
				m_addr <= 0;
				m_read <= '0';
				m_write <= '0';
				m_writedata <= (others => '0');
			ELSE 
				CASE state IS
				WHEN IDLE =>
					IF (s_write = '1') THEN

					ELSIF (s_read = '1') THEN 
						idx := to_integer(to_unsigned(s_addr(8 DOWNTO 4)));
						IF (info(idx)(7) = '1' AND info(idx)(5 DOWNTO 0) = s_addr(14 DOWNTO 9)) THEN 
							offset = to_integer(to_unsigned(s_addr(3 downto 2)));
							s_readdata <= data(idx)((offset * 32 + 31) DOWNTO (offset * 32));
							s_waitrequest <= '0';
							state <= SENDING;
						ELSE
							IF (info(idx)(6) = '1') THEN 

							ELSE 
								m_read <= 1;
								m_write <= 0;
								count := 0;
								address := to_integer(to_unsigned(s_addr(14 DOWNTO 0)));
								m_addr <= address;
								state <= MEMREAD
							END IF;
						END IF;
					END IF;
				WHEN MEMREAD =>
					IF (m_waitrequest = '0') THEN
						data(idx)(offset * 32 + count * 8 + 8 DOWNTO offset * 32 + count * 8) <= m_readdata;
						m_read <= '0';
						IF (count = 3) THEN 
							info(idx)(7) <= '1';
							info(idx)(6) <= '0';
							info(idx)(5 DOWNTO 0) <= s_addr(14 DOWNTO 9);
							state <= IDLE;
						ELSE 
							count := count + 1;
							m_addr <= address + count;
						END IF;
					ELSE 
						m_read <= '1';
					END IF;
				WHEN MEMWRITE => 
					IF (m_waitrequest = '0') THEN 
						IF (count = 3) THEN 
							state <= IDLE;
						ELSE
							count := count + 1;
							m_addr := address + count;
							m_writedata <= data(idx)(offset * 32 + count * 8 + 8 DOWNTO offset * 32 + count * 8);
							m_write <= '1';
						END IF;

					ELSE 
						m_write = '1';
					END IF;
				WHEN SENDING => 
					s_waitrequest <= '1';
					state <= IDLE;
				WHEN OTHERS =>
					state <= IDLE;
					FOR i IN 0 TO 31 LOOP
						data(i) <= (others => '0')
						info(i) <= (others => '0')
					END LOOP;
					s_readdata <= (others => '0');
					s_waitrequest <= '1';
					m_addr <= 0;
					m_read <= '0';
					m_write <= '0';
					m_writedata <= (others => '0');
				END CASE;
			END IF;
		END IF;
	END PROCESS;

END arch;