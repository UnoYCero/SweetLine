; ==============================================================
;  FILLING-BOT v0.3   –   Esqueleto con define-map oficial
;  PIC16F877A  •  XT 4 MHz
;  Autor :  LUCA ⚡
; ==============================================================

            LIST      P=16F877A
            #include <P16F877A.INC>
            __CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _BOREN_OFF & \
                     _LVP_OFF & _CPD_OFF & _WRT_OFF & _CP_OFF

; ───────────────  ÁREA DE DATOS  ───────────────────────────────
            CBLOCK  0x20
TEMP
ENTRADA1         ; Bits RA5-0 + RE1-0 (ya ensamblados)
ENTRADA2         ; Bits RB7-0
STATE
FLAGS
TMR0_TMP
            ENDC

; ───────────────  ETIQUETAS  DE  ENTRADA  ─────────────────────
; ENTRADA1 (MSB…LSB)
#define S_Pieza         ENTRADA1,7   ; RE1
#define S_limiteM1_1    ENTRADA1,6   ; RE0
#define S_limiteM1_2    ENTRADA1,5   ; RA5
#define S_limiteM2      ENTRADA1,4   ; RA4
#define S_limiteM3      ENTRADA1,3   ; RA3
#define Celda           ENTRADA1,2   ; RA2 (comparador de carga)
#define NI1             ENTRADA1,1   ; RA1 (no usada)
#define NI2             ENTRADA1,0   ; RA0 (no usada)

; ENTRADA2  (HMI)
#define STOP            ENTRADA2,7   ; RB7
#define START           ENTRADA2,6   ; RB6
#define S0              ENTRADA2,5   ; RB5  (INICIO)
#define S1              ENTRADA2,4   ; RB4
#define AUTO            ENTRADA2,3   ; RB3
#define MAN             ENTRADA2,2   ; RB2
#define NI3             ENTRADA2,1   ; RB1
#define NI4             ENTRADA2,0   ; RB0

; ───────────────  ETIQUETAS  DE  SALIDA  ──────────────────────
; PORTD → Motores 1 y 2
#define M1_1_OUT        PORTD,7
#define M1_2_OUT        PORTD,6
#define M1_3_OUT        PORTD,5
#define M1_4_OUT        PORTD,4
#define M2_1_OUT        PORTD,3
#define M2_2_OUT        PORTD,2
#define M2_3_OUT        PORTD,1
#define M2_4_OUT        PORTD,0

; PORTC → Motor 3 + LCD
#define M3_1_OUT        PORTC,7
#define M3_2_OUT        PORTC,6
#define M3_3_OUT        PORTC,5
#define M3_4_OUT        PORTC,4
; RC3-0 = LCD (RC3=LCD1.1, etc.)

; ───────────────  RESET VECTOR  ───────────────────────────────
            ORG   0x0000
            GOTO  Init
            ORG   0x0004
ISR         RETFIE

; ───────────────  INICIALIZACIÓN  ─────────────────────────────
Init
            bsf     STATUS,RP0          ; Banco 1
            movlw   b'00111111'         ; RA0-5 entradas
            movwf   TRISA
            movlw   b'00000011'         ; RE0-1 entradas
            movwf   TRISE
            movlw   0xFF
            movwf   TRISB               ; RB0-7 entradas
            clrf    TRISC               ; Salidas (LCD+M3)
            clrf    TRISD               ; Salidas (M1 & M2)

            ; Comparadores off / analógico off
            movlw   b'00000111'
            movwf   CMCON
            movlw   b'00000110'
            movwf   ADCON1
            bcf     STATUS,RP0          ; Banco 0
            clrf    PORTC
            clrf    PORTD
            clrf    STATE
            clrf    FLAGS

; ───────────────  LAZO PRINCIPAL  ─────────────────────────────
MainLoop
            call    ActEntradas         ; Refresca ENTRADA1/2
            movf    STATE,W
            call    JumpTable
            goto    MainLoop

; ───────────────  TABLA DE SALTOS  ────────────────────────────
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

; ───────────────  HANDLERS  ───────────────────────────────────
St0_Espera
            btfsc   STOP            ; STOP activo → quieto
            goto    St0_Espera
            btfss   START           ; Espera START
            goto    St0_Espera
            btfsc   AUTO
            bsf     FLAGS,0         ; fAUTO
            btfsc   MAN
            bsf     FLAGS,1         ; fMAN
            movlw   1
            movwf   STATE
            return

St1_Home                     ; Condiciones iniciales / homing
            ; TODO: usa S_limiteM1_*, M2, M3 para “home-seek”
            movlw   2
            movwf   STATE
            return

St2_Vaciado                  ; Llenado / vaciado tolva
WaitCeldaOK
            btfss   Celda           ; Celda (RA2) alto ⇒ listo
            goto    WaitCeldaOK
            call    MotorTolva_Open
WaitLleno
            btfss   Celda           ; Cuando vuelva bajo ⇒ lleno
            goto    WaitLleno
            call    MotorTolva_Close
            movlw   3
            movwf   STATE
            return

St3_Carrusel
            btfss   S_Pieza         ; Espera RE1=1 pieza presente
            goto    St3_Carrusel
            call    MotorCarrusel_Step
            movlw   4
            movwf   STATE
            return

St4_Banda
            call    MotorBanda_Move
            movlw   0              ; Reinicia ciclo
            movwf   STATE
            return

; ──────────  SUBRUTINAS DE MOTORES  (vacías)  ─────────────────
MotorTolva_Open
            ; TODO: secuencia de RD7-4 (CW)
            return
MotorTolva_Close
            ; TODO: secuencia de RD7-4 (CCW)
            return
MotorCarrusel_Step
            ; TODO: RD3-0 avance 90 °
            return
MotorBanda_Move
            ; TODO: RC7-4 pasos o PWM
            return

; ───────────────  ENTRADAS → SNAPSHOT  ───────────────────────
ActEntradas
            bcf     STATUS,C
            movf    PORTA,W
            movwf   ENTRADA1
            movf    PORTE,W
            movwf   TEMP
            rlf     TEMP,F
            rlf     TEMP,F
            rlf     TEMP,F
            rlf     TEMP,F
            rlf     TEMP,F
            rlf     TEMP,W
            iorwf   ENTRADA1,F       ; RE1-0 se vuelven bits 7-6
            movf    PORTB,W
            movwf   ENTRADA2
            return

; ───────────────  RETARDOS  ───────────────────────────────────
            INCLUDE <RETARDOS.INC>
; =============================================================
            END
