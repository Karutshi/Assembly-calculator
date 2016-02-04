calculator: calculator.o
	ld -m elf_i386 -o calculator calculator.o

calculator.o: calculator.asm
	nasm -f elf -g -F stabs calculator.asm