; VROUM PROJECT / PF

; Principe de fonctionnement du PWM:
; (? r??crire)
; Le code est fait de manicre r ce que la partie pour commander la direction soit la meme que pour commander le moteur.
; La diff?renciation se fait au niveau de la valeur de R0 (utilisé en adressage indirect)

; Les interruptions peuvent empecher une d?tection imm?diate de la fin du timer.
; C'est pour cette raison que les interruptions seront d?sactiv?es durant les ?tapes 1 et 3 (envoi d'un signal) et activ?s durant les ?tapes 2 et 4 (attente)
; La gestion des capteurs est effectu?e durant ces deux quarts de cycle PWM d'attente.

; Utilisations des registres:
; R3: (temps d'?tat haut en microsecondes - 1000) / 4

; Valeurs:
; Direction: entre 25 (droite) et 225 (gauche). Tout droit: 125

; Asservissement:
; Un asservissement en vitesse est effectu?. Pour cela, le timer 1 compte sur P3.5, qui est reli? ? la diode.
; R?guli?rement, la valeur de ce timer est v?rifi?e. La d?cision d'augmenter la vitesse ou de la diminuer est alors prise selon cette valeur. Enfin, le timer est remis ? zero.

            PIN_DIR               bit    P1.4
            PIN_MOTEUR            bit    P1.5
            CAPT_D                bit    P1.6
            CAPT_G                bit    P1.7
            DIODE               bit       P1.0
            NOIR_DROIT             bit     00h
            LASER_ACTIVE  bit 01h
            ENCORE bit 02h
            VITESSE            equ    01b
            DIRECTION            equ    10b
                VITESSE_MIN                equ     30h
                ATTENTE_ASSERV        equ     32h
                BP_MEM                equ     33h
                                                   
            org 0000h
            jmp init
            
            ; Réveil par cette interruption  (mode idle)
            org 000Bh
				clr TF0
            reti
                       
            org 0030h
;---------------------------
; Initialisation
init:
            mov SP, #6Fh             ; afin de ne pas ?craser la banque 1
            clr DIODE                     ; on allume la diode de la carte
           
            ; ASSERV
            mov DIRECTION, #125d     ; roues droites
            mov VITESSE_MIN, #165                ; vitesse sans boost, modifiable par les boutons poussoirs
            mov VITESSE, VITESSE_MIN
            mov ATTENTE_ASSERV, #50     ; 500ms entre deux changements de puissance d?livr?e au moteur
				setb RS0
            mov 08h, #01h	; 08h: R0 de la banque 1
           
            ; TIMER
            setb EA
            setb ET0				; activation de l'interruption de timer0
            mov TMOD, #01010001b     ; initialisation du timer 0 (mode 16bits) et du timer 1 (mode 16bits, avec horloge externe)
            setb TR0
            setb TR1                         ; on lance directement le timer 1
            db 0,0,0,0,0,0	; équilibrage de timer 0

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
					jmp TOUT_DROIT
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
                jb LASER_ACTIVE, tout_droit
                jnc tourne_normalement
tout_droit:
                ; si on arrive ici, c'est que NOIR_DROIT a chang?
                ; dans ce cas, on remet les roues droites et on reprend la vitesse initiale
                mov DIRECTION, #125
                jmp fin_direction
               
tourne_normalement:
                jb NOIR_DROIT, tourne_droite
                mov A, DIRECTION
                clr C        ; pour ne pas fausser les subb
                subb A, #221
                jz fin_direction
                ; on tourne progressivement et on abaisse la vitesse
                inc DIRECTION
                jmp fin_direction
tourne_droite:
                mov A, DIRECTION            ;pas de commentaires ici. ?a vous apprendra.
                clr C
                subb A, #29
                jz fin_direction
                dec DIRECTION
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
; asservissement

      djnz ATTENTE_ASSERV, pasEncore
      mov ATTENTE_ASSERV, #50
      mov A, TL1
      mov TL1, #0            ; on n'?teint pas le timer1 seulement pour ?a, WOLOLO
      jnz pas_bloque
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

; ne rien ?crire ici, sinon le cas o? R3=0 serait d?cal? de quelques microsecondes, ce qui pourrait faire exploser le v?hicule.

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
