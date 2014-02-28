; VROUM PROJECT / PF

; Principe de fonctionnement du PWM:
; (? r??crire)
; Le code est fait de manicre r ce que la partie pour commander la direction soit la meme que pour commander le moteur.
; La diff?renciation se fait au niveau de la valeur de R0 (utilisé en adressage indirect)

; Les interruptions peuvent empecher une d?tection imm?diate de la fin du timer.
; C'est pour cette raison que les interruptions seront d?sactiv?es durant les ?tapes 1 et 3 (envoi d'un signal) et activ?s durant les ?tapes 2 et 4 (attente)
; La gestion des capteurs est effectu?e durant ces deux quarts de cycle PWM d'attente.

; Utilisations des registres:
; R0: pointe vers un registe contenant (temps d'?tat haut en microsecondes - 1000) / 4
; R1: pointe vers un octet entre 30h et 7Fh

; Valeurs:
; Direction: entre 28 (droite) et 222 (gauche). Tout droit: 125

; Asservissement:
; Un asservissement en vitesse est effectu?. Pour cela, le timer 1 compte sur P3.5, qui est reli? ? la diode.
; R?guli?rement, la valeur de ce timer est v?rifi?e. La d?cision d'augmenter la vitesse ou de la diminuer est alors prise selon cette valeur. Enfin, le timer est remis ? zero.

            PIN_DIR               bit    P1.4
            PIN_MOTEUR            bit    P1.5
            CAPT_D                bit    P1.6
            CAPT_G                bit    P1.7
            DIODE               bit       P1.0
            LASER_ACTIVE  bit P3.0	; modifié par la carte esclave

            NOIR_DROIT		bit 	00h
            TOGGLE_CAPT             bit     01h
            PANIQUE		bit 02h
	
            VITESSE            equ    01b
            DIRECTION            equ    10b
                VITESSE_MIN                equ     R2	;peut-être les remplacer par des R...
;                VITESSE_MIN_ADDR				equ 12h
                ATTENTE_ASSERV        equ     R3
;                ATTENTE_ASSERV_ADDR equ 13h
                BP_MEM                equ     R4
;                BP_MEM_ADDR	equ 14h
                DROITITUDE					equ 	R5
;                DROITITUDE_ADDR equ 15h
                HUIT_FOIS	equ R6
;                HUIT_FOIS_ADDR equ 16h
                COMPTEUR	equ R6
;                COMPTEUR_ADDR equ 17h
            
                                                   
            org 0000h
            jmp init
            
            ; Réveil par cette interruption (mode idle)
            org 000Bh
				clr TF0
            reti
                       
            org 0030h
;---------------------------
; Initialisation
init:
            mov SP, #0Fh             ; afin de ne pas ?craser la banque 1
            clr DIODE                     ; on allume la diode de la carte
				setb RS0	; utilisation de la banque 1
           
            ; ASSERV
            mov DIRECTION, #125d     ; roues droites
            mov VITESSE_MIN, #165                ; vitesse sans boost, modifiable par les boutons poussoirs
            mov VITESSE, VITESSE_MIN
            mov ATTENTE_ASSERV, #8     ;2.5 * 8 = 20ms entre deux changements de puissance d?livr?e au moteur, soit un cycle PWM
		      mov HUIT_FOIS, #8
            mov 08h, #01h	; 08h: R0 de la banque 1
            mov 09h, #60h	; 09h: R1 de la banque 1
           
            ; TIMER
            setb EA
            setb ET0				; activation de l'interruption de timer0
            mov TMOD, #01010001b     ; initialisation du timer 0 (mode 16bits) et du timer 1 (mode 16bits, avec horloge externe) et démarrage
            setb TR0
            setb TR1
            db 0,0,0,0,0,0	; équilibrage de timer 0 (OPEN NOP PARTY)

; ne rien écrire ici

demiBouclePWM:
; --------------------------
; PWM         
            ; on s'occupe du moteur si R0 vaut 01b, de la direction si R0 vaut 10b
            ; il ne faut pas faire d'embranchement sinon timer 0 n'aura pas toujours la même valeur
            mov A, R0
				mov C, ACC.2
				orl C, ACC.3
				cpl C
				mov ACC.7, C	; pourquoi ACC.7 particulièrement? Sans raison, c'est juste un bit disponible pour retenir C
				anl C, ACC.0
            mov PIN_MOTEUR, C
				mov C, ACC.1
				anl C, ACC.7
            mov PIN_DIR, C

            ; attente de 1ms. Pendant ce temps, on fait le reste.
            mov TL0, #2Ch
            mov TH0, #0FCh

; ----------------------
; gestion des capteurs et de la direction

					; cas particulier: si les deux détectent en même temps, on va tout droit
					jnb CAPT_G, pasLesDeux
					jnb CAPT_D, pasLesDeux
					jmp tout_droit
pasLesDeux:
					
                mov C, NOIR_DROIT
                anl C, /CAPT_G                    ;si on capte ? gauche, on met NOIR_DROIT ? 0. Sinon, on ne change rien.
                orl C, CAPT_D                    ;si on capte ? droite, on met NOIR_DROIT ? 1. Sinon, on ne change rien.
                ; ensuite, on effectue l'op?ration "XRL C, NOIR_DROIT" qui n'est pas dans le jeu d'instructions
                jnb NOIR_DROIT, est_nul
                mov NOIR_DROIT, C
                cpl C
                jmp fin_xor
est_nul:
                mov NOIR_DROIT, C
fin_xor:
                jnc pasChange
                clr PANIQUE 	; ouf, on a retrouvé la ligne
 				 	 setb TOGGLE_CAPT
pasChange:
                jnb LASER_ACTIVE, tourne
tout_droit:
                ; si on arrive ici, c'est que NOIR_DROIT a chang?
                ; dans ce cas, on remet les roues droites et on reprend la vitesse initiale
                mov DIRECTION, #125
                jmp fin_direction
               
tourne:
                jb NOIR_DROIT, tourne_droite
                mov A, #177
                jnb PANIQUE, pas_braque_gauche
					 add A, #50		; la somme doit faire 222
pas_braque_gauche:
					 clr C
                subb A, DROITITUDE
                mov DIRECTION, A
                mov A, DIRECTION
                jmp fin_direction
tourne_droite:
                mov A, #78
                jnb PANIQUE, pas_braque_droite
                clr C
 					 subb A, #50	; la différence doit faire 28
pas_braque_droite:                
                add A, DROITITUDE
                mov DIRECTION, A
fin_direction:

; ----------------------
; gestion des boutons poussoirs

                mov A, P1
                xrl A, BP_MEM    ; on v?rifie que l'?tat a chang? (qu'on soit sur un front)
                anl A, BP_MEM  ; on v?rifie que la pr?c?dente valeur est 1. Ces deux lignes d?tectent donc un front descendant.
                rr A
                rrc A
                jnc pas_bp0
                dec VITESSE_MIN   ; si BP0 est enfonc?, on ralentit
;                setb DIODE        ; et on ?teint la diode
                jmp pas_bp1
pas_bp0:
                rrc A
                jnc pas_bp1
                inc VITESSE_MIN    ; si BP1 est enfonc?, on acc?l?re
;                clr DIODE        ; et on allume la diode
pas_bp1:
                mov BP_MEM, P1        ; on actualise la m?moire
fin_bp:

; --------------------------
; asservissement vitesse et adoucissement rotation

      djnz ATTENTE_ASSERV, pasEncore
      mov ATTENTE_ASSERV, #8

      ; adoucissement rotation      
      mov A, @R1
      jnb ACC.0, pas_diminuer_compteur	; ACC.0 est le bit qui va disparaître
      dec COMPTEUR

pas_diminuer_compteur:
      mov C, TOGGLE_CAPT
      clr TOGGLE_CAPT
      jnc pas_augmenter_compteur
      inc COMPTEUR

pas_augmenter_compteur:
      mov ACC.0, C     			; une valeur est conservée 2560ms
      rlc A
      mov ACC.0, C
      djnz HUIT_FOIS, touche_pas_R1
      mov HUIT_FOIS, #8
      inc R1
      anl 09h, #11101111b	; au 6F on revient à 60
touche_pas_R1:

		jb PANIQUE, fin_consigne	;si on panique, la droititude reste à 0
		mov A, COMPTEUR
		clr C
		subb A, #3d
		jnb ACC.7, pasTropPetit
      ; compteur < 3
      setb PANIQUE	; on a perdu la ligne! Panique à bord!
      mov DROITITUDE, #0
		jmp fin_consigne
pasTropPetit:
		mov A, DROITITUDE
		clr C
		subb A, #40d	; On ne retourne pas complètement à des roues droites
		jz fin_consigne
		inc DROITITUDE
fin_consigne:

      ; asservissement vitesse
      mov A, TL1
      mov TL1, #0            ; on n'?teint pas le timer1 seulement pour ?a, WOLOLO
      clr C
      subb A, #3d
      jnb ACC.7, pas_bloque
      ; TL1 < 3
      mov VITESSE, #180d		; BOOST!
      jmp pasEncore
pas_bloque:
      mov VITESSE, VITESSE_MIN
pasEncore:


            inc PCON			; DODO             

; ----------------------
; fin gestion du PWM

              ; attente de 1ms encore
            mov TL0, #00Bh
            mov TH0, #0FCh
           
                ; R0 pointe soit vers vitesse, soit vers direction, soit vers 0
                mov A, @R0
                jz etat_bas

; ne rien ?crire ici, sinon le cas o? @R0=0 serait d?cal? de quelques microsecondes, ce qui pourrait faire exploser le v?hicule.

boucleElementaire:    ; dur?e d'une boucle ?l?mentaire: 4microsecondes
                nop
                nop
            djnz ACC, boucleElementaire
etat_bas:
            clr PIN_MOTEUR
            nop								; afin que l'écart temporel entre les deux clr soit le même qu'en les deux mov
            nop
            nop
            nop
            clr PIN_DIR
            inc PCON	; DODO		(si R3 vaut 250, alors que PC est sur cette ligne, timer0 vaut FFFF)
           
             ; on lance le timer pour 0.5ms
            mov TL0, #029h
            mov TH0, #0FEh
            
				inc R0
				anl 08h, #111b	; on tourne sur 8 registres
pasToggle:
            inc PCON
               ; DODO
            jmp demiBouclePWM

            end    
