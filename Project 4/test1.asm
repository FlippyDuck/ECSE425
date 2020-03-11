    addi $11,  $0, 2000 
	addi $1,   $0, 1	
	addi $2,   $0, 2	
	addi $3,   $0, 3	
	addi $15,  $0, 4	
	sw 	 $11,  0($0)

EoP:	beq	 $11, $11, EoP