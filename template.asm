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
   	stw zero, CP_VALID(zero)					; Sets the CP_VALID to 0

main_init_game:
	call init_game								; Initializes the game

main_get_input:
	call wait									; ------ MAKES THE GAME PLAYABLE
	call get_input								; Reads the input

	ori t0, zero, BUTTON_CHECKPOINT
	beq v0, t0, main_restore_checkpoint		; If the input is equal to CHECKPOINT, then go to RESTORE_CHECKPOINT
	
	call hit_test								; Else call HIT_TEST

	ori t0, zero, 1
	beq v0, t0, main_food_eaten				; If snake collides with food, go to FOOD_EATEN

	ori t0, zero, 2								
	beq v0, t0, main_init_game					; Else if snake dies, go to INIT_GAME

	ori a0, zero, 0								; Makes argument to 0	
	call move_snake								; Else move the snake

	jmpi main_redraw							; Go to REDRAW procedure

main_food_eaten:
	ldw t0, SCORE(zero)							; Gets the current score
	addi t0, t0, 1								; Increments the score by 1
	stw t0, SCORE(zero)							; Stores back the score
	
	call display_score							; Displays the updated score

	ori a0, zero, 1								; Makes the argument to 1
	call move_snake								; Moves snake
	call create_food							; Create a new food
	or a0, zero, zero							; Resets the argument to 0
	call save_checkpoint						; Tries to save the game

	beq v0, zero, main_redraw					; If game was not saved, go to REDRAW

	jmpi main_blink_score						; Go to BLINK_SCORE

main_redraw:	
	call clear_leds								; Clears all LEDs
	call draw_array								; Draw the updated LEDs array
	call display_score							; Displays the score

	jmpi main_get_input						; Goes back to GET_INPUT
	

main_restore_checkpoint:
	call restore_checkpoint					; Restores to the checkpoint if possible
	
	beq v0, zero, main_get_input				; If checkpoint was not done, go back to GET_INPUT

	jmpi main_blink_score						; Else go to BLINK_SCORE
	
main_blink_score:
	call blink_score							; Makes the score blink
	
	jmpi main_redraw							; Go to REDRAW

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
	ldw t0, digit_map(zero)		; Gets the representation of zero
	stw t0, SEVEN_SEGS(zero)		; Sets the thousands to 0
	addi t1, zero, 4				
	stw t0, SEVEN_SEGS(t1)			; Sets the hundreds to 0

	ldw t0, SCORE(zero)				; Gets the score
	addi t1, zero, 10 				; Sets the modulo
	addi t2, zero, 0 				; Initializes tens counter
	
ds_while: 
	blt t0, t1, ds_done				; If score is less then 10, then go to REMOVE_UNITS
	addi t0, t0, -10				; Substracts 10 from the score
	addi t2, t2, 1					; Add 1 to the tens
	jmpi ds_while					; Repeats

ds_done:
	slli t0, t0, 2					; Offsets the units to get the map index
	slli t2, t2, 2					; Offset the tens to get the map index

	ldw	t0, digit_map(t0)			; Gets the representation of the units
	ldw t2, digit_map(t2)			; Gets the representation of the tens

	ori t1, zero, 12				; Gets the units offset
	stw t0, SEVEN_SEGS(t1)			; Sets the units

	ori t1, zero, 8					; Gets the tens offset
	stw t2, SEVEN_SEGS(t1)			; Sets the tens

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
	ori t0, zero, 96				; Sets the upper limit
	ori t1, zero, 0					; Initializes the counter

ig_clear_GSA:
	beq t0, t1, ig_GSA_cleared		; If counter == upper limit, then end
	
	slli t2, t1, 2					; Gets address from counter

	stw zero, GSA(t2)				; Resets GSA's element

	addi t1, t1, 1					; Adds 1 to counter

	br ig_clear_GSA

ig_GSA_cleared:
	; --- Initializes the GSA with snake position and direction ---
	ori t0, zero, DIR_RIGHT 		; Sets the default direction
	stw t0, GSA(zero)				; Sets the default position

	; --- Creates food ---
	stw ra, -4(sp)					; Saves the current return address
	call create_food				; Calls CREATE_FOOD procedure
	ldw ra, -4(sp)					; Restores the return address

	; --- Sets score to 0 ---
	stw zero, SCORE(zero)

	; --- Redraws LEDs ---
	stw ra, -4(sp)					; Stores the return address
	
	call clear_leds					; Clears the LEDs
	call draw_array					; Draws the initial array
	call display_score				; Displays the initial score

	ldw ra, -4(sp)					; Restores the return address

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
	
	ori v0, zero, 0					; Sets the default return value to 0
	beq t1, zero, ht_done			; Goes to the DONE procedure if cell is empty
	
	ori t0, zero, FOOD				
	beq t1, t0, ht_hit_food		; Goes to the HIT_FOOD procedure if snake is going to hit food
	
	ori t0, zero, DIR_LEFT			; Checks if next cell value is greater or equal to 1
	bge t1, t0, ht_hit_obs			; Goes to the HIT_OBS procedure if snake is going to hit itself

	jmpi ht_done

ht_hit_obs:
	ori v0, zero, 2					; Sets the return value to 2 if an obstacle is going to be hit
	jmpi ht_done	

ht_hit_food:
	ori v0, zero, 1					; Sets the return value to 1 if food is going to be eaten

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

	ldw t5, GSA(t3)					; Gets the current direction

	andi t2, t1, 16					; Checks if checkpoint button is pressed, priority #1
	bne t2, zero, gi_case_ck		; If yes, goes to BUTTON_CHECKPOINT procedure

gi_case_left:						; --- BUTTON LEFT PROCEDURE ---
	andi t2, t1, 1					; Checks if BUTTON_LEFT has been pressed
	beq t2, zero, gi_case_up		; Else goes to BUTTON_UP procedure

	ori v0, zero, BUTTON_LEFT 		; Outputs value BUTTON_LEFT

	ori t6, zero, DIR_RIGHT		
	beq t6, t5, gi_done				; If the snake is going to opposite direction, don't update the direction

	stw v0, GSA(t3)					; Else, updates the GSA accordingly

	jmpi gi_done					; Goes to DONE procedure

gi_case_up:							; --- BUTTON UP PROCEDURE ---
	andi t2, t1, 2					; Checks if BUTTON_UP has been pressed
	beq t2, zero, gi_case_down 	; Else goes to BUTTON_DOWN procedure
	
	ori v0, zero, BUTTON_UP 		; Outputs value BUTTON_UP
	
	ori t6, zero, DIR_DOWN		
	beq t6, t5, gi_done				; If the snake is going to opposite direction, don't update the direction

	stw v0, GSA(t3)					; Updates the GSA accordingly

	jmpi gi_done					; Goes to DONE procedure

gi_case_down:						; --- BUTTON DOWN PROCEDURE ---
	andi t2, t1, 4					; Checks if BUTTON_DOWN has been pressed
	beq t2, zero, gi_case_right	; Else goes to BUTTON_RIGHT procedure

	ori v0, zero, BUTTON_DOWN		; Outputs value BUTTON_DOWN

	ori t6, zero, DIR_UP		
	beq t6, t5, gi_done				; If the snake is going to opposite direction, don't update the direction	

	stw v0, GSA(t3)					; Updates the GSA accordingly

	jmpi gi_done					; Goes to DONE procedure

gi_case_right:						; --- BUTTON RIGHT PROCEDURE ---
	andi t2, t1, 8					; Checks if BUTTON_RIGHT has been pressed
	beq t2, zero, gi_none			; Else goes to NONE procedure

	ori v0, zero, BUTTON_RIGHT		; Outputs value BUTTON_RIGHT

	ori t6, zero, DIR_LEFT		
	beq t6, t5, gi_done				; If the snake is going to opposite direction, don't update the direction	

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
	ldw t0, SCORE(zero)				; Gets the score
	addi t1, zero, 10				; Sets the modulo to 10

sc_loop:
	blt t0, t1, sc_end_loop			; If the updated score is less than 10, then continue
	sub t0, t0, t1	 				; Else remove the modulo from the score
	br sc_loop						; Go to top of loop

sc_end_loop:
	addi v0, zero, 0				; Sets the return value to 0

	bne t0, zero, sc_end			; If the updated score is not equal to then go to the end

	addi v0, zero, 1				; Updates the return value to 1
	stw v0, CP_VALID(zero)			; Sets CP_VALID to 1

	addi t0, zero, HEAD_X			; Gets the first element to copy
	addi t1, zero, CP_HEAD_X		; Gets the first place to copy to 

	addi t2, zero, 0x1198			; Gets the upper limit

sc_save:
	beq t0, t2, sc_end				; While the elements are to be copied
	
	ldw t3, 0(t0)					; Gets the element
	stw t3, 0(t1)					; Copies it

	addi t0, t0, 4					; Gets the next element
	addi t1, t1, 4					; Gets the next place to copy to

	br sc_save

sc_end:
	ret
; END: save_checkpoint


; BEGIN: restore_checkpoint
restore_checkpoint:
	ldw v0, CP_VALID(zero)			; Gets CP_VALID

	beq v0, zero, rc_end			; Checks if CP_VALID is equal to 1

	addi t0, zero, HEAD_X			; Gets the first element to copy to
	addi t1, zero, CP_HEAD_X		; Gets the first element to copy

	addi t2, zero, 0x1198			; Gets the upper limit
rc_loop:
	beq t0, t2, rc_end				; While the elements are to be copied
	
	ldw t3, 0(t1)					; Gets the element
	stw t3, 0(t0)					; Copies it

	addi t0, t0, 4					; Gets the next place to copy to
	addi t1, t1, 4					; Gets the next element

	br rc_loop

rc_end:
	ret
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

	stw ra, -4(sp)
	call wait	
	ldw ra, -4(sp)

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
	addi t0, zero, 1				; Initializes counter to 2^22 ~ 2 000 000
	slli t0, t0, 21

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
