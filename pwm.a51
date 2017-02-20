
; VROUM PROJECT / PF

; Principe de fonctionnement du PWM:
; On divise le cycle de 20ms (appel� cycle PWM) en petits cycles de 25microsecondes (appel�s cycles �l�mentaire).
; Il faut donc 800 cycles �l�mentaires pour faire un cycle PWM. Chaque cycle �l�mentaire est mesur� par un timer
; De plus, le cycle PWM est divis� en quatre parties d'�gales longueurs (5ms chacune).
; Etape 1: le signal haut pour la direction est envoy�.
; Etape 2: le programme attend.
; Etape 3: le signal haut pour le moteur est envoy�.
; Etape 4: le programme attend.
; La direction et le moteur auront donc chacun un PWM de meme p�riode (20ms) mais d�phas� (ce qui n'a aucune incidence).
; Le code est fait de manicre r ce que la partie pour commander la direction soit la meme que pour commander le moteur.
; La diff�renciation se fait au niveau de la banque utilis�e (direction: banque 0 / moteur: banque 1).

; Les interruptions peuvent empecher une d�tection imm�diate de la fin du timer.
; C'est pour cette raison que les interruptions seront d�sactiv�es durant les �tapes 1 et 3 (envoi d'un signal) et activ�s durant les �tapes 2 et 4 (attente)
; La gestion des capteurs est effectu�e durant ces deux quarts de cycle PWM d'attente.

; Utilisations des registres:
; R1: pointe vers BANDE_NOIRE ou VITESSE
; R2: nombre de cycles �l�mentaires restants pour un quart de boucle PWM
; R3: nombre de cycles �l�mentaires d'�tats bas pour un quart de boucle PWM
; R4: contient une sauvegarde de P1 afin de d�tecter les fronts descendants

; Valeurs:
; Direction: entre 125 (gauche) et 155 (droit). Tout droit: 140

; Asservissement:
; Un asservissement en vitesse est effectu�. Pour cela, le timer 1 compte sur P3.5, qui est reli� � la diode.
; R�guli�rement, la valeur de ce timer est v�rifi�e. La d�cision d'augmenter la vitesse ou de la diminuer est alors prise selon cette valeur. Enfin, le timer est remis � zero.

            PIN_DIR       	bit    P1.4
            PIN_MOTEUR    	bit    P1.5
            CAPT_D        	bit    P1.6
            CAPT_G        	bit    P1.7
            DIODE       	bit  	 P1.0
            NOIR_DROIT	 	bit	 00h
            VITESSE        equ    0Bh
            DIRECTION    	equ    03h
				CONSIGNE			equ	 30h
				ATTENTE_INT		equ	 31h
				BP_MEM			equ	 32h

            org 0000h
            jmp init
            
            org 0030h
;---------------------------
; Initialisation
init:
            mov SP, #0Fh             ; afin de ne pas �craser la banque 1 (non n�cessaire si pas d'utilisation de la pile)
            mov DIRECTION, #140d     ; roues droites
            mov VITESSE, #135d       ; vitesse standard
            clr DIODE					 ; on allume la diode de la carte
            mov TMOD, #01010001b     ; initialisation du timer 0 (mode 16bits) et du timer 1 (mode 16bits, avec horloge externe)            
            setb TR1						 ; on lance directement le timer 1
            mov ATTENTE_INT, #50
            mov CONSIGNE, #15			 ; consigne en vitesse
           
demiBouclePWM:
; --------------------------
; PWM
            ; ces quelques lignes mettent � 1 la pin soit de direction (si on est dans l'�tape de la direction) soit du moteur
            mov C, RS0
            mov PIN_MOTEUR, C
            cpl C
            mov PIN_DIR, C
            mov R1,#200d                ;un quart de cycle �l�mentaire = 200 * 25microsecondes = 5 ms
boucleElementaire:
            db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ;quelques nop pour compl�ter la boucle elementaire
            mov A, R1                    ;ces trois lignes v�rifies l'in�galit� entre R1 et R2
            subb A, R3
            jnz continue
            ; on �teint les deux
            clr PIN_MOTEUR
            clr PIN_DIR
continue:
            djnz R1, boucleElementaire        ;on recommence 200 fois

            mov TL0, #08Eh
            mov TH0, #0ECh
            clr TF0
            setb TR0                   ; on d�marre le timer 0

; ----------------------
; gestion des capteurs et de la direction

				mov C, NOIR_DROIT
				anl C, /CAPT_G					;si on capte � gauche, on met NOIR_DROIT � 0. Sinon, on ne change rien.
				orl C, CAPT_D					;si on capte � droite, on met NOIR_DROIT � 1. Sinon, on ne change rien.
				mov NOIR_DROIT, C
				
				jnc tourne_gauche
				inc DIRECTION
				jmp fin_direction
tourne_gauche:
				dec DIRECTION
fin_direction:

; ----------------------
; gestion des boutons poussoirs

				mov A, P1
				xrl A, BP_MEM	; on v�rifie que l'�tat a chang� (qu'on soit sur un front)
				anl A, BP_MEM  ; on v�rifie que la pr�c�dente valeur est 1. Ces deux lignes d�tectent donc un front descendant.
				rr A
				rrc A
				jnc pas_bp0
				dec CONSIGNE   ; si BP0 est enfonc�, on ralentit
				setb DIODE		; et on �teint la diode
				jmp pas_bp1
pas_bp0:
				rrc A
				jnc pas_bp1
				inc CONSIGNE	; si BP1 est enfonc�, on acc�l�re
				clr DIODE		; et on allume la diode
pas_bp1:
				mov BP_MEM, P1		; on actualise la m�moire

; --------------------------
; Asservissement

				djnz ATTENTE_INT, pasEncore
				clr TR1   					; on arr�te de compter, on r�cup�re sa valeur, r�initialise le compteur et red�marre le timer
				mov A, TL1					
				mov TL1, #0
				setb TR1
				subb A, CONSIGNE
				anl A, #11111100b ; application d'un seuil (valeur exp�rimentale)
				cjne A, #0, modifier_vitesse
				jmp fin_asserv
modifier_vitesse:	
				jc augmente
				dec VITESSE					; la vitesse est trop grande, il faut la diminuer
				jmp fin_asserv
augmente:
				inc VITESSE					; la vitesse est trop basse, il faut l'augmenter
fin_asserv:
				mov ATTENTE_INT, #50h	; on relance une nouvelle attente
pasEncore:
				
; ----------------------
; fin gestion du PWM
                                            ; attente de 5ms (�tape 2 et 4)
attente2:
            jnb TF0, attente2
            clr TR0                        ; on arrete le timer 0
            clr EX0								 ; on d�sactive INT0
            nop                            ; pas toujours n�cessaire, selon la parit�
            cpl RS0
            jmp demiBouclePWM         ;une fois les 200 cycles �l�mentaires termin�es, on reprend le cycle PWM
            end
            
