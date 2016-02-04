;  Executable name : calculator
;  Version         : 1.0
;  Created date    : 23/12/2015
;  Last update     : 24/12/2015
;  Author          : Johan Ribom
;  Description     : A calculator that takes input and provides an answer.
;
;  Run it this way:
;    calculator
;    equation to calculate    
;
;  Build using these commands:
;    nasm -f elf -g -F stabs calculator.asm
;    ld -o calculator calculator.o
;
section .data
    maxNumbers         equ 10                       ; Max amount of numbers
    maxOperands        equ maxNumbers - 1           ; Max amount of operands
    asciiLeftPar       equ 40                   ; ASCII codes for the usable signs
    asciiRightPar      equ 41
    asciiMul           equ 42   
    asciiAdd           equ 43
    asciiSub           equ 45
    asciiDiv           equ 47
    asciiPowerTo       equ 94


    ignored            equ 0                    ; Codes for the different operations
    leftpar            equ 1                    
    rightPar           equ 2
    powerTo            equ 3
    multiplication     equ 4
    division           equ 5
    addition           equ 6 
    subtraction        equ 7


    entryString db 'Calculator v1.0', 0Ah, 'This version supports:', 0Ah, 'Addition', 0Ah, 'Subtraction', 0Ah, 'Multiplication', 0Ah, 'Division', 0Ah, 0Ah
    entryStringLen equ $-entryString

    ansString db 'Ans'
    ansStringLen equ $-ansString

    operandErrorString db 'Error:', 0Ah, 'Found unexpected character in input: ', 027h, 0h, 027h, 0Ah
    operandErrorStringLen equ $-operandErrorString

    tooManyOperandsErrorString db 'Error:', 0Ah, 'Too many operands in the calculation. Maximum number is: ', maxOperands + 48, 0Ah  
    tooManyOperandsErrorStringLen equ $-tooManyOperandsErrorString

    overflowErrorString db 'Error:', 0Ah, 'Overflow', 0Ah  
    overflowErrorStringLen equ $-overflowErrorString

    divideByZeroErrorString db 'Error:', 0Ah, 'Division by zero', 0Ah
    divideByZeroErrorStringLen equ $-divideByZeroErrorString

    zeroToPowerZeroErrorString db 'Error:', 0ah, '0^0 is undefined', 0Ah
    zeroToPowerZeroErrorStringLen equ $-zeroToPowerZeroErrorString

    returnString db 'Result: '
    returnStringLen equ $-returnString

    negativeSign db ' '

    lastResult dd 0

section .bss
    numbers resd maxNumbers
    operations resb maxOperands
    resultNumberASCII resb 11
    resultNumberASCIILen equ $-resultNumberASCII
    leftpar resb 1
    rightpar resb 1

    input times 15 resb maxNumbers
    inputLen equ $-input




section .text
    global _start

_start:

        mov eax, 4                      ;Writes out the start message
        mov ebx, 1
        mov ecx, entryString
        mov edx, entryStringLen
        int 80h

MainLoop:
        call Read
        call RemoveSpaces
        call CheckIfQuit
        call ConvertOperands
        call PrintEquation
        call DoPow
        call DoMul
        call DoDiv
        call DoAdd
        call DoSub
        call PrintResult

        jmp MainLoop











Read:
        mov eax, 3                      ;Reads user input for calculation
        mov ebx, 1
        mov ecx, input
        mov edx, inputLen
        int 80h
        
        ret











;
;               ###################################################
;               ################## INPUT PARSING ##################
;               ###################################################
;







RemoveSpaces:                           ;Removes all spaces in input
        mov eax, input                  ;Sets register EAX to point to input
        mov ebx, eax                    ;Sets register EBX to point to input
RemoveLoop:
        mov byte cl, [eax]              ;Moves the byte at EAX to EBX (via ECX).
        mov [ebx], cl                   
        cmp byte [eax], 32              ;Checks if the byte at address EAX is space
        je SpaceFound                   ;Increments EBX if the character at EAX is NOT a space
        inc ebx
SpaceFound:     
        inc eax                         ;EAX now points to the next byte in memory to check
        cmp byte [eax], 0Ah             ;Checks if the byte at EAX is line feed
        jne RemoveLoop                  ;If it isn't, loop
        
        mov byte cl, [eax]              ;At this point, the letter in EAX is line feed
        mov [ebx], cl                   ;Since the loop was broken, the \n must be moved to                                  the address EBX as well
        cmp eax, ebx                    ;If EAX = EBX no spaces have been removed
        je  SpacesRemoved               ;NullFiller will only be run if spaces have been removed


NullFiller:                             ;Sets all characters after \n to 0                  
        inc ebx                         ;EBX points to the next memory location to be nulled
        mov byte [ebx], 0h              ;Null the byte
        cmp ebx, eax                    ;Check if EBX points to the same memory location as EAX
        jne NullFiller                  ;Loop until NullFiller finds the line feed.
        mov byte [ebx + 1], 0h          ;Null the line feed character
SpacesRemoved:
        ret











CheckIfQuit:
    cmp byte [input], 71h
    jne NoQuit
    cmp byte [input + 1], 0Ah
    je Quit
    cmp byte [input + 1], 75h
    jne NoQuit
    cmp byte [input + 2], 69h
    jne NoQuit
    cmp byte [input + 3], 74h
    jne NoQuit
    cmp byte [input + 4], 0Ah
    je Quit
NoQuit:
    ret










ConvertOperands:
        mov eax, input                  ;Sets register EAX to point to input
        mov ebx, 0                      ;EBX decides which operand number to set
        push ebx                        ;
        mov cl, 0                       ;ECX holds the length of the number currently read
OperandsLoop:
        cmp byte [eax], asciiPowerTo
        je  PowerToFound
        cmp byte [eax], 47              ;Checks if the ascii character at EAX is a number
        jle CheckIfMul                  ;If it isn't, it's either an operand or an error
        cmp byte [eax], 58              
        jge OperandError
                                        

StackNumber:                            ;If this point is reached, the character was a number
        mov edx, 0                      ;EDX will hold the number read and push it up to the stack
        cmp eax, input
        je AddPlusSign
        cmp byte [eax - 1], asciiPowerTo
        je OperationFound
        cmp byte [eax - 1], 48
        jge AfterNumber
        cmp byte [eax - 1], asciiSub
        je SubtractionSignFound
OperationFound:
        mov byte dl, [eax - 1]
        push edx 
        jmp AfterNumber
SubtractionSignFound:
        cmp eax, input + 1
        je OperationFound
        cmp byte [eax - 2], asciiPowerTo
        je OperationFound
        cmp byte [eax - 2], 48
        jge AddPlusSign
        jmp OperationFound
AddPlusSign:
        mov edx, asciiAdd
        push edx
AfterNumber:
        mov byte dl, [eax]
        sub dl, 48
        push edx                        ;Pushes the number read onto the stack
        inc cl
        jmp OperandsLoopCheck

PowerToFound:
        mov byte [operations + ebx], powerTo            ;Set the operation to ^
        jmp ConvertNumbers
CheckIfMul:
        cmp byte [eax], asciiMul                        ;Checks if the sign is multiplication
        jne CheckIfDiv                                  ;If it isn't, go to next check
        mov byte [operations + ebx], multiplication     ;If it is, set the operation to mul
        jmp ConvertNumbers                              ;Jump to OperandsFound if one is found
CheckIfDiv:
        cmp byte [eax], asciiDiv                        ;Same principle as multiplication above
        jne CheckIfAdd
        mov byte [operations + ebx], division
        jmp ConvertNumbers
CheckIfAdd:
        cmp byte [eax], asciiAdd                        ;Same principle as division above
        jne CheckIfSub
        mov byte [operations + ebx], addition
        jmp ConvertNumbers
CheckIfSub:
        cmp byte [eax], asciiSub                            ;Same principle as addition above
        jne OperandError
        cmp eax, input
        je OperandsLoopCheck
        cmp byte [eax - 1], 47
        jle OperandsLoopCheck
        cmp byte [eax - 1], asciiPowerTo
        je OperandsLoopCheck
        mov byte [operations + ebx], subtraction
        jmp ConvertNumbers          


SaveNumber:
        pop ecx                                             ;Pop the index value to ECX
        mov dword [numbers + ecx + ecx + ecx + ecx], ebx    ;Move the current number to position
        mov ebx, ecx                                        ;Move the index value to EBX
        mov ecx, 0                      ;Make ECX 0 so it can be used again
        inc ebx                         ;Increase index
        push ebx                        ;Push index so that EBX can be used
        cmp eax, 0                      ;Check if EAX is 0
        je ParsingDone                  ;If it is, EOL is reached, and parsing is done

OperandsLoopCheck:
        inc eax                         ;EAX now points to the next byte in memory to check
        cmp ebx, maxOperands            ;Check that there aren't too many operands
        jg TooManyOperands              ;
        cmp byte [eax], 0Ah             ;Checks if the byte at EAX is line feed
        jne OperandsLoop                ;If it isn't, loop      

        mov eax, 0                      ;Make EAX 0 to show that this is the last number conversion
        jmp ConvertNumbers              ;Convert the numbers

ParsingDone:
        pop ebx                         ;remove the extra EBX that was put on the stack

        ret 











ConvertNumbers:
        mov ebx, 0                      ;Make EBX 0 so that it can store the converted number
        mov ch, 0                       ;Make CH 0 to start at numbers from 0-9
        cmp eax, input
        jne ConvertNumbersLoop
        mov ebx, [lastResult]
        jmp SaveNumber

ConvertNumbersLoop:
        pop edx                         ;Pop digit from the stack to EDX
        call EDXToPowerOfCH             ;Make the number in EDX = EDX * 10^(CH)
        add ebx, edx                    ;Add the new number to ebx
        jo OverflowError
        inc ch                          ;Increase CH, since the next digit will be 10 times larger
        cmp ch, cl                      ;If CH is as big as CL, the last digit has been added
        jne ConvertNumbersLoop          ;If the last digit hasnt been added, loop until it has
        pop edx
        cmp edx, asciiSub
        jne SaveNumber
        neg ebx
        jmp SaveNumber                  ;If it has, jump back to the main functions

EDXToPowerOfCH:                         ;Makes a digit the correct size, for example: The digit '1' in 123 should be '100', '2' should be '20' and '3' should be '3'
        push eax                        ;Push EAX so that the register can be used
        push cx                         ;Same with CX, where both cl and ch are used
PowerToLoopCH:
        cmp ch, 0                       ;Check if the value in CH is 0
        je PowerToLoopDoneCH            ;If it is, stop looping
        mov eax, 10                     ;Make the number in EAX 10
        imul edx                        ;EAX = EDX*EAX = EDX*10
        jo OverflowError
        mov edx, eax                    ;Move the result to EDX
        dec ch                          ;Decrease the value in CH
        jmp PowerToLoopCH               ;Loop, the program will loop until EDX is the correct size
PowerToLoopDoneCH:
        pop cx                          ;Pop CX to the original value
        pop eax                         ;Pop EAX to the original value
        ret










PrintEquation:
        cmp byte [input], asciiSub
        je PrintEqu
        cmp byte [input], 48
        jl PrintAns
        cmp byte [input], 57
        jle PrintEqu
PrintAns:
        mov eax, 4
        mov ebx, 1
        mov ecx, ansString
        mov edx, ansStringLen
        int 80h

PrintEqu:
        mov edx, input - 1
PrintEquLoop:
        inc edx
        cmp byte [edx], 0Ah
        jne PrintEquLoop
        sub edx, input - 1
        mov eax, 4
        mov ebx, 1
        mov ecx, input
        int 80h

        ret










;
;               ##################################################
;               ################## CALCULATIONS ##################
;               ##################################################
;










DoPow:
        mov eax, 0                                      ;EAX will hold the result
        mov ebx, 0                                      ;EBX points to the second factor
        mov ecx, -1                                     ;ECX points to the current operation
        mov edx, 0                                      ;EDX*4 points to the first factor
PowLoop:
        inc ecx                                         ;Increase ECX to point to the next operation
        add ebx, 4                                      ;Inc EBX by 1 dword
        cmp ecx, maxOperands                            ;Compare ECX to maximum amount of operands
        jg PowDone                                      ;If ECX is greater, work is done
        cmp byte [operations + ecx], powerTo            ;Compares the operation to ^
        jne PowLoop                                     ;If it isn't multiplication, check next
        cmp ecx, 0                              ;Compare ECX to 0
        je PowerTo                              ;If ECX = 0, the number to use is always number[0]
        mov edx, ecx                            ;EDX = ECX
        inc edx
FindFirstPowNumber:
        dec edx                                     ;Move EDX one step to the left in the operations
        cmp edx, 0                                  ;Check if EDX points to the first operation
        je PowerTo                                  ;If it does, do the multiplication
        cmp byte [operations + edx - 1], ignore     ;Check if the number at EDX-1 should be ignored
        je FindFirstPowNumber                       ;If it should, check the next

PowerTo:
        mov eax, edx                        ;Multiply EDX by 4
        mov edx, 4                          ;
        mul edx                             ;   
        push ecx
        mov edx, [numbers + eax]            ;Move the first number to EDX
        mov ecx, [numbers + ebx]            ;Move the second number to ECX
        call EDXToPowerOfECX
        pop ecx
        mov [numbers + eax], edx
        mov byte [operations + ecx], 0  ;Make the other number ignored by calculations
        mov dword [numbers + ebx], 0        ;Make the other number 0
        jmp PowLoop                     ;

PowDone:
    ret


EDXToPowerOfECX:                        ;Makes a digit the correct size, for example: The digit '1' in 123 should be '100', '2' should be '20' and '3' should be '3'
        push eax                        ;Push EAX so that the register can be used
        push ebx
        mov ebx, edx
        mov eax, edx
        cmp ecx, 0
        jg PowerToLoopECX
        jl EDXToNegativePowerOfECX
        cmp edx, 0
        je ZeroToPowerZeroError
        mov edx, 1
        pop ebx
        pop eax
        ret

PowerToLoopECX:
        cmp ecx, 1                      ;Check if the value in ECX is 0
        je PowerToLoopDoneECX           ;If it is, stop looping
        imul ebx                        ;EAX = EBX*EAX = 
        jo OverflowError
        dec ecx                         ;Decrease the value in ECX
        jmp PowerToLoopECX              ;Loop, the program will loop until EDX is the correct size
PowerToLoopDoneECX:
        mov edx, eax
        pop ebx
        pop eax                         ;Pop EAX to the original value
        ret


EDXToNegativePowerOfECX:
        mov eax, 1
        mov ecx, 1
        cmp edx, 1
        je PowerToLoopECX
        mov edx, 0
        pop ebx
        pop eax
        ret










DoMul:
        mov eax, 0                                      ;EAX will hold the result
        mov ebx, 0                                      ;EBX points to the second factor
        mov ecx, -1                                     ;ECX points to the current operation
        mov edx, 0                                      ;EDX*4 points to the first factor

MulLoop:
        inc ecx                                         ;Increase ECX to point to the next operation
        add ebx, 4                                      ;Inc EBX by 1 dword
        cmp ecx, maxOperands                            ;Compare ECX to maximum amount of operands
        jg MulDone                                      ;If ECX is greater, work is done
        cmp byte [operations + ecx], multiplication     ;Compares the operation to multiplication
        jne MulLoop                                     ;If it isn't multiplication, check next
        cmp ecx, 0                              ;Compare ECX to 0
        je Multiply                             ;If ECX = 0, the number to use is always number[0]
        mov edx, ecx                            ;EDX = ECX
        inc edx
FindFirstMulNumber:
        dec edx                                     ;Move EDX one step to the left in the operations
        cmp edx, 0                                  ;Check if EDX points to the first operation
        je Multiply                                 ;If it does, do the multiplication
        cmp byte [operations + edx - 1], ignore     ;Check if the number at EDX-1 should be ignored
        je FindFirstMulNumber                       ;If it should, check the next
        cmp byte [operations + edx - 1], division   ;Check if the number at EDX-1 is a divisor
        je FindFirstMulNumber                       ;If it is, check the next       


Multiply:
        mov eax, edx                        ;Multiply EDX by 4
        mov edx, 4                          ;
        mul edx                         ;
        mov edx, eax                        ;       
        push edx                            ;Push the pointer at EDX to the stack
        mov eax, [numbers + edx]            ;Move the first number to EAX
        mov edx, [numbers + ebx]            ;Move the second number to EDX
        imul edx                            ;Multiply them together
        jo OverflowError                    ;
        pop edx                             ;Pop the pointer back to EDX
        mov [numbers + edx], eax            ;Move the result to the number specified by the pointer
        mov byte [operations + ecx], 0  ;Make the other number ignored by calculations
        mov dword [numbers + ebx], 0        ;Make the other number 0
        jmp MulLoop                         ;Run the loop again
MulDone:
        ret











DoDiv:
        mov eax, 0                                      ;EAX will hold the result
        mov ebx, 0                                      ;EBX points to the second factor
        mov ecx, -1                                     ;ECX points to the current operation
        mov edx, 0                                      ;EDX*4 points to the first factor

DivLoop:
        inc ecx                                         ;Increase ECX to point to the next operation
        add ebx, 4                                      ;Inc EBX by 1 dword
        cmp ecx, maxOperands                            ;Compare ECX to maximum amount of operands
        jg DivDone                                      ;If ECX is greater, work is done
        cmp byte [operations + ecx], division           ;Compares the operation to division
        jne DivLoop                                     ;If it isn't division, check next
        cmp ecx, 0                              ;Compare ECX to 0
        je Divide                               ;If ECX = 0, the number to use is always number[0]
        mov edx, ecx                            ;EDX = ECX
        inc edx
FindFirstDivNumber:
        dec edx                                     ;Move EDX one step to the left in the operations
        cmp edx, 0                                  ;Check if EDX points to the first operation
        je Divide                                   ;If it does, do the division
        cmp byte [operations + edx - 1], ignore     ;Check if the number at EDX-1 should be ignored
        je FindFirstDivNumber                       ;If it should, check the next


Divide:
        mov eax, edx                        ;Multiply EDX by 4
        mov edx, 4                          ;
        mul edx                             ;
        mov edx, eax                        ;       
        push edx                            ;Push the pointer at EDX to the stack
        push ebx
        mov eax, [numbers + edx]            ;Move the first number to EAX
        mov edx, ebx
        mov ebx, [numbers + edx]            ;Move the second number to EBX
        cmp ebx, 0
        je DivideByZeroError
        mov edx, 0                          ;Make EDX 0 so it doesn't affect the division
        cmp eax, 0
        jl  MakeEDXNegative                 ;
PerformDivision:
        idiv ebx                            ;Divide EDX:EAX with EBX
        pop ebx
        pop edx                             ;Pop the pointer back to EDX
        mov [numbers + edx], eax            ;Move the result to the number specified by the pointer
        mov byte [operations + ecx], 0  ;Make the other number ignored by calculations
        mov dword [numbers + ebx], 0        ;Make the other number 0
        jmp DivLoop                         ;Run the loop again
DivDone:
        ret



MakeEDXNegative:
        mov edx, -1
        jmp PerformDivision










DoAdd:
        mov eax, 0                                      ;EAX will hold the result
        mov ebx, 0                                      ;EBX points to the second factor
        mov ecx, -1                                     ;ECX points to the current operation
        mov edx, 0                                      ;EDX*4 points to the first factor

AddLoop:
        inc ecx                                         ;Increase ECX to point to the next operation
        add ebx, 4                                      ;Inc EBX by 1 dword
        cmp ecx, maxOperands                            ;Compare ECX to maximum amount of operands
        jg AddDone                                      ;If ECX is greater, work is done
        cmp byte [operations + ecx], addition           ;Compares the operation to addition
        jne AddLoop                                     ;If it isn't addition, check next
        cmp ecx, 0                              ;Compare ECX to 0
        je Add                                  ;If ECX = 0, the number to use is always number[0]
        mov edx, ecx                            ;EDX = ECX
        inc edx
FindFirstAddNumber:
        dec edx                                     ;Move EDX one step to the left in the operations
        cmp edx, 0                                  ;Check if EDX points to the first operation
        je Add                                      ;If it does, do the addition
        cmp byte [operations + edx - 1], ignore     ;Check if the number at EDX-1 should be ignored
        jne Add                                     ;If not, perform the addition
        jmp FindFirstAddNumber                      ;Else loop and check the next operation
Add:
        mov eax, edx                        ;Multiply EDX by 4
        mov edx, 4                          ;
        mul edx                             ;
        mov edx, eax                        ;
        mov eax, [numbers + edx]            ;Move the first number to EAX
        add eax, [numbers + ebx]            ;Add the second number to EAX
        jo OverflowError                    ;
        mov [numbers + edx], eax            ;Move the result to the number specified by the pointer
        mov byte [operations + ecx], 0  ;Make the other number ignored by calculations
        mov dword [numbers + ebx], 0        ;Make the other number 0
        jmp AddLoop                         ;Run the loop again
AddDone:
        ret











DoSub:
        mov eax, 0                                      ;EAX will hold the result
        mov ebx, 0                                      ;EBX points to the second factor
        mov ecx, -1                                     ;ECX points to the current operation
        mov edx, 0                                      ;EDX*4 points to the first factor

SubLoop:
        inc ecx                                         ;Increase ECX to point to the next operation
        add ebx, 4                                      ;Inc EBX by 1 dword
        cmp ecx, maxOperands                            ;Compare ECX to maximum amount of operands
        jg SubDone                                      ;If ECX is greater, work is done
        cmp byte [operations + ecx], subtraction        ;Compares the operation to subtraction
        jne SubLoop                                     ;If it isn't subtraction, check next
        cmp ecx, 0                              ;Compare ECX to 0
        je Sub                                  ;If ECX = 0, the number to use is always number[0]
        mov edx, ecx                            ;EDX = ECX
        inc edx
FindFirstSubNumber:
        dec edx                                     ;Move EDX one step to the left in the operations
        cmp edx, 0                                  ;Check if EDX points to the first operation
        je Sub                                      ;If it does, do the subtraction
        cmp byte [operations + edx - 1], ignore     ;Check if the number at EDX-1 should be ignored
        jne Sub                                     ;If not, perform the subtraction
        jmp FindFirstSubNumber                      ;Else loop and check the next operation
Sub:
        mov eax, edx                        ;Multiply EDX by 4
        mov edx, 4                          ;
        mul edx                             ;
        mov edx, eax                        ;
        mov eax, [numbers + edx]            ;Move the first number to EAX
        sub eax, [numbers + ebx]            ;Subtract the second number from EAX
        jo OverflowError                    ;
        mov [numbers + edx], eax            ;Move the result to the number specified by the pointer
        mov byte [operations + ecx], 0  ;Make the other number ignored by calculations
        mov dword [numbers + ebx], 0        ;Make the other number 0
        jmp SubLoop                         ;Run the loop again
SubDone:
        ret











;
;               ###################################################
;               ############ PARSE TO STRING AND PRINT ############
;               ###################################################
;











PrintResult:
        mov eax, [numbers]
        mov [lastResult], eax
        mov ecx, 10
        mov ebx, 0

CheckIfNegative:
        mov byte [negativeSign], 20h
        cmp eax, 0
        jge PushDigit
        neg eax
        mov byte [negativeSign], 2Dh 

PushDigit:
        mov edx, 0
        div ecx
        push edx
        inc ebx
        cmp ebx, 10
        je AllDigitsPushed
        cmp eax, 0
        jne PushDigit
        
AllDigitsPushed:
        mov eax, 0
        mov ecx, 0
ParseNumber:
        pop edx
        add edx, 48
        mov [resultNumberASCII + eax], dl
        inc eax
        cmp eax, ebx
        je AddLineFeed
        jmp ParseNumber

AddLineFeed:
        inc ebx
        mov byte [resultNumberASCII + ebx], 0xA
        cmp ebx, resultNumberASCIILen
        jne FillRestZeros
        jmp PrintFinishedResult

FillRestZeros:
        inc ebx
        mov byte [resultNumberASCII + ebx], 0
        cmp ebx, resultNumberASCIILen
        jne FillRestZeros

PrintFinishedResult:
        mov byte [resultNumberASCII + resultNumberASCIILen - 1], 0xA
        mov eax, 4
        mov ebx, 1
        mov ecx, returnString
        mov edx, returnStringLen
        int 80h

        mov eax, 4
        mov ebx, 1
        mov ecx, negativeSign
        mov edx, 1
        int 80h 

        mov eax, 4
        mov ebx, 1
        mov ecx, resultNumberASCII
        mov edx, resultNumberASCIILen
        int 80h 

        mov eax, 0
        mov ebx, 0
        mov ecx, 4

NullEverything:
        mov dword [numbers + ebx], 0
        mov byte [operations + eax], 0
        inc eax
        add ebx, ecx
        cmp eax, maxNumbers
        jne NullEverything
        add ebx, ecx
        mov dword [numbers + ebx], 0
    
        mov eax, 0
NullResultString:
        mov byte [resultNumberASCII + eax], 0
        inc eax
        cmp eax, resultNumberASCIILen
        jne NullResultString

        ret











;
;           ###########################################################
;           ##################### ERROR MESSAGES ######################
;           ###########################################################
;


OverflowError:
        mov ecx, overflowErrorString        ;Move error message to ecx to be printed
        mov edx, overflowErrorStringLen
        jmp PrintError

DivideByZeroError:
        mov ecx, divideByZeroErrorString
        mov edx, divideByZeroErrorStringLen
        jmp PrintError

ZeroToPowerZeroError:
        mov ecx, zeroToPowerZeroErrorString
        mov edx, zeroToPowerZeroErrorStringLen
        jmp PrintError

TooManyOperands:
        mov ecx, tooManyOperandsErrorString         ;Move error message to ecx to be printed
        mov edx, tooManyOperandsErrorStringLen
        jmp PrintError

OperandError:
        mov ebx, operandErrorString     ;Make EBX point to the same location as EAX
        add ebx, operandErrorStringLen  ;Add the string length to EBX
        sub ebx, 3                      ;Make EBX point to the third last character 
        mov cl, [eax]                   ;Moves the unreadable character to the error message
        mov [ebx], cl
        mov ecx, operandErrorString     ;Moves the error message to ecx to be printed
        mov edx, operandErrorStringLen
        jmp PrintError

PrintError:
        mov eax, 4                      ;Print the error message
        mov ebx, 2                      
        int 80h

        jmp MainLoop











;
;           ###########################################################
;           ########################## QUIT ###########################
;           ###########################################################
;

Quit:
        mov eax, 1
        mov ebx, 0
        int 80h


