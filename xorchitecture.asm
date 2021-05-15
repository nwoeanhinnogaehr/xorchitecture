; xorchitecture
; code: byte.observer
;
; a 256b x86 Linux (ELF) framebuffer intro with sound for Outline 2021
;
; github: @nwoeanhinnogaehr
; https://byte.observer
;
; system requirements:
; 1. Framebuffer access. Press ctrl-alt-Fx to switch to a virtual terminal and
;    log in. Make sure you are in the video group so that you can access the
;    framebuffer. You can add yourself to the group with
;    $ sudo usermod -a -G video $USER
;    After adding yourself to the video group, you will need to log out and
;    back in for the changes to take effect. You can test if you have
;    framebuffer access by doing:
;    cat /dev/urandom > /dev/fb0
; 2. Framebuffer resolution of 1024x768x32. You can set this using the
;    fbset command.
; 3. Working ALSA audio with 8 channel support. This demo uses the aplay
;    command for audio playback. You can test if it is working by running:
;    $ aplay -c8 /dev/urandom
;    Note: depending on your configuration, aplay may not work if you are
;    logged in as root.
;
; to build and run, execute:
; $ nasm -f bin xorchitecture.asm -o xorchitecture
; $ chmod +x xorchitecture
; $ ./xorchitecture
;
; ALTERNATIVE TO FRAMEBUFFER:
; If your framebuffer isn't working or cannot be set to the required resolution,
; there is a simple C program included that uses SDL2 to emulate a framebuffer
; device. You will still need aplay working to use this emulated version.
; To run the framebuffer emulator version, do:
; $ fbe/xorchitecture-fbe.sh
;
; greets:
; everyone in the sizecoding discord
; sizecoders who I haven't met yet
; jpeg xl fan club

pattern equ 11 ; change this for variants!
colorscheme equ 2 ; 1, 2, and 3 are good choices

bits 32
org $00010000
    db $7F,"ELF" ; e_ident
    dd 1 ; p_type
    dd 0 ; p_offset
    dd $$ ; p_vaddr
    dw 2 ; e_type, p_paddr
    dw 3 ; e_machine
    dd entry ; e_version, p_filesz
    dd entry ; e_entry, p_memsz
    dd 4 ; e_phoff, p_flags
fname:
    db "/tmp/fb0",0 ; e_shoff, p_align, e_flags, e_ehsize
entry:
    mov ebp, fname ; e_phentsize, e_phnum
    ; e_shentsize, e_shnum, e_shstrndx are below but we don't really care
    push ebp

    ; make a timer to limit FPS
    mov ax,0x142 ; timerfd_create
    int 0x80 ; timer fd = 3
    pop ebx
    push eax

    inc ecx
    mov al,5
    int 0x80 ; open /dev/fb0 = 4

    ; set timer rate
    pop ebx
    mov edi,16000000 ; 62.5 fps
    pusha
    push edx
    mov ax,0x145 ; timerfd_set
    mov edx,esp
    int 0x80
    pop edi ; zero edi for later

    ; make a pipe to communicate with the audio player
    mov ebx,esp
    mov al,0x2a ; pipe
    int 0x80

    ; fork off a process for the audio player
    mov al,2 ; fork
    int 0x80
    dec eax
    js child

; parent
    lea eax,[ecx-1+0x3f] ; eax=0x3f
    pop ebx
    dec ecx
    int 0x80 ; dup2(pipe[0], stdin)

    pop eax
    mov bl,2
    int 0x80 ; close(stderr)

    mov al,0xb
    push ecx ;push 0
    mov ebx,ebp
    mov bl,chan-$$
    push ebx
    mov bl,binaplay-$$+5
    push ebx
    mov bl,binaplay-$$
    mov ecx,esp
    lea edx,[ecx+48] ; edx = environ
    int 0x80 ; execve("/bin/aplay", {"-c8", 0}, environ)

child:
    mov ebp,1024*768*4 ; ebp = screen size
    sub esp,ebp ; make room on the stack for the video memory

mainloop:
    lea ebx,[esi+pattern] ; ebx = pattern
    mov ecx,ebp ; pixel index
    inc edi ; frame counter
gen:
    ; compute coordinates
    mov eax,edi
    and al,0x81
    shl eax,3
    add eax,ecx
    mov edx,edi

    ; test if the demo just started and we need to show the intro sequence
    cmp dh,1
    jg no_intro
    and eax,edx

no_intro:
    ; continue computing coordinates
    shl edx,12
    add eax,edx
    movzx edx,ax
    and dh,3
    shr eax,10
    ; eax = x, edx = y

    ; rotate 45 degrees
    mov esi,edx
    add edx,eax
    sub eax,esi

    ; create sierpinski pattern
    and eax,edx

    ; divide by "pattern" constant
    cdq
    div ebx

    ; update frame buffer
    ; is the frame number odd?
    mov edx,edi
    and edx,1
    jnz odd
; even
    or byte [esp+ecx],al
    xor byte [esp+ecx+colorscheme],al
    xchg eax,edx ; eax = 0; make the following effectively NOP
odd:
    or byte [esp+ecx+colorscheme],al
    xor byte [esp+ecx],al

    loop gen

    ; write to linux framebuffer
    mov ecx,esp
    mov edx,ebp
    push edi
    xchg eax,edi
    xor esi,esi
    mov bl,4
    and eax,1
    add al,0xb5
    int 0x80 ; pwrite64 to framebuffer
    pop edi

    ; read from timer (block until next frame)
    dec ebx
    mov eax,ebx
    int 0x80

    ; write audio
    add ecx,0x2a0000
    mov al,4
    cdq
    mov dh,4
    mov bl,6
    int 0x80

    jmp mainloop

chan:
    db "-c8",0
binaplay:
    db "/bin/aplay"
