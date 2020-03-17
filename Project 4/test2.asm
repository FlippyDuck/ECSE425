    addi $1,   $0, 1		#1 in R1                                                                        test
	addi $2,   $1, 1		#2 in R2, 1 operand, 1 distance exe                                             functional
	add  $3,   $2, $1		#3 in R3, 2 operands, 1 and 2 distance in exe                                   functional
    addi $4,   $1, 3        #4 in R4, 1 operand, 3 distance in exe                                          functional
    lw $5,      0($4)       #1st (2nd) dmem in R5, 1 operand, 1 distance in exe                             functional
    sw $4,      0($4)       #4 in 1st (2nd) dmem, 2 operands 2 distance in exe,                             functional
    lw $6, 0($0)            #0th dmem in R6                                                                 test
    addi $7, $6, 0          #0th dmem in R7, 1 operand, 1 distance need stall before going to execute       functional
    addi $8, $6, 0          #0th dmem in R8, 1 operand, 2 distance, get from register bank                  functional
    lw $9, 0($0)            #0th dmem in R9                                                                 test
    sw $9, 8($0)            #0th dmem in 2nd (third) dmem, 1 operand 1 distancein mem                       functional
    addi $10, $0, 12        #12 in R10                                                                      test
    sw $10, 0($10)          #12 in 3rd (4th) dmem, 2 operand, 1 away in exe and mem                         functional
    lw $11, 0($10)          #12 in R11, 1 operand, 1 and 2 away, in exe                                     functional
    sw $11, 4($10)          #12 in 4th (fifth) dmem, 2 operands, 1 and 3 away in exe and mem                functional
    mult $2, $3             #6 in LO, 0 in HI                                                               test
	mflo $12				#8 in R12, 1 operand, 1 away in exe                                             functional
    mult $4, $3             #12 in LO, 0 in HI                                                              test
    mfhi $13                #0 in R13                                                                       test
    mflo $14                #12 in R14, 1 operand 2 away in exe                                             functional
    addi $15, $0, 92        #92 in R15                                                                      test      
    addi $3, $3, 4          #7 in R3                                                                        functional
    #jr $15                                                                                                 
    #addi $1, $0,0
EoP: beq	 $1, $1, EoP


