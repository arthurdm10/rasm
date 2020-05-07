all: asm_main.o cpp
	g++ asm_main.o cpp.o -o main

asm_main.o: main.asm file.asm dir.asm
		nasm -felf64 main.asm -g -o asm_main.o

asm:	asm_main.o
		gcc asm_main.o aes.a -no-pie -o main
		
clean: 
	rm asm_main.o main
	rm testDir/*
	cp *.asm testDir/