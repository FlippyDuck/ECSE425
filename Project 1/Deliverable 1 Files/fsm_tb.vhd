LIBRARY ieee;
USE ieee.STD_LOGIC_1164.all;
USE ieee.numeric_std.all;

ENTITY fsm_tb IS
END fsm_tb;

ARCHITECTURE behaviour OF fsm_tb IS

COMPONENT comments_fsm IS
PORT (clk : in std_logic;
      reset : in std_logic;
      input : in std_logic_vector(7 downto 0);
      output : out std_logic
  );
END COMPONENT;

--The input signals with their initial values
SIGNAL clk, s_reset, s_output: STD_LOGIC := '0';
SIGNAL s_input: std_logic_vector(7 downto 0) := (others => '0');

CONSTANT clk_period : time := 1 ns;
CONSTANT SLASH_CHARACTER : std_logic_vector(7 downto 0) := "00101111";
CONSTANT STAR_CHARACTER : std_logic_vector(7 downto 0) := "00101010";
CONSTANT NEW_LINE_CHARACTER : std_logic_vector(7 downto 0) := "00001010";

--constant test_string : string(1 to 50) := "hello world" & lf & "//hello" & lf & "int main()" & lf & "//comment" & lf & "return 01";
constant test_string : string (1 to 174) := 
	"/*large comment" & lf &
	"continuing comment*/outside comment" & lf &
	"//single line comment" & lf &
	"insert code hereasd faksdj fals als aa s adfjkls adfsjkla dsfjkla dfs" & lf &
	"//one more comment" & lf &
	"end program";

constant test_string2 : string(1 to 337) := 
	"#include <stdio.h>" & lf &
	"/ this is not a comment" & lf &
	"* this is not a comment" & lf &
	"/* this is a multiline comment" & lf &
	"continuing the multiline comment" & lf &
	"// inside ml comment" & lf &
	"asldkfjasdlkf */ comment ended" & lf &
	"int main(void) {" & lf &
	"        // single line comment printf" & lf &
	"        printf(asldkfjasljaf);" & lf &
	"// single line comment /*" & lf &
	"this should not be commented" & lf &
	"*/ no comment";
	
constant test1 : string(1 to 19) := "#include <stdio.h>" & lf;
constant test2 : string(1 to 24) := "/ this is not a comment" & lf;
constant test3 : string(1 to 24) := "* this is not a comment" & lf;
constant test4 : string(1 to 119) := "/* this is a multiline comment" & lf & 
									"still in multiline comment" & lf & 
									"// comment inside ml comment" & lf &
									"aklsdghfkasdhf */ comment ended" & lf;
constant test5 : string(1 to 17) := "int main(void) {" & lf;
constant test6 : string(1 to 36) := "// single line comment above printf" & lf;
constant test7 : string(1 to 44) := "printf(" & '"' & "Hello World" & '"' & "); // print hello world" & lf;
constant test8 : string(1 to 26) := "// single line comment /*" & lf;
constant test9 : string(1 to 34) := "return 0; Should not be commented" & lf;
constant test10 : string(1 to 24) := "*/ still no comment here";

BEGIN
dut: comments_fsm
PORT MAP(clk, s_reset, s_input, s_output);

 --clock process
clk_process : PROCESS
BEGIN
	clk <= '0';
	WAIT FOR clk_period/2;
	clk <= '1';
	WAIT FOR clk_period/2;
END PROCESS;
 
--TODO: Thoroughly test your FSM
stim_process: PROCESS
BEGIN 

	for i in 1 to 19 loop
		s_input <= std_logic_vector(to_unsigned(character'pos(test1(i)), 8));
		wait for 1 * clk_period;
		ASSERT (s_output = '0') REPORT "First line output should be 0" SEVERITY ERROR;
	end loop;

	for i in 1 to 24 loop
		s_input <= std_logic_vector(to_unsigned(character'pos(test2(i)), 8));
		wait for 1 * clk_period;
		ASSERT (s_output = '0') REPORT "Second line output should be 0" SEVERITY ERROR;
	end loop;

	for i in 1 to 24 loop
		s_input <= std_logic_vector(to_unsigned(character'pos(test3(i)), 8));
		wait for 1 * clk_period;
		ASSERT (s_output = '0') REPORT "Third line output should be 0" SEVERITY ERROR;
	end loop;

	for i in 1 to 119 loop
		s_input <= std_logic_vector(to_unsigned(character'pos(test4(i)), 8));
		wait for 1 * clk_period;
		if (i < 2) then 
			ASSERT (s_output = '0') REPORT "First two characters should have output 0" SEVERITY ERROR;
		elsif (i < 104) then
			ASSERT (s_output = '1') REPORT "Body should have output 1" SEVERITY ERROR;
		else 
			ASSERT (s_output = '0') REPORT "Ending should have output 0" SEVERITY ERROR;
		end if;
	end loop;

	for i in 1 to 17 loop
		s_input <= std_logic_vector(to_unsigned(character'pos(test5(i)), 8));
		wait for 1 * clk_period;
		ASSERT (s_output = '0') REPORT "int main(void) output should be 0" SEVERITY ERROR;
	end loop;

	for i in 1 to 36 loop
		s_input <= std_logic_vector(to_unsigned(character'pos(test6(i)), 8));
		wait for 1 * clk_period;
		if (i < 2 or i = 36) then 
			ASSERT (s_output = '0') REPORT "First two and last character output should be 0" SEVERITY ERROR;
		else 
			ASSERT (s_output = '1') REPORT "Test6 should be commented after //" SEVERITY ERROR;
		end if;
	end loop;

	for i in 1 to 44 loop
		s_input <= std_logic_vector(to_unsigned(character'pos(test7(i)), 8));
		wait for 1 * clk_period;
		if (i < 25 or i = 44) then
			ASSERT (s_output = '0') REPORT "Printf line output should be 0" SEVERITY ERROR;
		else
			ASSERT (s_output = '1') REPORT "Test7 comment after printf incorrectly detected" SEVERITY ERROR;
		end if;
	end loop;

	for i in 1 to 26 loop
		s_input <= std_logic_vector(to_unsigned(character'pos(test8(i)), 8));
		wait for 1 * clk_period;
		if (i < 2 or i = 26) then 
			ASSERT (s_output = '0') REPORT "Slash characters output should be 0" SEVERITY ERROR;
		else 
			ASSERT (s_output = '1') REPORT "Line containing /* should be commented" SEVERITY ERROR;
		end if;
	end loop;

	for i in 1 to 34 loop
		s_input <= std_logic_vector(to_unsigned(character'pos(test9(i)), 8));
		wait for 1 * clk_period;
		ASSERT (s_output = '0') REPORT "Test9 line output should be 0" SEVERITY ERROR;
	end loop;

	for i in 1 to 24 loop
		s_input <= std_logic_vector(to_unsigned(character'pos(test10(i)), 8));
		wait for 1 * clk_period;
		ASSERT (s_output = '0') REPORT "Test10 line output should be 0" SEVERITY ERROR;
	end loop;
	-- for i in 1 to 337 loop
	-- 	s_input <= std_logic_vector(to_unsigned(character'pos(test_string2(i)), 8));
	-- 	wait for 1 * clk_period;
	-- end loop;

	-- for i in 1 to 174 loop
	-- 	s_input <= std_logic_vector(to_unsigned(character'pos(test_string(i)), 8));
	-- 	wait for 1 * clk_period;
	-- 	if (i < 2) then 
	-- 		ASSERT (s_output = '0') REPORT "Output should be 0" SEVERITY ERROR;
	-- 	elsif (i < 36) then 
	-- 		ASSERT (s_output = '1') REPORT "Output should be 1 (Multiline comment fail)" SEVERITY ERROR;
	-- 	elsif (i < 54) then
	-- 		ASSERT (s_output = '0') REPORT "Output should be 0" SEVERITY ERROR;
	-- 	elsif (i < 74) then 
	-- 		ASSERT (s_output = '1') REPORT "Output should be 1" SEVERITY ERROR;
	-- 	elsif (i < 146) then 
	-- 		ASSERT (s_output = '0') REPORT "Output should be 0" SEVERITY ERROR;
	-- 	elsif (i < 163) then 
	-- 		ASSERT (s_output = '1') REPORT "Output should be 1" SEVERITY ERROR;
	-- 	else 
	-- 		ASSERT (s_output = '0') REPORT "Final output should be 0" SEVERITY ERROR;
	-- 	end if;
	-- end loop;

	-- REPORT "Example case, reading a meaningless character";
	-- s_input <= "01011000";
	-- WAIT FOR 1 * clk_period;
	-- ASSERT (s_output = '0') REPORT "When reading a meaningless character, the output should be '0'" SEVERITY ERROR;
	-- REPORT "_______________________";
    
	WAIT;
END PROCESS stim_process;
END;
