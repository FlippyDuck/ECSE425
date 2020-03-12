    addi $11,  $0, 2000 
	addi $1,   $0, 1	
	addi $2,   $0, 2
	addi $15,  $0, 4	
	addi $3,   $0, 3		
	sw 	 $11,  0($0)
	sw   $11,  8($0)
	add  $4,   $1, $11
	sub  $5,   $15, $2
	mult $2, $15
	lw   $6,   0($15)
	lw   $9,   12($0)
	and  $7,   $3, $1
	or   $8,   $15, $3
	mfhi $10
	mflo $12
	j next
	addi $1, $0, 0
next: sll $13, $2, 1
EoP:	beq	 $11, $11, EoP