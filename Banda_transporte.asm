; ****************************************************************************************
;  Sweet-Line – PIC16F877A  @ 4 MHz    MAIN v2.2  (08-may-2025)
; ****************************************************************************************
            LIST      P=16F877A
            #include  <P16F877A.INC>

; — LIBRERÍAS —
            INCLUDE   "RETARDOS.INC"
            INCLUDE   "LCD_4BIT.INC"          ; ¡¡OJO AJUSTAR RS/E/RW a pines libres
            INCLUDE   "UNIPOLAR_STEPPER.INC"  ; Multipuerto

            __CONFIG  _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF & _CP_OFF

; *****************************************  RAM (Bank0)  *****************************************
;  0x20-0x22 = Paso,Contador,Direccion (librería stepper)
CBLOCK  0x24
    TEMP
    ENTRADA1            ; bits: 7-NI,6-pieza,5-M1.1,4-M1.2,3-M2,2-M3,1-CEL1,0-CEL2
    ENTRADA2            ; bits: 7-6-NI,5-START,4-RESET,3-STOP,2-PARO,1-AUTO/MAN,0-DIR
    STATE
    FLAGS
ENDC

; *****************************************  FLAGS  *****************************************
#define fAUTO   0
#define fMAN    1

; *****************************************  ENTRADAS 1  (SEÑALES) *****************************************
#define S_Pieza      ENTRADA1,6   ; RB0
#define LIM_M1_1     ENTRADA1,5   ; RA5
#define LIM_M1_2     ENTRADA1,4   ; RA4
#define LIM_M2       ENTRADA1,3   ; RA3
#define LIM_M3       ENTRADA1,2   ; RE2
#define CELDA_1      ENTRADA1,1   ; RE1
#define CELDA_2      ENTRADA1,0   ; RE0

; *****************************************  ENTRADAS 2  (HMI) *****************************************
#define START_M1     ENTRADA2,5   ; RB6
#define RESET_M2     ENTRADA2,4   ; RB5
#define STOP_M3      ENTRADA2,3   ; RB4
#define PARO_SIS     ENTRADA2,2   ; RB3
#define MODO_SEL     ENTRADA2,1   ; RB2 (1=auto / 0=manual)
#define DIR_SEL      ENTRADA2,0   ; RB1 (Horario / Anti)

; *****************************************  SALIDAS (INDICADORES) *****************************************
#define BUZZER        PORTB,7     ; RB7  (activo)
#define LED_VERDE     PORTA,2     ; RA2
#define LED_AMARILLO  PORTA,1     ; RA1
#define LED_ROJO      PORTA,0     ; RA0

; *****************************************  VECTORES  *****************************************
            ORG   0x0000
            goto  Init
            ORG   0x0004
ISR         RETFIE

; *****************************************  INICIALIZACIÓN  *****************************************
Init
            ;  Configura TRIS 
            bsf     STATUS,RP0                 ; BANK1
            movlw   b'00111000'                ; RA5-3 IN, RA2-0 OUT
            movwf   TRISA
            movlw   b'00000111'                ; RE2-0 IN (tres señales)
            movwf   TRISE
            movlw   b'01111111'                ; RB7 OUT, RB6-1 IN, RB0 IN
            movwf   TRISB
            clrf    TRISC                      ; salidas (LCD nibble bajo + M3)
            clrf    TRISD                      ; salidas (M1, M2)
            bcf     STATUS,RP0                 ; BANK0
            clrf    PORTA
            clrf    PORTB
            clrf    PORTC
            clrf    PORTD
            clrf    PORTE
            clrf    FLAGS
            clrf    STATE

            ;  Comparadores / ADC off 
            movlw   b'00000111'
            movwf   CMCON
            movlw   b'00000110'
            movwf   ADCON1

            ; LCD banner
            call    LCD_Inicializa
            call    LCD_Borra
            call    LCD_Linea1
            movlw   "S"
            call    LCD_Caracter
            movlw   "W"
            call    LCD_Caracter
            movlw   "E"
            call    LCD_Caracter
            movlw   "E"
            call    LCD_Caracter
            movlw   "T"
            call    LCD_Caracter
            movlw   "-"
            call    LCD_Caracter
            movlw   "L"
            call    LCD_Caracter
            movlw   "I"
            call    LCD_Caracter
            movlw   "N"
            call    LCD_Caracter
            movlw   "E"
            call    LCD_Caracter
            call    Retardo_200ms

; *****************************************  BUCLE PRINCIPAL  *****************************************
MainLoop
            call    ActEntradas
            movf    STATE,W
            call    JumpTable
            goto    MainLoop

; *****************************************  TABLA INDEXADA  *****************************************
JumpTable
            addwf   PCL,F
            RETLW   HIGH St0_Espera
            RETLW   LOW  St0_Espera
            RETLW   HIGH St1_Home
            RETLW   LOW  St1_Home
            RETLW   HIGH St2_Vaciado
            RETLW   LOW  St2_Vaciado
            RETLW   HIGH St3_Carrusel
            RETLW   LOW  St3_Carrusel
            RETLW   HIGH St4_Banda
            RETLW   LOW  St4_Banda

; *****************************************  HANDLERS  *****************************************
St0_Espera
            btfsc   PARO_SIS
            goto    St0_Espera
            btfss   START_M1
            goto    St0_Espera
            btfsc   MODO_SEL
            bsf     FLAGS,fAUTO
            btfss   MODO_SEL
            bsf     FLAGS,fMAN
            call    LCD_Borra
            call    LCD_Linea1
            movlw   "H"
            call    LCD_Caracter
            movlw   "O"
            call    LCD_Caracter
            movlw   "M"
            call    LCD_Caracter
            movlw   "E"
            call    LCD_Caracter
            movlw   1
            movwf   STATE
            return

; ***************************************** HOMING *****************************************
St1_Home
            ; Implementa búsqueda de LIM_
            call    Retardo_1s
            movlw   2
            movwf   STATE
            return

; ***************************************** VACÍO / LLENADO *****************************************
St2_Vaciado
            bcf     Direccion,0          ; CW
            call    M1_Gira_45           ; Tolva abre
WaitLleno
            call    ActEntradas
            btfss   CELDA_1              ; espera comparador 1
            goto    WaitLleno
            bsf     Direccion,0          ; CCW
            call    M1_Gira_45           ; Tolva cierra
            movlw   3
            movwf   STATE
            return

; ***************************************** CARRUSEL *****************************************
St3_Carrusel
            bsf     Direccion,0          ; CCW
            call    M2_Gira_90
            movlw   4
            movwf   STATE
            return

; ***************************************** BANDA *****************************************
St4_Banda
            bcf     Direccion,0          ; CW
            call    M3_Gira_90
            movlw   0
            movwf   STATE
            return

; *****************************************  ACTUALIZAR ENTRADAS  *****************************************
ActEntradas
            ;  ENTRADA1 (RA5-3 + RE2-0 + RB0) 
            clrf    ENTRADA1
            ; RA5-3 → bits6-4
            movf    PORTA,W
            andlw   b'00111000'          ; RA5-3
            rlf     WREG,W               ; desplaza 1 → RA5→6, RA4→5, RA3→4
            movwf   ENTRADA1
            ; RE2-0 → bits3-1
            movf    PORTE,W
            andlw   b'00000111'          ; RE2-0
            rlf     WREG,W               ; RE2→3, RE1→2, RE0→1
            iorwf   ENTRADA1,F
            ; RB0  → bit0
            btfsc   PORTB,0
            bsf     ENTRADA1,0

            ;  ENTRADA2  (RB6-1) 
            movf    PORTB,W
            andlw   b'01111110'          ; limpia RB7 y RB0
            movwf   ENTRADA2
            return

            END
