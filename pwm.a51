
; VROUM PROJECT / PF

; Principe de fonctionnement du PWM:
; On divise le cycle de 20ms (appelé cycle PWM) en petits cycles de 25microsecondes (appelés cycles élémentaire).
; Il faut donc 800 cycles élémentaires pour faire un cycle PWM. Chaque cycle élémentaire est mesuré par un timer
; De plus, le cycle PWM est divisé en quatre parties d'égales longueurs (5ms chacune).
; Etape 1: le signal haut pour la direction est envoyé.
; Etape 2: le programme attend.
; Etape 3: le signal haut pour le moteur est envoyé.
; Etape 4: le programme attend.
; La direction et le moteur auront donc chacun un PWM de meme période (20ms) mais déphasé (ce qui n'a aucune incidence).
; Le code est fait de manicre r ce que la partie pour commander la direction soit la meme que pour commander le moteur.
; La différenciation se fait au niveau de la banque utilisée (direction: banque 0 / moteur: banque 1).

; Les interruptions peuvent empecher une détection immédiate de la fin du timer.
; C'est pour cette raison que les interruptions seront désactivées durant les étapes 1 et 3 (envoi d'un signal) et activés durant les étapes 2 et 4 (attente)
; La gestion des capteurs est effectuée durant ces deux quarts de cycle PWM d'attente.

; Utilisations des registres:
; R2: nombre de cycles élémentaires restants pour un quart de boucle PWM
; R3: nombre de cycles élémentaires d'états bas pour un quart de boucle PWM

; Valeurs:
; Direction: entre 125 (gauche) et 155 (droit). Tout droit: 140

; Asservissement:
; Un asservissement en vitesse est effectué. Pour cela, le timer 1 compte sur P3.5, qui est relié à la diode.
; Régulièrement, la valeur de ce timer est vérifiée. La décision d'augmenter la vitesse ou de la diminuer est alors prise selon cette valeur. Enfin, le timer est remis à zero.

            PIN_DIR       	bit    P1.4
            PIN_MOTEUR    	bit    P1.5
            CAPT_D        	bit    P1.6
            CAPT_G        	bit    P1.7
            DIODE       	bit  	 P1.0
            NOIR_DROIT	 	bit	 00h
            VITESSE        equ    0Bh
            DIRECTION    	equ    03h
				CONSIGNE			equ	 30h
				ATTENTE_ASSERV	equ	 31h
				BP_MEM			equ	 32h
                                    
            org 0000h
            jmp init
            
            org 0030h
;---------------------------
; Initialisation
init:
            mov SP, #0Fh             ; afin de ne pas écraser la banque 1 (non nécessaire si pas d'utilisation de la pile)
            mov DIRECTION, #140d     ; roues droites
            mov VITESSE, #135d       ; vitesse standard
            mov CONSIGNE, #15			 ; consigne en vitesse
            clr DIODE					 ; on allume la diode de la carte
            mov TMOD, #01010001b     ; initialisation du timer 0 (mode 16bits) et du timer 1 (mode 16bits, avec horloge externe)
            setb TR1						 ; on lance directement le timer 1
            mov ATTENTE_ASSERV, #50	 ; 500ms entre deux changements de puissance délivrée au moteur
           
demiBouclePWM:
; --------------------------
; PWM
            ; ces quelques lignes mettent à 1 la pin soit de direction (si on est dans l'étape de la direction) soit du moteur
            mov C, RS0
            mov PIN_MOTEUR, C
            cpl C
            mov PIN_DIR, C
            mov R2,#200d                ;un quart de cycle élémentaire = 200 * 25microsecondes = 5 ms
boucleElementaire:
            db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ;quelques nop pour compléter la boucle elementaire
            mov A, R2                    ;ces trois lignes vérifies l'inégalité entre R2 et R3
            subb A, R3
            jnz continue
            ; on éteint les deux
            clr PIN_MOTEUR
            clr PIN_DIR
continue:
            djnz R2, boucleElementaire        ;on recommence 200 fois

            mov TL0, #08Dh
            mov TH0, #0ECh
            clr TF0
            setb TR0                   ; on démarre le timer 0

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
				mov DIRECTION, #140
				mov CONSIGNE, #15
				jmp fin_direction
				
tourne_normalement:
				djnz ATTENTE_ASSERV, fin_direction	; on change l'angle progressivement et la consigne en vitesse
				jnb NOIR_DROIT, tourne_gauche
				clr C		; pour ne pas fausser les subb
				mov A, DIRECTION
				subb A, #155
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
				mov A, DIRECTION
				subb A, #125
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
				dec CONSIGNE   ; si BP0 est enfoncé, on ralentit
				setb DIODE		; et on éteint la diode
				jmp pas_bp1
pas_bp0:
				rrc A
				jnc pas_bp1
				inc CONSIGNE	; si BP1 est enfoncé, on accélère
				clr DIODE		; et on allume la diode
pas_bp1:
				mov BP_MEM, P1		; on actualise la mémoire

; --------------------------
; asservissement

				mov A, ATTENTE_ASSERV
				jnz pasEncore
				mov A, TL1					
				mov TL1, #0
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
attente2:
            jnb TF0, attente2
            clr TR0                        ; on arrete le timer 0
;            nop                            ; pas toujours nécessaire, selon la parité
            cpl RS0
            jmp demiBouclePWM         ;une fois les 200 cycles élémentaires terminées, on reprend le cycle PWM
            end
            
