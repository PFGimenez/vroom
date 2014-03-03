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
; R1: pointe vers un octet entre 60h et 6Fh. Sert � la m�morisation des derni�res valeurs.

; Valeurs:
; Direction: entre 28 (droite) et 222 (gauche). Tout droit: 125

; Asservissement:
; Un asservissement en vitesse est effectu?. Pour cela, le timer 1 compte sur P3.5, qui est reli? ? la diode.
; R?guli?rement, la valeur de ce timer est v?rifi?e. La d?cision d'augmenter la vitesse ou de la diminuer est alors prise selon cette valeur. Enfin, le timer est remis ? zero.

            PIN_DIR           bit    P1.4
            PIN_MOTEUR        bit    P1.5
            CAPT_D            bit    P1.6
            CAPT_G            bit    P1.7
            DIODE             bit    P1.0
            LASER_ACTIVE      bit      P3.0    ; modifié par la carte esclave

            NOIR_DROIT        bit    00h
            TOGGLE_CAPT       bit    01h
            PANIQUE           bit    10h
				PASLESDEUX			bit	 11h
 
            VITESSE           equ    01b
            DIRECTION         equ    10b
            VITESSE_MIN       equ    R2
            ATTENTE_ASSERV    equ    30h
            ATTENTE_BLINK         equ    R3
            BP_MEM            equ    R4
            BP_MEM_ADR			equ	 0Bh
            DROITITUDE        equ    R5
            HUIT_FOIS         equ      R6
            COMPTEUR          equ    R7
            NB_TOURS          equ   31h
         
                                                
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
                clr PIN_DIR
                clr PIN_MOTEUR
                clr LASER_ACTIVE
              
                ; n�cessaire si reset
                clr NOIR_DROIT
                clr TOGGLE_CAPT
                clr PANIQUE
              
            setb RS0    ; utilisation de la banque 1
        
            ; ASSERV
            mov DIRECTION, #125d     ; roues droites
            mov VITESSE_MIN, #160                ; vitesse sans boost, modifiable par les boutons poussoirs
            mov VITESSE, VITESSE_MIN
            mov ATTENTE_ASSERV, #8     ;2.5 * 8 = 20ms entre deux changements de puissance d?livr?e au moteur, soit un cycle PWM
            mov HUIT_FOIS, #8
            mov 09h, #60h    ; 09h: R1 de la banque 1
            mov NB_TOURS, #3
            mov ATTENTE_BLINK, #100
            mov DROITITUDE, #0	; � v�rifier
            mov BP_MEM, #0FFh
            mov 60h, #0FFh
            mov COMPTEUR, #8	; afin de ne pas avoir un coup de boost au d�part
        
;mov VITESSE, #0    
;mov DIRECTION, #35    ; pour test
        
            ; TIMER
            mov TMOD, #01010001b     ; initialisation du timer 0 (mode 16bits) et du timer 1 (mode 16bits, avec horloge externe) et démarrage
            setb TR0
            setb TR1
            setb EA                ; activation de l'interruption de timer0
            setb ET0

            clr DIODE                     ; on allume la diode de la carte
            mov SP, #0Fh             ; afin de ne pas ?craser la banque 1
            nop    ; équilibrage de timer 0 ("par chance", il n'en faut qu'un)
; ne rien écrire ici

demiBouclePWM:
; --------------------------
; PWM  
            ; on s'occupe du moteur si R0 vaut 01b, de la direction si R0 vaut 10b
            ; il ne faut pas faire d'embranchement sinon timer 0 n'aura pas toujours la me;me valeur
            mov A, R0
            mov C, ACC.0            ; on allume le moteur si R0 vaut 001b
            anl C, /ACC.1
                anl C, /ACC.2
            mov PIN_MOTEUR, C
            mov C, ACC.1         ; on change de direction si R0 vaut 010b
            anl C, /ACC.0
                anl C, /ACC.2
            mov PIN_DIR, C

            ; attente de 1ms.
            mov TL0, #2Eh
            mov TH0, #0FCh

            inc PCON            ; DODO          

              ; attente de 1ms encore.
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
            nop                                ; afin que l'écart temporel entre les deux clr soit le me;me qu'en les deux mov
            nop
            nop
            nop
            nop
            nop
            clr PIN_DIR
            inc PCON    ; DODO        (si R3 vaut 250, alors que PC est sur cette ligne, timer0 vaut FFFF)
        
             ; on lance le timer pour 0.5ms. Pendant ce temps, on fait le reste (asservissement, boutons, capteurs, ...).
            mov TL0, #026h
            mov TH0, #0FEh

; ----------------------
; gestion des capteurs et de la direction
                    ; cas particulier: si les deux détectent en me;me temps, on va tout droit
                jnb CAPT_G, pasNouveauTour
                jnb CAPT_D, pasNouveauTour
				    jbc PASLESDEUX, passageLigneNoire
				    jmp fin_direction	; on est encore sur la ligne noire
passageLigneNoire:
                djnz NB_TOURS, tout_droit   ; on compte le nombre de tours. Le début d'un tour est repéré par la bande noire.
                ; POWER DOWN
                orl PCON, #10b
                jmp fin_direction		; le cas de la ligne noire est un peu complexe du fait que NOIR_DROIT est binaire et ne peut g�rer ce cas.
pasNouveauTour:

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
            clr PANIQUE     ; ouf, on a retrouvé la ligne
            setb TOGGLE_CAPT    ; on compte
            setb PASLESDEUX	; pour compter les tours
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
            add A, #50        ; la somme doit faire 222
pas_braque_gauche:
;                    clr C
;                subb A, DROITITUDE
                mov DIRECTION, A
                jmp fin_direction
tourne_droite:
                mov A, #78
                jnb PANIQUE, pas_braque_droite
                clr C
                subb A, #50    ; la différence doit faire 28
pas_braque_droite:             
;                add A, DROITITUDE
                mov DIRECTION, A
fin_direction:

; ----------------------
; gestion des boutons poussoirs

jmp fin_bp
                mov A, P1
                push ACC
                xrl A, BP_MEM    ; on v?rifie que l'?tat a chang? (qu'on soit sur un front)
                anl A, BP_MEM  ; on v?rifie que la pr?c?dente valeur est 1. Ces deux lignes d?tectent donc un front descendant.
                rr A
                rrc A
                jnc pas_bp0
                dec VITESSE_MIN   ; si BP0 est enfonc?, on ralentit
                jmp pas_bp1
pas_bp0:
                rrc A
                jnc pas_bp1
                inc VITESSE_MIN    ; si BP1 est enfonc?, on acc?l?re
pas_bp1:
                pop BP_MEM_ADR        ; on actualise la m?moire
fin_bp:

; --------------------------
; clignotage de la led en cas de panique
      jnb PANIQUE, fin_blink
      djnz ATTENTE_BLINK, fin_blink
      mov ATTENTE_BLINK, #100 ; 100 * 2.5 = 250 ms
      cpl DIODE
fin_blink:
;mov C, PANIQUE
;cpl C
;mov DIODE, C

; --------------------------
; asservissement vitesse et adoucissement rotation

      djnz ATTENTE_ASSERV, pasEncore
      mov ATTENTE_ASSERV, #8

      ; adoucissement rotation   
      mov A, @R1
      jnb ACC.0, pas_diminuer_compteur    ; ACC.0 est le bit qui va disparaître
      dec COMPTEUR

pas_diminuer_compteur:
      mov C, TOGGLE_CAPT
      clr TOGGLE_CAPT
      jnc pas_augmenter_compteur
      inc COMPTEUR
pas_augmenter_compteur:
      mov ACC.0, C                 ; une valeur est conservée 2560ms
      rlc A
      mov ACC.0, C
      mov @R1, A
      djnz HUIT_FOIS, touche_pas_R1
      mov HUIT_FOIS, #8
      inc R1
      anl 09h, #11101111b    ; au 6F on revient r' 60
touche_pas_R1:

        jb PANIQUE, fin_consigne    ;si on panique, la droititude reste r' 0
        mov A, COMPTEUR
        clr C
        subb A, #3d
        jnb ACC.7, pasTropPetit
      ; compteur < 3
      setb PANIQUE    ; on a perdu la ligne! Panique r' bord!
      mov DROITITUDE, #0
        jmp fin_consigne
pasTropPetit:
        mov A, DROITITUDE
        clr C
        subb A, #40d    ; On ne retourne pas complc(tement r' des roues droites
        jz fin_consigne
        inc DROITITUDE
fin_consigne:

      ; asservissement vitesse
      mov A, TL1			; on r�cup�re le nombre de fragments de tours de roues, qu'on r�initialise au passage
      mov TL1, #0
      clr C
      subb A, #3d
      jnb ACC.7, pas_bloque
      ; TL1 < 3
      mov VITESSE, #180d        ; BOOST!
      jmp pasEncore
pas_bloque:
      mov VITESSE, VITESSE_MIN
pasEncore:

; ----------------------
; fin gestion du PWM

                inc R0
                anl 08h, #111b    ; on tourne sur 8 registres
pasToggle:
            inc PCON
               ; DODO
            jmp demiBouclePWM

            end 
            
