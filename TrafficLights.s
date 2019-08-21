@ Uvic CSC 230 (Spring 2014) - Traffic Light Simulation Program
@ Embest Board (ARM Assembly)
@ Daniel Gilroy V00813027

@===== STAGE 0
@  	Sets initial outputs and screen for INIT
@   Calls StartSim to start the simulation,
@	polls for left black button, returns to main to exit simulation

        .equ    SWI_EXIT, 		0x11	@ Terminate program
        @ swi codes for using the Embest board
        .equ    SWI_SETSEG8, 		0x200	@ Display on 8 Segment
        .equ    SWI_SETLED, 		0x201	@ LEDs on/off
        .equ    SWI_CheckBlack, 	0x202	@ Check press Black button
        .equ    SWI_CheckBlue, 		0x203	@ Check press Blue button
        .equ    SWI_DRAW_STRING, 	0x204	@ Display a string on LCD
        .equ    SWI_DRAW_INT, 		0x205	@ Display an int on LCD  
        .equ    SWI_CLEAR_DISPLAY, 	0x206	@ Clear LCD
        .equ    SWI_DRAW_CHAR, 		0x207	@ Display a char on LCD
        .equ    SWI_CLEAR_LINE, 	0x208	@ Clear a line on LCD
        .equ 	SEG_A,	0x80		@ Patterns for 8 segment display
		.equ 	SEG_B,	0x40
		.equ 	SEG_C,	0x20
		.equ 	SEG_D,	0x08
		.equ 	SEG_E,	0x04
		.equ 	SEG_F,	0x02
		.equ 	SEG_G,	0x01
		.equ 	SEG_P,	0x10                
        .equ    LEFT_LED, 	0x02	@ Patterns for LED lights
        .equ    RIGHT_LED, 	0x01
        .equ    BOTH_LED, 	0x03
        .equ    NO_LED, 	0x00       
        .equ    LEFT_BLACK_BUTTON, 	0x02	@ Bit patterns for black buttons
        .equ    RIGHT_BLACK_BUTTON, 0x01
        @ bit patterns for blue keys 
        .equ    Ph1, 		0x0100	@ =8
        .equ    Ph2, 		0x0200	@ =9
        .equ    Ps1, 		0x0400	@ =10
        .equ    Ps2, 		0x0800	@ =11

		@ timing related
		.equ    SWI_GetTicks, 		0x6d	@ Get current time 
		.equ    EmbestTimerMask, 	0x7fff	@ 15 bit mask for Embest timer
											@(2^15) -1 = 32,767        										
        .equ	OneSecond,	1000	@ Time intervals
        .equ	TwoSecond,	2000
	@define the 2 streets
	@	.equ	MAIN_STREET		0
	@	.equ	SIDE_STREET		1
 
       .text           
       .global _start

@ ==== The entry point of the program
_start:		
	@ initialize all outputs
	BL Init				@ void Init ()
	@ Check for left black button press to start simulation
RepeatTillBlackLeft:
	swi     SWI_CheckBlack
	cmp     r0, #LEFT_BLACK_BUTTON	@ Start of simulation
	beq		StrS
	cmp     r0, #RIGHT_BLACK_BUTTON	@ Stop simulation
	beq     StpS

	bne     RepeatTillBlackLeft
StrS:	
	BL StartSim		@ Else start simulation: void StartSim()
	@ on return here, the right black button was pressed
StpS:
	BL EndSim		@ Clear board: void EndSim()
EndTrafficLight:
	swi	SWI_EXIT
		
	
	
@ ==== void Init()
@   Inputs:	None	
@   Outputs:	None 
@   Description:
@ 		Both LED lights on
@		8-segment = point only
@		LCD = ID only
Init:
	stmfd	sp!,{r0-r2,lr}
	@ LCD = ID on line 1
	mov	r1, #0			@ R1 = row
	mov	r0, #0			@ R0 = column 
	ldr	r2, =lineID		@ Identification
	swi	SWI_DRAW_STRING
	@ both LED on
	mov	r0, #BOTH_LED	@LEDs on
	swi	SWI_SETLED
	@ display point only on 8-segment
	mov	r0, #10			@ 8-segment pattern off
	mov	r1,#1			@ 8-segment point on
	BL	Display8Segment

DoneInit:
	LDMFD	sp!,{r0-r2,pc}



@ ==== void EndSim()
@   Inputs:	None
@   Outputs:	None
@   Description:
@		Clear the board and display the last message
EndSim:	
	stmfd	sp!, {r0-r2,lr}
	mov	r0, #10			@ 8-segment pattern off
	mov	r1,#0
	BL	Display8Segment		@ Display8Segment(R0:number;R1:point)
	mov	r0, #NO_LED
	swi	SWI_SETLED
	swi	SWI_CLEAR_DISPLAY
	mov	r0, #2
	mov	r1, #7
	ldr	r2, =Goodbye
	swi	SWI_DRAW_STRING  	@ Display goodbye message on line 7
	ldr	r10, =4000		@ Set Wait Delay to 4000 miliseconds
	BL	Wait			@ void Wait(Delay:R10)
	swi	SWI_CLEAR_DISPLAY
	ldmfd	sp!, {r0-r2,pc}
	
	
	
@ ==== void StartSim()
@   Inputs:	None	
@   Outputs:	None 
@   Description:
@ 		Handles primary control flow of the program
StartSim:
	stmfd	sp!,{r1-r10,lr}	

	mov	r1, #1		@ Initially start in S1.1
StartCarCycle:
	BL	CarCycle	@ int:R0 CarCycle(State:R1)
	cmp	r0, #0		@ Check why it returned
	beq	DoneStartSim	@ Right black was pressed - end simulation
	mov	r1, r0		@ Else set input to ped cycle place of call
	BL	PedCycle	@ void PedCycle(CallPosition:R1);
	cmp	r0, #1		@ Check why it returned
	beq	DoneStartSim	@ Right black was pressed - end simulation

	@ On return from PedCycle, go back to correct state in CarCycle
	@ test R1 where the call position to PedCycle came from originally
	cmp	r1, #3		@ If from I3, go back to S1.1
	beq	S1Car
	mov	r1, #5		@ Else restart CarCycle from State S5
	bal	StartCarCycle
S1Car:
	mov	r1, #1		@ Restart CarCycle from State S1.1	
	bal	StartCarCycle

DoneStartSim:
	ldmfd	sp!,{r1-r10,pc}



@ ==== int:R0 CarCycle(State:R1)
@   Inputs:	State:R1 = State where CarCycle starts
@   Outputs:	int:R0 = #1 for a pedestrian call at I1
@		int:R0 = #2 for a pedestrian call at I2
@		int:R0 = #3 for a pedestrian call at I3
@		int:R0 = #0 for a request to end simulation
@   Description:
@      		Start CarCycle from the given state in R1
@		State will either be #1 (S1) or #5 (S5)
@		Return value R0 for StartSim to process program flow
CarCycle:
	stmfd	sp!,{r1-r10,lr}	
	
	cmp	r1, #1
	bne	CarCycleS5
CarCycleLoop:
	mov	r5, #0		@ Set loop counter to zero
CarCycleS1:
	mov	r10, #1		@ Set DrawScreen PatternType to S1.1
				@ Set DrawState PatternType to S1
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r0, #10		@ Set Display8Segment to display no number
	mov	r1, #1		@ Set Display8Segment to display point
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r0, #LEFT_LED	@ Left LED on
	swi	SWI_SETLED
	mov	r10, #2000	@ Set Wait Delay to 2000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
CarCycleS1.2:
	mov	r10, #2		@ Set DrawScreen PatternType to S1.2
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
	add	r5, r5, #1	@ Increment loop counter by one
	cmp	r5, #4		@ Compare loop counter with #4
	blt	CarCycleS1	@ Branch if loop counter is less than #4
@ButtonCheckI1:
	mov	r6, #1		@ Set R6 to current state in CarCycle
	BL	ButtonCheck	@ int:R0 ButtonCheck(State:R6)
	cmp	r0, #0
	BGE	DoneCarCycle
	mov	r5, #0		@ Set loop counter to zero
CarCycleS2:
	mov	r10, #2		@ Set DrawState PatternType to S2
	BL	DrawState	@ void DrawState(PatternType:R10)
	mov	r10, #1		@ Set DrawScreen PatternType to S2.1
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
@ButtonCheckI2
	mov	r6, #2		@ Set R6 to current state in CarCycle
	mov	r10, #2000	@ Set Wait Delay to 2000 miliseconds
	BL	WaitAndPoll	@ void WaitAndPoll(State:R6, Delay:R10)
	cmp	r0, #0
	bge	DoneCarCycle
CarCycleS2.2:
	mov	r10, #2		@ Set DrawScreen PatternType to S2.2
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
@ButtonCheckI2:
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
				@ R6 is currently set to state S2 in CarCycle
	BL	WaitAndPoll	@ void WaitAndPoll(State:R6, Delay:R10)
	cmp	r0, #0
	bge	DoneCarCycle
	add	r5, r5, #1	@ Increment loop counter by one
	cmp	r5, #2		@ Compare loop counter with #2
	blt	CarCycleS2	@ Branch if loop counter is less than #2
CarCycleS3:
	mov	r10, #3		@ Set DrawScreen\DrawState PatternType to S3
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r0, #10		@ Set Display8Segment to display no number
	mov	r1, #0		@ Set Display8Segment to not display point
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r10, #2		@ Set WaitAndBlink Delay to 2 seconds
	BL	WaitAndBlink	@ void Wait(Delay:R10)
CarCycleS4:
	mov	r10, #4		@ Set DrawScreen\DrawState PatternType to S4
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r0, #BOTH_LED	@ LEDs on
	swi	SWI_SETLED
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
CarCycleS5:
	mov	r10, #5		@ Set DrawScreen\DrawState PatternType to S5
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r0, #10		@ Set Display8Segment to display no number
	mov	r1, #1		@ Set Display8Segment to display point
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r0, #RIGHT_LED	@ Right LED on
	swi	SWI_SETLED
	ldr	r10, =6000	@ Set Wait Delay to 6000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
CarCycleS6:
	mov	r10, #6		@ Set DrawScreen\DrawState PatternType to S6
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r1, #0		@ Set Display8Segment to not display point
	mov	r0, #10 	@ Set Display8Segment to display no number
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r10, #2		@ Set WaitAndBlink Delay to 2 seconds
	BL	WaitAndBlink	@ void Wait(Delay:R10)
CarCycleS7:
	mov	r10, #7		@ Set DrawScreen\DrawState PatternType to S7
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r0, #BOTH_LED	@ LEDs on
	swi	SWI_SETLED
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
@ButtonCheckI3:
	mov	r6, #3		@ Set R6 to current state in CarCycle
	BL	ButtonCheck	@ int:R0 ButtonCheck(State:R6)
	cmp	r0, #0		
	BGE	DoneCarCycle	
	
	BL	CarCycleLoop	@ Branch to beginning of CarCycle loop
DoneCarCycle:
	ldmfd	sp!,{r1-r10,pc}



@ ==== int:R0 PedCycle(CallPosition:R1)
@   Inputs:	CallPosition:R1 = Position where a pedestrian call was made
@   Outputs:	int:R0 = #0 if PedCycle ends normally
@		int:R0 = #1 if the right black button was pressed
@   Description:
@     		Start PedCycle from the given position in R1. 
@		If call made at I1 in CarCycle, R1 = #1
@		If call made at I2 in CarCycle, R1 = #2
@		If call made at I3 in CarCycle, R1 = #3
@		Return value R0 for StartSim to process program flow
PedCycle:
	stmfd	sp!,{r1-r10,lr}	

	cmp	r1, #3
	beq	PedCycleP3
PedCycleP1:
	mov	r10, #11	@ Set DrawScreen\DrawState PatternType to P1 using #11
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r0, #10		@ Set Display8Segment to display no number
	mov	r1, #0		@ Set Display8Segment to not display point
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r10, #2		@ Set WaitAndBlink Delay to 2 seconds
	BL	WaitAndBlink	@ void Wait(Delay:R10)
PedCycleP2:
	mov	r10, #12	@ Set DrawScreen\DrawState PatternType to P2 using #12
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
PedCycleP3:
	mov	r10, #13	@ Set DrawScreen\DrawState PatternType to P3 using #13
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r0, #NO_LED	@ LEDs off
	swi	SWI_SETLED
	mov	r0, #6		@ Set Display8Segment Number to #6
	mov	r1, #0		@ Turn Display8Segment point off
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
	mov	r0, #5		@ Set Display8Segment Number to #5
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
	mov	r0, #4		@ Set Display8Segment Number to #4
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
	mov	r0, #3		@ Set Display8Segment Number to #3
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
PedCycleP4:
	mov	r10, #14	@ Set DrawScreen\DrawState PatternType to P4 using #14
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r0, #2		@ Set Display8Segment Number to #2
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
	mov	r0, #1		@ Set Display8Segment Number to #1
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
PedCycleP5:
	mov	r10, #15	@ Set DrawScreen\DrawState PatternType to P5 using #15
	BL	DrawState	@ void DrawState(PatternType:R10)
	BL	DrawScreen	@ void DrawScreen(PatternType:R10)
	mov	r0, #0		@ Set Display8Segment Number to #0
	BL	Display8Segment	@ void Display8Segment(Number:R0; Point:R1)
	mov	r10, #1000	@ Set Wait Delay to 1000 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
ButtonCheckI4:
	swi     SWI_CheckBlack
	cmp     r0, #RIGHT_BLACK_BUTTON
	mov	r0, #0		@ Assume no button was pressed
	bne     DonePedCycle	@ Return R0 set to #0 if black button not pressed
	mov	r0, #1		@ Return R0 set to #1 if black button was pressed
		
DonePedCycle:
	ldmfd	sp!,{r1-r10,pc}
	
	
	
@ ==== int:R0 ButtonCheck(State:R6) 
@   Inputs:	State:R6 = State in CarCycle where button press is checked	
@   Outputs:	int:R0 = #0 if the right black button was pressed
@		int:R0 = #-1 if unused button or no button was pressed
@		int:R0 = State:R6 if a blue button 8-11 was pressed
@   Description:
@      		Checks if a button was pressed and returns the correct 
@		corresponding value for CarCycle to use
@		If a blue button 8-11 was pressed, the current state in CarCycle
@		that was passed to ButtonCheck in R6 is returned in R0
ButtonCheck:
	stmfd	sp!,{r1-r10,lr}
	
	swi	SWI_CheckBlack
	cmp	r0, #RIGHT_BLACK_BUTTON	@ Was the right black button pressed?
	mov	r0, #0			@ If yes, return R0 = #0
	beq	DoneButtonCheck
	swi	SWI_CheckBlue			
	cmp	r0, #Ph1		@ Was the #8 blue button pressed?
	beq	BlueButtonPushed	@ If yes, branch to BlueButtonPushed	
	cmp	r0, #Ph2		@ Was the #9 blue button pressed?
	beq	BlueButtonPushed	@ If yes, branch to BlueButtonPushed	
	cmp	r0, #Ps1		@ Was the #10 blue button pressed?
	beq	BlueButtonPushed	@ If yes, branch to BlueButtonPushed
	cmp	r0, #Ps2		@ Was the #11 blue button pressed?
	beq	BlueButtonPushed	@ If yes, branch to BlueButtonPushed
	bal	NoButtonPushed		@ Unused button or no button pressed
BlueButtonPushed:
	mov	r0, r6			@ If blue button 8-11 was pressed, return R0 = current state of CarCycle
	bal	DoneButtonCheck
NoButtonPushed:
	mov	r0, #-1			@ If unused button or no button was pressed, return R0 = #-1
DoneButtonCheck:
	ldmfd	sp!,{r1-r10,pc}

	

@ ==== void Wait(Delay:R10) 
@   Inputs:	Delay:R10 = Delay in milliseconds
@   Outputs:	None
@   Description:
@      		Wait for R10 milliseconds using a 15-bit timer 
Wait:
	stmfd	sp!, {r0-r2,r7-r10,lr}
	
	ldr     r7, =EmbestTimerMask
	swi     SWI_GetTicks	@ Get time T1
	and	r1,r0,r7	@ T1 in 15 bits
WaitLoop:
	swi 	SWI_GetTicks	@ Get time T2
	and	r2,r0,r7	@ T2 in 15 bits
	cmp	r2,r1		@ Is T2>T1?
	bge	simpletimeW
	sub	r9,r7,r1	@ Elapsed TIME = 32,676 - T1
	add	r9,r9,r2	@    + T2
	bal	CheckIntervalW
simpletimeW:
	sub	r9,r2,r1	@ Elapsed TIME = T2-T1
CheckIntervalW:
	cmp	r9,r10		@ Is TIME < desired interval?
	blt	WaitLoop
WaitDone:
	ldmfd	sp!, {r0-r2,r7-r10,pc}	



@ ==== void WaitAndBlink(Delay:R10) 
@   Inputs:	Delay:R10 = Delay in seconds
@   Outputs:	None
@   Description:
@      		Wait for R10 seconds and blink LED lights using 500 milisecond intervals
@		Each BlinkLoop is a 500 milisecond interval so the total delay in R10
@		is doubled and used to iterate through the loops of BlinkLoop
@		If total delay is 4 seconds, the total time will be 2*4(500 miliseconds)
@		which will result in a total 4000 milisecond delay time.
WaitAndBlink:
	stmfd	sp!, {r0-r2,r7-r10,lr}	

	mov	r1, r10		@ Store total delay seconds in R1 so R10 can be used
	add	r1, r1, r1	@ Because each BlinkLoop is 500 miliseconds, double total delay
				@ and use it to compute number of BlinkLoop iterations.
	mov 	r5, #0		@ Set loop counter to zero
BlinkLoop:
	cmp	r5, r1
	BGE	WaitAndBlinkDone
	mov	r0, #NO_LED	@ LEDs off
	swi	SWI_SETLED
	ldr	r10, =250	@ Set Wait Delay to 250 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
	mov	r0, #BOTH_LED	@ LEDs on
	swi	SWI_SETLED
	ldr	r10, =250	@ Set Wait Delay to 250 miliseconds
	BL	Wait		@ void Wait(Delay:R10)
	add	r5, r5, #1	@ Add #1 to loop counter
	BAL	BlinkLoop
	
WaitAndBlinkDone:
	ldmfd	sp!, {r0-r2,r7-r10,pc}

	
		
@ ==== int:R0 WaitAndPoll(State:R6, Delay:R10) 
@   Inputs:	State:R6 = Current state of CarCycle, Delay:R10 = Delay in milliseconds
@   Outputs:	int:R0 = #0 if the right black button was pressed
@		int:R0 = #-1 if unused button or no button was pressed
@		int:R0 = State:R6 if a blue button 8-11 was pressed
@   Description:
@     		Wait for R10 milliseconds using a 15-bit timer while polling
@		Stay for the interval unless there is a pedestrian request (blue button)
@		or an end of simulation request (right black button)
WaitAndPoll:
	stmfd	sp!,{r1-r10,lr}
	
	ldr    	r7, =EmbestTimerMask
	swi    	SWI_GetTicks	@ Get time T1
	and	r1,r0,r7	@ T1 in 15 bits
WaitAndPollLoop:
	BL	ButtonCheck	@ int:R0 ButtonCheck(State:R6)
	cmp	r0, #0		
	bge	DoneWaitAndPoll
	
	swi 	SWI_GetTicks	@ Get time T2
	and	r2,r0,r7	@ T2 in 15 bits
	cmp	r2,r1		@ Is T2>T1?
	bge	simpletimeWP
	sub	r9,r7,r1	@ Elapsed TIME= 32,676 - T1
	add	r9,r9,r2	@    + T2
	bal	CheckIntervalWP
simpletimeWP:
	sub	r9,r2,r1	@ Elapsed TIME = T2-T1
CheckIntervalWP:
	cmp	r9,r10		@ Is TIME < desired interval?
	blt	WaitAndPollLoop		
	mov	r0, #-1		@ No button was pressed. Return -1
DoneWaitAndPoll:
	LDMFD	sp!,{r1-r10,pc}



@ ==== void Display8Segment(Number:R0, Point:R1)
@   Inputs:	Number:R0 = Number to display, Point:R1 = Point or no point
@   Outputs:	None
@   Description:
@ 		Displays the number 0-9 in R0 on the 8-segment
@ 		If R1 = 1, the point is also shown
Display8Segment:
	STMFD 	sp!,{r0-r2,lr}
	ldr 	r2,=Digits
	ldr 	r0,[r2,r0,lsl#2]
	tst 	r1,#0x01 @if r1=1,
	orrne 	r0,r0,#SEG_P 		@then show P
	swi 	SWI_SETSEG8
	LDMFD 	sp!,{r0-r2,pc}
	
	
	
@ ==== void DrawScreen(PatternType:R10)
@   Inputs:	PatternType:R10 = Pattern to display according to state
@   Outputs:	None
@   Description:
@ 		Displays on LCD screen the 5 lines denoting
@		the state of the traffic light
@	Possible displays:
@	1 => S1.1 or S2.1- Green High Street
@	2 => S1.2 or S2.2	- Green blink High Street
@	3 => S3 or P1 - Yellow High Street   
@	4 => S4 or S7 or P2 or P5 - all red
@	5 => S5	- Green Side Road
@	6 => S6 - Yellow Side Road
@	7 => P3 - all pedestrian crossing
@	8 => P4 - all pedestrian hurry

@@@ NOTE: State number on upper right corner is shown
@@@ 		by procedure void DrawState (PatternType:R10)
@@@			called from within each state before calling
@@@			this DrawScreen
DrawScreen:
	STMFD 	sp!,{r0-r2,lr}
	cmp	r10,#1
	beq	S1		@ Used for S1.1 and S2.1
	cmp	r10,#2
	beq	S2		@ Used for S1.2 and S2.2
	cmp	r10,#3
	beq	S3
	cmp	r10,#4
	beq	S4
	cmp	r10,#5
	beq	S5
	cmp	r10,#6
	beq	S6
	cmp	r10,#7
	beq	S4		@ S7 has the same display as S4
	cmp	r10,#11
	beq	S3		@ Used for P1. Has same display as S3
	cmp	r10,#12
	beq	S4		@ Used for P2. Has same display as S4
	cmp	r10,#13
	beq	P3		
	cmp	r10,#14
	beq	P4
	cmp	r10,#15
	beq	S4		@ P5 has the same display as S4
	bal	EndDrawScreen
S1:
	ldr	r2,=line1S11
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S11
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S11
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
S2:
	ldr	r2,=line1S12
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S12
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S12
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
S3:
	ldr	r2,=line1S3
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S3
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S3
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
S4:
	ldr	r2,=line1S4
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S4
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S4
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
S5:
	ldr	r2,=line1S5
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S5
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S5
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
S6:
	ldr	r2,=line1S6
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3S6
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5S6
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
P3:
	ldr	r2,=line1P3
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3P3
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5P3
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
P4:
	ldr	r2,=line1P4
	mov	r1, #6			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line3P4
	mov	r1, #8			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	ldr	r2,=line5P4
	mov	r1, #10			@ r1 = row
	mov	r0, #11			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawScreen
EndDrawScreen:
	LDMFD 	sp!,{r0-r2,pc}
	
	
	
@ ==== void DrawState(PatternType:R10)
@   Inputs:	PatternType:R10 = number to display according to state
@   Outputs:	None
@   Description:
@ 		Displays on LCD screen the state number
@		on top right corner
DrawState:
	STMFD 	sp!,{r0-r2,lr}
	cmp	r10,#1
	beq	S1draw		
	cmp	r10,#2
	beq	S2draw
	cmp	r10,#3
	beq	S3draw
	cmp	r10,#4
	beq	S4draw
	cmp	r10,#5
	beq	S5draw
	cmp	r10,#6
	beq	S6draw
	cmp	r10,#7
	beq	S7draw
	cmp	r10,#11
	beq	P1draw
	cmp	r10,#12
	beq	P2draw
	cmp	r10,#13
	beq	P3draw
	cmp	r10,#14
	beq	P4draw
	cmp	r10,#15
	beq	P5draw
	bal	EndDrawState
S1draw:
	ldr	r2,=S1label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S2draw:
	ldr	r2,=S2label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S3draw:
	ldr	r2,=S3label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S4draw:
	ldr	r2,=S4label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S5draw:
	ldr	r2,=S5label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S6draw:
	ldr	r2,=S6label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
S7draw:
	ldr	r2,=S7label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
P1draw:
	ldr	r2,=P1label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
P2draw:
	ldr	r2,=P2label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
P3draw:
	ldr	r2,=P3label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
P4draw:
	ldr	r2,=P4label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
P5draw:
	ldr	r2,=P5label
	mov	r1, #2			@ r1 = row
	mov	r0, #30			@ r0 = column
	swi	SWI_DRAW_STRING
	bal	EndDrawState
EndDrawState:
	LDMFD 	sp!,{r0-r2,pc}
	
	
	
@@@@@@@@@@@@=========================
	.data
	.align
Digits:							@for 8-segment display
	.word SEG_A|SEG_B|SEG_C|SEG_D|SEG_E|SEG_G 	@0
	.word SEG_B|SEG_C 				@1
	.word SEG_A|SEG_B|SEG_F|SEG_E|SEG_D 		@2
	.word SEG_A|SEG_B|SEG_F|SEG_C|SEG_D 		@3
	.word SEG_G|SEG_F|SEG_B|SEG_C 			@4
	.word SEG_A|SEG_G|SEG_F|SEG_C|SEG_D 		@5
	.word SEG_A|SEG_G|SEG_F|SEG_E|SEG_D|SEG_C 	@6
	.word SEG_A|SEG_B|SEG_C 			@7
	.word SEG_A|SEG_B|SEG_C|SEG_D|SEG_E|SEG_F|SEG_G @8
	.word SEG_A|SEG_B|SEG_F|SEG_G|SEG_C 		@9
	.word 0 					@Blank 
	.align
lineID:		.asciz	"Traffic Light: Daniel Gilroy, V00813027"
@ patterns for all states on LCD
line1S11:		.asciz	"        R W        "
line3S11:		.asciz	"GGG W         GGG W"
line5S11:		.asciz	"        R W        "

line1S12:		.asciz	"        R W        "
line3S12:		.asciz	"  W             W  "
line5S12:		.asciz	"        R W        "

line1S3:		.asciz	"        R W        "
line3S3:		.asciz	"YYY W         YYY W"
line5S3:		.asciz	"        R W        "

line1S4:		.asciz	"        R W        "
line3S4:		.asciz	" R W           R W "
line5S4:		.asciz	"        R W        "

line1S5:		.asciz	"       GGG W       "
line3S5:		.asciz	" R W           R W "
line5S5:		.asciz	"       GGG W       "

line1S6:		.asciz	"       YYY W       "
line3S6:		.asciz	" R W           R W "
line5S6:		.asciz	"       YYY W       "

line1P3:		.asciz	"       R XXX       "
line3P3:		.asciz	"R XXX         R XXX"
line5P3:		.asciz	"       R XXX       "

line1P4:		.asciz	"       R !!!       "
line3P4:		.asciz	"R !!!         R !!!"
line5P4:		.asciz	"       R !!!       "

S1label:		.asciz	"S1"
S2label:		.asciz	"S2"
S3label:		.asciz	"S3"
S4label:		.asciz	"S4"
S5label:		.asciz	"S5"
S6label:		.asciz	"S6"
S7label:		.asciz	"S7"
P1label:		.asciz	"P1"
P2label:		.asciz	"P2"
P3label:		.asciz	"P3"
P4label:		.asciz	"P4"
P5label:		.asciz	"P5"

Goodbye:
	.asciz	"*** Traffic Light program ended ***"

	.end

