;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Features Added / Fixed:
;   Assemblipede now properly:
;       -Starts out paused
;       -Grows when eating food
;       -Dies when hitting walls characters, itself, or going out of bounds
;       -Does NOT die when "reversing" into itself (i.e., going left when it's going right already)
;       -Proudly displays his score above the map, respresenting the number of pellets eaten
;       -Is able to warp through the magic of portals, only two of which can exist in any level
;
;   I hope to continue working on this on my own time to add things I'd wanted, like a death animation, 
;       game over screen / continuation into next level, and other things.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; define some symbols (constants)
   maxLvlBufferSize equ 2000
   maxSegmentIndex equ maxLvlBufferSize - 1
   
section .data
    usageMsg db "\Usage: Assemblipede levelFileName",0x0A,0x00
    openFileFailMsg db "Failed to open level file.",0x0A,0x00
    badFileFormatMsg db "Invalid File Format.",0x0A,0x00
    invalidPortalsMsg db "Invalid number of portals in level. Must be either two portals or none at all.",0x0A,0x00
    readModeStr db "r",0x00
    
    ;; scanf formats
    oneIntFmt db "%d",0x00    ; format string for scanf reading one integer
    twoIntFmt db "%d %d",0x00 ; format string for scanf reading two integers
    
    ;printf formats
    dbgIntFmt db "\Debug: %d %d",0x0A,0x00
    
    ;; Pause message
    pauseMsg db "PAUSED",10,"Press 'q' to quit",10,"Press 'spacebar' to continue",10,"Controls -",10,"W (Up), A (left), S (Down), D (Right)", 0
    scoreMsg db "Score : %d", 10, 0                        ;; print score

    
    ;; Initial timeout duration
    gameSpeed dd 250
    
section .bss
    lvlFilePtr resb 4
    
    lvlWidth resb 4
    lvlHeight resb 4
    
    lvlBuffer resb maxLvlBufferSize ; this stores that actual game level as a grid of asci text characters
                                    ; this is the "picture" of the game which is redrawn each game tick
    lvlBufSize equ $ - lvlBuffer

    xStep resb 4     ; -1, 0, or 1, how far to step horizontally per tick 
    yStep resb 4     ; -1, 0, or 1, how far to step vertically per tick 
    yDelta resb 4    ; amount to change address of head to move exacly one line up or down (should be lvlWidth+1)
    
    segmentX resb 4    ; place to temporarily store X coordinate of a body segment (or head)
    segmentY resb 4    ; place to temporarily store Y coordinate of a body segment (or head)
    
    headAddressInLvlBuffer resb 4 ; address of millipede (player) head in the lvlBuffer = lvlBuffer + Y*yDelta + X
                       ; note: we never need to keep track of X & Y position separately
                       ; if we want to go "up" or "down" one step, we subtract or add yDelta (which is lvlWidth+1)
                       
    bodySegmentAddresses times maxLvlBufferSize resb 4  ;array of pointers to location of body segments in the lvlBuffer
    headIndex  resb 4  ; index of the head Address in bodyAddresses
    tailIndex  resb 4  ; index of the tail Address (last body segmeent) in bodyAddresses
                       ; note that that headIndex and tailIndex "chase" each other around within the bodyAddresses array
                       ; and can wrap around so the head can be chasing the tail (when head is chasing tail, the entries in between are garbage data)
    bodyLength resb 4  ; length of the millipede body -- should equal 1 + ( headIndex-tailIndex(modulo maxLvlBufferSize) )
                       ; "modulo" or "clock arithmetic" because head/tail indexes can "wrap around"

    dbgBuffer resb 1000

    ;; Flags & Counters
    hardMode resb 1           ;; flag for hard mode
    startedMoving resb 1      ;; used to start paused
    score resb 4              ;; tracks number of segments total
    scoreToWin resb 4         ;; no. of food pellets req'd to win level
    gameSpeedDelta resb 4     ;; no. of ms to reduce gameTick length, based on total food (i.e., should never dip below 0 seconds)
    plusCounter resb 4        ;; both used to read in portals
    portalCounter resb 4
    storeHeadCounter resb 4   ;; flag to store only the first segment (i.e., the head)
    
    ;; Addresses & Positions
    portalOneAddress resb 4     ;; address of first portal
    portalTwoAddress resb 4     ;; address of second portal
    headPositionInArray resb 4  ;; decimal value -> = headAddress - lvlBuffer
    headY resb 4                ;; tracks y-position of head segment
    portalTwoY resb 4           ;; updates headY when going through portals
    portalOneY resb 4

    
;; std C lib functions
extern printf
extern fscanf
extern fgets
extern fopen
extern fclose
extern getchar
extern gets

;; ncurse lib functions
extern initscr
extern cbreak
extern clear
extern endwin
extern printw
extern getch
extern curs_set
extern noecho
extern timeout
extern notimeout
extern refresh

global _start

section .text

_start:
    
   ;follow cdecl -- we will be using command line arguments
   push EBP
   mov  EBP, ESP

   ; [EBP+4] is the arg count
   ; [EBP+8,12,16,...] are pointers to strings
   ; [EBP+8] is the command itself (usually the program name)
   ; [EBP+12] is first argument...  
   
   ; verify the first argument
   push dword [EBP+12]
   call printf
   add esp,4
   
   ; the args will be used by _LoadLevel -- getting the filename of the level data to load
   ; loadlevel is purely internal to this program and does not need cdecl
   call _LoadLevel 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize ncurses stuff...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    call initscr  ; ncurses: initscr -- initialize the screen, ready for ncurses stuff...
    call cbreak   ; ncurses: cbreak -- disables line buffering so we can get immediate key input
    call clear    ; ncurses: clear -- clear the screen
    push 0
    call curs_set ; ncurses: curs_set(0) makes cursor invisible
    add esp, 4
    call noecho   ; ncurses: noecho -- don't echo type characters to screen

; game loop
_GameLoop:

    ;; Moved this here so it can be altered (if hard mode is enabled)
    push dword [gameSpeed]
    call timeout  ; ncurses: timeout(milliseconds) set how long getch() will wait for a keypress (determines game speed)
    add esp, 4
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; _DisplayLevel
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    call clear      ; ncurses: clear --  clears screen and puts print position in the top left corner
    
    ;; Print score
    mov eax, [score]
    and esp, 0xFFFFFFF0
    sub esp, 8
    push eax
    push dword scoreMsg
    call printw
    add esp, 24

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    push dword lvlBuffer  ; lvlBuffer should just contain one large multiline string...
    call printw           ; ncurses: printw -- works just like printf, except printing starts from current print position on the ncurses screen
                          ;                    here we are just using it to print entire lvlBuffer
    add esp,4
    call refresh          ;; added for debugging
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; _Update lvlBuffer based on player movement & game "AI"
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    call _GameTick
    jmp _GameLoop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_exit:
    ;wrapup ncurses stuff...
    call endwin  ; cleanup/deallocate ncurses stuff (probably won't matter much since we're about to exit anyway... but let's keep things clean)
    ; wrapup cdecl
    mov     esp, ebp
    pop     ebp
    ; sys_exit
    mov     eax, 1 ; sys_exit
    xor     ebx, ebx
    int     80H

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  _GameTick
;;      handle a single tick for the game clock
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_GameTick:

    call getch     ; the ncurses getch (allows us to not wait indefinitely -- google ncurses nodelay timeout
                   ; the single return character should be in AL
                   
    ;  check for wasd and update player step in horizontal & vertical directions
    cmp AL, 'w'
    je _keyUp
    cmp AL, 'a'
    je _keyLeft
    cmp AL, 's'
    je _keyDown
    cmp AL, 'd'
    je _keyRight
    
    cmp AL, ' '     ;; spacebar to pause game
    je _pause
    
    jmp _continue

    ; [xStep] and [yStep] act as a sort of "velocity" or "step size per tick", can be either 1, 0 or -1
    _keyUp:
       cmp dword [yStep], 1     ;; Added check so Assemblipede does not "scrunch" into itself and die
       je _continue             ;; that is, hitting down when going up will not kill you
       mov byte [startedMoving], 1
       mov dword [xStep],0
       mov dword [yStep],-1
       jmp _continue
    _keyLeft:
       cmp dword [xStep], 1     ;; same for hitting left when going right
       je _continue
       mov byte [startedMoving], 1
       mov dword [xStep],-1
       mov dword [yStep],0
       jmp _continue
    _keyDown:
       cmp dword [yStep], -1   ;; same for hitting down while going up
       je _continue 
       mov byte [startedMoving], 1
       mov dword [xStep],0
       mov dword [yStep],1
       jmp _continue
    _keyRight:
       cmp dword [xStep], -1   ;; finally, same for hitting right while going left
       je _continue
       mov byte [startedMoving], 1
       mov dword [xStep],1
       mov dword [yStep],0
       jmp _continue
    
    _pause:
       push dword pauseMsg
       call printw
       add esp, 4
    _pauseMenu:
       call getch
       cmp AL, 'q'
       je _exit
       cmp AL, ' '
       jne _pauseMenu
       
       ret
       
    _continue:
        
       ;; Check whether player has moved yet
       cmp byte [startedMoving], 0
       je _startPaused
       
       cmp dword [xStep], 0
       jne _updatedHeadY
       cmp dword [yStep], 1
       jne _decrementY
       
       add dword [headY], 1
       jmp _updatedHeadY
       
    _decrementY:    
       sub dword [headY], 1
       
    _updatedHeadY:
       
       ; fetch head & tail INDEXES into ESI & EDI
       mov esi, [headIndex]
       mov edi, [tailIndex] 
       ; fetch head & tail ADDRESSES into EAX & EBX
       mov eax, [bodySegmentAddresses + 4*esi]      ;; address for head
       mov ebx, [bodySegmentAddresses + 4*edi]      ;; address for tail
       

       ; replace current head with a body segment
       mov byte [eax], 'o'
       ; replace current tail with a space
       mov byte [ebx], ' '
       
       ;; Check if there are portals in the map
       cmp dword [portalOneAddress], 0
       je _noPortals
       
       ;; Store registers
       push ecx
       push edx
       ;; Fetch portal addresses
       mov ecx, [portalOneAddress]
       mov edx, [portalTwoAddress]
       ;; Draw portals
       mov byte [ecx], '0'
       mov byte [edx], '0'
       ;; Restore registers
       pop edx
       pop ecx
       
    _noPortals:       
       ; increment headIndex (wrap if >= maxLvlBufferSize)
       add esi, 1
       cmp esi, maxSegmentIndex
       jl _skipWrapHeadIndex
       sub esi, maxSegmentIndex
       
    _skipWrapHeadIndex:
       mov [headIndex], esi      ; store the new head index back into memory
       
       ; now do the same for the tail index
       add edi, 1
       cmp edi, maxSegmentIndex
       jl _skipWrapTailIndex
       sub edi, maxSegmentIndex
    _skipWrapTailIndex:    
       mov [tailIndex], edi

       ; get new location of head and put '@' there
       add eax, [xStep]   ; add -1,1 or 0 to current address of head
       mov ecx, [yDelta]  ; [yDelta] -- the number of bytes to wrap around to same position on next or previous line: lvlWidth+1 
       imul ecx, [yStep]  ; multiply [ydelta] by -1,1, or 0, depending on whether we are moving up/down/neither
       add eax, ecx       ; add it to the head position address
       mov [headAddressInLvlBuffer], eax        ;; store head address
       
       ;; Die when hitting walls or self
       cmp byte [eax], '|'
       je _exit
       cmp byte [eax], '-'
       je _exit
       cmp byte [eax], 'o'
       je _exit
       
       ;; Calculate headPositionInArray & determine out of bounds
       push eax
       push ebx
       call _determineOutOfBounds
       pop ebx
       pop eax
       
       ;; Hits a portal
       cmp byte [eax], '0'
       je _portal
       
       ;; Hits food
       cmp byte [eax], '*'
       jne _noFood
       
       ;; Add segment if food has been eaten
       inc byte [bodyLength]    ;; increment bodyLength
       inc dword [score]        ;; increment score
       mov byte [ebx], 'o'      ;; draw segment
       dec edi                  ;; adjust tailIndex accordingly
       mov [tailIndex], edi
       
       ;; Increase speed if hard mode is enabled
       cmp byte [hardMode], 1
       jne _noFood
       sub dword [gameSpeed], 20    ;; increase game speed
       
    _noFood:
       mov byte [eax],'@' ; put the head in the new location
       mov [bodySegmentAddresses + 4*esi],eax ; save the new head address in bodySementAddressees[headIndex]
       
    _startPaused:
       ret

_determineOutOfBounds:
    
    mov ebx, lvlBuffer
    mov eax, [headAddressInLvlBuffer]
    sub eax, ebx
    mov [headPositionInArray], eax
    
    ;; Upper bound
    mov ebx, [headPositionInArray]
    cmp ebx, [yDelta]
    jle _outOfBounds
    
    ;; Lower bound
    mov ebx, [headY]
    add ebx, 2
    cmp ebx, [lvlHeight]
    je _outOfBounds
    
    ;; Left bound
    mov ebx, [yDelta]
    xor edx, edx
    div ebx
    cmp edx, 0
    je _outOfBounds
    
    ;; Right bound    
    mov eax, [headPositionInArray]
    sub eax, [headY]
    mov ebx, [lvlWidth]
    xor edx, edx
    div ebx
    cmp edx, 0
    je _outOfBounds
    
    ret
    
_portal:
    ;; If entering portal one
    cmp dword [portalOneAddress], eax
    je _exitPortalTwo
    ;; Else, entering portal two
    
    _exitPortalOne:
        ;; Update headY
        mov eax, dword [portalOneY]
        mov [headY], eax
        ;; Change head address to portal one address
        mov eax, [portalOneAddress]
        mov [headAddressInLvlBuffer], eax
        
        jmp _teleport    

    _exitPortalTwo:
        ;; Update headY
        mov eax, dword [portalTwoY]
        mov [headY], eax
        ;; Change head address to portal two address
        mov eax, [portalTwoAddress]
        mov [headAddressInLvlBuffer], eax
        
        jmp _teleport
    
    _teleport:
        ;; Reverse direction
        cmp dword [xStep], 0
        jne _reverseX

        _reverseY:
           neg dword [yStep]
           jmp _noFood
        _reverseX:
           neg dword [xStep]
           jmp _noFood

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  _LoadLevel
;;      Reads the level file, with some rudimentary verification of format
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_LoadLevel:
    
    ;check that we have exactly one arg (in addition to command)
    mov edx, [EBP+4]
    cmp edx, 2
    jne _usage
    ;ok, try to open the file...
    push readModeStr
    push dword [EBP+12]
    call fopen
    add esp, 8
    ;file pointers should be in EAX now (or null on failure
    cmp eax,0
    jle _openFileFail
    ;OK we have the file, save the filepointer & read the file...
    mov [lvlFilePtr], eax
    
    ;first line should tell us the width & height
    push lvlHeight            ; address to store the height of the level
    push lvlWidth             ; address to store the width of the level
    push twoIntFmt            ; format string for reading a two integers
    push dword [lvlFilePtr]   ; file pointer for the opened level file
    call fscanf
    add esp,16                ; remove scanf parameters from stack   
    
;;vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
    ; make sure ((width+1) * height) +1 is less than size of lvlBuffer 
    ; "+1" for newline at end of each line
    ; "-1" for null terminator at end of entire level
    ; jump to _LevelExceedsMaximumSize
;;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    
    ; calculate & store yDelta (number of character steps to arrive at exact same position in previous or next line)
    mov eax, [lvlWidth]
    inc eax
    mov [yDelta], eax
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    ; use fgets to read (and ignore) remainder of the last line we read in...
    push dword [lvlFilePtr]
    push lvlBufSize
    push lvlBuffer   ; whatever is still on the line we put here, but it will be overwritten below
    call fgets
    add esp,12

    ; next lvlHeight lines should be the level itself
    
    ; initialize for LoadLevelLoop... (we'll be using registers that are "safe" in cdecl function calls
    mov edi, lvlBuffer     ; edx will point successively to beginning of each line
    mov esi, [lvlWidth]    ; add 2 to this for newline & null for limit on what fgets will read 
    add esi, 2
    mov ebx, [lvlHeight]   ; use ebx to count down lines read
 
_LoadLevelLoop:
    ;fgets
    push dword [lvlFilePtr]   ; file pointer 
    push esi            ; max size of string to read in (included the added null terminator)
    push edi            ; pointer to where we want that string to go (within lvlBuffer)
    call fgets          ; read line from lvl file
    add esp, 12
    cmp eax,edi         ; check for failure to successfully read -- return value should just be pointer to where the string was stored
    jne _badFileFormat
    
;;vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
    ; Verify that line is the correct length, do not overflow the lvlBuffer
    ; if wrong length, jump to _badFileFormat
;;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        
    dec ebx
    jz _ValidatePortals 
    add edi, esi  ;adjust edx to where next line will start in lvlBuffer
    sub edi,1     ;back off 1 because we want to overwrite the null terminators (except the last line)

    jmp _LoadLevelLoop
    
_ValidatePortals:
    ;; setting up stuff for loop
    mov ecx, lvlBuffer  ;; load address into register
    mov edx, lvlBufSize ;; load size of lvlBuffer into register
    xor esi, esi        ;; init counter

_countPortals:
    ;; Jump to validation when we've hit the third plus sign     
    ;;          NOTE: This means only levels whose corners are plus signs, and ONLY its corners, are valid
    cmp byte [plusCounter], 3
    je _rejectInvalidNumberOfZeroes
    
    mov AL, byte [ecx + esi]     ;; move char into AL to compare
    inc esi
    
    cmp AL, '*'
    je _foundFood
    cmp AL, '+'
    je _foundPlus
    cmp AL, '0'
    je _foundPortal

    jmp _countPortals

_foundFood:
    inc dword [scoreToWin]
    jmp _countPortals
_foundPlus:
    inc byte [plusCounter]
    jmp _countPortals
    
_foundPortal:
    ;; Store location for zeroes/portals:
    cmp byte [portalCounter], 0
    je _storePortalOne
    cmp byte [portalCounter], 1
    je _storePortalTwo
    
    jmp _invalidPortals
    
_storePortalOne:
    lea eax, [ecx + esi-1]
    mov dword [portalOneAddress], eax
    inc byte [portalCounter]
    
    ;; Used to shift offset value for out of bounds calc
    mov ebx, lvlBuffer
    sub eax, ebx
    sub eax, dword [lvlWidth]
    mov ebx, [lvlWidth]
    xor edx, edx
    div ebx
    mov dword [portalOneY], eax
    
    jmp _countPortals
    
_storePortalTwo:
    lea eax, [ecx + esi-1]
    mov dword [portalTwoAddress], eax
    inc byte [portalCounter]
    
    ;; Used to shift offset value for out of bounds calc
    mov ebx, lvlBuffer
    sub eax, ebx
    sub eax, dword [lvlWidth]
    mov ebx, [lvlWidth]
    xor edx, edx
    div ebx
    mov dword [portalTwoY], eax
    
    jmp _countPortals

_rejectInvalidNumberOfZeroes:
    cmp byte [portalCounter], 0       ;; Accept no zeroes
    je _LoadInitialBody
    cmp byte [portalCounter], 2       ;; Accept two zeroes
    je _LoadInitialBody
    
    jmp _invalidPortals              ;; reject all else

_LoadInitialBody:
; next line should tell us how many initial body segments
    push bodyLength
    push oneIntFmt
    push dword [lvlFilePtr]
    call fscanf
    add  esp, 12
    
; next bodyLength lines should contain the X,Y coords of the body segments, starting with the head
    mov edi, [bodyLength]  ; edi will be the index into bodySegmentAddresses array
    dec edi                ; decrement by 1 because zero based -- this is index of the head
    mov [headIndex], edi
    mov dword [tailIndex], 0     ; the index of the tailAddress will initially be 0

_LoadBodySegmentsLoop:        
    ; next line should have the millipede head starting position
    push segmentY  ; remember cdecl reverse order onto the stack -- in lvl file, it is X then Y
    push segmentX
    push twoIntFmt
    push dword [lvlFilePtr]
    call fscanf
    add esp,16    
    push eax
    push dword edi
    push dword [segmentX]
    push dbgIntFmt
    call printf
    add esp, 12
    pop eax
    
    ;; Jump to store initial headY
    cmp dword [storeHeadCounter], 0
    je _storeHeadY

    inc dword [storeHeadCounter]

_storeHeadYDone:    
    ; calculate the body segment's address within lvlBuffer
    ; the store it in appropriate element within bodySegmentAddresses
    mov eax, lvlBuffer
    mov ecx, [segmentY]
    imul ecx, [yDelta]
    add eax, ecx         ; eax now hold the address of this body segment within lvlBuffer
    add eax, [segmentX]
    mov esi, bodySegmentAddresses
    mov [esi + 4*edi],eax            ; storing the address for this body segment in bodySegmentAddresses
    
    dec edi
    cmp edi,0
    jl  _DrawInitialBody   ; jump if less than 0 -- we want another go around for 0 index

    jmp _LoadBodySegmentsLoop
_storeHeadY:
    
    push eax
    ;; Store headY
    mov eax, [segmentY]
    mov [headY], eax
    dec dword [headY]
    inc dword [storeHeadCounter]
    pop eax

    jmp _storeHeadYDone

_DrawInitialBody:
    mov edi, [headIndex]
    mov esi, bodySegmentAddresses
    mov edx, [esi+4*edi]        ; get the head address from bodySegmentAddresses
    
    ;; Store initial head address
    mov [headAddressInLvlBuffer], edx
    
    mov byte [edx], '@'         ; put the head '@' at that location within lvlBuffer
    
_DrawBodyLoop:
    dec edi
    cmp edi,0
    jl _LoadLevelWrapup         ; break out of loop after last segment
    mov edx, [esi+4*edi]        ; get the segment address from bodySegmentAddresses
    mov byte [edx], 'o'         ; put the segment 'o' at that location within lvlBuffer
    jmp _DrawBodyLoop           ; repeat for next segment
    
_LoadLevelWrapup:
    ret     ; internal non-cdecl routine, so nothing else to do but return
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_usage:
    push usageMsg
    call printf
    jmp _exit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_openFileFail:
    push openFileFailMsg
    call printf
    jmp _exit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_badFileFormat:
    push badFileFormatMsg
    call printf
    jmp _exit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_invalidPortals:
    push invalidPortalsMsg
    call printf
    jmp _exit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_outOfBounds:

    jmp _exit
;;vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
    ; _LevelExceedsMaximumSize
;;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

