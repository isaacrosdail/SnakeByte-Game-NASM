## SnakeByte

<img src="https://github.com/Isaac-rosdail/SnakeByte-Game-NASM/blob/main/images/screenshot1.png?raw=true" alt="Screenshot 1" width="500"/>
<img src="https://github.com/Isaac-rosdail/SnakeByte-Game-NASM/blob/main/images/screenshot2.png?raw=true" alt="Screenshot 2 Paused" width="500"/>

SnakeByte is a 32-bit NASM assembly project designed to run in a Linux environment (e.g., WSL).

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
nasm -f elf32 -o SnakeByte.o SnakeByte.asm  
To Link:  
ld -m elf_i386 --dynamic-linker /lib/ld-linux.so.2 -o SnakeByte SnakeByte.o -lncurses -lc  

Troubleshooting "cannot execute: required file not found":
Ensure the interpreter is set correctly:
patchelf --set-interpreter /lib/ld-linux.so.2 SnakeByte

## Level Selection

Run the Program with:
./SnakeByte levels/[levelname].txt
* Replace [levelname].txt with the desired level file, such as lvl_001.txt

## Instructions

Controls:
- Move with WASD
- Pause with spacebar
