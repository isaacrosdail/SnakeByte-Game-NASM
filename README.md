## Lab0xFF Assemblipede

Lab0xFF Assemblipede is a 32-bit NASM assembly project designed to run in a Linux environment (e.g., WSL).

## Prerequisites

To run this program, you'll need the following:
- Linux environment (e.g., WSL or native Linux)
- nasm: The Netwide Assembler
- gcc-multilib (for 32-bit development)
- libncurses (32-bit, library for terminal handling)
- patchelf (For fixing dynamic interpreter issues?)

## Install Required Dependencies

Run these commands in your Linux terminal to install all the required tools and libraries:
sudo apt update
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install nasm gcc-multilib libncurses5-dev:i386 libc6:i386 patchelf

## Building the Program

To Assemble:
nasm -f elf32 -o Lab0xFF-Assemblipede.o Lab0xFF-Assemblipede.asm
To Link:
ld -m elf_i386 --dynamic-linker /lib/ld-linux.so.2 -o Lab0xFF-Assemblipede Lab0xFF-Assemblipede.o -lncurses -lc

Run the Program with:
./Lab0xFF-Assemblipede

Troubleshooting "cannot execute: required file not found":
Ensure the interpreter is set correctly:
patchelf --set-interpreter /lib/ld-linux.so.2 Lab0xFF-Assemblipede

