_calcDiff:
        ;; Calculate distance in array between 0 point and initial head position for out of bounds calculation
    mov eax, lvlBuffer
    mov ebx, [headAddressInLvlBuffer]
    sub ebx, eax
    mov [difference], ebx
    
    ret
    
    
;; Code for out of bounds using difference

;; Out Of Bounds using Modulo
       
       push eax 
       ;; Calculate difference
       mov eax, lvlBuffer
       mov ebx, [headAddressInLvlBuffer]
       sub ebx, eax
       mov [difference], ebx
       
       ;; Too far down
       mov eax, [numberOfSpaces]
       cmp dword [difference], eax
       jge _outOfBounds
       ;; Too far up
       mov eax, [lvlWidth] 
       cmp dword [difference], eax
       jle _outOfBounds
       
       pop eax

       push eax
       push ebx
       push edx
       
       ;; Too far left
       mov eax, [difference]
       mov ebx, [lvlWidth]
       xor edx, edx
       idiv ebx
       
       cmp edx, 0
       je _outOfBounds
       
       ;; Too far right
       mov eax, [difference]
       mov ebx, [lvlWidthPlusOne]
       xor edx, edx
       idiv ebx
       
       cmp edx, 0
       je _outOfBounds
       
       pop edx
       pop ebx
       pop eax
       
       
       
       
       
       
       
       
    mov eax, [difference]
    mov ebx, [lvlWidthPlusOne]
    xor edx, edx
    div ebx
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
