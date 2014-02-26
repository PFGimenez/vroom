 
	org 0000h
	jmp init
	
	org 000Bh
	jmp gestion
	
	org 0030h
init:
; --------------------
; INITIALISATION
	; Modification de SP
	mov SP, #2Fh
	; Adresse du thread 2
	mov 32h, #00h       ; octet de poids faible
	mov 33h, #02h       ; octet de poids fort
	; Lancement du timer 0
	setb ea
	setb et0
	mov tmod, 1b	;mode 1: compteur sur 16 bits
	setb tr0
	jmp thread1
	
; ----------------------
; GESTION DU TIMER 0
gestion:
	clr tf0
	inc SP
	inc SP
	anl SP, #11111011b   ; toggle de pile
   xrl PSW, #00001000b 	; toggle de banque
   reti
		
; ----------------------
; THREAD 1
	; TODO
thread1:
	mov A, #1
	jmp thread1
	
; ----------------------
; THREAD 2
	org 0200h
	; TODO
thread2:
	mov A, #2	
	jmp thread2
