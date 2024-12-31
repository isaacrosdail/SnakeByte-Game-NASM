
section .data
    resultMsg db "%d / %d = %d, with remainder: %d", 10, 0
    
    lvlWidth dd 42
    lvlWidthPlusOne dd 43
    
section .bss
    difference resb 4
    
section .text
    global main

extern printf

main:
    
    xor esi, esi
    
_loop:
    
    push esp
    
    ;inc dword [difference]
    add dword [difference], 170
    
    ;; Should be zero
    ;mov eax, [difference]
    ;mov ebx, [lvlWidth]
    ;xor edx, edx
    ;div ebx
    mov eax, 1
    mov ebx, 1
    mov edx, 1
    
    ;; Should be one
    mov eax, [difference]
    mov ebx, [lvlWidthPlusOne]
    xor edx, edx
    div ebx
    ;;Print
    push edx
    push eax
    push dword [lvlWidthPlusOne]
    push dword [difference]
    push dword resultMsg
    call printf
    add esp, 20
    
    pop esp
    
    inc esi
    cmp esi, 20
    je _exit
    
    jmp _loop
    
_exit:

    mov     eax, 1 ; sys_exit
    xor     ebx, ebx
    int     80H
