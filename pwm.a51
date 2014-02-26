
; VROUM PROJECT / PF

; Principe de fonctionnement du PWM:
; (à réécrire)
; Le code est fait de manicre r ce que la partie pour commander la direction soit la meme que pour commander le moteur.
; La différenciation se fait au niveau de la banque utilisée (direction: banque 0 / moteur: banque 1).

; Les interruptions peuvent empecher une détection immédiate de la fin du timer.
; C'est pour cette raison que les interruptions seront désactivées durant les étapes 1 et 3 (envoi d'un signal) et activés durant les étapes 2 et 4 (attente)
; La gestion des capteurs est effectuée durant ces deux quarts de cycle PWM d'attente.

; Utilisations des registres:
; R3: (temps d'état haut en microsecondes - 1000) / 4

; Valeurs:
; Direction: entre 25 (droite) et 225 (gauche). Tout droit: 125

; Asservissement:
; Un asservissement en vitesse est effectué. Pour cela, le timer 1 compte sur P3.5, qui est relié à la diode.
; Régulièrement, la valeur de ce timer est vérifiée. La décision d'augmenter la vitesse ou de la diminuer est alors prise selon cette valeur. Enfin, le timer est remis à zero.

            PIN_DIR       		bit    P1.4
            PIN_MOTEUR    		bit    P1.5
            CAPT_D        		bit    P1.6
            CAPT_G        		bit    P1.7
            DIODE       		bit  	 P1.0
            NOIR_DROIT	 		bit	 00h
            VITESSE        	equ    0Bh
            DIRECTION    		equ    03h
				CONSIGNE				equ	 30h
				CONSIGNE_INIT		equ	 31h
				ATTENTE_ASSERV		equ	 32h
				ATTENTE_CONSIGNE  equ	 33h
				BP_MEM				equ	 34h
                                    
            org 0000h
            jmp init
            
            org 0030h
;---------------------------
; Initialisation
init:
            mov SP, #0Fh             ; afin de ne pas écraser la banque 1
            clr DIODE					 ; on allume la diode de la carte
            
            ; ASSERV
            mov DIRECTION, #125d     ; roues droites
            mov VITESSE, #145d       ; vitesse standard
            mov CONSIGNE_INIT, #15				; consigne de référence, constante a priori (peut-être modifiée par les boutons poussoirs)
            mov CONSIGNE, CONSIGNE_INIT		; consigne en vitesse, variable
            mov ATTENTE_ASSERV, #50	 ; 500ms entre deux changements de puissance délivrée au moteur
				mov ATTENTE_CONSIGNE, #1	; pour la modifier immédiatement
            
            ; TIMER
            mov TMOD, #01010001b     ; initialisation du timer 0 (mode 16bits) et du timer 1 (mode 16bits, avec horloge externe)
            setb TR1						 ; on lance directement le timer 1
				
demiBouclePWM:
; --------------------------
; PWM
            ; ces quelques lignes mettent à 1 la pin soit de direction (si on est dans l'étape de la direction) soit du moteur
            mov C, RS0
            mov PIN_MOTEUR, C
            cpl C
            mov PIN_DIR, C

            ; attente de 1ms
            mov TL0, #2Fh
            mov TH0, #0FCh
            setb TR0
boucle_attente_1ms:
            jnb TF0, boucle_attente_1ms
            clr TF0
            clr TR0
		      
		      ; attente de 1ms encore
            mov TL0, #00Fh
            mov TH0, #0FCh
            setb TR0
            
				; R3 contient soit VITESSE soit DIRECTION
				mov ACC, R3
				jz etat_bas

; ne rien écrire ici, sinon le cas où R3=0 serait décalé de quelques microsecondes, ce qui pourrait faire exploser le véhicule.

boucleElementaire:	; durée d'une boucle élémentaire: 4microsecondes
				nop
				nop
            djnz ACC, boucleElementaire

etat_bas:
				nop						; ajustement de la parité de PC
            clr PIN_MOTEUR
            nop				; le nop est ici pour synchroniser la mise à 1 et la mise à 0.
            clr PIN_DIR
            
boucle_attente_1ms_bis:
            jnb TF0, boucle_attente_1ms_bis	;si R3 vaut 250, alors lorsqu'on arrive ici pour la première fois, THL0 = 0
            clr TF0
            clr TR0
            
             ; on lance le timer pour 8ms 
            mov TL0, #0D8h
            mov TH0, #0E0h
            setb TR0

; ----------------------
; gestion des capteurs et de la direction

				mov C, NOIR_DROIT
				anl C, /CAPT_G					;si on capte à gauche, on met NOIR_DROIT à 0. Sinon, on ne change rien.
				orl C, CAPT_D					;si on capte à droite, on met NOIR_DROIT à 1. Sinon, on ne change rien.
				; ensuite, on effectue l'opération "XRL C, NOIR_DROIT" qui n'est pas dans le jeu d'instructions
				jnb NOIR_DROIT, est_nul
				mov NOIR_DROIT, C
				cpl C
				jmp fin_xor
est_nul:
				mov NOIR_DROIT, C
fin_xor:
				jnc tourne_normalement
				; si on arrive ici, c'est que NOIR_DROIT a changé
				; dans ce cas, on remet les roues droites et on reprend la vitesse initiale
				mov DIRECTION, #125
				mov CONSIGNE, CONSIGNE_INIT
				mov ATTENTE_CONSIGNE, #1
				jmp fin_direction
				
tourne_normalement:
				djnz ATTENTE_CONSIGNE, fin_direction
				mov ATTENTE_CONSIGNE, #50h			;500ms entre deux changements de consigne
				jnb NOIR_DROIT, tourne_gauche
				clr C		; pour ne pas fausser les subb
				mov A, DIRECTION
				subb A, #195
				jz fin_direction
				; on tourne progressivement et on abaisse la vitesse
				mov A, DIRECTION
				add A, #3
				mov DIRECTION, A
				mov A, CONSIGNE
				subb A, #3
				mov CONSIGNE, A
				jmp fin_direction
tourne_gauche:
				mov A, DIRECTION			;pas de commentaires ici. ça vous apprendra.
				subb A, #155
				jz fin_direction
				mov A, DIRECTION
				subb A, #3
				mov DIRECTION, A
				mov A, CONSIGNE
				subb A, #3
				mov CONSIGNE, A
fin_direction:

; ----------------------
; gestion des boutons poussoirs

				mov A, P1
				xrl A, BP_MEM	; on vérifie que l'état a changé (qu'on soit sur un front)
				anl A, BP_MEM  ; on vérifie que la précédente valeur est 1. Ces deux lignes détectent donc un front descendant.
				rr A
				rrc A
				jnc pas_bp0
				dec CONSIGNE_INIT   ; si BP0 est enfoncé, on ralentit
				setb DIODE		; et on éteint la diode
				jmp pas_bp1
pas_bp0:
				rrc A
				jnc pas_bp1
				inc CONSIGNE_INIT	; si BP1 est enfoncé, on accélère
				clr DIODE		; et on allume la diode
pas_bp1:
				mov BP_MEM, P1		; on actualise la mémoire

; --------------------------
; asservissement
				djnz ATTENTE_ASSERV, pasEncore
				mov A, TL1
				mov TL1, #0			; on n'éteint pas le timer1 seulement pour ça, WOLOLO
				clr C					; sait-on jamais, on ne peut pas lui faire confiance
				subb A, CONSIGNE
				anl A, #11111100b ; application d'un seuil (valeur expérimentale)
				cjne A, #0, modifier_vitesse
				jmp fin_asserv
modifier_vitesse:
				jc augmente
				dec VITESSE					; la vitesse est trop grande, il faut la diminuer
				jmp fin_asserv
augmente:
				inc VITESSE					; la vitesse est trop basse, il faut l'augmenter
fin_asserv:
				mov ATTENTE_ASSERV, #50h	; on relance une nouvelle attente
pasEncore:
				
; ----------------------
; fin gestion du PWM
                                            ; attente du reste des 5ms (étape 2 et 4)
attente_fin_pwm:
            jnb TF0, attente_fin_pwm
 				mov A, TL0
 				rrc A
 ;Le problème vient du fait qu'on recharge TL0 sans prendre en compte la valeur qu'il avait déjà.
 ;Or, celle-ci peut varier de 1 car "jnb" dure deux cycles. On redécale donc afin de ne plus avoir ce problème.
 ;Ce problème ne se pose qu'ici car, en début du programme, les embranchements conditionnels ne modifient pas la parité de PC. 
 				jc pasNop
 				nop									; COUCOU MARC !!!
pasNop:
            clr TF0
            clr TR0                       ; on arrete le timer 0
            cpl RS0                   		; toggle de banque
            jmp demiBouclePWM         		;à présent, on refait l'autre moitié de la boucle

            end            
