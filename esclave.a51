
; ESCLAVE / PF
; Deux proto-threads sont utilisés sur cette carte.
; Le passage de l'un à l'autre se fait de la manière suivant.
; A chaque fois que le timer0 (sur 13bits) overflow, son interruption déroute le programme et modifie la banque.
; Chaque thread a à sa disposition une pile de 5 octets qu'il ne doit pas dépasser

	SORTIE_LASER equ	30h
	MUTEX_A		 bit	00h	; 0 si A occupé, 1 si A disponible
 
	org 0000h
	jmp init

	org 0023h
   clr RI
   push SBUF
   mov A, SBUF
   clr ACC.7		; on supprime le bit de parité
	push ACC
	push 7Fh	;vaut 0
	; TODO
	ret	

	retour:
	reti

; ----------------------
; GESTION DU TIMER 0
	org 000Bh
	jmp gestion_threads
   
   org 34h
   inc R1
   org 43h
   inc R1
   org 44h
   inc R1
   org 47h
   ; passage au maître
   jmp retour
   
	org 0050h
init:
; --------------------
; INITIALISATION
	; Modification de SP
	mov SP, #10h
	; Adresse du thread 1
	mov 18h, #1Ah
	mov 19h, #00h       ; octet de poids faible
	mov 1Ah, #02h       ; octet de poids fort
	setb MUTEX_A

	; Lancement du timer 0
	setb EA
	setb ET0
	setb TR0
	jmp thread1
			
; ----------------------
; THREAD 0, banque 0
	; TODO
thread1:
;recommence:
	call lock
	mov A, #1
	call unlock
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	jmp thread1
	
; ----------------------
; THREAD 1, banque 1
	org 0200h
	; TODO
thread2:
	call lock
	mov A, #2	
	call unlock
	db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	jmp thread2

; ----------------------
; Gestion des threads

gestion_threads:
	setb RS1
	mov R0, SP
   cpl RS0 			; toggle de banque
   mov SP, R0
   clr RS1
   reti

; ----------------------
; Procédure lock A

lock:
	jbc MUTEX_A, fin_lock
	clr TR0	; on arrête le timer 0
	mov TL0, #0FFh
	mov TH0, #0FFh	; on le met tout à la fin
	setb TR0	; on relance le timer 0, ce qui précipite le changement de thread
	jmp lock
fin_lock:
	ret

; ----------------------
; Procédure unlock A

unlock:
	setb MUTEX_A
	ret
	
	end
