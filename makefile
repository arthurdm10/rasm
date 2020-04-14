all: asm_main.o cpp
	g++ asm_main.o cpp.o -o main

asm_main.o: main.asm file.asm dir.asm
		nasm -felf64 main.asm -g -o asm_main.o

asm:	asm_main.o
		ld -dynamic-linker /lib64/ld-linux-x86-64.so.2  -o main -lc asm_main.o aes.a
		
cpp: main.cpp
		g++ -c main.cpp -o cpp.o -O0 


clean: 
	rm asm_main.o cpp.o main