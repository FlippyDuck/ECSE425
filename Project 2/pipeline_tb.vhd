LIBRARY ieee;
USE ieee.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY pipeline_tb IS
END pipeline_tb;

ARCHITECTURE behaviour OF pipeline_tb IS

	COMPONENT pipeline IS
		PORT (
			clk : IN std_logic;
			a, b, c, d, e : IN INTEGER;
			op1, op2, op3, op4, op5, final_output : OUT INTEGER
		);
	END COMPONENT;

	--The input signals with their initial values
	SIGNAL clk : STD_LOGIC := '0';
	SIGNAL s_a, s_b, s_c, s_d, s_e : INTEGER := 0;
	SIGNAL s_op1, s_op2, s_op3, s_op4, s_op5, s_final_output : INTEGER := 0;

	CONSTANT clk_period : TIME := 1 ns;

	TYPE int_array IS ARRAY (1 TO 6) OF INTEGER;

	CONSTANT a_arr : int_array := (1, -2, 3, 4, 5, 0);
	CONSTANT b_arr : int_array := (5, 4, -3, 2, 1, 0);
	CONSTANT c_arr : int_array := (10, 20, -30, 40, 50, 0);
	CONSTANT d_arr : int_array := (-25, 15, 20, 30, 5, 0);
	CONSTANT e_arr : int_array := (2, 4, -8, 16, -32, 0);

	CONSTANT op1_arr : int_array := (6, 2, 0, 6, 6, 0);
	CONSTANT op2_arr : int_array := (252, 84, 0, 252, 252, 0);
	CONSTANT op3_arr : int_array := (-250, 300, -600, 1200, 250, 0);
	CONSTANT op4_arr : int_array := (-1, -6, 11, -12, 37, 0);
	CONSTANT op5_arr : int_array := (250, -1800, -6600, -14400, 9250, 0);	
	CONSTANT ans_arr : int_array := (2, 1884, 6600, 14652, -8998, 0);

BEGIN
	dut : pipeline
	PORT MAP(clk, s_a, s_b, s_c, s_d, s_e, s_op1, s_op2, s_op3, s_op4, s_op5, s_final_output);

	--clock process
	clk_process : PROCESS
	BEGIN
		clk <= '0';
		WAIT FOR clk_period/2;
		clk <= '1';
		WAIT FOR clk_period/2;
	END PROCESS;

	stim_process : PROCESS
	BEGIN
		--TODO: Stimulate the inputs for the pipelined equation ((a + b) * 42) - (c * d * (a - e)) and assert the results
		FOR i IN 1 TO 6 LOOP
			s_a <= a_arr(i);
			s_b <= b_arr(i);
			s_c <= c_arr(i);
			s_d <= d_arr(i);
			s_e <= e_arr(i);
			WAIT FOR clk_period;
		END LOOP;

		WAIT;
	END PROCESS stim_process;

	stage1_verify : PROCESS
	BEGIN
		WAIT FOR clk_period;
		FOR i IN 1 TO 6 LOOP
			ASSERT (s_op1 = op1_arr(i)) REPORT "OP1 error" SEVERITY ERROR;
			ASSERT (s_op3 = op3_arr(i)) REPORT "OP3 error" SEVERITY ERROR;
			ASSERT (s_op4 = op4_arr(i)) REPORT "OP4 error" SEVERITY ERROR;
			WAIT FOR clk_period;
		END LOOP;

		WAIT;
	END PROCESS stage1_verify;

	stage2_verify : PROCESS
	BEGIN
		WAIT FOR clk_period * 2;
		FOR i IN 1 TO 6 LOOP
			ASSERT (s_op2 = op2_arr(i)) REPORT "OP2 error" SEVERITY ERROR;
			ASSERT (s_op5 = op5_arr(i)) REPORT "OP5 error" SEVERITY ERROR;
			WAIT FOR clk_period;
		END LOOP;

		WAIT;
	END PROCESS stage2_verify;

	result_verify : PROCESS
	BEGIN
		WAIT FOR clk_period * 3;
		FOR i IN 1 TO 6 LOOP
			ASSERT (s_final_output = ans_arr(i)) REPORT "RESULT error" SEVERITY ERROR;
			WAIT FOR clk_period;
		END LOOP;

		WAIT;
	END PROCESS result_verify;
END;