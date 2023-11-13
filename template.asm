;	set game state memory location
.equ    HEAD_X,         0x1000  ; Snake head's position on x
.equ    HEAD_Y,         0x1004  ; Snake head's position on y
.equ    TAIL_X,         0x1008  ; Snake tail's position on x
.equ    TAIL_Y,         0x100C  ; Snake tail's position on Y
.equ    SCORE,          0x1010  ; Score address
.equ    GSA,            0x1014  ; Game state array address

.equ    CP_VALID,       0x1200  ; Whether the checkpoint is valid.
.equ    CP_HEAD_X,      0x1204  ; Snake head's X coordinate. (Checkpoint)
.equ    CP_HEAD_Y,      0x1208  ; Snake head's Y coordinate. (Checkpoint)
.equ    CP_TAIL_X,      0x120C  ; Snake tail's X coordinate. (Checkpoint)
.equ    CP_TAIL_Y,      0x1210  ; Snake tail's Y coordinate. (Checkpoint)
.equ    CP_SCORE,       0x1214  ; Score. (Checkpoint)
.equ    CP_GSA,         0x1218  ; GSA. (Checkpoint)

.equ    LEDS,           0x2000  ; LED address
.equ    SEVEN_SEGS,     0x1198  ; 7-segment display addresses
.equ    RANDOM_NUM,     0x2010  ; Random number generator address
.equ    BUTTONS,        0x2030  ; Buttons addresses

; button state
.equ    BUTTON_NONE,    0
.equ    BUTTON_LEFT,    1
.equ    BUTTON_UP,      2
.equ    BUTTON_DOWN,    3
.equ    BUTTON_RIGHT,   4
.equ    BUTTON_CHECKPOINT,    5

; array state
.equ    DIR_LEFT,       1       ; leftward direction
.equ    DIR_UP,         2       ; upward direction
.equ    DIR_DOWN,       3       ; downward direction
.equ    DIR_RIGHT,      4       ; rightward direction
.equ    FOOD,           5       ; food

; constants
.equ    NB_ROWS,        8       ; number of rows
.equ    NB_COLS,        12      ; number of columns
.equ    NB_CELLS,       96      ; number of cells in GSA
.equ    RET_ATE_FOOD,   1       ; return value for hit_test when food was eaten
.equ    RET_COLLISION,  2       ; return value for hit_test when a collision was detected
.equ    ARG_HUNGRY,     0       ; a0 argument for move_snake when food wasn't eaten
.equ    ARG_FED,        1       ; a0 argument for move_snake when food was eaten



; initialize stack pointer
addi    sp, zero, LEDS

; main
; arguments
;     none
;
; return values
;     This procedure should never return.
main:
    ; TODO: Finish this procedure.
	call init_game

	ret


turn_on_all:
	ori t0, t0, 0xFFFF 				; Stores 0xFFFF_FFFF in t0
	slli t0, t0, 16
	ori t0, t0, 0xFFFF

	stw t0, LEDS(zero)				; Sets LEDS[0] to LEDS[31] to 1

	ori t1, zero, 4					; Sets the offset to 4
	stw t0, LEDS(t1)				; Sets LEDS[32] to LEDS[63] to 1

	slli t1, t1, 1					; Sets the offset to 8
	stw t0, LEDS(t1)				; Sets LEDS[64] to LEDS[95] to 1

	ret

; BEGIN: clear_leds
clear_leds:
	stw zero, LEDS(zero)			; Sets LEDS[0] to LEDS[31] to 0

	ori t0, zero, 4					; Sets the offset to 4
	stw zero, LEDS(t0)				; Sets LEDS[32] to LEDS[63] to 0

	slli t0, t0, 1					; Sets the offset to 8
	stw zero, LEDS(t0)				; Sets LEDS[64] to LEDS[95] to 0

	ret
; END: clear_leds


; BEGIN: set_pixel
set_pixel:
	; t0 ~ Gets the index in the 32 bits array : (x % 4) * 8 + y <=> (x & 0b11) << 3 + y 
	andi t0, a0, 0b11				; x1 = x % 4
	slli t0, t0, 3					; x2 = x1 * 8
	add t0, t0, a1					; x3 = x2 + y
	
	; t1 ~ Turns on the nth bit of t1
	ori t1, zero, 1					; t1 = 0b0000...0001
	sll t1, t1, t0					; t1 = 0b00..010..00 at index n

	; t2 ~ Gets which LED array should be used
	andi t2, a0, 0b1100			; = 0 if LEDS[0], 4 if LEDsS[1] or 8 if LEDS[2], 

	; t3 ~ Modifies LEDS[i] accordingly
	ldw t3, LEDS(t2)				; Retrieves the current LED configuration
	or t3, t3, t1					; Modifies it
	stw t3, LEDS(t2)				; Apply the changes

	or a0, zero, zero				; Reset the args
	or a1, zero, zero				; Reset the args

	ret
; END: set_pixel


; BEGIN: display_score
display_score:
	ldw t0, digit_map(zero)
	stw t0, SEVEN_SEGS(zero)
	addi t1, zero, 4
	stw t0, SEVEN_SEGS(t1)
	ldw t0, SCORE(zero)
	addi t1, zero, 10 
	add t2, t0, zero  
	addi t3, zero, 0 
	
	
ds_while_unite: 
	blt t2, t1, ds_remove_units
	sub t2, t2, t1
	jmpi ds_while_unite


ds_remove_units: 
	sub t0, t0, t2

ds_while_tens:
	blt t0, t1, ds_done
	sub t0, t0, t1
	addi t3, t3, 1 
	jmpi ds_while_tens
	
	
ds_done:
	
	ldw t0, digit_map(t0) 
	ldw t2, digit_map(t2) 
	addi t1, zero, 8
	stw t0, SEVEN_SEGS(t1) 
	addi t1, zero, 12
	stw t2, SEVEN_SEGS(t1)
	ret
	

	
; END: display_score


; BEGIN: init_game
init_game:
	; --- Sets snake's position to 0 and length to 1 ---
	stw zero, HEAD_X(zero)
	stw zero, HEAD_Y(zero)

	stw zero, TAIL_X(zero)
	stw zero, TAIL_Y(zero)

	; --- Clears the GSA ---
	ori t0, zero, 11				; Sets x to 11
ig_for_x:							; --- TOP OF X LOOP ---
	blt t0, zero, ig_x_end			; While x > 0, else goes to the end of the x loop

	ori t1, zero, 7					; Sets y to 7
		
ig_for_y:							; --- TOP OF Y LOOP ---
	blt t1, zero, ig_y_end			; While y > 0, else goes to the end of the y loop

	slli t2, t0, 3					; = x * 8
	add t2, t2, t1					; = x * 8 + y which is the corresponding index/offset in the GSA 

	slli t3, t2, 2					; Multiplies by 4 the GSA index to get the offset

	stw zero, GSA(t3)					; -> Sets this GSA value to 0
	
	addi t1, t1, -1					; Removes 1 from y
	jmpi ig_for_y					; Goes to the top of y loop

ig_y_end:							; --- END OF Y LOOP ---
	addi t0, t0, -1					; Removes 1 from x
	jmpi ig_for_x					; Goes to the top of x loop

ig_x_end:							; --- END OF X LOOP ---

	; --- Initializes the GSA with snake position and direction ---
	ori t0, zero, DIR_RIGHT 		; Sets the default direction
	stw t0, GSA(zero)				; Sets the default position

	; --- Creates food ---
	or s0, zero, ra					; Saves the current return address
	call create_food				; Calls CREATE_FOOD procedure
	or ra, zero, s0					; Restores the return address

	; --- Sets score to 0 ---
	stw zero, SCORE(zero)

	; --- Sets all temporary registers to 0 ---
	or t0, zero, zero
	or t1, zero, zero
	or t2, zero, zero
	or t3, zero, zero
	or t4, zero, zero
	or t5, zero, zero
	or t6, zero, zero
	or t7, zero, zero

	; --- Sets all saved registers to 0 ---
	or s0, zero, zero
	or s1, zero, zero
	or s2, zero, zero
	or s3, zero, zero
	or s4, zero, zero
	or s5, zero, zero
	or s6, zero, zero
	or s7, zero, zero

	; --- Sets all argument registers to 0 ---
	or a0, zero, zero
	or a1, zero, zero
	or a2, zero, zero
	or a3, zero, zero

	; --- Sets all return registers to 0 ---
	or v0, zero, zero
	or v1, zero, zero

	; --- Sets stack pointer back to original position ---
	ori sp, zero, LEDS

	ret
; END: init_game


; BEGIN: create_food
create_food:
	ldw t0, RANDOM_NUM(zero)		; Get a random number
	andi t0, t0, 0xFF				; Only keeps the last byte

	cmplti t1, t0, 96				; If the random number is less than 96

	beq t1, zero, create_food		; Then start over

	slli t0, t0, 2					; Offsets the GSA index to get the address

	ldw t2, GSA(t0)					; Gets the current element in the GSA at this address

	bne t2, zero, create_food		; If this element is already occupied, then start over
	
	ori t2, zero, FOOD				; Store FOOD in this element
	stw t2, GSA(t0)

	ret
; END: create_food


; BEGIN: hit_test
hit_test:
	ldw t6, HEAD_X(zero)			; Gets current X coordinate of snake's head
	ldw t7, HEAD_Y(zero)			; Gets current Y coordinate of snake's head
	
	slli t0, t6, 3					; = x * 8
	add t0, t0, t7					; = x * 8 + y which is the corresponding index in the GSA 
	
	slli t0, t0, 2					; Multiplies by 4 the GSA index to get the offset

	ldw t1, GSA(t0)					; Gets snake's head direction

ht_mv_left:							; --- MOVE LEFT ---
	addi t0, zero, DIR_LEFT		; If snake is going left
	bne t1, t0, ht_mv_up			; Else go to MOVE_UP procedure

	addi t6, t6, -1					; Removes 1 from the head x coordinate 

	jmpi ht_new_coord				; New head coordinates have been determined

ht_mv_up:							; --- MOVE UP ---
	addi t0, zero, DIR_UP			; If snake is going up
	bne t1, t0, ht_mv_right		; Else go to MOVE_RIGHT

	addi t7, t7, -1					; Removes 1 from the head y coordinate
	
	jmpi ht_new_coord				; New head coordinates have been determined

ht_mv_right:						; --- MOVE RIGHT ---
	addi t0, zero, DIR_RIGHT		; If snake is going right
	bne t1, t0, ht_mv_down			; Else go to MOVE_DOWN

	addi t6, t6, 1					; Adds 1 to the head x coordinate

	jmpi ht_new_coord				; New head coordinates have been determined

ht_mv_down:							; --- MOVE DOWN ---
	addi t7, t7, 1					; Adds 1 to the head y coordinate

	jmpi ht_new_coord				; New head coordinates have been determined

ht_new_coord:				
	; Bounds verifications
	ori t0, zero, NB_COLS			; Sets the X upper bound
	ori t1, zero, NB_ROWS			; Sets the Y upper bound
	
	bge t6, t0, ht_hit_obs			; Goes to HIT_OBS procedure if x coordinate is greater or equal to x bound
	bge t7, t1, ht_hit_obs			; Goes to HIT_OBS procedure if y coordinate is greater or equal to y bound
	blt t6, zero, ht_hit_obs		; Goes to HIT_OBS procedure if x coordinate is strictly smaller than 0
	blt t7, zero, ht_hit_obs		; Goes to HIT_OBS procedure if y coordinate is strictly smaller than 0


	slli t0, t6, 3					; = x * 8
	add t0, t0, t7					; = x * 8 + y which is the corresponding index in the GSA 
	slli t0, t0, 2					; Multiplies by 4 the GSA index to get the offset
	ldw t1, GSA(t0)					; Gets next snake's head cell value
	
	or v0, v0, zero					; Sets the default return value to 0
	beq t1, zero, ht_done			; Goes to the DONE procedure if cell is empty
	
	ori t0, zero, FOOD				
	beq t1, t0, ht_hit_food			; Goes to the HIT_FOOD procedure if snake is going to hit food
	
	ori t0, zero, DIR_LEFT			; Checks if next cell value is greater or equal to 1
	bge t1, t0, ht_hit_obs			; Goes to the HIT_OBS procedure if snake is going to hit itself

	jmpi ht_done

ht_hit_obs:
	ori v0, v0, 2					; Sets the return value to 2 if an obstacle is going to be hit
	jmpi ht_done	

ht_hit_food:
	ori v0, v0, 1					; Sets the return value to 1 if food is going to be eaten

ht_done:
	ret
; END: hit_test


; BEGIN: get_input
get_input:
	ldw t0, BUTTONS(zero)			; Loads all Status bits
	ori t1, zero, 4					; Gets the button offset
	ldw t1, BUTTONS(t1)				; Loads all the Edgecapture bits

	andi t0, t0, 0b11111			; Status significant bits
	andi t1, t1, 0b11111			; Edgecapture significant bits

	ldw t3, HEAD_X(zero)			; Gets current X coordinate of snake's head
	ldw t4, HEAD_Y(zero)			; Gets current Y coordinate of snake's head
	
	slli t3, t3, 3					; = x * 8
	add t3, t3, t4					; = x * 8 + y which is the corresponding index in the GSA 
	
	slli t3, t3, 2					; Multiplies by 4 the GSA index to get the offset

	andi t2, t1, 16					; Checks if checkpoint button is pressed, priority #1
	bne t2, zero, gi_case_ck		; If yes, goes to BUTTON_CHECKPOINT procedure

gi_case_left:						; --- BUTTON LEFT PROCEDURE ---
	andi t2, t1, 1					; Checks if BUTTON_LEFT has been pressed
	beq t2, zero, gi_case_up		; Else goes to BUTTON_UP procedure

	ori v0, zero, BUTTON_LEFT 		; Outputs value BUTTON_LEFT
	stw v0, GSA(t3)					; Updates the GSA accordingly

	jmpi gi_done					; Goes to DONE procedure

gi_case_up:							; --- BUTTON UP PROCEDURE ---
	andi t2, t1, 2					; Checks if BUTTON_UP has been pressed
	beq t2, zero, gi_case_down 	; Else goes to BUTTON_DOWN procedure
	
	ori v0, zero, BUTTON_UP 		; Outputs value BUTTON_UP
	stw v0, GSA(t3)					; Updates the GSA accordingly

	jmpi gi_done					; Goes to DONE procedure

gi_case_down:						; --- BUTTON DOWN PROCEDURE ---
	andi t2, t1, 4					; Checks if BUTTON_DOWN has been pressed
	beq t2, zero, gi_case_right	; Else goes to BUTTON_RIGHT procedure

	ori v0, zero, BUTTON_DOWN		; Outputs value BUTTON_DOWN
	stw v0, GSA(t3)					; Updates the GSA accordingly

	jmpi gi_done					; Goes to DONE procedure

gi_case_right:						; --- BUTTON RIGHT PROCEDURE ---
	andi t2, t1, 8					; Checks if BUTTON_RIGHT has been pressed
	beq t2, zero, gi_none			; Else goes to NONE procedure

	ori v0, zero, BUTTON_RIGHT		; Outputs value BUTTON_RIGHT
	stw v0, GSA(t3)					; Updates the GSA accordingly

	jmpi gi_done					; Goes to DONE procedure

gi_case_ck: 						; --- BUTTON CHECKPOINT PROCEDURE ---
	ori v0, zero, BUTTON_CHECKPOINT ; Outputs value BUTTON_CHECKPOINT

	jmpi gi_done 					; Goes to DONE procedure

gi_none:							; --- NO BUTTON PROCEDURE ---
	ori v0, zero, BUTTON_NONE 		; Outputs value BUTTON_NONE 

	jmpi gi_done					; Goes to DONE procedure

gi_done:							; --- DONE PROCEDURE --- 
	ori t1, zero, 4					; Sets the BUTTON address offset to EDGECAPTURE
	stw zero, BUTTONS(t1)			; Sets EDGECAPTURE to 0

	ret
	
; END: get_input


; BEGIN: draw_array
draw_array:
	ori s0, zero, 11				; Sets x to 11
	
da_for_x:							; --- TOP OF X LOOP ---
	blt s0, zero, da_x_end			; While x > 0, else goes to the end of the x loop

	ori s1, zero, 7					; Sets y to 7
		
da_for_y:							; --- TOP OF Y LOOP ---
	blt s1, zero, da_y_end			; While y > 0, else goes to the end of the y loop

	slli s2, s0, 3					; = x * 8
	add s2, s2, s1					; = x * 8 + y which is the corresponding index/offset in the GSA 

	slli s5, s2, 2					; Multiplies by 4 the GSA index to get the offset

	ldw s3, GSA(s5)					; Gets the direction of the current GSA element

	bne s3, zero, da_draw_pixel	; If the current GSA element is not equal to 0 then goes to DRAW_PIXEL procedure

da_pixel_drawn:						; Way back into the loop
	addi s1, s1, -1					; Removes 1 from y
	jmpi da_for_y					; Goes to the top of y loop

da_y_end:							; --- END OF Y LOOP ---
	addi s0, s0, -1					; Removes 1 from x
	jmpi da_for_x					; Goes to the top of x loop

da_x_end:							; --- END OF X LOOP ---
	ret

da_draw_pixel:
	or a0, zero, s0					; Sets the first argument to the current x
	or a1, zero, s1					; Sets the second argument to the current y

	or s4, zero, ra					; Saves the return address
	call set_pixel					; Draws the pixel accordingly
	or ra, zero, s4					; Restores the return address				

	jmpi da_pixel_drawn			; Goes back to the loop
	
; END: draw_array


; BEGIN: move_snake
move_snake:							; -- t5 => GSA address, t6 => snake X_HEAD, t7 => snake Y_HEAD
	ldw t6, HEAD_X(zero)			; Gets current X coordinate of snake's head
	ldw t7, HEAD_Y(zero)			; Gets current Y coordinate of snake's head
	
	slli t0, t6, 3					; = x * 8
	add t0, t0, t7					; = x * 8 + y which is the corresponding index/offset in the GSA 

	slli t5, t0, 2					; Multiplies by 4 the GSA index to get the offset

	ldw t1, GSA(t5)					; Gets the direction of the snake's head

ms_case_left:						; --- DIRECTION LEFT PROCEDURE --- (will always be done)
	cmpeqi t0, t1, DIR_LEFT		; Is the head going left ?
	beq t0, zero, ms_case_up		; If not, goes to DIRECTION_UP procedure

	ori t0, zero, 1					
	sub t6, t6, t0					; Substracts 1 from HEAD_X
	stw t6, HEAD_X(zero)			; Stores it back

	slli t0, t6, 3					; = x * 8
	add t0, t0, t7					; = x * 8 + y which is the corresponding index/offset in the GSA 

	slli t5, t0, 2					; Multiplies by 4 the GSA index to get the offset

	ori t0, zero, DIR_LEFT			
	stw t0, GSA(t5)					; Stores the direction of the new HEAD 

	jmpi ms_done					; Goes to DONE procedure	

ms_case_up:							; --- DIRECTION UP PROCEDURE ---
	cmpeqi t0, t1, DIR_UP			; Is the head going up ?
	beq t0, zero, ms_case_right	; If not, goes to DIRECTION_RIGHT procedure
	
	ori t0, zero, 1					
	sub t7, t7, t0					; Substracts 1 from HEAD_Y
	stw t7, HEAD_Y(zero)			; Stores it back

	slli t0, t6, 3					; = x * 8
	add t0, t0, t7					; = x * 8 + y which is the corresponding index/offset in the GSA 

	slli t5, t0, 2					; Multiplies by 4 the GSA index to get the offset

	ori t0, zero, DIR_UP			
	stw t0, GSA(t5)					; Stores the direction of the new HEAD 
	
	jmpi ms_done					; Goes to DONE procedure
			
ms_case_right: 						; --- DIRECTION RIGHT PROCEDURE ---
	cmpeqi t0, t1, DIR_RIGHT 		; Is the head going right ?
	beq t0, zero, ms_case_down		; If not, goes to DIRECTION_DOWN procedure
	
	addi t6, t6, 1					; Adds 1 to HEAD_X
	stw t6, HEAD_X(zero)			; Stores it back

	slli t0, t6, 3					; = x * 8
	add t0, t0, t7					; = x * 8 + y which is the corresponding index/offset in the GSA 

	slli t5, t0, 2					; Multiplies by 4 the GSA index to get the offset

	ori t0, zero, DIR_RIGHT			
	stw t0, GSA(t5)					; Stores the direction of the new HEAD 

	jmpi ms_done

ms_case_down:						; --- DIRECTION DOWN PROCEDURE --- (default procedure, shouldn't happen)
	addi t7, t7, 1					; Adds 1 to HEAD_Y
	stw t7, HEAD_Y(zero)			; Stores it back

	slli t0, t6, 3					; = x * 8
	add t0, t0, t7					; = x * 8 + y which is the corresponding index/offset in the GSA 

	slli t5, t0, 2					; Multiplies by 4 the GSA index to get the offset

	ori t0, zero, DIR_DOWN			
	stw t0, GSA(t5)					; Stores the direction of the new HEAD

	jmpi ms_done

ms_done: 
	beq a0, zero, move_tail		; Does the snake collide with food ?

	ret								; If yes, no change, else goes to MOVE_TAIL procedure

move_tail:							; --- MOVE TAIL PROCEDURE ---
	ldw t6, TAIL_X(zero)			; Gets current X coordinate of snake's tail
	ldw t7, TAIL_Y(zero)			; Gets current Y coordinate of snake's tail

	slli t0, t6, 3					; = x * 8
	add t0, t0, t7					; = x * 8 + y which is the corresponding index/offset in the GSA 

	slli t5, t0, 2					; Multiplies by 4 the GSA index to get the offset

	ldw t0, GSA(t5)					; Gets the direction of the tail
	stw zero, GSA(t5)				; Erases the current tail in the GSA

	ori t1, zero, DIR_LEFT			; Checks if the old tail is going left
	beq t0, t1, mt_left
	
	ori t1, zero, DIR_UP			; Checks if the old tail is going up
	beq t0, t1, mt_up

	ori t1, zero, DIR_RIGHT		; Checks if the old tail is going right
	beq t0, t1, mt_right

	ori t1, zero, DIR_DOWN			; Checks if the old tail is going down
	beq t0, t1, mt_down

	ret

mt_left:
	addi t6, t6, -1					; Removes 1 from TAIL_X
	stw t6, TAIL_X(zero)			; Stores it back
	ret

mt_up:
	addi t7, t7, -1					; Removes 1 from TAIL_Y
	stw t7, TAIL_Y(zero)			; Stores it back
	ret

mt_right:
	addi t6, t6, 1					; Adds 1 to TAIL_X
	stw t6, TAIL_X(zero)			; Stores it back
	ret

mt_down:
	addi t7, t7, 1					; Adds 1 to TAIL_Y
	stw t7, TAIL_Y(zero)			; Stores it back
	ret
; END: move_snake


; BEGIN: save_checkpoint
save_checkpoint:

; END: save_checkpoint


; BEGIN: restore_checkpoint
restore_checkpoint:

; END: restore_checkpoint


; BEGIN: blink_score
blink_score:
	addi s1, zero, 8 				; Gets the tens offset
	ldw s0, SEVEN_SEGS(s1) 		; Gets the tens
	addi s1, zero, 12 				; Gets the units offset
	ldw s1, SEVEN_SEGS(s1)			; Gets the units
	
	stw zero, SEVEN_SEGS(zero) 	; Turns off thousands 
	addi s2, zero, 4 
	stw zero, SEVEN_SEGS(s2) 		; Turns off hundreds
	addi s2, zero, 8 
	stw zero, SEVEN_SEGS(s2) 		; Turns off tens
	addi s2, zero, 12 
	stw zero, SEVEN_SEGS(s2) 		; Turns off units

	; --- ONLY DO THAT WHEN TESTING ON GECKO
	add s3, zero, ra				; Saves the return address
	call wait 						; Calls WAIT function --- ONLY WHEN 
	add ra, zero ,s3				; Restores the return address
	; -----
	
	ldw s4, digit_map(zero)		; Gets the representation of 0
	stw s4, SEVEN_SEGS(zero) 		; Sets the thousands to 0
	addi s5, zero, 4
	stw s4, SEVEN_SEGS(s5) 		; Sets the hundreds to 0
	
	addi s6, zero, 8 				; Restores the tens value
	stw s0, SEVEN_SEGS(s6) 
	addi s6, zero, 12 				; Restores the units value
	stw s6, SEVEN_SEGS(s6)
	
	ret 


; END: blink_score

wait: 
	addi t0, zero, 1				; Initializes counter to 2^24 ~ 50 000 000 / 3
	slli t0, t0, 24

wait_loop:
	beq t0, zero, wait_done 		; Goes to DONE procedure if counter is equal to 0
	addi t0, t0, -1					; Decreases counter by 1
	jmpi wait_loop 					
	
wait_done: 
	ret
		

digit_map:
	.word 0xFC ;0
	.word 0x60 ;1
	.word 0xDA ;2
	.word 0xF2 ;3
	.word 0x66 ;4
	.word 0xB6 ;5
	.word 0xBE ;6
	.word 0xE0 ;7
	.word 0xFE ;8
	.word 0xF6 ;9
