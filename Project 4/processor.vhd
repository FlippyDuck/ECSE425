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
    SIGNAL branch_stall : std_logic := '0';
    SIGNAL memory_stall : std_logic := '0';
    SIGNAL writeback_stall : std_logic := '0';

    --for fetching
    SIGNAL program_counter : std_logic_vector(31 DOWNTO 0);
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

    --for executing
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
    SIGNAL mem_waiting : std_logic;

    --for forwarding / hazard detection
    SIGNAL id_ex_forwarding :  std_logic_vector(5 downto 0);     -- 'hazard in s''ex_mem or mem_wr''empty for now' repeat for t  
    SIGNAL ex_mem_forwarding :  std_logic_vector(5 downto 0);    --uneeded unless account for writes 
    Signal id_repeat: std_logic;
    Signal load_stall : std_logic;
    
BEGIN

    register_bank(0) <= (OTHERS => '0');                --$0 hardcoded to 0
    register_output <= register_bank;                   --output registers for testbench

    --fetch the instruction from cache or mem
    fetch_process : PROCESS (clock)
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (reset = '1') THEN
                program_counter <= (OTHERS => '0');
                if_id_instruction <= "00000000000000000000000000100000";
                --instruction_register <= (OTHERS => '0');
                fetch_state<=IDLE;
                fetch_complete<='0';
                inst_read<='0';
                -- decode_stall<='1';
                -- execute_stall<='1';
                -- memory_stall<='1';
                -- writeback_stall<='1';
                -- count_rst<=4;
            ELSIF (mem_waiting = '1') THEN          --stall when waiting for mem
            ELSIF (load_stall= '1') then
            ELSIF (fetch_stall='0') then
                
                CASE fetch_state IS
                    --Idle when preparing to get new command, set signals to interact with iCache and change PC
                    WHEN IDLE =>
                        IF (branch_stall = '1') THEN             
                            program_counter <= ex_mem_aluresult;
                        END IF;
                        inst_addr <= program_counter;
                        inst_read <= '1';
                        fetch_complete <= '0';
                        decode_stall <= '1';
                        fetch_state <= WAITING;
                        if_id_programcounter <= program_counter;
                        IF (branch_stall = '0') THEN 
                            program_counter <= std_logic_vector(unsigned(program_counter) + X"00000004");
                        END IF;
                    
                    --Waiting for cache to send instruction then propagate it to decode
                    WHEN WAITING =>
                        IF (branch_stall = '1') THEN 
                            program_counter <= ex_mem_aluresult;
                            --binst <= ex_mem_aluresult;
                        END IF;

                        IF (inst_waitrequest = '0') THEN
                            if_id_instruction <= inst_readdata;
                            fetch_complete <= '1';
                            decode_stall <= '0';
                            inst_read <= '0';
                            fetch_state <= IDLE;
                        END IF;
                END CASE;
            END IF;
        END IF;
    END PROCESS;
    
    --decode instruction for execute stage
    decode_process : PROCESS (clock)
    
    variable id_regwriteback_ex: std_logic_vector (5 downto 0);     -- 5-1 is reg index and 0 is if load
    variable id_regwriteback_mem: std_logic_vector (5 downto 0);
    
    BEGIN
        IF (rising_edge(clock)) THEN 
            if (reset = '1') THEN
                id_ex_pc<=program_counter;
                id_ex_opcode<="000000";
                id_ex_funct<="100000";
                id_ex_shamt<="00000";

                id_ex_register_s <= (others=>'0');
                id_ex_register_t_index<=0;
                id_ex_register_t<=(others=>'0');
                id_ex_register_d_index<=0;
                
                --forwading 
                id_ex_forwarding<= (others => '0');
                id_regwriteback_mem:=(others => '0');
                id_regwriteback_ex:= (others => '0');
                id_repeat<='0';
                load_stall<='0';
            ELSIF (mem_waiting = '1') THEN                  --if memory write or read then stall until complete
            ELSIF (load_stall= '1') then
                load_stall <= '0';
            --update register for execute stage to use and check for data hazards
            elsif (fetch_complete = '1' AND decode_stall = '0') then
                execute_stall <= '0';
                id_ex_pc <= if_id_programcounter;
                
                id_ex_opcode<=if_id_instruction(31 downto 26);
                id_ex_register_s<=register_bank(to_integer(unsigned(if_id_instruction(25 downto 21))));
                id_ex_register_t_index<=to_integer(unsigned(if_id_instruction(20 downto 16)));
                id_ex_register_t<=register_bank(to_integer(unsigned(if_id_instruction(20 downto 16))));
                id_ex_register_d_index<=to_integer(unsigned(if_id_instruction(15 downto 11)));

                id_ex_shamt<=if_id_instruction(10 downto 6);
                id_ex_funct<=if_id_instruction(5 downto 0);

                id_ex_immediate_zero<= "0000000000000000" & if_id_instruction(15 downto 0);
                -- id_ex_immediate_sign<=instruction_register(15 downto 0) & instruction_register(15);
                id_ex_immediate_sign <= (others => if_id_instruction(15));
                id_ex_immediate_sign(15 DOWNTO 0) <= if_id_instruction(15 DOWNTO 0);
                id_ex_jaddress<=if_id_instruction(25 downto 0);
                
                --forwarding

                --requires s
                --ADD, ADDI, AND, ANDI, BEQ, BNE, DIV, JR, LW, MULT, OR, ORI, SLT, SLTI, SUB, SW, XOR, XORI, NOR    , for sw s is address and t is value
                
                --requires t
                --ADD, AND, BEQ, BNE, DIV, MULT, OR, SLL, SLT, SRL, SRA, SUB, SW, XOR, NOR

                if(if_id_instruction(25 downto 21)=id_regwriteback_ex(5 downto 1)) then           --potential hazard in s
                    if (id_regwriteback_ex(5 downto 1)="00000") then                                --ignore non write backs
                        id_ex_forwarding (5 downto 3) <= "000";
                    --ADDI, ANDI, ORI, SLTI, XORI, LW, beq, bne, sw,    jr, mult, div, add, and, or, slt, sub, xor,  
                    elsif ((if_id_instruction(31 downto 26)="001000")or (if_id_instruction(31 downto 26)="001100") or (if_id_instruction(31 downto 26)="100011") or 
                        (if_id_instruction(31 downto 26)="001101")or (if_id_instruction(31 downto 26)="001010") or (if_id_instruction(31 downto 26)="100011") or 
                        (if_id_instruction(31 downto 26)="000100")or (if_id_instruction(31 downto 26)="000101") or (if_id_instruction(31 downto 26)="101011") or 
                        ((if_id_instruction(31 downto 26)="000000")and ((if_id_instruction(5 downto 0)="001000") or (if_id_instruction(5 downto 0)="011000") or
                        (if_id_instruction(5 downto 0)="011010") or (if_id_instruction(5 downto 0)="100000") or (if_id_instruction(5 downto 0)="100100") or 
                        (if_id_instruction(5 downto 0)="100101") or (if_id_instruction(5 downto 0)="101010") or (if_id_instruction(5 downto 0)="100010") or 
                        (if_id_instruction(5 downto 0)="101000") or (if_id_instruction(5 downto 0)="100111")) )) then
                        if (id_regwriteback_ex(0)='1') then
                            --load_stall<='1';
                            id_ex_forwarding (5 downto 3) <= "000"; 
                            id_ex_register_s<=mem_wb_writeback;
                        else
                            id_ex_forwarding (5 downto 3) <= "100";         --s hazard get from ex_mem
                        end if;
                        --modify signal
                        --id_ex_forwarding (5 downto 3) <= "100";         --s hazard get from ex_mem
                    else 
                        --modify signal
                        id_ex_forwarding (5 downto 3) <= "000";
                    end if;
                
                -- elsif (if_id_instruction(25 downto 21)=id_regwriteback_mem(5 downto 1)) then
                --     if (id_regwriteback_mem(5 downto 1)="00000") then 
                --         id_ex_forwarding (5 downto 3) <= "000";
                --     elsif ((if_id_instruction(31 downto 26)="001000")or (if_id_instruction(31 downto 26)="001100") or (if_id_instruction(31 downto 26)="100011") or 
                --         (if_id_instruction(31 downto 26)="001101")or (if_id_instruction(31 downto 26)="001010") or (if_id_instruction(31 downto 26)="100011") or 
                --         (if_id_instruction(31 downto 26)="000100")or (if_id_instruction(31 downto 26)="000101") or (if_id_instruction(31 downto 26)="101011") or 
                --         ((if_id_instruction(31 downto 26)="000000")and ((if_id_instruction(5 downto 0)="001000") or (if_id_instruction(5 downto 0)="011000") or
                --         (if_id_instruction(5 downto 0)="011010") or (if_id_instruction(5 downto 0)="100000") or (if_id_instruction(5 downto 0)="100100") or 
                --         (if_id_instruction(5 downto 0)="100101") or (if_id_instruction(5 downto 0)="101010") or (if_id_instruction(5 downto 0)="100010") or 
                --         (if_id_instruction(5 downto 0)="101000") or (if_id_instruction(5 downto 0)="100111")) )) then

                --         --modify signal
                --         id_ex_forwarding (5 downto 3) <= "110";     --s hazard get from mem_wr
                --     else 
                --         --modify signal
                --         id_ex_forwarding (5 downto 3) <= "000";
                --     end if;
                else
                     --modify signal
                    id_ex_forwarding (5 downto 3) <= "000";
                end if;

                if (if_id_instruction(20 downto 16)=id_regwriteback_ex(5 downto 1)) then       --potential hazard in t
                    if (id_regwriteback_ex(5 downto 1)="00000") then 
                        id_ex_forwarding (2 downto 0) <= "000";
                
                    --beq, bne, sw,   mult, div, add, and, or, slt, sub, xor, nor, sll, srl, sra 
                    elsif ((if_id_instruction(31 downto 26)="000100") or (if_id_instruction(31 downto 26)="000101") or (if_id_instruction(31 downto 26)="101011") or 
                        ((if_id_instruction(31 downto 26)="000000")and ((if_id_instruction(5 downto 0)="011000") or (if_id_instruction(5 downto 0)="011010") or 
                        (if_id_instruction(5 downto 0)="100000") or (if_id_instruction(5 downto 0)="100100") or (if_id_instruction(5 downto 0)="100101") or 
                        (if_id_instruction(5 downto 0)="101010") or (if_id_instruction(5 downto 0)="100010") or (if_id_instruction(5 downto 0)="101000") or 
                        (if_id_instruction(5 downto 0)="100111") or (if_id_instruction(5 downto 0)="000000") or (if_id_instruction(5 downto 0)="000010") or
                        (if_id_instruction(5 downto 0)="000011")) )) then
                        if (id_regwriteback_ex(0)='1') then
                            id_ex_forwarding (2 downto 0) <= "000";         --t hazard get from ex_mem
                            id_ex_register_t<=mem_wb_writeback;
                            --load_stall<='1';
                        else
                            id_ex_forwarding (2 downto 0) <= "100";         --t hazard get from ex_mem
                        end if;
                        --modify signal
                        --id_ex_forwarding (2 downto 0) <= "100";         --t hazard get from ex_mem
                    else 
                        --modify signal
                        id_ex_forwarding (2 downto 0) <= "000";
                    end if;
                

                -- elsif (if_id_instruction(20 downto 16)=id_regwriteback_mem(5 downto 1)) then
                --     if (id_regwriteback_mem(5 downto 1)="00000") then 
                --         id_ex_forwarding (2 downto 0) <= "000";
                    
                --     elsif ((if_id_instruction(31 downto 26)="000100") or (if_id_instruction(31 downto 26)="000101") or (if_id_instruction(31 downto 26)="101011") or 
                --         ((if_id_instruction(31 downto 26)="000000")and ((if_id_instruction(5 downto 0)="011000") or (if_id_instruction(5 downto 0)="011010") or 
                --         (if_id_instruction(5 downto 0)="100000") or (if_id_instruction(5 downto 0)="100100") or (if_id_instruction(5 downto 0)="100101") or 
                --         (if_id_instruction(5 downto 0)="101010") or (if_id_instruction(5 downto 0)="100010") or (if_id_instruction(5 downto 0)="101000") or 
                --         (if_id_instruction(5 downto 0)="100111") or (if_id_instruction(5 downto 0)="000000") or (if_id_instruction(5 downto 0)="000010") or
                --         (if_id_instruction(5 downto 0)="000011")) )) then

                --         --modify signal
                --         id_ex_forwarding (2 downto 0) <= "110";         --t hazard get from mem_wr
                --     else 
                --         id_ex_forwarding (2 downto 0) <= "000";
                --         --modify signal
                --     end if;
                else 
                    --modify signal
                    id_ex_forwarding (2 downto 0) <= "000";
                end if;
                
                --id_ex_forwarding  -- 'get s','from',for','get t', 'from', 'for', 31-27 are write back reg, 26 is replace in exe 0 or mem 1  
                --ex_mem_forwarding  -- 31-27 are write back reg, 26 is replace in exe 0 or mem 1 


                id_regwriteback_mem:=id_regwriteback_ex;
                if (id_repeat='0') then
                    --writeback to t,       ADDI, ANDI, ORI, SLTI, XORI, LUI
                    if ((if_id_instruction(31 downto 26)="001000")or (if_id_instruction(31 downto 26)="001100") or (if_id_instruction(31 downto 26)="001110") or 
                        (if_id_instruction(31 downto 26)="001101")or (if_id_instruction(31 downto 26)="001010") or (if_id_instruction(31 downto 26)="001111")) then

                        id_regwriteback_ex (5 downto 1):=if_id_instruction(20 downto 16);
                        id_regwriteback_ex (0):='0';
                    
                    --writeback to t and LW
                    elsif (if_id_instruction(31 downto 26)="100011") then 
                        id_regwriteback_ex (5 downto 1):=if_id_instruction(20 downto 16);
                        id_regwriteback_ex (0):='1';

                    --write back to d,      ADD, AND, MFHI, MFLO, OR, SLL, SLT, SRL, SRA, SUB, XOR, NOR
                    elsif ((if_id_instruction(31 downto 26)="000000") and (if_id_instruction(5 downto 0)/="001000") and (if_id_instruction(5 downto 0)/="011000") and
                        (if_id_instruction(5 downto 0)/="011010")) then                              
                        
                        id_regwriteback_ex(5 downto 1) :=if_id_instruction(15 downto 11);
                        id_regwriteback_ex (0):='0';

                    elsif (if_id_instruction(31 downto 26)="000011") then                             --write back to R31,    JAL 
                        id_regwriteback_ex(5 downto 1):= "11111";
                        id_regwriteback_ex (0):='0';
                    else
                        id_regwriteback_ex:=(others => '0');
                    end if;
                end if;
                id_repeat<='1';
            
            else        --insert stall if fetch not yet complete
                -- id_ex_pc<=program_counter;
                -- id_ex_opcode<="000000";
                -- id_ex_funct<="100000";
                -- id_ex_shamt<="00000";

                -- id_ex_register_s <= (others=>'0');
                -- id_ex_register_t_index<=0;
                -- id_ex_register_t<=(others=>'0');
                -- id_ex_register_d_index<=0;
                
                -- --forwading 
                -- id_ex_forwardex<="00";
                -- id_regwriteback_mem:=id_regwriteback_ex;
                -- id_regwriteback_ex:=0;
                execute_stall <= '1';
                id_repeat<='0';
            end if;

        end if;     
    END PROCESS;

    --execute commands 
    execute_process : PROCESS (clock)
        VARIABLE mult_result : std_logic_vector(63 DOWNTO 0);
        variable bcount: std_logic;
    BEGIN
        IF (rising_edge(clock)) THEN
            IF (reset = '1' or execute_stall = '1') THEN 
                IF (mem_waiting = '1') THEN 
                    memory_stall <= '0';
                else 
                    memory_stall <= '1';
                end if;
                --ex_mem_aluresult <= (others => '0');
                --ex_mem_branchtaken <= '0';
                ex_mem_regvalue <= (others => '0');
                ex_mem_isWriteback <= '0';
                ex_mem_opcode <= (others => '0');
                --bcount :='0';
            ELSIF (mem_waiting = '1') THEN                      --if read or write then stall until done
            ELSIF (load_stall = '1') THEN      
            --this is used to flush instructions after a successful branch taken
            ELSIF (execute_stall = '0' AND branch_stall = '1') THEN 
                if (bcount='1') then
                    branch_stall <='0';
                    bcount :='0';
                else
                    branch_stall <= '1';
                    bcount :='1';
                end if;
                
            --populate registers and execute commands based on op code and function, branch target resolution occurs here
            ELSIF (execute_stall = '0') THEN
                memory_stall <= '0';
                ex_mem_opcode <= id_ex_opcode;
                
                CASE id_ex_opcode IS
                WHEN "000000" =>
                    CASE id_ex_funct IS
                    WHEN "000000" => -- sll
                        if (id_ex_forwarding(2 downto 0)="100") then
                            ex_mem_aluresult <= std_logic_vector(shift_left(unsigned(ex_mem_aluresult), to_integer(unsigned(id_ex_shamt))));
                        elsif (id_ex_forwarding(2 downto 0)="110") then
                            ex_mem_aluresult <= std_logic_vector(shift_left(unsigned(mem_wb_writeback), to_integer(unsigned(id_ex_shamt))));
                        else 
                            ex_mem_aluresult <= std_logic_vector(shift_left(unsigned(id_ex_register_t), to_integer(unsigned(id_ex_shamt))));
                        end if;
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "000010" => -- srl
                        if (id_ex_forwarding(2 downto 0)="100") then
                            ex_mem_aluresult <= std_logic_vector(shift_right(unsigned(ex_mem_aluresult), to_integer(unsigned(id_ex_shamt))));
                        elsif (id_ex_forwarding(2 downto 0)="110") then
                            ex_mem_aluresult <= std_logic_vector(shift_right(unsigned(mem_wb_writeback), to_integer(unsigned(id_ex_shamt))));
                        else 
                            ex_mem_aluresult <= std_logic_vector(shift_right(unsigned(id_ex_register_t), to_integer(unsigned(id_ex_shamt))));
                        end if;
                        
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "000011" => -- sra
                        if (id_ex_forwarding(2 downto 0)="100") then
                            ex_mem_aluresult <= std_logic_vector(shift_right(signed(ex_mem_aluresult), to_integer(unsigned(id_ex_shamt))));
                        elsif (id_ex_forwarding(2 downto 0)="110") then
                            ex_mem_aluresult <= std_logic_vector(shift_right(signed(mem_wb_writeback), to_integer(unsigned(id_ex_shamt))));
                        else 
                            ex_mem_aluresult <= std_logic_vector(shift_right(signed(id_ex_register_t), to_integer(unsigned(id_ex_shamt))));
                        end if;
                        
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "001000" => -- jr
                        if (id_ex_forwarding(5 downto 3)="100") then
                            ex_mem_aluresult <= ex_mem_aluresult;
                        elsif (id_ex_forwarding(5 downto 3)="110") then
                            ex_mem_aluresult <= mem_wb_writeback;
                        else 
                            ex_mem_aluresult <= id_ex_register_s;
                        end if;

                        ex_mem_branchtaken <= '1';
                        branch_stall<= '1';
                        bcount :='0';
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
                        if (id_ex_forwarding="100000") then             --replace s from ex
                            mult_result := std_logic_vector(signed(ex_mem_aluresult) * signed(id_ex_register_t));
                        elsif (id_ex_forwarding="110000") then          --replace s from mem
                            mult_result := std_logic_vector(signed(mem_wb_writeback) * signed(id_ex_register_t));
                        elsif (id_ex_forwarding="000100") then          --replace t from ex
                            mult_result := std_logic_vector(signed(id_ex_register_s) * signed(ex_mem_aluresult));
                        elsif (id_ex_forwarding="000110") then          --replace t from mem
                            mult_result := std_logic_vector(signed(id_ex_register_s) * signed(mem_wb_writeback));
                        elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                            mult_result := std_logic_vector(signed(ex_mem_aluresult) * signed(ex_mem_aluresult));
                        elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                            mult_result := std_logic_vector(signed(mem_wb_writeback) * signed(mem_wb_writeback));
                        elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                            mult_result := std_logic_vector(signed(ex_mem_aluresult) * signed(mem_wb_writeback)); 
                        elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                            mult_result := std_logic_vector(signed(mem_wb_writeback) * signed(ex_mem_aluresult)); 
                        else 
                            mult_result := std_logic_vector(signed(id_ex_register_s) * signed(id_ex_register_t));
                        end if;
                        register_HI <= mult_result(63 DOWNTO 32);
                        register_LO <= mult_result(31 DOWNTO 0);
                        ex_mem_aluresult <= (others => '0');
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= 0;
                        ex_mem_isWriteback <= '0';
                    WHEN "011010" => -- div
                        if (id_ex_forwarding="100000") then             --replace s from ex
                            register_HI <= std_logic_vector(signed(ex_mem_aluresult) mod signed(id_ex_register_t));
                            register_LO <= std_logic_vector(signed(ex_mem_aluresult) / signed(id_ex_register_t)); 
                        elsif (id_ex_forwarding="110000") then          --replace s from mem
                            register_HI <= std_logic_vector(signed(mem_wb_writeback) mod signed(id_ex_register_t));
                            register_LO <= std_logic_vector(signed(mem_wb_writeback) / signed(id_ex_register_t)); 
                        elsif (id_ex_forwarding="000100") then          --replace t from ex
                            register_HI <= std_logic_vector(signed(id_ex_register_s) mod signed(ex_mem_aluresult));
                            register_LO <= std_logic_vector(signed(id_ex_register_s) / signed(ex_mem_aluresult)); 
                        elsif (id_ex_forwarding="000110") then          --replace t from mem
                            register_HI <= std_logic_vector(signed(id_ex_register_s) mod signed(mem_wb_writeback));
                            register_LO <= std_logic_vector(signed(id_ex_register_s) / signed(mem_wb_writeback)); 
                        elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                            register_HI <= std_logic_vector(signed(ex_mem_aluresult) mod signed(ex_mem_aluresult));
                            register_LO <= std_logic_vector(signed(ex_mem_aluresult) / signed(ex_mem_aluresult)); 
                        elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                            register_HI <= std_logic_vector(signed(mem_wb_writeback) mod signed(mem_wb_writeback));
                            register_LO <= std_logic_vector(signed(mem_wb_writeback) / signed(mem_wb_writeback)); 
                        elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                            register_HI <= std_logic_vector(signed(ex_mem_aluresult) mod signed(mem_wb_writeback));
                            register_LO <= std_logic_vector(signed(ex_mem_aluresult) / signed(mem_wb_writeback)); 
                        elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                            register_HI <= std_logic_vector(signed(mem_wb_writeback) mod signed(ex_mem_aluresult));
                            register_LO <= std_logic_vector(signed(mem_wb_writeback) / signed(ex_mem_aluresult));
                        else 
                            register_HI <= std_logic_vector(signed(id_ex_register_s) mod signed(id_ex_register_t));
                            register_LO <= std_logic_vector(signed(id_ex_register_s) / signed(id_ex_register_t));
                        end if;

                        ex_mem_aluresult <= (others => '0');
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= 0;
                        ex_mem_isWriteback <= '0';
                    WHEN "100000" => -- add
                        if (id_ex_forwarding="100000") then             --replace s from ex
                            ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) + signed(id_ex_register_t));
                        elsif (id_ex_forwarding="110000") then          --replace s from mem
                            ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) + signed(id_ex_register_t)); 
                        elsif (id_ex_forwarding="000100") then          --replace t from ex
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(ex_mem_aluresult)); 
                        elsif (id_ex_forwarding="000110") then          --replace t from mem
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(mem_wb_writeback)); 
                        elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                            ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) + signed(ex_mem_aluresult)); 
                        elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                            ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) + signed(mem_wb_writeback)); 
                        elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                            ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) + signed(mem_wb_writeback));
                        elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                            ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) + signed(ex_mem_aluresult));
                        else 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(id_ex_register_t));
                        end if;

                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "100010" => -- sub
                        if (id_ex_forwarding="100000") then             --replace s from ex
                            ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) - signed(id_ex_register_t));
                        elsif (id_ex_forwarding="110000") then          --replace s from mem
                            ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) - signed(id_ex_register_t)); 
                        elsif (id_ex_forwarding="000100") then          --replace t from ex
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) - signed(ex_mem_aluresult)); 
                        elsif (id_ex_forwarding="000110") then          --replace t from mem
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) - signed(mem_wb_writeback)); 
                        elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                            ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) - signed(ex_mem_aluresult)); 
                        elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                            ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) - signed(mem_wb_writeback)); 
                        elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                            ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) - signed(mem_wb_writeback));
                        elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                            ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) - signed(ex_mem_aluresult));
                        else 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) - signed(id_ex_register_t));
                        end if;
                        
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "100100" => -- and
                        if (id_ex_forwarding="100000") then             --replace s from ex
                            ex_mem_aluresult <= ex_mem_aluresult AND id_ex_register_t;
                        elsif (id_ex_forwarding="110000") then          --replace s from mem
                            ex_mem_aluresult <= mem_wb_writeback AND id_ex_register_t;
                        elsif (id_ex_forwarding="000100") then          --replace t from ex
                            ex_mem_aluresult <= id_ex_register_s AND ex_mem_aluresult;
                        elsif (id_ex_forwarding="000110") then          --replace t from mem
                            ex_mem_aluresult <= id_ex_register_s AND mem_wb_writeback; 
                        elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                            ex_mem_aluresult <= ex_mem_aluresult AND ex_mem_aluresult; 
                        elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                            ex_mem_aluresult <= mem_wb_writeback AND mem_wb_writeback;
                        elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                            ex_mem_aluresult <= ex_mem_aluresult AND mem_wb_writeback;
                        elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                            ex_mem_aluresult <= mem_wb_writeback AND ex_mem_aluresult;
                        else 
                            ex_mem_aluresult <= id_ex_register_s AND id_ex_register_t;
                        end if;

                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "100101" => -- or
                        if (id_ex_forwarding="100000") then             --replace s from ex
                            ex_mem_aluresult <= ex_mem_aluresult OR id_ex_register_t;
                        elsif (id_ex_forwarding="110000") then          --replace s from mem
                            ex_mem_aluresult <= mem_wb_writeback OR id_ex_register_t;
                        elsif (id_ex_forwarding="000100") then          --replace t from ex
                            ex_mem_aluresult <= id_ex_register_s OR ex_mem_aluresult;
                        elsif (id_ex_forwarding="000110") then          --replace t from mem
                            ex_mem_aluresult <= id_ex_register_s OR mem_wb_writeback; 
                        elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                            ex_mem_aluresult <= ex_mem_aluresult OR ex_mem_aluresult; 
                        elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                            ex_mem_aluresult <= mem_wb_writeback OR mem_wb_writeback;
                        elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                            ex_mem_aluresult <= ex_mem_aluresult OR mem_wb_writeback;
                        elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                            ex_mem_aluresult <= mem_wb_writeback OR ex_mem_aluresult;
                        else 
                            ex_mem_aluresult <= id_ex_register_s OR id_ex_register_t;
                        end if;

                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "101000" => -- xor                                                 --assembler error should be 100110
                        if (id_ex_forwarding="100000") then             --replace s from ex
                            ex_mem_aluresult <= ex_mem_aluresult xor id_ex_register_t;
                        elsif (id_ex_forwarding="110000") then          --replace s from mem
                            ex_mem_aluresult <= mem_wb_writeback xor id_ex_register_t;
                        elsif (id_ex_forwarding="000100") then          --replace t from ex
                            ex_mem_aluresult <= id_ex_register_s xor ex_mem_aluresult;
                        elsif (id_ex_forwarding="000110") then          --replace t from mem
                            ex_mem_aluresult <= id_ex_register_s xor mem_wb_writeback; 
                        elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                            ex_mem_aluresult <= ex_mem_aluresult xor ex_mem_aluresult; 
                        elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                            ex_mem_aluresult <= mem_wb_writeback xor mem_wb_writeback;
                        elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                            ex_mem_aluresult <= ex_mem_aluresult xor mem_wb_writeback;
                        elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                            ex_mem_aluresult <= mem_wb_writeback xor ex_mem_aluresult;
                        else 
                            ex_mem_aluresult <= id_ex_register_s xor id_ex_register_t;
                        end if;

                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "100111" => -- nor
                        if (id_ex_forwarding="100000") then             --replace s from ex
                            ex_mem_aluresult <= ex_mem_aluresult NOR id_ex_register_t;
                        elsif (id_ex_forwarding="110000") then          --replace s from mem
                            ex_mem_aluresult <= mem_wb_writeback NOR id_ex_register_t;
                        elsif (id_ex_forwarding="000100") then          --replace t from ex
                            ex_mem_aluresult <= id_ex_register_s NOR ex_mem_aluresult;
                        elsif (id_ex_forwarding="000110") then          --replace t from mem
                            ex_mem_aluresult <= id_ex_register_s NOR mem_wb_writeback; 
                        elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                            ex_mem_aluresult <= ex_mem_aluresult NOR ex_mem_aluresult; 
                        elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                            ex_mem_aluresult <= mem_wb_writeback NOR mem_wb_writeback;
                        elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                            ex_mem_aluresult <= ex_mem_aluresult NOR mem_wb_writeback;
                        elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                            ex_mem_aluresult <= mem_wb_writeback NOR ex_mem_aluresult;
                        else 
                            ex_mem_aluresult <= id_ex_register_s NOR id_ex_register_t;
                        end if;
                        
                        ex_mem_branchtaken <= '0';
                        ex_mem_regvalue <= (others => '0');
                        ex_mem_writebackreg <= id_ex_register_d_index;
                        ex_mem_isWriteback <= '1';
                    WHEN "101010" => -- slt
                        if (id_ex_forwarding="100000") then             --replace s from ex
                            IF (signed(ex_mem_aluresult) < signed(id_ex_register_t)) THEN 
                                ex_mem_aluresult <= (others => '0');
                                ex_mem_aluresult(0) <= '1';
                            else 
                                ex_mem_aluresult <= (others => '0');
                            END IF;
                        elsif (id_ex_forwarding="110000") then          --replace s from mem
                            IF (signed(mem_wb_writeback) < signed(id_ex_register_t)) THEN 
                                ex_mem_aluresult <= (others => '0');
                                ex_mem_aluresult(0) <= '1';
                            else 
                                ex_mem_aluresult <= (others => '0');
                            END IF;
                        elsif (id_ex_forwarding="000100") then          --replace t from ex
                            IF (signed(id_ex_register_s) < signed(ex_mem_aluresult)) THEN 
                                ex_mem_aluresult <= (others => '0');
                                ex_mem_aluresult(0) <= '1';
                            else 
                                ex_mem_aluresult <= (others => '0');
                            END IF;
                        elsif (id_ex_forwarding="000110") then          --replace t from mem
                            IF (signed(id_ex_register_s) < signed(mem_wb_writeback)) THEN 
                                ex_mem_aluresult <= (others => '0');
                                ex_mem_aluresult(0) <= '1';
                            else 
                                ex_mem_aluresult <= (others => '0');
                            END IF;
                        elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                            IF (signed(ex_mem_aluresult) < signed(ex_mem_aluresult)) THEN 
                                ex_mem_aluresult <= (others => '0');
                                ex_mem_aluresult(0) <= '1';
                            else 
                                ex_mem_aluresult <= (others => '0');
                            END IF;
                        elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                            IF (signed(mem_wb_writeback) < signed(mem_wb_writeback)) THEN 
                                ex_mem_aluresult <= (others => '0');
                                ex_mem_aluresult(0) <= '1';
                            else 
                                ex_mem_aluresult <= (others => '0');
                            END IF;
                        elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                            IF (signed(ex_mem_aluresult) < signed(mem_wb_writeback)) THEN 
                                ex_mem_aluresult <= (others => '0');
                                ex_mem_aluresult(0) <= '1';
                            else 
                                ex_mem_aluresult <= (others => '0');
                            END IF;
                        elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                            IF (signed(mem_wb_writeback) < signed(ex_mem_aluresult)) THEN 
                                ex_mem_aluresult <= (others => '0');
                                ex_mem_aluresult(0) <= '1';
                            else 
                                ex_mem_aluresult <= (others => '0');
                            END IF;
                        else 
                            IF (signed(id_ex_register_s) < signed(id_ex_register_t)) THEN 
                                ex_mem_aluresult <= (others => '0');
                                ex_mem_aluresult(0) <= '1';
                            else 
                                ex_mem_aluresult <= (others => '0');
                            END IF;
                        end if;


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
                    ex_mem_aluresult(25 DOWNTO 0) <= std_logic_vector(shift_left(signed(id_ex_jaddress),2));
                    ex_mem_branchtaken <= '1';
                    branch_stall<= '1';
                    bcount :='0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= 0;
                    ex_mem_isWriteback <= '0';
                WHEN "000011" => -- jal
                    ex_mem_aluresult <= (others => '0');
                    ex_mem_aluresult(25 DOWNTO 0) <= std_logic_vector(shift_left(signed(id_ex_jaddress),2));    --pc +8 because of branch delay slot
                    ex_mem_branchtaken <= '1';
                    branch_stall<= '1';
                    bcount :='0';
                    ex_mem_regvalue <= std_logic_vector(unsigned(id_ex_pc) + to_unsigned(8, 32));
                    ex_mem_writebackreg <= 31;
                    ex_mem_isWriteback <= '1';
                    -- register_bank(31) <= std_logic_vector(unsigned(id_ex_pc) + to_unsigned(8, 32));
                WHEN "000100" => -- beq
                    if (id_ex_forwarding="100000") then             --replace s from ex
                        IF (ex_mem_aluresult = id_ex_register_t) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="110000") then          --replace s from mem
                        IF (mem_wb_writeback = id_ex_register_t) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="000100") then          --replace t from ex
                        IF (id_ex_register_s = ex_mem_aluresult) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="000110") then          --replace t from mem
                        IF (id_ex_register_s = mem_wb_writeback) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                        IF (ex_mem_aluresult = ex_mem_aluresult) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                        IF (mem_wb_writeback = mem_wb_writeback) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                        IF (ex_mem_aluresult = mem_wb_writeback) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                        IF (mem_wb_writeback = ex_mem_aluresult) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    else 
                        IF (id_ex_register_s = id_ex_register_t) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    end if;

                    ex_mem_regvalue <= (others  => '0');
                    ex_mem_writebackreg <= 0;
                    ex_mem_isWriteback <= '0';
                WHEN "000101" => -- bne
                    if (id_ex_forwarding="100000") then             --replace s from ex
                        IF (ex_mem_aluresult /= id_ex_register_t) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="110000") then          --replace s from mem
                        IF (mem_wb_writeback /= id_ex_register_t) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="000100") then          --replace t from ex
                        IF (id_ex_register_s /= ex_mem_aluresult) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="000110") then          --replace t from mem
                        IF (id_ex_register_s /= mem_wb_writeback) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                        IF (ex_mem_aluresult /= ex_mem_aluresult) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                        IF (mem_wb_writeback /= mem_wb_writeback) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                        IF (ex_mem_aluresult /= mem_wb_writeback) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                        IF (mem_wb_writeback /= ex_mem_aluresult) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    else 
                        IF (id_ex_register_s /= id_ex_register_t) THEN 
                            ex_mem_aluresult <= std_logic_vector(signed(id_ex_pc) + to_signed(4, 32) + shift_left(signed(id_ex_immediate_sign), 2));
                            ex_mem_branchtaken <= '1';
                            branch_stall<= '1';
                            bcount :='0';
                            -- execute_stall <= '1';
                        ELSE
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_branchtaken <= '0';
                            branch_stall <= '0';
                        END IF;
                    end if;

                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= 0;
                    ex_mem_isWriteback <= '0';
                WHEN "001000" => -- addi
                    if (id_ex_forwarding(5 downto 3)="100") then
                        ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) + signed(id_ex_immediate_sign));
                    elsif (id_ex_forwarding(5 downto 3)="110") then
                        ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) + signed(id_ex_immediate_sign));
                    else 
                        ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(id_ex_immediate_sign));
                    end if;
                
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "001010" => -- slti
                    if (id_ex_forwarding(5 downto 3)="100") then
                        IF (signed(ex_mem_aluresult) < signed(id_ex_immediate_sign)) THEN 
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_aluresult(0) <= '1';
                        else
                            ex_mem_aluresult <= (others => '0');
                        END IF;
                    elsif (id_ex_forwarding(5 downto 3)="110") then
                        IF (signed(mem_wb_writeback) < signed(id_ex_immediate_sign)) THEN 
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_aluresult(0) <= '1';
                        else 
                            ex_mem_aluresult <= (others => '0');
                        END IF;
                    else 
                        IF (signed(id_ex_register_s) < signed(id_ex_immediate_sign)) THEN 
                            ex_mem_aluresult <= (others => '0');
                            ex_mem_aluresult(0) <= '1';
                        else 
                            ex_mem_aluresult <= (others => '0');
                        END IF;
                    end if;
                    
                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "001100" => -- andi
                    if (id_ex_forwarding(5 downto 3)="100") then
                        ex_mem_aluresult <= ex_mem_aluresult AND id_ex_immediate_zero;
                    elsif (id_ex_forwarding(5 downto 3)="110") then
                        ex_mem_aluresult <= mem_wb_writeback AND id_ex_immediate_zero;
                    else 
                        ex_mem_aluresult <= id_ex_register_s AND id_ex_immediate_zero;
                    end if;

                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "001101" => -- ori
                    if (id_ex_forwarding(5 downto 3)="100") then
                        ex_mem_aluresult <= ex_mem_aluresult OR id_ex_immediate_zero;
                    elsif (id_ex_forwarding(5 downto 3)="110") then
                        ex_mem_aluresult <= mem_wb_writeback OR id_ex_immediate_zero;
                    else 
                        ex_mem_aluresult <= id_ex_register_s OR id_ex_immediate_zero;
                    end if;

                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "001110" => -- xori
                    if (id_ex_forwarding(5 downto 3)="100") then
                        ex_mem_aluresult <= ex_mem_aluresult XOR id_ex_immediate_zero;
                    elsif (id_ex_forwarding(5 downto 3)="110") then
                        ex_mem_aluresult <= mem_wb_writeback XOR id_ex_immediate_zero;
                    else 
                        ex_mem_aluresult <= id_ex_register_s XOR id_ex_immediate_zero;
                    end if;

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
                    if (id_ex_forwarding(5 downto 3)="100") then
                        ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) + signed(id_ex_immediate_sign));
                    elsif (id_ex_forwarding(5 downto 3)="110") then
                        ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) + signed(id_ex_immediate_sign));
                    else 
                        ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(id_ex_immediate_sign));
                    end if;

                    ex_mem_branchtaken <= '0';
                    ex_mem_regvalue <= (others => '0');
                    ex_mem_writebackreg <= id_ex_register_t_index;
                    ex_mem_isWriteback <= '1';
                WHEN "101011" => -- sw
                    if (id_ex_forwarding="100000") then             --replace s from ex
                        ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) + signed(id_ex_immediate_sign));
                        ex_mem_regvalue <= id_ex_register_t;
                    elsif (id_ex_forwarding="110000") then          --replace s from mem
                        ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) + signed(id_ex_immediate_sign));
                        ex_mem_regvalue <= id_ex_register_t;
                    elsif (id_ex_forwarding="000100") then          --replace t from ex
                        ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(id_ex_immediate_sign));
                        ex_mem_regvalue <= ex_mem_aluresult;
                    elsif (id_ex_forwarding="000110") then          --replace t from mem
                        ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(id_ex_immediate_sign));
                        ex_mem_regvalue <= mem_wb_writeback; 
                    elsif (id_ex_forwarding="100100") then           --replace s and t from ex
                        ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) + signed(id_ex_immediate_sign));
                        ex_mem_regvalue <= ex_mem_aluresult; 
                    elsif (id_ex_forwarding="110110") then           --replace s and t from mem
                        ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) + signed(id_ex_immediate_sign));
                        ex_mem_regvalue <= mem_wb_writeback;
                    elsif (id_ex_forwarding="100110") then           --replace s from ex and t from mem
                        ex_mem_aluresult <= std_logic_vector(signed(ex_mem_aluresult) + signed(id_ex_immediate_sign));
                        ex_mem_regvalue <= mem_wb_writeback;
                    elsif (id_ex_forwarding="110100") then           --replace s from mem and t from ex
                        ex_mem_aluresult <= std_logic_vector(signed(mem_wb_writeback) + signed(id_ex_immediate_sign));
                        ex_mem_regvalue <= ex_mem_aluresult;
                    else 
                        ex_mem_aluresult <= std_logic_vector(signed(id_ex_register_s) + signed(id_ex_immediate_sign));
                        ex_mem_regvalue <= id_ex_register_t;
                    end if;
                    ex_mem_branchtaken <= '0';
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

    --perform load and stores and update writeback registers
    memory_process : PROCESS (clock)
    BEGIN
        IF (rising_edge(clock)) THEN 
            IF (reset = '1') THEN 
            --IF (reset = '1' or memory_stall = '1') THEN 
                writeback_stall <= '1';
                memory_state <= IDLE;
                mem_wb_loaded <= (others => '0');
                mem_wb_writeback <= (others => '0');
                mem_wb_writeback_index <= 0;
                mem_wb_isWriteback <= '0';
                mem_waiting <= '0';
            ELSIF (memory_stall='0') THEN 
                writeback_stall <= '0';
                mem_wb_writeback<= ex_mem_aluresult;
                mem_wb_isWriteback<= ex_mem_isWriteback;
                mem_wb_writeback_index<=ex_mem_writebackreg;

                CASE memory_state IS 
                --idle when receiving new commands, determine if load or store and if not propagate info to writeback
                WHEN IDLE =>
                    IF (ex_mem_opcode="100011") THEN --load
                        --mem_loaded<= get from memory [ex_mem_aluresult]
                        mem_waiting <= '1';
                        
                        data_addr <= ex_mem_aluresult;
                        data_read <= '1';
                        data_write <= '0';
                        data_writedata <= (others => '0');

                        memory_state <= WAITREAD;
                    ELSIF (ex_mem_opcode="101011") THEN  --store
                        --store ex_mem_regvalue into memory [ex_mem_aluresult]
                        mem_waiting <= '1';

                        data_addr <= ex_mem_aluresult;
                        data_read <= '0';
                        data_write <= '1';
                        data_writedata <= ex_mem_regvalue;
                        
                        memory_state <= WAITWRITE;
                    ELSIF (ex_mem_opcode="000011") THEN 
                        mem_waiting <= '0';
                        mem_wb_writeback <= ex_mem_regvalue;
                    ELSE 
                        --fetch_stall <= '0';
                        --decode_stall <= '0';
                        --execute_stall <= '0';
                        mem_waiting <= '0';
                        data_addr <= (others => '0');
                        data_read <= '0';
                        data_write <= '0';
                        data_writedata <= (others => '0');
                    END IF;
                
                --used when loading, stall all stages until read from dCache completes, propagate data to writeback registers
                WHEN WAITREAD =>
                    IF (data_waitrequest = '0') THEN 
                        mem_wb_writeback  <= data_readdata;
                        memory_state <= IDLE;
                        mem_wb_isWriteback<='1';
                        mem_waiting <= '0';
                        data_addr <= (others => '0');
                        data_read <= '0';
                        data_write <= '0';
                        data_writedata <= (others => '0');
                    END IF;
                --used when storing, stall all stages until write to dCache completes
                WHEN WAITWRITE => 
                    IF (data_waitrequest = '0') THEN 
                        memory_state <= IDLE;
                        mem_waiting <= '0';
                        data_addr <= (others => '0');
                        data_read <= '0';
                        data_write <= '0';
                        data_writedata <= (others => '0');
                    END IF;
                END CASE;                
            end if;
        end if;   

    END PROCESS;

    --Write results of execution or loading into registers
    writeback_process : PROCESS (clock)
    BEGIN
        IF (rising_edge(clock)) THEN 
            --init all regs to 0
            IF (reset = '1') THEN 
                FOR i IN 0 TO 31 LOOP
                    register_bank(i) <= (others => '0');
                END LOOP;
            ELSIF (writeback_stall='0') then
                IF (mem_waiting = '1') THEN 
                elsif (mem_wb_isWriteback='1') then
                    register_bank(mem_wb_writeback_index)<=mem_wb_writeback;
                end if;
            end if;
        end if;
    END PROCESS;
END proc_arch;