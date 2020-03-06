    addi $10,  $0, 4	# number of generating Fibonacci-numbers 
	addi $1,   $0, 1	# initializing Fib(-1) = 0
	addi $2,   $0, 1	# initializing Fib(0) = 1
	addi $11,  $0, 2000  	# initializing the beginning of Data Section address in memory
	addi $15,  $0, 4	# word size in byte

EoP:	beq	 $11, $11, EoP 	#end of program (infinite loop)