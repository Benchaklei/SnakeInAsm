bits 16
org 100h

section .data

; Game constants

; Logo data
LOGO_NUM_LINES EQU 8
LOGO_LINE_LENGTH EQU 46

; Snake Stats
SNAKE_MAX_LENGTH EQU 50 ; Change this value to change the score needed for victory
SNAKE_INITIAL_POS EQU 896

SNAKE_BODY_SIGN EQU '1'
APPLE_SIGN EQU '@'
WALL_SIGN EQU '*'
SNAKE_HEAD_SIGN EQU 'O'

; Snake movement stats
SNAKE_MOVE_RIGHT EQU 1
SNAKE_MOVE_LEFT EQU -1
SNAKE_MOVE_UP EQU -80
SNAKE_MOVE_DOWN EQU 80

; Scan codes for gameplay buttons
UP_ARROW_SCAN_CODE EQU 0x48
LEFT_ARROW_SCAN_CODE EQU 0x4B
RIGHT_ARROW_SCAN_CODE EQU 0x4D
DOWN_ARROW_SCAN_CODE EQU 0X50
ESC_SCAN_CODE EQU 0x01
SPACE_SCAN_CODE EQU 0x39

; Used for apple generation
RAND_MAX_VALUE EQU 1816 ; Due to resolution concerns
RAND_MIN_VALUE EQU 80

; Used for score printing
SCORE_FIRST_DIGIT_POSITION EQU 1846

; Game macros

%macro delay_timer 1
    mov ah,86h
    mov al,0
    mov cx,%1
    mov dx,0
    int 15h
%endmacro

%macro clear_screen 0
    mov ax,3h ; setting video mode to 3 - will clear screen too
    int 10h
%endmacro

; Game variables

snake_logo db     ' _______  __    _  _______  ___   _  _______ $',
           db     '|       ||  |  | ||   _   ||   | | ||       |$',
           db     '|  _____||   |_| ||  |_|  ||   |_| ||    ___|$',
           db     '| |_____ |       ||       ||      _||   |___ $',
           db     '|_____  ||  _    ||       ||     |_ |    ___|$',
           db     ' _____| || | |   ||   _   ||    _  ||   |___ $',
           db     '|_______||_|  |__||__| |__||___| |_||_______|$',
           db     '          ~Developed by Benchaklei~          $'

; game is 24x79
game_screen_arr db '*******************************************************************************',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*                                                                             *',10
                db '*******************************************************************************',10
                db 'SCORE:  $'

; The 0x20 is the ascii value of a SPACE, just to make the string print look a little better :D

game_victory_msg db 10 dup 0x20,'You won! Thanks for playing my snake game :)',10,27 dup 0x20,'~Benchaklei~$'
game_lost_msg db 10 dup 0x20, 'I am sorry.. you lost! :(',10,17 dup 0x20,'~Benchaklei~$'

snake_body dw SNAKE_INITIAL_POS, SNAKE_INITIAL_POS + 1, SNAKE_INITIAL_POS + 2, SNAKE_MAX_LENGTH dup (0)
snake_length db 3
current_row db 7 ; initial row for logo print is 7
current_direction db SNAKE_MOVE_RIGHT
apple_position dw 0
snake_tail_position dw SNAKE_INITIAL_POS

ate_apple_flag db 0

section .text
global _start

_start:
    clear_screen
    call generate_apple
    call logo_print

main_loop:
    call screen_update
    call check_user_input
    call move_snake
    call check_game_events
    call set_score
    jmp main_loop

; Prints the big SNAKE game logo
logo_print:
    mov si,0
    mov cx,LOGO_NUM_LINES

    print_all_rows:
        mov bh,0
        mov dh,[current_row]
        mov dl,18    ; column to start printing each line of SNAKE logo
        mov ah,02    ; set cursor position to print SNAKE logo nicely
        int 10h
    
        mov ah,9 ; print a string (terminated by $)
        lea dx, [snake_logo + si]
        int 21h

        inc byte [current_row]  ; so next cursor set is to next line
        add si,LOGO_LINE_LENGTH ; to move to next line needed to print
        loop print_all_rows

    ; A sleep function
    delay_timer 30

    ret

; updates the screen - Printing the updated game array
screen_update:

    ; extract positions from snake_body and inserts them into game_screen_arr
    mov ch,0
    mov cl,[snake_length]
    mov si,0
    mov bx,snake_body
    
    update_snake_on_screen:
        mov word di, [bx+si] ; di contains position of snake_body[si]

        cmp cl,1
        je place_head_sign
        mov byte [game_screen_arr+di], SNAKE_BODY_SIGN
        jmp skip_head_sign
        
        place_head_sign:
            mov byte [game_screen_arr+di], SNAKE_HEAD_SIGN
            jmp print_screen_arr ; If it is the head then it is the last body part to print, so we can skip the skip_head_sign label
        
        skip_head_sign:
            add si,2 ; because it is a word array (so each element is 2)
            loop update_snake_on_screen
    
    print_screen_arr:
        clear_screen
        mov al,0
        mov ah,9
        mov dx,game_screen_arr ; string terminated by $
        int 21h
    
    mov si,[snake_tail_position]
    mov byte [game_screen_arr+si],' ' ; To remove the tail from the screen
    ; A delay so the screen won't be cleared again so quickly
    delay_timer 3 ; Increase this value to change game difficulty (the higher the value, the slower the snake goes)
    ret

; updates the current_direction variable based on user's input
check_user_input:
    mov al,0
    mov ah,01h
    int 16h ; a key was pressed => ZF=0

    jz no_key_pressed ; no key was pressed

    ; A key was pressed:

    mov al,0
    mov ah,0
    int 16h ; reads scan code of key pressed and stores it in AH

    cmp ah,SPACE_SCAN_CODE
    je pause_game

    cmp ah,ESC_SCAN_CODE
    je end_program

    cmp ah,UP_ARROW_SCAN_CODE
    je up_button

    cmp ah,DOWN_ARROW_SCAN_CODE
    je down_button

    cmp ah,LEFT_ARROW_SCAN_CODE
    je left_button

    cmp ah,RIGHT_ARROW_SCAN_CODE
    je right_button

    jmp no_key_pressed ; If user pressed a key which is not one of the arrow buttons

    mov bx,0
    lea bx,[current_direction]

    pause_game:
        ; Using int 16h to check if the SPACE key was pressed again (if true -> unpause game)
        mov ah,0
        mov al,0
        int 16h

        cmp ah,SPACE_SCAN_CODE
        jne pause_game

        unpause_game:
            ret

    up_button:
        cmp byte [current_direction], SNAKE_MOVE_DOWN
        je no_key_pressed ; If snake is now moving down, it can't go up

        mov byte [current_direction],SNAKE_MOVE_UP
        ret
    
    down_button:
        cmp byte [current_direction], SNAKE_MOVE_UP
        je no_key_pressed ; If snake is now moving up, it can't go down

        mov byte [current_direction],SNAKE_MOVE_DOWN
        ret
    
    left_button:
        cmp byte [current_direction], SNAKE_MOVE_RIGHT
        je no_key_pressed ; If snake is now moving right, it can't go left

        mov byte [current_direction], SNAKE_MOVE_LEFT
        ret
    
    right_button:
        cmp byte [current_direction], SNAKE_MOVE_LEFT
        je no_key_pressed ; If snake is now moving left, it can't go right

        mov byte [current_direction], SNAKE_MOVE_RIGHT
        ret

    no_key_pressed:
        ret


; Generates an apple in a random location and updates the game_screen_arr array
; This function is using the following formula:
; system_timer() % (max_number + 1 - minimum_number) + minimum_number

; PLEASE NOTE THAT THIS IS NOT A SECURED RANDOM NOR A "REAL" RANDOM BUT IS ENOUGH FOR THE GAME

generate_apple:
    mov ah,00h
    int 1ah ; get system timer in CX:DX

    mov ax,dx

    mov bx,RAND_MAX_VALUE
    inc bx
    sub bx,RAND_MIN_VALUE

    xor dx,dx ; Because div with 16 bits is using DX:AX and I only want AX
    div bx
    mov ax,dx ; DX = remainder 

    add ax,RAND_MIN_VALUE

    ; Now ax contains the rand value

    mov si,ax
    cmp byte [game_screen_arr+si], ' ' ; Making sure apple is generated in a blank space
    jne generate_apple

    mov word [apple_position],si ; Save the current position of the apple generated
    mov byte [game_screen_arr+si],APPLE_SIGN
    ret


; Updates the snake pixels on the screen
move_snake:
    mov ax,0
    mov ch,0
    mov cl,[snake_length] ; Will be used in the mov_snake_body loop
    dec cl ; Because the last element we change is the head and we move it "manually"

    mov di,2 ; As the first element we move is arr[1] (into arr[0])

    ; Will be used later to check if it is the first element moving (therefore it is also the current tail of the snake)
    mov bh,0
    mov bl,cl
    
    ; If an apple was eaten we just add a new head
    cmp byte [ate_apple_flag],1
    jne move_snake_body
    jmp move_head

    move_snake_body:
        mov ax,[snake_body+di] ; ax = snake_body[i]

        mov [snake_body+di-2],ax ; snake_body[i-1] = snake_body[i]

        cmp cl,bl ; if we now move the last element -> this element is the current tail position
        jne skip_tail_update

        mov [snake_tail_position],ax
        
        skip_tail_update:
            add di,2 ; Increase by two so we move to the next element in the snake array (as each element is 2 bytes - word)
            dec cx
            cmp cx,0
            jne move_snake_body

    move_head:
        mov cl,0
        mov ch,0

        mov cl,bl
        inc cl ; As bl is [snake_length] - 1 (see above)

        mov si,cx

        shl si,1 ; because we work with words
        sub si,2 ; as last element is arr[len(arr)-1]

        mov ax,[snake_body+si]
        
        mov cl,[current_direction]
        cmp cl,0

        JS sub_direction ; If it is a negative number we need to convert it to positive and do a substract
                
        add ax,cx
        jmp finish_moving_head

        sub_direction:
            neg cl
            sub ax,cx

        finish_moving_head:
            cmp byte [ate_apple_flag],1
            jne no_add_new_head
            add_new_head:
                add si,2 ; Creating new head
            no_add_new_head:
                mov [snake_body+si],ax ; Update the new head
                ret

; This function will check if any of the following has happened:
; - The snake ate an apple
; - The snake collide with its body
; - The snake collide with the wall
check_game_events:
    xor cx,cx
    mov cl,[snake_length]
    cmp cl,SNAKE_MAX_LENGTH
    je won_game
    dec cl

    mov si,cx
    shl si,1 ; as we are working with words

    ate_apple_check:
        mov ax,[snake_body+si] ; Get the head of the snake
        cmp ax,[apple_position]
        jne check_body_collision
        ate_apple:
            mov byte [ate_apple_flag],1
            call move_snake
            inc byte [snake_length]
            call generate_apple
            mov byte [ate_apple_flag],0
            ret
    check_body_collision:
        mov di,ax ; Need di in order to have a valid addressing mode
        cmp byte [game_screen_arr+di],SNAKE_BODY_SIGN
        je lost_game
        jne check_wall_collision
    check_wall_collision:
        cmp byte [game_screen_arr+di],WALL_SIGN
        je lost_game
        ret

; Will print the game winning message
won_game:
    clear_screen
    mov dx,game_victory_msg
    mov al,0
    mov ah,9
    int 21h
    jmp wait_for_exit

; Will print the game losing message
lost_game:
    clear_screen
    mov dx,game_lost_msg
    mov al,0
    mov ah,9
    int 21h
    jmp wait_for_exit

; Will exit the program when user presses ESCAPE button
wait_for_exit:
        ; Using int 16h to check if the ESCAPE key was pressed again (if true -> exit game over screen)
        mov ah,0
        mov al,0
        int 16h

        cmp ah,ESC_SCAN_CODE
        jne wait_for_exit
        exit_game_over_screen:
            jmp end_program
            

; Sets the score element in the game_screen_arr
set_score:
    xor cx,cx
    mov cl,[snake_length]
    mov ax,cx
    mov dx,0
    mov bh,0
    mov bx,10
    div bl ; AL = quotient, AH=remainder
    
    ; To turn digit into a char
    add al,48
    add ah,48 
    
    mov di,SCORE_FIRST_DIGIT_POSITION
    mov byte [game_screen_arr+di],al
    mov byte [game_screen_arr+di+1],ah
    ret

; exit(0)
end_program:
    clear_screen ; Just to make it look better
    mov ax,4c00h
    int 21h