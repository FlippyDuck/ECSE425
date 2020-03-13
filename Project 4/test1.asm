	addi $11,  $0, 2000   	#11111010000 in R11
	addi $1,   $0, 1		#1 in R1
	addi $2,   $0, 2		#2 in R2
	addi $22, $0, 24		#24 in R22
	jr $22					#jump to line 7
	addi $11, $0, 0
	addi $15,  $0, 4		#4 in R15
	addi $3,   $0, 3		#3 in R3
	sw 	 $11,  0($0)		#2000 in 0th mem
	sw   $11,  8($0)		#2000 in 2nd mem
	add  $4,   $1, $11		#2001 in R4
	sub  $5,   $2, $15		#-2 in R5
	mult $2, $15
	lw   $6,   0($15)		#
	lw   $9,   12($0)		#
	and  $7,   $3, $1		#1 in R7
	or   $8,   $15, $3		#7 in R8
	mfhi $10				#0 in R10
	mflo $12				#8 in R12
	j next
	addi $1, $0, 0
next: sll $13, $2, 1		#4 in R13
	bne $1, $2, next2
	addi $2, $0, 0
next2: div $15, $2			
	slt $14, $2, $15		#1 in r14
	slti $16, $2, 3			#1 in R16
	nor $17, $0, $2			#complement of 2 in R17
	xor $18, $8, $3			#4 in R18
	jal next3				#124 in R31
	addi $1, $0, 0
next3: andi $21, $8, 2		#2 in R21
	mfhi $19				#0 in R19
	mflo $20				#2 in R20
	srl	 $23, $5, 1			#0 then all 1s in R23
	sra $24, $5, 1			#-1 in R24
	ori $25, $5, 1			#-1 in R25
	xori $26, $5, 3			#-3 in R26
	lui $27, 63
EoP:	beq	 $11, $11, EoP