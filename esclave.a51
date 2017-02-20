
; ESCLAVE / PF
; Deux proto-threads sont utilis�s sur cette carte.
; Le passage de l'un � l'autre se fait de la mani�re suivant.
; A chaque fois que le timer0 (sur 13bits) overflow, son interruption d�route le programme et modifie la banque.
; Par contre, cela emp�che aux threads d'utiliser la pile.
; On pourrait modifier la structure de la pile pour pallier � ce probl�me, mais ce n'�tait pas n�cessaire.
 
	org 0000h
	jmp init
	
; ----------------------
; GESTION DU TIMER 0
	org 000Bh
	xrl SP, #10b   ; toggle de pile
   cpl RS0 			; toggle de banque
   reti
   
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
	setb EA
	setb ET0
	setb TR0
	jmp thread1
			
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
