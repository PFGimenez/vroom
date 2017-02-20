
; VROUM PROJECT / PF

; Principe de fonctionnement du PWM:
; on divise le cycle de 20ms (appel� cycle PWM) en petits cycles de 25�s (appel�s cycles �l�mentaire).
; Il faut donc 800 cycles �l�mentaires pour faire un cycle PWM. Chaque cycle �l�mentaire est mesur� par un timer
; De plus, le cycle PWM est divis� en quatre parties d'�gales longueurs (5ms chacune).
; Etape 1: le signal haut pour la direction est envoy�.
; Etape 2: le programme attend.
; Etape 3: le signal haut pour le moteur est envoy�.
; Etape 4: le programme attend.
; La direction et le moteur auront donc chacun un PWM de m�me p�riode (20ms) mais d�phas� (ce qui n'a aucune incidence). 
; Le code est fait de mani�re � ce que la partie pour commander la direction soit la m�me que pour commander le moteur.
; La diff�renciation se fait au niveau de la banque utilis�e (direction: banque 0 / moteur: banque 1).

; Les interruptions peuvent emp�cher une d�tection imm�diate de la fin du timer.
; C'est pour cette raison que les interruptions seront d�sactiv�es durant les �tapes 1 et 3 (envoi d'un signal) et activ�s durant les �tapes 2 et 4 (attente)
; La gestion des capteurs est effectu�e durant ces deux quarts de cycle PWM d'attente.

; Utilisations des registres:
; R0: nombre de cycles �l�mentaires restants pour un quart de boucle PWM
; R1: nombre de cycles �l�mentaires d'�tats bas pour un quart de boucle PWM
; R2: masque OU de sortie (0001000b pour direction car on utilise P1.4 et 0010000b pour moteur car on utilise P1.5)
; R3: masque ET de sortie, R3 = not(R2) (not �tant le compl�mentaire en 1)

			CAPT_D		bit 	P1.6
			CAPT_G		bit	P1.7
			DIODE       bit   P1.0
			VITESSE		equ	09h
			DIRECTION	equ	01h

			org 0000h
			jmp init
       
        	org 0030h
;---------------------------
; Initialisation
init:
		  	mov sp, #0Fh				; afin de ne pas �craser la banque 1 (non n�cessaire si pas d'utilisation de la pile)
		  	mov DIRECTION, #140d		; roues droites
		  	mov VITESSE, #138d      ; vitesse standard
		  	; �criture des masques
		  	mov 02h, #00010000b		; R2 de la banque 0
		  	mov 03h, #11101111b  	; R3 de la banque 0
		  	mov 0Ah, #00100000b  	; R2 de la banque 1
		  	mov 0Bh, #11011111b  	; R3 de la banque 1
        	mov tmod, #1b        	; initialisation du timer 0
        	
; --------------------------
; PWM
quartBouclePWM:
			mov A, P1					; au d�but, on est � l'�tat haut
			orl A, R2
			mov P1, A
        	mov R0,#200d        		;un quart de cycle �l�mentaire = 200 * 25�s = 5 ms
boucleElementaire:
			db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        	mov A, R0					;ces trois lignes v�rifies l'in�galit� entre R0 et R1
        	subb A, R1
        	jnz continue
			mov A, P1					; on passe � l'�tat bas
			anl A, R3
			mov P1, A
continue:
        	djnz R0, boucleElementaire    	;on recommence 200 fois

        	mov tl0, #089h
        	mov th0, #0ECh
        	clr tf0
        	setb tr0           		; on d�marre le timer 0

; ----------------------
; gestionCapteur
            jb CAPT_G, pasGauche
           
            mov DIRECTION, #150d
            jmp finIf
pasGauche:
            jb CAPT_D, pasDroit
            mov DIRECTION, #130d
            jmp finIf
pasDroit:           
            ; Si on arrive ici, c'est qu'on n'a d�tect� aucune bande noire
            mov DIRECTION, #140d
finIf:		

; ----------------------
; fin gestion du PWM
    										; attente de 5ms (�tape 2 et 4)
attente2:
        	jnb tf0, attente2
        	clr tr0						; on arrete le timer 0
        	nop							; pas toujours n�cessaire, selon la parit�
        	xrl PSW, #00001000b
        	jmp quartBouclePWM 		;une fois les 200 cycles �l�mentaires termin�es, on reprend le cycle PWM
        	end
