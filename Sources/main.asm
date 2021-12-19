;*******************************************************************************
; Lab5 for HCS908QG
; EE 465 @ MSU
; 3 April 2014
; Kyler Callahan
;*******************************************************************************

NVOPT_VALUE         equ       $7E                 ; NVOPT: KEYEN=0,FNORED=1,SEC01=1,SEC00=0
                    #Uses     qg8.inc

;*******************************************************************************

LCD_E               pin       PTAD
LCD_RS              pin
LCD_DATA            equ       PTBD

I2C_DATA            pin
I2C_CLK             pin

;*******************************************************************************
                    #RAM
;*******************************************************************************

MyVars
heartbeat           rmb       1
bus_data            rmb       1
bus_address         rmb       1
seq_start           rmb       2
seq_loc             rmb       2
seq_len             rmb       1
seq_count           rmb       1
key_num             rmb       1
hb_toggle           rmb       1
key_val             rmb       2
lcd_count           rmb       1
str_write           rmb       1
bit_count           rmb       1                   ; Used to count bits in a Tx
seconds             rmb       1
minutes             rmb       1
hours               rmb       1
weekday             rmb       1
month_day           rmb       1
month               rmb       1
year                rmb       1
i2c_readbit         rmb       1
read_count          rmb       1
time_var            rmb       1
                    #size     MyVars

;*******************************************************************************
                    #ROM
;*******************************************************************************

STR_LENGTH          equ       8

Blank               fcb       %00000000
Date                fcb       'Date is '
Time                fcb       'Time is '
Slash               fcb       '/'
Colon               fcb       ':'

;*******************************************************************************

Start               proc
                    ldhx      #STACKTOP           ; initialize the stack pointer
                    txs
          ;-------------------------------------- ; Initialize Ports A[0] and B[0:7] as outputs
                    bset      LCD_E+DDR           ; Sets as output
                    bset      LCD_RS+DDR          ; Sets as output
                    bset      I2C_DATA+DDR        ; Sets as output
                    bset      I2C_CLK+DDR         ; Sets as output
                    bclr      LCD_E
                    bclr      LCD_RS
                    bset      I2C_DATA
                    bset      I2C_CLK
                    mov       #%11111111,LCD_DATA+DDR ; Sets LCD_DATA as outputs
          ;-------------------------------------- ; Initialize the variables declared in memory
                    @ClrVar   MyVars
                    mov       #$3C,heartbeat      ; Loads variable heartbeat with count
                    mov       #15,lcd_count
          ;--------------------------------------
                    jsr       Initialize_LEDs     ; Initializes the LEDs as off
                    jsr       MCU_init            ; Does stuff
          ;-------------------------------------- ; Initialize the LCD
                    jsr       LCDReset
          ;-------------------------------------- ; LED's output nothing
                    ldhx      #Blank              ; Points SequStart to Blank
                    sthx      seq_start
                    sthx      seq_loc             ; Points the current location to the beginning of Blank
                    mov       #1,seq_len          ; Blank is 1 long
                    mov       #1,seq_count        ; Blank is 1 long
          ;-------------------------------------- ; Initializes the time counters
                    mov       #$39,minutes        ; Initialize minutes with 39
                    mov       #$51,hours          ; 24hr mode, 11AM. Into the hours register %01010001
                    mov       #$01,weekday        ; This value doesnt actually matter for what we are doing
                    mov       #$19,month_day      ; It's the 19th
                    mov       #$09,month          ; It's the 9th month
                    mov       #$14,year           ; 2014

                    bsr       I2Csend
                    bsr       I2CRead
                    jsr       Diplay_Time

MainLoop            nop
                    @cop                          ; By default COP is disabled with device init. When enabling, also reset the watchdog.
                    bra       MainLoop

;*******************************************************************************
; I2C stuff
;*******************************************************************************

;*******************************************************************************
; Sends info

I2Csend             proc
          ;-------------------------------------- ; START condition
                    jsr       I2CStartBit         ; Give START condition
          ;-------------------------------------- ; ADDRESS byte, consists of 7-bit address + 0 as LSbit
                    lda       #$D0                ; Slave device address write
                    bsr       I2CTxByte           ; Send the eight bits
          ;-------------------------------------- ; DATA bytes
                    clra                          ; $00 sets pointer to seconds adress
                    bsr       I2CTxByte           ; Send it

                    lda       seconds             ; Data going into seconds
                    bsr       I2CTxByte           ; Send it

                    lda       minutes             ; Data going into minutes
                    bsr       I2CTxByte           ; Send it

                    lda       hours               ; Data going into hours
                    bsr       I2CTxByte           ; Send it

                    lda       weekday             ; Data going into what day of the week
                    bsr       I2CTxByte           ; Send it

                    lda       month_day           ; Data going into day of the month
                    bsr       I2CTxByte           ; Send it

                    lda       month               ; Data going into the month of the year
                    bsr       I2CTxByte           ; Send it

                    lda       year                ; WHAT YEAR IS IT!?
                    bsr       I2CTxByte           ; Send it
          ;-------------------------------------- ; STOP condition
                    jsr       I2CStopBit          ; Give STOP condition
                    jmp       I2CBitDelay         ; Wait a bit

;*******************************************************************************

I2CTxByte           proc
                    mov       #8,bit_count        ; Initialize bit counter
Loop@@              rola                          ; Shift MSbit into Carry
                    bcc       Low@@               ; Send low bit or high bit
          ;-------------------------------------- ; send high
                    bset      I2C_DATA            ; Set MSbit into Carry
                    jsr       I2CSetupDelay       ; Give some time for data

                    bset      I2C_CLK             ; Clock it in
                    jsr       I2CBitDelay         ; Wait a bit
                    bra       Cont@@
          ;-------------------------------------- ; send low
Low@@               bclr      I2C_DATA
                    jsr       I2CSetupDelay
                    bset      I2C_CLK
                    jsr       I2CBitDelay
          ;--------------------------------------
Cont@@              bclr      I2C_CLK             ; Restore clock to low state
                    dbnz      bit_count,Loop@@
;                   bra       I2CAckPoll

;*******************************************************************************
; Checks for the acknowledge bit

I2CAckPoll          proc
                    bset      I2C_DATA            ; Pulls data low
                    bclr      I2C_DATA+DDR        ; Set SDA as input
                    jsr       I2CSetupDelay       ; waits a bit
                    bset      I2C_CLK             ; Pulls clock high
                    jsr       I2CBitDelay         ; waits a bit
                    brset     I2C_DATA,NoAck@@    ; Look for ACK from slave

                    bclr      I2C_CLK             ; Restore clock line
                    bset      I2C_DATA+DDR        ; SDA back as output
          ;--------------------------------------
          ; No acknowledgment received from slave device currently does nothing
          ;--------------------------------------
NoAck@@             bclr      I2C_CLK
                    bset      I2C_DATA+DDR
                    rts

;*******************************************************************************
; Receives info

I2CRead             proc
          ;-------------------------------------- ; START condition
                    mov       #7,read_count       ; Count before not Agknowledge
                    bsr       I2CStartBit         ; Give START condition
          ;-------------------------------------- ; ADDRESS byte, consists of 7-bit address + 0 as LSbit
                    lda       #$D0                ; Slave device address write
                    bsr       I2CTxByte           ; Send the eight bits

                    clra                          ; $00 sets pointer to seconds adress
                    bsr       I2CTxByte           ; Send it

                    bsr       I2CStartBit         ; Give START condition

                    lda       #$D1                ; Slave device address write
                    bsr       I2CTxByte           ; Send the eight bits

                    bsr       Storebit            ; seconds
                    mov       i2c_readbit,seconds

                    bsr       Storebit            ; minutes
                    mov       i2c_readbit,minutes

                    bsr       Storebit            ; hours
                    mov       i2c_readbit,hours

                    bsr       Storebit            ; Day of week
                    mov       i2c_readbit,weekday

                    bsr       Storebit            ; Day of month
                    mov       i2c_readbit,month_day

                    bsr       Storebit            ; month of year
                    mov       i2c_readbit,month

                    bsr       Storebit            ; year
                    mov       i2c_readbit,year
          ;-------------------------------------- ; STOP condition
                    bsr       I2CStopBit          ; Give STOP condition
                    bra       I2CBitDelay         ; Wait a bit

;*******************************************************************************

Storebit            proc
                    bclr      I2C_DATA+DDR        ; Set SDA as input
                    bsr       I2CSetupDelay       ; waits a bit

                    mov       #8,bit_count
                    clr       i2c_readbit         ; Resets the temp variable

Loop@@              bset      I2C_CLK             ; Restore clock to low state
                    lda       PTAD
                    and       #%00000100          ; Grabs only the bit of interest
                    ora       i2c_readbit
                    rola
                    sta       i2c_readbit
                    dec       bit_count           ; Decrement the bit counter
                    bclr      I2C_CLK             ; Restore clock to low state
                    bsr       I2CSetupDelay
                    bne       Loop@@

                    lda       PTAD
                    and       #%00001000          ; Grabs only the bit of interest
                    ora       i2c_readbit
                    sta       i2c_readbit
                    bclr      I2C_CLK             ; Restore clock to low state
                    bsr       I2CSetupDelay

                    bset      I2C_DATA+DDR        ; Set SDA as output
                    dbnz      read_count,SendAck@@
          ;-------------------------------------- ; Send not agknoldege
                    bset      I2C_DATA
                    bra       Done@@
          ;-------------------------------------- ; Send agknoldege
SendAck@@           bclr      I2C_DATA
                    bsr       I2CBitDelay
Done@@              bset      I2C_CLK
                    bsr       I2CSetupDelay
                    bclr      I2C_CLK
                    rts

;*******************************************************************************
; Sends the start condition

I2CStartBit         proc
                    bset      I2C_DATA            ; Pulls data High
                    bset      I2C_CLK             ; Pulls clock low
                    bclr      I2C_DATA            ; Pulls data low
                    bsr       I2CBitDelay         ; Waits
                    bclr      I2C_CLK             ; Pulls clock low
                    rts

;*******************************************************************************
; Sends the stop condition

I2CStopBit          proc
                    bclr      I2C_DATA            ; Pulls data low
                    bset      I2C_CLK             ; pulls clock high
                    bset      I2C_DATA            ; Pulls data high
;                   bra       I2CBitDelay         ; waits

;*******************************************************************************
; Bit delay to provide the desired SCL freq

I2CBitDelay         proc
                    nop:4
;                   bra       I2CSetupDelay

;*******************************************************************************
; Arbitrary delay to let SDA stabalize

I2CSetupDelay       proc
                    nop:2
                    rts

;*******************************************************************************
; Reads Data from the BUS

Read_BUS            proc
                    psha
                    mov       #%1111,LCD_DATA+DDR ; Sets PortB [7:4] to inputs
                    mov       #%00000011,LCD_DATA ; Makes the Transceiver write to the bus
                    lda       LCD_DATA
                    and       #%11110000          ; Saves only the upper nibble of the port as data
                    sta       bus_data
                    pula
                    rts

;*******************************************************************************

Write_BUS           proc
                    psha                          ; Pushes the contents of A onto the stack
                    mov       #%11111111,PTBDD    ; Sets PortB [7:0] to outputs
                    lda       bus_data            ; Loads the contents of bus_data into accumulator A
                    and       #%11110000          ; Trows away the lower nibble
                    ora       bus_address         ; Adds the adress nibble to accumulator A
                    sta       LCD_DATA            ; Stores data and adress bringing the clock to a low
                    ora       #%00001000          ; Writes a 1 to G2A to create a logic high on all of the DFF to update the clock
                    sta       LCD_DATA
                    pula                          ; Restores previous A values
                    rts

;*******************************************************************************

Initialize_LEDs     proc
                    clr       bus_data            ; Sets the lower 4 LED DFF clock to a low
                    clr       bus_address
                    bsr       Write_BUS
                    inc       bus_address         ; Sets the upper 4 LED DFF clock to a low
                    bra       Write_BUS

;*******************************************************************************

Scan_Keypad         proc
                    push

                    mov       #%00000010,bus_address ; Writes to the rows of the keypad
                    mov       #%11100000,bus_data ; Looks at the first row
                    bsr       Write_BUS
                    bsr       Read_BUS
                    bsr       Check1

                    mov       #%00000010,bus_address ; Writes to the rows of the keypad

                    mov       #%11010000,bus_data ; Looks at the second row
                    bsr       Write_BUS
                    bsr       Read_BUS
                    bsr       Check4

                    mov       #%00000010,bus_address ; Writes to the rows of the keypad

                    mov       #%10110000,bus_data  ; Looks at the third row
                    bsr       Write_BUS
                    bsr       Read_BUS
                    bsr       Check7

                    mov       #%00000010,bus_address ; Writes to the rows of the keypad

                    mov       #%01110000,bus_data ; Looks at the fourth row
                    bsr       Write_BUS
                    bsr       Read_BUS
                    jsr       CheckStar

                    pull
                    rts

;*******************************************************************************

?CommonCheck        proc
                    sta       key_num
                    sta       key_val+1
                    mov       #%00110000,key_val
                    lda       bus_data
                    coma
                    rts

;*******************************************************************************
; CHECKS FOR WHICH BUTTON IS PRESSED

Check1              proc
                    lda       #$10
                    bsr       ?CommonCheck
                    and       #%00010000
                    bne       _1@@

Check2              lda       #$20
                    bsr       ?CommonCheck
                    and       #%00100000
_1@@                bne       _2@@

Check3              lda       #$30
                    bsr       ?CommonCheck
                    and       #%01000000
_2@@                bne       _3@@

CheckA              mov       #$A0,key_num
                    mov       #$10,key_val+1
                    mov       #%01000000,key_val
                    lda       bus_data
                    coma
                    and       #%10000000
_3@@                bne       _4@@
                    rts

Check4              lda       #$40
                    bsr       ?CommonCheck
                    and       #%00010000
_4@@                bne       _5@@

Check5              lda       #$50
                    bsr       ?CommonCheck
                    and       #%00100000
_5@@                bne       _6@@

Check6              lda       #$60
                    bsr       ?CommonCheck
                    and       #%01000000
_6@@                bne       _7@@

CheckB              mov       #$B0,key_num
                    mov       #$20,key_val+1
                    mov       #%01000000,key_val
                    lda       bus_data
                    coma
                    and       #%10000000
_7@@                bne       _8@@
                    rts

Check7              lda       #$70
                    bsr       ?CommonCheck
                    and       #%00010000
_8@@                bne       _9@@

Check8              lda       #$80
                    bsr       ?CommonCheck
                    and       #%00100000
_9@@                bne       _10@@

Check9              lda       #$90
                    bsr       ?CommonCheck
                    and       #%01000000
_10@@               bne       _11@@

CheckC              mov       #$C0,key_num
                    mov       #$30,key_val+1
                    mov       #%01000000,key_val
                    lda       bus_data
                    coma
                    and       #%10000000
_11@@               bne       _12@@
                    rts

CheckStar           lda       bus_data
                    coma
                    and       #%00010000
                    bne       star

Check0              clra
                    jsr       ?CommonCheck
                    and       #%00100000
_12@@               bne       _13@@

CheckPound          mov       #$F0,key_num
                    mov       #$60,key_val+1
                    mov       #%01000000,key_val
                    lda       bus_data
                    coma
                    and       #%01000000
_13@@               bne       _14@@

CheckD              mov       #$D0,key_num
                    mov       #$40,key_val+1
                    mov       #%01000000,key_val
                    lda       bus_data
                    coma
                    and       #%10000000
_14@@               bne       Key_Write
                    rts
          ;-------------------------------------- ; Clear diplay
star                mov       #%0100,bus_address
                    clr       bus_data
                    jsr       Write_BUS
                    jsr       Delay_Sub           ; wait for 20ms
                    mov       #$10,bus_data
                    jsr       Write_BUS
                    jmp       Delay_Sub           ; wait for 20ms

;*******************************************************************************
; ASSIGNS BUTTON VALUES

Key_Write           proc
                    mov       key_num,bus_data
                    clr       bus_address
                    jsr       Write_BUS
                    jmp       LCDwritenum

;*******************************************************************************
; Displays the time values

Diplay_Time         proc
          ;-------------------------------------- ; Clear diplay
                    mov       #%0100,bus_address
                    clr       bus_data
                    jsr       Write_BUS
                    jsr       Delay_Sub           ; wait for 20ms
                    mov       #$10,bus_data
                    jsr       Write_BUS
                    jsr       Delay_Sub           ; wait for 20ms
          ;-------------------------------------- ; Writes the date on the first line
                    ldhx      #Date
                    mov       #STR_LENGTH,str_write
                    jsr       LCD_stringwrite
                    mov       month,time_var      ; Writes the month
                    bsr       TimeWrite

                    ldhx      #Slash              ; Writes a '/'
                    mov       #1,str_write
                    jsr       LCD_stringwrite
                    mov       month_day,time_var  ; Writes the day of the month
                    bsr       TimeWrite

                    ldhx      #Slash              ; Writes a '/'
                    mov       #1,str_write
                    jsr       LCD_stringwrite
                    mov       year,time_var       ; Writes the year
                    bsr       TimeWrite
          ;-------------------------------------- ; Shift cursor to second line
                    mov       #%0100,bus_address
                    mov       #$C0,bus_data
                    jsr       Write_BUS
                    jsr       Delay_Sub           ; wait for 20ms
                    clr       bus_data
                    jsr       Write_BUS
                    jsr       Delay_Sub           ; wait for 20ms
          ;-------------------------------------- ; Writes the date on the second line
                    ldhx      #Time
                    mov       #STR_LENGTH,str_write
                    bsr       LCD_stringwrite
                    mov       hours,time_var      ; Writes the hour
                    bsr       HourWrite

                    ldhx      #Colon              ; Writes a ':'
                    mov       #1,str_write
                    bsr       LCD_stringwrite
                    mov       minutes,time_var    ; Writes the minutes
                    bsr       TimeWrite

                    ldhx      #Colon              ; Writes a ':'
                    mov       #1,str_write
                    bsr       LCD_stringwrite
                    mov       minutes,time_var    ; Writes the seconds
;                   bra       TimeWrite

;*******************************************************************************
; Writes I2C values

TimeWrite           proc
                    mov       #%00110000,key_val

                    lda       time_var
                    and       #$F0                ; Prints upper decimal
                    sta       key_val+1
                    bsr       Key_Write@@

                    lda       time_var
                    and       #$0F                ; Prints lower decimal
                    sta       key_val+1
Key_Write@@         jmp       Key_Write

;*******************************************************************************

HourWrite           proc
                    mov       #%00110000,key_val

                    lda       time_var
                    and       #$30                ; Prints upper decimal
                    sta       key_val+1
                    jsr       Key_Write

                    lda       time_var
                    and       #$0F                ; Prints lower decimal
                    sta       key_val+1
                    jmp       Key_Write

;*******************************************************************************
; Writes values to the LCD

LCDwritenum         proc
                    psha

                    jsr       Delay_Sub           ; wait for 20ms
                    bset      LCD_RS              ; Writes a 1 to Port A [1] to enable RS
                    mov       #%0100,bus_address
                    mov       key_val,bus_data    ; Writes the first nibble required to display characters 0-9
                    jsr       Write_BUS
                    jsr       Delay_Sub           ; wait for 20ms

                    mov       key_val+1,bus_data  ; Loads second nibble
                    jsr       Write_BUS
                    jsr       Delay_Sub           ; wait for 20ms
                    bclr      LCD_RS              ; Writes a 0 to Port A [1] to disable RS

                    pula
                    rts

;*******************************************************************************
; Writes strings to the LCD

LCD_stringwrite     proc
                    @pushv    key_val

Loop@@              lda       ,x
                    sta       key_val
                    nsa
                    sta       key_val+1

                    bsr       LCDwritenum

                    aix       #1
                    dbnz      str_write,Loop@@    ; loop for the whole string

                    @pullv    key_val
                    rts

;*******************************************************************************
; Strobes the heartbeat LED

HeartBeat_LED       proc
                    lda       hb_toggle           ; Loads contents of portA [0] into accumulator A
                    eor       #%10000000          ; Toggles the contents of A
                    sta       hb_toggle
                    sta       bus_data            ; Store
                    mov       #1,bus_address
                    jmp       Write_BUS

;*******************************************************************************
; Initializes the LCD

LCDReset            proc
                    bsr       Delay_Sub           ; wait for 20ms
                    mov       #$30,bus_data
                    mov       #%0100,bus_address
                    jsr       Write_BUS
                    bsr       Delay_Sub           ; wait for 20ms
                    mov       #$30,bus_data
                    jsr       Write_BUS
          ;-------------------------------------- ; wait for 20ms
                    mov       #$30,bus_data
                    jsr       Write_BUS
                    bsr       Delay_Sub           ; wait for 20ms
          ;-------------------------------------- ; 4-BIT BUS, 2 ROWS, 5X7 DOTS
                    mov       #$20,bus_data
                    jsr       Write_BUS
                    bsr       Delay_Sub           ; wait for 20ms
                    mov       #$20,bus_data
                    jsr       Write_BUS
                    bsr       Delay_Sub           ; wait for 20ms
                    mov       #$80,bus_data
                    jsr       Write_BUS
                    bsr       Delay_Sub           ; wait for 20ms
          ;-------------------------------------- ; Display on, cursor on, blinking
                    clr       bus_data
                    jsr       Write_BUS
                    bsr       Delay_Sub           ; wait for 20ms
                    mov       #$F0,bus_data
                    jsr       Write_BUS
                    bsr       Delay_Sub           ; wait for 20ms
          ;-------------------------------------- ; Clear diplay, cursor addr=0
                    clr       bus_data
                    jsr       Write_BUS
                    bsr       Delay_Sub           ; wait for 20ms
                    mov       #$10,bus_data
                    jsr       Write_BUS
                    bsr       Delay_Sub           ; wait for 20ms
          ;--------------------------------------
          ; Set mod to increment adress by one and shift the cursor to the right
          ;--------------------------------------
                    clr       bus_data
                    jsr       Write_BUS
                    bsr       Delay_Sub           ; wait for 20ms
                    mov       #%01100000,bus_data
                    jsr       Write_BUS
;                   bra       Delay_Sub           ; wait for 20ms

;*******************************************************************************
; Delay Sub-routine
; Code originally written by Matt.  Used with permission
; Sub-routine delays 20ms

                    #spauto

Delay_Sub           proc
                    push                          ; save the existing values of registers
                    #ais

                    clra
                    psha
                    lda       #$13
                    psha
                    lda       #$88
                    psha      count@@,3

                    tsx
Loop@@              @cop
                    tst       count@@,spx         ; if byte[0] == 0
                    beq       _1@@                ; jump to SUB_delay_outer_loop
                    dec       count@@,spx         ; else, decrement byte[0]
                    bra       Loop@@              ; repeat
          ;--------------------------------------
_1@@                tst       count@@+1,spx       ; if byte[1] == 0
                    beq       _2@@                ; branch to done
                    dec       count@@+1,spx       ; else, decrement byte[1]
                    lda       #$FF                ; reset byte[0]
                    sta       count@@,spx
                    bra       Loop@@              ; repeat
          ;--------------------------------------
_2@@                tst       count@@+2,spx       ; if byte[2] == 0
                    beq       Done@@              ; branch to done
                    dec       count@@+2,spx       ; else, decrement byte[2]

                    lda       #$FF
                    sta       count@@,spx         ; reset byte[0]
                    sta       count@@+1,spx       ; reset byte[1]
                    bra       Loop@@              ; repeat
          ;--------------------------------------
Done@@              ais       #:ais
                    pull                          ; restore registers to previous values
                    rts

                    #sp
;*******************************************************************************
                    #Uses     mcuinit.sub
;*******************************************************************************
