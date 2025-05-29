# Just need Debian base here
FROM debian:bookworm-slim

WORKDIR /app

# Add i386 architecture support
RUN dpkg --add-architecture i386

# Install nasm, 32-bit ncurses library for terminal drawing, multilib so gcc can compile/link for multiple architectures (32-bit & 64-bit, let's us do -m elf_i386), 32-bit standard C library (libc6:i386, used for syscalls & for ncurses' C lib calls internally), and patchelf (dynamic linker path? study this)
RUN apt update && apt install -y nasm gcc-multilib libncurses5-dev:i386 libc6:i386 patchelf ttyd

# Copy files into workdir
COPY . .

# Assemble
RUN nasm -f elf32 SnakeByte.asm -o SnakeByte.o
# Link
RUN ld -m elf_i386 --dynamic-linker /lib/ld-linux.so.2 -o SnakeByte SnakeByte.o -lncurses -lc
# Just to ensure the interpreter is set correctly
RUN patchelf --set-interpreter /lib/ld-linux.so.2 SnakeByte

# Expose ttyd's default port & run via ttyd
EXPOSE 7681
CMD ["ttyd", "./SnakeByte", "levels/lvl_001.txt"]