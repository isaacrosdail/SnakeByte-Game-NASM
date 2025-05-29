# Just need Debian base here
FROM debian:bookworm-slim

WORKDIR /app

# Add i386 architecture support
RUN dpkg --add-architecture i386

# Best practices: Set ENV (just needs to be set BEFORE we use 'apt')
ENV DEBIAN_FRONTEND=noninteractive

# Install nasm, 32-bit ncurses library for terminal drawing, multilib so gcc can compile/link for multiple architectures (32-bit & 64-bit, let's us do -m elf_i386), 32-bit standard C library (libc6:i386, used for syscalls & for ncurses' C lib calls internally), and patchelf (dynamic linker path? study this)
RUN apt update && apt install -y nasm gcc-multilib libncurses5-dev:i386 libc6:i386 patchelf

# Build ttyd from source
RUN apt update && apt install -y build-essential cmake git libjson-c-dev libwebsockets-dev && \
    git clone https://github.com/tsl0922/ttyd.git && \
    cd ttyd && mkdir build && cd build && cmake .. && make && make install && \
    # Best practices: Prevents the cached apt lists from ending up in the container image
    rm -rf /var/lib/apt/lists/*

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
#CMD ["ttyd", "-W", "bash"]
CMD ["ttyd", "-W", "-t", "SnakeByte - Play Snake in Assembly!", "./SnakeByte", "levels/lvl_001.txt"]
