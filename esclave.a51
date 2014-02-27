
; ESCLAVE / PF
; Deux proto-threads sont utilisés sur cette carte.
; Le passage de l'un à l'autre se fait de la manière suivant.
; A chaque fois que le timer0 (sur 13bits) overflow, son interruption déroute le programme et modifie la banque.
; Par contre, cela empêche aux threads d'utiliser la pile.
; On pourrait modifier la structure de la pile pour pallier à ce problème, mais ce n'était pas nécessaire.

	LOCK_A	equ	30h
 
	org 0000h
	jmp init
	
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
   jmp retour
   
	org 0050h
init:
; --------------------
; INITIALISATION
	; Modification de SP
	mov SP, #10h
	; Adresse du thread 2
	mov 18h, #1Ah
	mov 19h, #00h       ; octet de poids faible
	mov 1Ah, #02h       ; octet de poids fort

	; Lancement du timer 0
	setb EA
	setb ET0
	setb TR0
	jmp thread1
			
; ----------------------
; THREAD 1, banque 0
	; TODO
thread1:
;recommence:

	mov A, #1
	jmp thread1
	
; ----------------------
; THREAD 2, banque 1
	org 0200h
	; TODO
thread2:
	mov R1, #34h ; mettre dans 31h la valeur communiquée par laser
	anl 09h, #01111111b	; on supprime le bit de parite
	push 09h	; R1
	push 7Fh	;vaut 0
	mov R1, #0
	ret	
retour:
	
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

	
	end
