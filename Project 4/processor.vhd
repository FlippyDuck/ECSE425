LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE register_pkg IS 
    TYPE t_register_bank IS ARRAY (31 DOWNTO 0) OF std_logic_vector(31 DOWNTO 0);
END PACKAGE;

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.register_pkg.all;

ENTITY processor IS
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
END processor;

ARCHITECTURE proc_arch OF processor IS

    -- TYPE t_register_bank IS ARRAY (31 DOWNTO 0) OF std_logic_vector(31 DOWNTO 0);
    TYPE t_fetch_state IS (IDLE, WAITING);
    TYPE t_memory_state IS (IDLE, WAITREAD, WAITWRITE);
    -- TYPE t_operation IS (ADD, SUB, ADDI, MULT, DIV, SLT, SLTI, AND, OR, NOR, XOR, ANDI, ORI, XORI, MFHI, MFLO, LUI, SLL, SRL, SRA, LW, SW, BEQ, BNE, J, JR, JAL);

    SIGNAL register_bank : t_register_bank;
    SIGNAL register_HI : std_logic_vector(31 DOWNTO 0);
    SIGNAL register_LO : std_logic_vector(31 DOWNTO 0);

    SIGNAL fetch_stall : std_logic := '0';
    SIGNAL decode_stall : std_logic := '0';
    SIGNAL execute_stall : std_logic := '0';
    SIGNAL memory_stall : std_logic := '0';
    SIGNAL writeback_stall : std_logic := '0';

    SIGNAL count: Integer Range 0 to 4;
    --for fetching
    SIGNAL program_counter : std_logic_vector(31 DOWNTO 0);
    SIGNAL instruction_register : std_logic_vector(31 DOWNTO 0);

    SIGNAL fetch_complete : std_logic := '0';
    SIGNAL fetch_state : t_fetch_state := IDLE;
    SIGNAL if_id_instruction : std_logic_vector(31 DOWNTO 0);
    SIGNAL if_id_programcounter : std_logic_vector(31 DOWNTO 0);

    --for decoding
    SIGNAL id_ex_pc : std_logic_vector(31 DOWNTO 0);
    SIGNAL id_ex_register_s : std_logic_vector(31 DOWNTO 0);
    SIGNAL id_ex_register_t_index : Integer Range 0 to 31;
    SIGNAL id_ex_register_t : std_logic_vector(31 DOWNTO 0);
    SIGNAL id_ex_register_d_index : Integer Range 0 to 31;
    SIGNAL id_ex_opcode : std_logic_vector(5 DOWNTO 0);
    SIGNAL id_ex_immediate_zero : std_logic_vector(31 DOWNTO 0);
    SIGNAL id_ex_immediate_sign: std_logic_vector(31 DOWNTO 0);
    SIGNAL id_ex_jaddress : std_logic_vector(25 DOWNTO 0);
    SIGNAL id_ex_shamt : std_logic_vector(4 DOWNTO 0);
    SIGNAL id_ex_funct: std_logic_vector(5 DOWNTO 0);
    SIGNAL id_ex_forwardex: std_logic_vector(1 downto 0);
    
    -- SIGNAL id_ex_operation : t_operation;

    --for execute
    -- SIGNAL ex_mem_operation : t_operation;
    SIGNAL ex_mem_aluresult : std_logic_vector(31 DOWNTO 0);
    SIGNAL ex_mem_branchtaken : std_logic;
    SIGNAL ex_mem_regvalue : std_logic_vector(31 DOWNTO 0);
    SIGNAL ex_mem_writebackreg : Integer RANGE 0 TO 31;
    SIGNAL ex_mem_isWriteback: std_logic;
    SIGNAL ex_mem_opcode: std_logic_vector(5 DOWNTO 0);

    --for memory
    SIGNAL memory_state : t_memory_state;
    SIGNAL mem_wb_loaded: std_logic_vector(31 downto 0);
    SIGNAL mem_wb_writeback: std_logic_vector(31 downto 0);
    SIGNAL mem_wb_writeback_index: Integer Range 0 to 31;
    SIGNAL mem_wb_isWriteback: std_logic;
    
    -- SIGNAL mem_wb_operation : t_operation;
    
BEGIN

    register_bank(0) <= (OTHERS => '0');

    register_output <= register_bank;

    fetch_process : PROCESS (clock)
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (reset = '1') THEN
                program_counter <= (OTHERS => '0');
                instruction_register <= (OTHERS => '0');
                fetch_state<=IDLE;
                fetch_complete<='0';
                inst_read<='0';
                decode_stall<='1';
                execute_stall<='1';
                memory_stall<='1';
                writeback_stall<='1';
                count<=4;
            ELSIF (fetch_stall='0') then
                if (count=4) then                       --count variable is used in case of resets
                    decode_stall<='0';
                    count<=3;
                elsif (count = 3) then 
                    count<=2;
                    execute_stall<='0';
                elsif (count = 2) then 
                    count<=1;
                    memory_stall<='0';
                elsif (count=1) then
                    count<=0;
                    writeback_stall<='0';
                end if;
                CASE fetch_state IS
                    WHEN IDLE =>
                        inst_addr <= program_counter;
                        inst_read <= '1';
                        fetch_complete <= '0';
                        fetch_state <= WAITING;
                        if_id_programcounter <= program_counter;
                        program_counter <= std_logic_vector(unsigned(program_counter) + X"00000004");
                    WHEN WAITING =>
                        IF (ex_mem_branchtaken = '1') THEN 
                            program_counter <= ex_mem_aluresult;
                        END IF;

                        IF (inst_waitrequest = '0') THEN
                            if_id_instruction <= inst_readdata;
                            fetch_complete <= '1';
                            fetch_state <= IDLE;
                        END IF;
                END CASE;
            END IF;
        END IF;
    END PROCESS;
    
    decode_process : PROCESS (clock)
    variable id_regwriteback_ex: Integer Range 0 to 31;
    variable id_regwriteback_mem: Integer Range 0 to 31;
    --variable id_regwriteback_ex: Integer 0 to 31;
    BEGIN
        IF (rising_edge(clock)) THEN 
            if (reset = '1') THEN
                id_regwriteback_ex:=0;
                id_regwriteback_mem:=0;

                
            elsif (fetch_complete = '1' AND fetch_stall = '0') then
                id_ex_pc <= if_id_programcounter;
                
                id_ex_opcode<=instruction_register(31 downto 26);
                id_ex_register_s<=register_bank(to_integer(unsigned(instruction_register(25 downto 21))));
                id_ex_register_t_index<=to_integer(unsigned(instruction_register(20 downto 16)));
                id_ex_register_t<=register_bank(to_integer(unsigned(instruction_register(20 downto 16))));
                id_ex_register_d_index<=to_integer(unsigned(instruction_register(15 downto 11)));

                id_ex_shamt<=instruction_register(10 downto 6);
                id_ex_funct<=instruction_register(5 downto 0);

                id_ex_immediate_zero<= "0000000000000000" & instruction_register(15 downto 0);
                -- id_ex_immediate_sign<=instruction_register(15 downto 0) & instruction_register(15);
                id_ex_immediate_sign <= (others => instruction_register(15));
                id_ex_immediate_sign(15 DOWNTO 0) <= instruction_register(15 DOWNTO 0);
                id_ex_jaddress<=instruction_register(25 downto 0);
                
                --forwarding
                if(to_integer(unsigned(instruction_register(25 downto 21)))=id_regwriteback_ex) then
                    id_ex_forwardex<="01";
                elsif (to_integer(unsigned(instruction_register(20 downto 16)))=id_regwriteback_ex) then
                    id_ex_forwardex<="11";
                else
                    id_ex_forwardex<="00";
                end if;

                id_regwriteback_mem:=id_regwriteback_ex;
                id_regwriteback_ex:=to_integer(unsigned(instruction_register(15 downto 11)));
            
            else        --insert no op 
                id_ex_pc<=program_counter;
                id_ex_opcode<="000000";
                id_ex_funct<="100000";
                id_ex_shamt<="00000";

                id_ex_register_s <= (others=>'0');
                id_ex_register_t_index<=0;
                id_ex_register_t<=(others=>'0');
                id_ex_register_d_index<=0;
                
                --forwading 
                id_ex_forwardex<="00";
                id_regwriteback_mem:=id_regwriteback_ex;
                id_regwriteback_ex:=0;
            end if;

        end if;     

    END PROCESS;

    execute_process : PROCESS (clock)
        VARIABLE mult_result : std_logic_vector(63 DOWNTO 0);
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (reset = '1') THEN 
                ex_mem_aluresult <= (others => '0');
                ex_mem_branchtaken <= '0';
                ex_mem_regvalue <= (others => '0');
                ex_mem_isWriteback <= '0';
                ex_mem_opcode <= (others => '0');
            ELSIF (execute_stall = '0') THEN
                ex_mem_opcode <= id_ex_opcode;
                
                CASE id_ex_opcode IS
                WHEN "000000" =>
                    CASE id_ex_funct IS
                    WHEN "000000" => -- sll
                        ex_mem_aluresult <= std_logic_vector(shift_left(unsigned(id_ex_register_t), to_integer(unsigned(id_ex_shamt))));
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "000010" => -- srl
                        ex_mem_aluresult <= std_logic_vector(shift_right(unsigned(id_ex_register_t), to_integer(unsigned(id_ex_shamt))));
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "000011" => -- sra
                        ex_mem_aluresult <= std_logic_vector(shift_right(signed(id_ex_register_t), to_integer(unsigned(id_ex_shamt))));
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "001000" => -- jr
                        ex_mem_aluresult <= id_ex_register_s;
                        ex_mem_branchtaken <= '1';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= 0;
                        ex_mem_isWriteback <= '0';
                    WHEN "010000" => -- mfhi
                        ex_mem_aluresult <= register_HI;
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "010010" => -- mflo
                        ex_mem_aluresult <= register_LO;
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "011000" => -- mult
                        ex_mem_aluresult <= (others => '0');
                        ex_mem_branchtaken <= '0';
                        mult_result := std_logic_vector(signed(id_ex_register_s) * signed(id_ex_register_t));
                        register_HI <= mult_result(63 DOWNTO 32);
                        register_LO <= mult_result(31 DOWNTO 0);
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= 0;
                        ex_mem_isWriteback <= '0';
                    WHEN "011010" => -- div
                        ex_mem_aluresult <= (others => '0');
                        ex_mem_branchtaken <= '0';
                        register_HI <= std_logic_vector(signed(id_ex_register_s) mod signed(id_ex_register_t));
                        register_LO <= std_logic_vector(signed(id_ex_register_s) / signed(id_ex_register_t));
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= 0;
                        ex_mem_isWriteback <= '0';
                    WHEN "100000" => -- add
                        ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(id_ex_register_t));
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "100010" => -- sub
                        ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) - signed(id_ex_register_t));
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "100100" => -- and
                        ex_mem_aluresult <= id_ex_register_s AND id_ex_register_t;
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "100101" => -- or
                        ex_mem_aluresult <= id_ex_register_s OR id_ex_register_t;
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "100110" => -- xor
                        ex_mem_aluresult <= id_ex_register_s XOR id_ex_register_t;
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "100111" => -- nor
                        ex_mem_aluresult <= id_ex_register_s NOR id_ex_register_t;
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "101010" => -- slt
                        ex_mem_aluresult <= (others => '0');
                        IF (signed(id_ex_register_s) < signed(id_ex_register_t)) THEN 
                            ex_mem_aluresult(0) <= '1';
                        END IF;
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN others => 
                        ex_mem_aluresult <= (others => '0');
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= 0;
                        ex_mem_isWriteback <= '0';
                    END CASE;
                WHEN "000010" => -- j
                    ex_mem_aluresult <= (others => '0');
                    ex_mem_aluresult(25 DOWNTO 0) <= id_ex_jaddress;
                    ex_mem_branchtaken <= '1';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= 0;
                    ex_mem_isWriteback <= '0';
                WHEN "000011" => -- jal
                    ex_mem_aluresult <= (others => '0');
                    ex_mem_aluresult(25 DOWNTO 0) <= id_ex_jaddress;
                    ex_mem_branchtaken <= '1';
                    ex_mem_regvalue <= (others  => '0');
                    ex_mem_writebackreg <= 0;
                    ex_mem_isWriteback <= '0';
                    register_bank(31) <= std_logic_vector(unsigned(id_ex_pc) + to_unsigned(8, 32));
                WHEN "000100" => -- beq
                    IF (id_ex_register_s = id_ex_register_t) THEN 
                        ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + signed(id_ex_immediate_sign));
                        ex_mem_branchtaken <= '1';
                    ELSE
                        ex_mem_aluresult <= (others => '0');
                        ex_mem_branchtaken <= '0';
                    END IF;
                    ex_mem_regvalue <= (others  => '0');
                    ex_mem_writebackreg <= 0;
                    ex_mem_isWriteback <= '0';
                WHEN "000101" => -- bne
                    IF (id_ex_register_s /= id_ex_register_t) THEN 
                        ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + signed(id_ex_immediate_sign));
                        ex_mem_branchtaken <= '1';
                    ELSE
                        ex_mem_aluresult <= (others => '0');
                        ex_mem_branchtaken <= '0';
                    END IF;
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= 0;
                    ex_mem_isWriteback <= '0';
                WHEN "001000" => -- addi
                    ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(id_ex_immediate_sign));
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "001010" => -- slti
                    ex_mem_aluresult <= (others => '0');
                    IF (signed(id_ex_register_s) < signed(id_ex_immediate_sign)) THEN 
                        ex_mem_aluresult(0) <= '1';
                    END IF;
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "001100" => -- andi
                    ex_mem_aluresult <= id_ex_register_s AND id_ex_immediate_zero;
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "001101" => -- ori
                    ex_mem_aluresult <= id_ex_register_s OR id_ex_immediate_zero;
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "001110" => -- xori
                    ex_mem_aluresult <= id_ex_register_s XOR id_ex_immediate_zero;
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "001111" => -- lui
                    ex_mem_aluresult(15 DOWNTO 0) <= (others => '0');
                    ex_mem_aluresult(31 DOWNTO 16) <= id_ex_immediate_zero(15 DOWNTO 0);
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "100011" => -- lw
                    ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(id_ex_immediate_sign));
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "101011" => -- sw
                    ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(id_ex_immediate_sign));
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= id_ex_register_t;
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '0';
                WHEN others => 
                    ex_mem_aluresult <= (others => '0');
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= 0;
                    ex_mem_isWriteback <= '0';
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    memory_process : PROCESS (clock)
    BEGIN
        IF (rising_edge(clock)) THEN 
            IF (reset = '1') THEN 
                memory_state <= IDLE;
                mem_wb_loaded <= (others => '0');
                mem_wb_writeback <= (others => '0');
                mem_wb_writeback_index <= 0;
                mem_wb_isWriteback <= '0';
            ELSIF (memory_stall='0') THEN 
                mem_wb_writeback<= ex_mem_aluresult;
                mem_wb_isWriteback<= ex_mem_isWriteback;
                mem_wb_writeback_index<=ex_mem_writebackreg;

                CASE memory_state IS 
                WHEN IDLE =>
                    IF (ex_mem_opcode="100011") THEN --load
                        --mem_loaded<= get from memory [ex_mem_aluresult]
                        fetch_stall <= '1';
                        decode_stall <= '1';
                        execute_stall <= '1';
                        
                        data_addr <= ex_mem_aluresult;
                        data_read <= '1';
                        data_write <= '0';
                        data_writedata <= (others => '0');

                        memory_state <= WAITREAD;
                    ELSIF (ex_mem_opcode="101011") THEN  --store
                        --store ex_mem_regvalue into memory [ex_mem_aluresult]
                        fetch_stall <= '1';
                        decode_stall <= '1';
                        execute_stall <= '1';

                        data_addr <= ex_mem_aluresult;
                        data_read <= '0';
                        data_write <= '1';
                        data_writedata <= ex_mem_regvalue;
                        
                        memory_state <= WAITWRITE;
                    ELSE 
                        fetch_stall <= '0';
                        decode_stall <= '0';
                        execute_stall <= '0';

                        data_addr <= (others => '0');
                        data_read <= '0';
                        data_write <= '0';
                        data_writedata <= (others => '0');
                    END IF;
                WHEN WAITREAD =>
                    IF (data_waitrequest = '0') THEN 
                        mem_wb_loaded <= data_readdata;
                        memory_state <= IDLE;

                        fetch_stall <= '0';
                        decode_stall <= '0';
                        execute_stall <= '0';
                        data_addr <= (others => '0');
                        data_read <= '0';
                        data_write <= '0';
                        data_writedata <= (others => '0');
                    END IF;
                WHEN WAITWRITE => 
                    IF (data_waitrequest = '0') THEN 
                        memory_state <= IDLE;

                        fetch_stall <= '0';
                        decode_stall <= '0';
                        execute_stall <= '0';
                        data_addr <= (others => '0');
                        data_read <= '0';
                        data_write <= '0';
                        data_writedata <= (others => '0');
                    END IF;
                END CASE;                
            end if;
        end if;   

    END PROCESS;

    writeback_process : PROCESS (clock)
    BEGIN
        IF (rising_edge(clock)) THEN 
            IF (reset = '1') THEN 
                FOR i IN 0 TO 31 LOOP
                    register_bank(i) <= (others => '0');
                END LOOP;
            ELSIF (writeback_stall='0') then
                if (mem_wb_isWriteback='0') then
                    register_bank(mem_wb_writeback_index)<=mem_wb_writeback;
                end if;
            end if;
        end if;
    END PROCESS;
END proc_arch;