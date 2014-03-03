; ESCLAVE / PF
; Deux proto-threads sont utilisés sur cette carte.
; Le passage de l'un ŕ l'autre se fait de la maničre suivant.
; A chaque fois que le timer0 (sur 13bits) overflow, son interruption déroute le programme, push le contexte, modifie SP et pop le contexte.
; Un mécanisme de mutex est mis en place pour la donnée partagée entre les deux threads

	MUTEX		 bit	00h	; 0 si A occupé, 1 si A disponible
    NB_THREAD    bit    01h
    AUTRE_SP     equ    30h
	 QUI			  bit 	02h 
 
	org 0000h
	jmp init

; ----------------------
; GESTION DU TIMER 0
	org 000Bh
	jmp gestion_threads
   
	org 0030h
init:
; --------------------
; INITIALISATION
	; Adresse du thread 1, valeur de sa pile
	mov 19h, #02h       ; octet de poids fort
   mov 1Ah, #10h ; PSW, banque 2
   mov AUTRE_SP, #1Bh
   ; Mutex
	setb MUTEX
	; Lancement du timer 0 (mode 0, 13 bits)
   mov TMOD, #0
	setb EA
	setb ET0
	setb TR0
    
	jmp thread0

; ----------------------
; THREAD 0, banque 0
	; TODO
thread0:
	jmp thread0
	
; ----------------------
; THREAD 1, banque 2
	org 0200h
	; TODO
thread1:
	jmp thread1

; ----------------------
; Gestion des threads

gestion_threads:
    push PSW
    push ACC
    mov A, SP
    xch A, AUTRE_SP    
    mov SP, A
    cpl NB_THREAD
    pop ACC
    pop PSW     ; le changement de banque se fait au chargement de PSW
    reti

; ----------------------
; Procédure lock

lock:
	jbc MUTEX, fin_lock ; le choix de cette instruction n'est pas innocent. C'est une des rares instructions à fournir à la fois un test et une affectation. De ce fait, ces deux étapes d'acquisition du mutex sont atomiques et ne peuvent être interrompues par un changement de thread qui pourrait tout ruiner.
	; si on est ici, c'est que la variable n'est pas disponible
	mov C, QUI
	jb NB_THREAD, pasComplement
	cpl C
pasComplement:	
	jc fin_lock	; dans ce cas, c'est que c'est ce m�me thread qui utilise d�j� la ressource
	clr TR0	; on arręte le timer 0
	mov TL0, #0FFh
	mov TH0, #0FFh	; on le met tout ŕ la fin
	setb TR0	; on relance le timer 0, ce qui précipite le changement de thread
    ; ou alors, juste "inc PCON" pour dormir le reste du temps
	jmp lock
fin_lock:
	mov C, NB_THREAD
	mov QUI, C
	ret

; ----------------------
; Procédure unlock

unlock:
	setb MUTEX
	ret

	end
