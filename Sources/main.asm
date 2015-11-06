;*******************************************************************
;* Lab5 for HCS908QG
;* EE 465 @ MSU
;* 3 April 2014
;* Kyler Callahan
;*
;* 
;*******************************************************************

; Include derivative-specific definitions
            INCLUDE 'derivative.inc'
            XREF MCU_init

; export symbols
            XDEF _Startup, main
            XDEF	Heartbeat, BUS_Data, BUS_Adress, Write_BUS, SeqStart, SeqLength, SeqLoc, SeqCount, Scan_Keypad, HeartBeat_LED
       
            ; we export both '_Startup' and 'main' as symbols. Either can
            ; be referenced in the linker .prm file or from C/C++ later on
            
            
            
            XREF __SEG_END_SSTACK   ; symbol defined by the linker for the end of the stack


; variable/data section
MY_ZEROPAGE: SECTION  SHORT         ; Insert here your data definition
			Heartbeat:		DS.B	1
			BUS_Data:		DS.B	1
			BUS_Adress:		DS.B	1
			SeqStart:		DS.B 	2 
			SeqLoc: 		DS.B 	2 
			SeqLength: 		DS.B 	1 
			SeqCount: 		DS.B 	1
			Key_Num:		DS.B	1
			HBToggle:		DS.B	1
			KeyvalH:		DS.B	1
			KeyvalL:		DS.B	1
			LCDcount:		DS.B	1
			str_write:		DS.B	1
			SUB_delay_cnt:	DS.B	3		; counter for SUB_delay subroutine
			vtempH:			DS.B	1
			vtempL:			DS.B	1
			BitCounter:		DS.B	1		;Used to count bits in a Tx
			Seconds:		DS.B	1
			Minutes:		DS.B	1
			Hours:			DS.B	1
			Weekday:		DS.B	1
			Dayofmonth:		DS.B	1
			Month:			DS.B	1
			Year:			DS.B	1
			I2CReadBit:		DS.B	1
			ReadCount:		DS.B	1
			Timevar:		DS.B	1
			
; Constand declaration
MY_CONST:	SECTION

			Blank:		DC.B	%00000000
			Date:		DC.B	"Date is "
			Time:		DC.B	"Time is "
			StrLength:	DC.B	8
			Slash:		DC.B	"/"
			Colon:		DC.B	":"
			CharLenght:	DC.B	1

; code section
MyCode:     SECTION
main:
_Startup:
            LDHX   #__SEG_END_SSTACK ; initialize the stack pointer
            TXS
            
            ; Initalizes Ports A[0] and B[0:7] as outputs
            bset	PTADD_PTADD0,PTADD 	; Sets DDRA [0] as an output
            bset	PTADD_PTADD1,PTADD	; Sets DDRA [1] as an output
            bset	PTADD_PTADD2,PTADD	; Sets DDRA [2] as output
            bset	PTADD_PTADD3,PTADD	; Sets DDRA [3] as output
			bclr	PTAD_PTAD0,PTAD  	; Writes a 0 to Port A [0]
			bclr	PTAD_PTAD1,PTAD  	; Writes a 0 to Port A [1]
			bset	PTAD_PTAD2,PTAD		; Writes a 1 to Port A [2]
			bset	PTAD_PTAD3,PTAD		; Writes a 1 to Port A [3]
			LDA		#%11111111
			STA		PTBDD				; Sets DDRB [0:7] as an output
			
			; Initalizes the variables declared in memory
			LDA		#$3C
			STA		Heartbeat			; Loads variable Heartbeat with count
			
			LDHX 	#$0000 				; Sets the start sequance to 0
 			STHX 	SeqStart 
 			STHX	SeqLoc 				; Sets the start location to 0
 			LDA		#$0F
 			STA		LCDcount
 			LDA 	#$00 					
 			STA 	SeqLength 			; Sets the lenght to 0
 			STA 	SeqCount 			; Sets the count to 0
 			STA		BUS_Data
 			STA		HBToggle			; Initalizes the heartbeat LED
 			STA		KeyvalL				; Sets Keyval to 0
 			STA		KeyvalH
 			STA		str_write			; Sets str_write to 0
 			STA		BitCounter
			STA		Seconds
			STA		I2CReadBit
			STA		ReadCount
 			
			JSR		Initalize_LEDs		; Initalizes the LEDs as off
			
			JSR    MCU_init			    ; Does stuff
			
			; Initaialize the LCD	
			JSR	   LCDReset
			
			; LED's output nothing
			LDHX	#Blank				; Points SequStart to Blank
			STHX	SeqStart
			STHX	SeqLoc				; Points the current location to the beginning of Blank
			LDA		#$01				; Blank is 1 long
			STA		SeqLength			
			STA		SeqCount
			
			
			;Initalizes the time coutners
			LDA		#$39				; Initalize minutes with 39
			STA		Minutes				
			
			LDA		#$51			; 24hr mode, 11AM.  Into the hours register %01010001
			STA		Hours
			
			LDA		#$01				; This value doesnt actually matter for what we are doing
			STA		Weekday
			
			LDA		#$19				; Its the 19th
			STA		Dayofmonth
			
			LDA		#$09				; Its the 9th month
			STA		Month
			
			LDA		#$14				; 2014
			STA		Year
			
			JSR		I2Csend
			JSR		I2CRead
			JSR		Diplay_Time
			
			
mainLoop:
			NOP
            ; feed_watchdog -- By default COP is disabled with device init. When enabling, also reset the watchdog. */
            BRA    mainLoop

;*************************************I2C stuff********************************************
;**************Sends info****************
I2Csend:
			;START condition
			JSR		I2CStartBit			; Give START condition
			
			;ADDRESS byte, consists of 7-bit address + 0 as LSbit
			LDA		#$D0				; Slave device address write
			JSR		I2CTxByte			; Send the eight bits
			
			;DATA bytes
			LDA		#$00				; $00 sets pointer to seconds adress
			JSR		I2CTxByte			; Send it
			
			LDA		Seconds				; Data going into seconds
			JSR		I2CTxByte			; Send it
			
			LDA		Minutes				; Data going into Minutes
			JSR		I2CTxByte			; Send it
			
			LDA		Hours				; Data going into Hours
			JSR		I2CTxByte			; Send it
			
			LDA		Weekday				; Data going into what day of the week
			JSR		I2CTxByte			; Send it
			
			LDA		Dayofmonth			; Data going into day of the month
			JSR		I2CTxByte			; Send it
			
			LDA		Month				; Data going into the month of the year
			JSR		I2CTxByte			; Send it
			
			LDA		Year				; WHAT YEAR IS IT!?
			JSR		I2CTxByte			; Send it

			;STOP condition
			JSR		I2CStopBit			; Give STOP condition
			
			JSR		I2CBitDelay			; Wait a bit
			RTS
I2CTxByte:
			;Initilize variable
			LDX		#$08
			STX		BitCounter
I2CNextBit:
			ROLA						; Shift MSbit into Carry
			BCC		SendLow				; Send low bit or high bit
SendHigh:
			BSET	PTAD_PTAD2,PTAD		; Set MSbit into Carry
			JSR		I2CSetupDelay		; Give some time for data
			
			BSET	PTAD_PTAD3,PTAD		; Clock it in
			JSR		I2CBitDelay			; Wait a bit
			BRA		I2CTxCont			; Continue
SendLow:
			BCLR	PTAD_PTAD2,PTAD
			JSR		I2CSetupDelay		
			BSET	PTAD_PTAD3,PTAD
			JSR		I2CBitDelay
I2CTxCont:
			BCLR	PTAD_PTAD3,PTAD		; Restore clock to low state
			DEC		BitCounter			; Decrement the bit counter
			BEQ		I2CAckPoll
			BRA		I2CNextBit

;***********Checks for the acknowledge bit**********			
I2CAckPoll:
			BSET	PTAD_PTAD2,PTAD				; Pulls data low
			BCLR	PTADD_PTADD2,PTADD			; Set SDA as input
			JSR		I2CSetupDelay				; waits a bit
			BSET	PTAD_PTAD3,PTAD				; Pulls clock high
			JSR		I2CBitDelay					; waits a bit
			BRSET	PTAD_PTAD2,PTAD,I2CNoAck	; Look for ACK from slave
			
			BCLR	PTAD_PTAD3,PTAD				; Restore clock line
			BSET	PTADD_PTADD2,PTADD			; SDA back as output
					
			;No acknowledgment received from slave device currently does nothing
I2CNoAck:
			BCLR	PTAD_PTAD3,PTAD
			BSET	PTADD_PTADD2,PTADD
			RTS
;************Receives info***************
I2CRead:
			;START condition
			LDA		#$07				; Counte before not Agknowledge
			STA		ReadCount
			
			JSR		I2CStartBit			; Give START condition
			
			;ADDRESS byte, consists of 7-bit address + 0 as LSbit
			LDA		#$D0				; Slave device address write
			JSR		I2CTxByte			; Send the eight bits
			
			LDA		#$00				; $00 sets pointer to seconds adress
			JSR		I2CTxByte			; Send it
			
			JSR		I2CStartBit			; Give START condition
			
			LDA		#$D1				; Slave device address write
			JSR		I2CTxByte			; Send the eight bits
			
			JSR		Storebit			; Seconds
			LDA		I2CReadBit
			STA		Seconds
			
			JSR		Storebit			; Minutes
			LDA		I2CReadBit
			STA		Minutes
			
			JSR		Storebit			; Hours
			LDA		I2CReadBit
			STA		Hours
			
			JSR		Storebit			; Day of week
			LDA		I2CReadBit
			STA		Weekday
			
			JSR		Storebit			; Day of month
			LDA		I2CReadBit
			STA		Dayofmonth
			
			JSR		Storebit			; Month of year
			LDA		I2CReadBit
			STA		Month
			
			JSR		Storebit			; Year
			LDA		I2CReadBit
			STA		Year
			
			;STOP condition
			JSR		I2CStopBit			; Give STOP condition
			
			JSR		I2CBitDelay			; Wait a bit
			
			
			RTS
			
Storebit:
			BCLR	PTADD_PTADD2,PTADD			; Set SDA as input
			JSR		I2CSetupDelay				; waits a bit
			
			LDX		#$08
			STX		BitCounter
			LDX		#$00						; Resets the temp variable
			STX		I2CReadBit
			
StoreLoop:			
			BSET	PTAD_PTAD3,PTAD				; Restore clock to low state
			LDA		PTAD
			AND		#%00000100					; Grabs only the bit of interest
			ORA		I2CReadBit
			ROLA
			STA		I2CReadBit
			DEC		BitCounter					; Decrement the bit counter
			BCLR	PTAD_PTAD3,PTAD				; Restore clock to low state
			JSR		I2CSetupDelay
			BNE		StoreLoop
			
			LDA		PTAD
			AND		#%00001000					; Grabs only the bit of interest
			ORA		I2CReadBit
			STA		I2CReadBit
			BCLR	PTAD_PTAD3,PTAD				; Restore clock to low state
			JSR		I2CSetupDelay
			
			BSET	PTADD_PTADD2,PTADD			; Set SDA as output
			DEC		ReadCount
			BEQ		SendnotAck
			
SendAck:
			BCLR	PTAD_PTAD2,PTAD				; Send agknoledge
			JSR		I2CBitDelay
			BSET	PTAD_PTAD3,PTAD
			JSR		I2CSetupDelay
			BCLR	PTAD_PTAD3,PTAD
			RTS


SendnotAck:
			BSET	PTAD_PTAD2,PTAD				; Send not agknoldege
			BSET	PTAD_PTAD3,PTAD
			JSR		I2CSetupDelay
			BCLR	PTAD_PTAD3,PTAD
			RTS

			
;**********Sends the start condition*********			
I2CStartBit:
			BSET	PTAD_PTAD2,PTAD				; Pulls data High
			BSET	PTAD_PTAD3,PTAD				; Pulls clock low
			BCLR	PTAD_PTAD2,PTAD				; Pulls data low
			JSR		I2CBitDelay					; Waits
			BCLR	PTAD_PTAD3,PTAD				; Pulls clock low
			RTS		
;**********Sends the stop condition**********
I2CStopBit:
			BCLR	PTAD_PTAD2,PTAD				; Pulls data low
			BSET	PTAD_PTAD3,PTAD				; pulls clock high
			BSET	PTAD_PTAD2,PTAD				; Pulls data high
			JSR		I2CBitDelay					; waits
			RTS
;*******Arbitrary delay to let SDA stabalize*******			
I2CSetupDelay:
			NOP
			NOP
			RTS
;*******Bit delay to provide the desired SCL freq*******					
I2CBitDelay:
			NOP
			NOP
			NOP
			NOP
			NOP
			NOP
			RTS		
;********************Reads Data from the BUS***********************
Read_BUS:
		 PSHA						; Pushes the contents of A onto the stack
		 
		 LDA		#%00001111		; Sets PortB [7:4] to inputs
		 STA		PTBDD
		 
		 LDA		#%00000011		; Makes the Transceiver write to the bus
		 STA		PTBD

		 LDA		PTBD
		 AND		#%11110000		; Saves only the upper nibble of the port as data
		 STA		BUS_Data
		 
		 PULA						; Restores previous A values
		 RTS
		 
Write_BUS:
		 PSHA						; Pushes the contents of A onto the stack
		 
		 LDA		#%11111111		; Sets PortB [7:0] to outputs
		 STA		PTBDD
		 
		 LDA		BUS_Data		; Loads the contents of BUS_Data into accumulator A
		 AND		#%11110000		; Trows away the lower nibble
         ORA		BUS_Adress		; Adds the adress nibble to accumulator A
         STA		PTBD			; Stores data and adress bringing the clock to a low
         
         ORA		#%00001000		; Writes a 1 to G2A to create a logic high on all of the DFF to update the clock
         STA		PTBD

		 PULA						; Restores previous A values
		 RTS



Initalize_LEDs:
			PSHA						; Pushes the contents of A onto the stack
			
			LDA		#%00000000
			STA		BUS_Data			; Sets the lower 4 LED DFF clock to a low
			STA		BUS_Adress
			JSR		Write_BUS
			
			LDA		#%00000001			; Sets the upper 4 LED DFF clock to a low
			STA		BUS_Adress
			JSR		Write_BUS
			

			PULA						; Restores previous A values
			
			RTS							; Returns from sub routine

Scan_Keypad:
			PSHA
			PSHH
			PSHX
			
			LDA		#%00000010			; Writes to the rows of the keypad
			STA		BUS_Adress
			
			LDA		#%11100000			; Looks at the first row
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Read_BUS
			JSR		Check1
			
			LDA		#%00000010			; Writes to the rows of the keypad
			STA		BUS_Adress	
			
			LDA		#%11010000			; Looks at the second row
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Read_BUS
			JSR		Check4	
			
			LDA		#%00000010			; Writes to the rows of the keypad
			STA		BUS_Adress
			
			LDA		#%10110000			; Looks at the third row
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Read_BUS
			JSR		Check7			
			
			LDA		#%00000010			; Writes to the rows of the keypad
			STA		BUS_Adress
			
			LDA		#%01110000			; Looks at the fourth row
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Read_BUS
			JSR		CheckStar
			
			PULX
			PULH
			PULA
			RTS			

;*********************** CHECKS FOR WHICH BUTTON IS PRESSED ****************************************			
Check1:		;Check for 1
			LDA		#$10
			STA		Key_Num
			STA		KeyvalL
			LDA		#%00110000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%00010000
			BNE		Key_Jump0

Check2:		;Check for 2
			LDA		#$20
			STA		Key_Num
			STA		KeyvalL
			LDA		#%00110000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%00100000
			BNE		Key_Jump0
			
Check3:		;Check for 3
			LDA		#$30
			STA		Key_Num
			STA		KeyvalL
			LDA		#%00110000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%01000000
			BNE		Key_Jump0

CheckA:		;Checks for A
			LDA		#$A0
			STA		Key_Num
			LDA		#$10
			STA		KeyvalL
			LDA		#%01000000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%10000000
			BNE		Key_Jump0
			RTS
			
Key_Jump0:
			BRA		Key_Jump1
			
Check4:		;Check for 4
			LDA		#$40
			STA		Key_Num
			STA		KeyvalL
			LDA		#%00110000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%00010000
			BNE		Key_Jump1
			

Check5:		;Check for 5
			LDA		#$50
			STA		Key_Num
			STA		KeyvalL
			LDA		#%00110000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%00100000
			BNE		Key_Jump1
			
Check6:		;Check for 6
			LDA		#$60
			STA		Key_Num
			STA		KeyvalL
			LDA		#%00110000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%01000000
			BNE		Key_Jump1					
			
CheckB:		;Checks for B
			LDA		#$B0
			STA		Key_Num
			LDA		#$20
			STA		KeyvalL
			LDA		#%01000000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%10000000
			BNE		Key_Jump1
			RTS
			
Key_Jump1:
			BRA		Key_Jump2
			
Check7:		;Check for 7
			LDA		#$70
			STA		Key_Num
			STA		KeyvalL
			LDA		#%00110000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%00010000
			BNE		Key_Jump2

Check8:		;Check for 8
			LDA		#$80
			STA		Key_Num
			STA		KeyvalL
			LDA		#%00110000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%00100000
			BNE		Key_Jump2
			
Check9:		;Check for 9
			LDA		#$90
			STA		Key_Num
			STA		KeyvalL
			LDA		#%00110000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%01000000
			BNE		Key_Jump2
			
CheckC:			;Checks for C
			LDA		#$C0
			STA		Key_Num
			LDA		#$30
			STA		KeyvalL
			LDA		#%01000000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%10000000
			BNE		Key_Jump2
			RTS

Key_Jump2:			
			BRA		Key_Write			
			
CheckStar:		;Check for Star
			LDA		BUS_Data
			COMA
			AND		#%00010000
			BNE		star

Check0:		;Check for 0
			LDA		#$00
			STA		Key_Num
			STA		KeyvalL
			LDA		#%00110000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%00100000
			BNE		Key_Jump2
			
CheckPound:		;Check for #
			LDA		#$F0
			STA		Key_Num
			LDA		#$60
			STA		KeyvalL
			LDA		#%01000000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%01000000
			BNE		Key_Write
			
CheckD:		;Checks for D
			LDA		#$D0
			STA		Key_Num
			LDA		#$40
			STA		KeyvalL
			LDA		#%01000000
			STA		KeyvalH
			LDA		BUS_Data
			COMA
			AND		#%10000000
			BNE		Key_Write
			RTS
			
star:		
			;Clear diplay
			LDA		#%0100
			STA		BUS_Adress
			LDA		#$00
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			LDA		#$10
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			
			RTS
			
;************************ASSIGNS BUTTON VALUES***************************
Key_Write:
			LDA		Key_Num
			STA		BUS_Data
			LDA		#$00
			STA		BUS_Adress
			JSR		Write_BUS
			JSR		LCDwritenum
			RTS			

;***************Displays the time values**************************
 Diplay_Time:
 			;Clear diplay
			LDA		#%0100
			STA		BUS_Adress
			LDA		#$00
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			LDA		#$10
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			
			;Writes the date on the first line
			LDHX	#Date
			LDA		StrLength
			STA		str_write
			JSR		LCD_stringwrite
			LDA		Month				; Writes the month
			STA		Timevar
			JSR		TimeWrite
			
			LDHX	#Slash				; Writes a '/'
			LDA		CharLenght
			STA		str_write
			JSR		LCD_stringwrite
			LDA		Dayofmonth			; Writes the day of the month
			STA		Timevar
			JSR		TimeWrite
			
			LDHX	#Slash				; Writes a '/'
			LDA		CharLenght
			STA		str_write
			JSR		LCD_stringwrite
			LDA		Year				; Writes the year
			STA		Timevar
			JSR		TimeWrite

			;Shift cursor to second line
			LDA		#%0100
			STA		BUS_Adress
			LDA		#$C0
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			LDA		#$00
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			
			;Writes the date on the second line
			LDHX	#Time
			LDA		StrLength
			STA		str_write
			JSR		LCD_stringwrite
			LDA		Hours				; Writes the hour
			STA		Timevar
			JSR		HourWrite
			
			LDHX	#Colon				; Writes a ':'
			LDA		CharLenght
			STA		str_write
			JSR		LCD_stringwrite
			LDA		Minutes			; Writes the minutes
			STA		Timevar
			JSR		TimeWrite
			
			LDHX	#Colon				; Writes a ':'
			LDA		CharLenght
			STA		str_write
			JSR		LCD_stringwrite
			LDA		Minutes			; Writes the seconds
			STA		Timevar
			JSR		TimeWrite
			
			RTS
			
;***********************Writes I2C values***********************
TimeWrite:
			LDA		#%00110000
			STA		KeyvalH
			
			LDA		Timevar
			AND		#$F0				; Prints upper decimal
			STA		KeyvalL
			JSR		Key_Write
			
			LDA		Timevar
			AND		#$0F				; Prints lower decimal
			STA		KeyvalL				
			JSR		Key_Write
			
			RTS
HourWrite:
			LDA		#%00110000
			STA		KeyvalH
			
			LDA		Timevar
			AND		#$30				; Prints upper decimal
			STA		KeyvalL
			JSR		Key_Write
			
			LDA		Timevar
			AND		#$0F				; Prints lower decimal
			STA		KeyvalL				
			JSR		Key_Write		
			
			RTS	

;*********************************Writes values to the LCD*****************************       	
LCDwritenum: 
			PSHA
			
			JSR		Delay_Sub			; wait for 20ms
			bset	PTAD_PTAD1,PTAD  	; Writes a 1 to Port A [1] to enable RS
			LDA		#%0100
			STA		BUS_Adress
			LDA		KeyvalH				; Writes the first nibble required to display characters 0-9
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms

			LDA		KeyvalL				; Loads second nibble
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			bclr	PTAD_PTAD1,PTAD  	; Writes a 0 to Port A [1] to disable RS
			
			PULA
			RTS
;******************** Writes strings to the LCD ******************
LCD_stringwrite:
			LDA		KeyvalH 			; Pushes the high values of the number onto the stack
			PSHA
			LDA		KeyvalL				; Pushes the low values of the number onto the stack
			PSHA
			
LCD_stringwrite_loop:			
			LDA		0,X		
			STA		KeyvalH
			NSA
			STA		KeyvalL
			
			JSR		LCDwritenum
			
			AIX		#1
			LDA		str_write
			DECA
			STA		str_write
			BNE		LCD_stringwrite_loop		;loop for the whole string
			
			PULA
			STA		KeyvalL
			PULA	
			STA		KeyvalH
			
			RTS
;***************Strobes the heartbeat LED**********************
HeartBeat_LED:

			LDA		HBToggle		; Loads contents of portA [0] into accumulator A
        	EOR		#%10000000		; Toggles the contents of A
        	STA		BUS_Data		; Store
        	STA		HBToggle
        	LDA		#%00000001
        	STA		BUS_Adress
        	
        	JSR		Write_BUS
        	
        	RTS	

;*************Initalizes the LCD*******************
LCDReset:
			JSR		Delay_Sub			; wait for 20ms
			LDA		#$30
			STA		BUS_Data
			LDA		#%0100
			STA		BUS_Adress
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			
			LDA		#$30
			STA		BUS_Data
			JSR		Write_BUS
					; wait for 20ms
			
			LDA		#$30
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			
			;4-BIT BUS, 2 ROWS, 5X7 DOTS
			LDA		#$20
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
				
			LDA		#$20
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			LDA		#$80
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			
			;Display on, cursor on, blinking
			LDA		#$00
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			LDA		#$F0
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			
			;Clear diplay, cursor addr=0
			LDA		#$00
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			LDA		#$10
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			
			; Set mod to increment adress by one and shift the cursor to the right
			LDA		#$00
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			LDA		#%01100000
			STA		BUS_Data
			JSR		Write_BUS
			JSR		Delay_Sub			; wait for 20ms
			
			RTS
;*************************Delay Sub-routine**********************************
; Code originally written by Matt.  Used with permission
; Sub-routine delays 20ms
Delay_Sub:
			; save the existing values of registers
			PSHH
			PSHX
			PSHA
			
			; load address of SUB_delay_cnt
			LDHX #SUB_delay_cnt
			LDA		#$00
			STA		2,X
			LDA		#$13
			STA		1,X
			LDA		#$88
			STA		0,X
			
SUB_delay_loop_0:

			feed_watchdog
			
			; if byte[0] == 0
			LDA 	0, X
			BEQ		SUB_delay_loop_1		; jump to SUB_delay_outer_loop
			
			;else
			DECA							; decrement byte[0]
			STA		0, X
			
			;repeat
			BRA SUB_delay_loop_0
			
SUB_delay_loop_1:

			; if byte[1] == 0
			LDA 	1, X
			BEQ		SUB_delay_loop_2		; branch to done
			
			;else
			DECA							; decrement byte[1]
			STA		1, X
			 
			LDA		#$FF					; reset byte[0]
			STA		0,X
			
			;repeat
			BRA SUB_delay_loop_0	
			
SUB_delay_loop_2:

			; if byte[2] == 0
			LDA 	2, X
			BEQ		SUB_delay_done			; branch to done
			
			;else
			DECA							; decrement byte[2]
			STA		2, X
			 
			LDA		#$FF					; reset byte[1]
			STA		1, X
			LDA		#$FF					; reset byte[0]
			STA		0, X
			
			;repeat
			BRA SUB_delay_loop_0	
			
SUB_delay_done:
			
			; restore registers to previous values 
			PULA
			PULX
			PULH
			
			RTS


