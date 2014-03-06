; VROUM PROJECT / PF

; Le code est fait de manicre r ce que la partie pour commander la direction soit la meme que pour commander le moteur.
; La diff?renciation se fait au niveau de la valeur de R0 (utilisA(? en adressage indirect)

; Utilisations des registres:
; R0: pointe vers un registe contenant (temps d'?tat haut en microsecondes - 1000) / 4

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
            ATTEND                bit      P3.0
            BP0                    bit      P1.1
            BP1                    bit      P1.2

            NOIR_DROIT        bit    00h
 
            VITESSE           equ    01b
            DIRECTION         equ    10b
            VITESSE_NORMALE    equ     R2
            ATTENTE_ASSERV    equ    R3
            BP_MEM            equ    R4
            BP_MEM_ADR        equ    0Ch            ; banque 1
            DIVERGE               equ     R5
            COMPTE_FIN            equ    R6
           
            org 0000h
            jmp init
       
            ; ne pas mettre d'autres interruptions qui pourraient perturber le fonctionnement du mode idle
       
            ; RA(?veil par cette interruption (mode idle)
            org 000Bh
            clr TF0
            reti
                  
            org 0030h
;---------------------------
; Initialisation
init:
            clr PIN_DIR
            clr PIN_MOTEUR
                setb DIODE
boucle_debut:
                jnb BP0, bypass_debut
                jnb BP1, bypass_debut
;            jb ATTEND, boucle_debut
            jmp go
bypass_debut:
                clr ATTEND
go:
            clr DIODE                     ; on allume la diode de la carte
           
                ; nécessaire si reset
            clr NOIR_DROIT
            
            setb RS0    ; utilisation de la banque 1
      
            ; ASSERV
            mov DIRECTION, #125     ; roues droites
            mov VITESSE_NORMALE, #174
            mov VITESSE, VITESSE_NORMALE
            mov ATTENTE_ASSERV, #20     ;2.5 * 20 = 500ms entre deux changements de puissance d?livr?e au moteur
                mov COMPTE_FIN, #40

            ; TIMER
            mov TMOD, #01010001b     ; initialisation du timer 0 (mode 16bits) et du timer 1 (mode 16bits, avec horloge externe) et dA(?marrage
            setb TR0
            setb TR1
            setb EA                ; activation de l'interruption de timer0
            setb ET0

            mov SP, #0Fh             ; afin de ne pas ?craser la banque 1
            nop    ; A(?quilibrage de timer 0 (il n'en faut qu'un)
; ne rien A(?crire ici

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
            nop                                ; afin que l'A(?cart temporel entre les deux clr soit le me;me qu'en les deux mov
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

            mov C, NOIR_DROIT
            anl C, /CAPT_G                    ;si on capte ? gauche, on met NOIR_DROIT ? 0. Sinon, on ne change rien.
            orl C, CAPT_D                    ;si on capte ? droite, on met NOIR_DROIT ? 1. Sinon, on ne change rien.
                mov NOIR_DROIT, C


                jb CAPT_G, gaucheOuDroite
                jb CAPT_D, gaucheOuDroite
                jmp niGaucheNiDroite
gaucheOuDroite:
                mov DIRECTION, #125
                mov DIVERGE, #0
                mov A, VITESSE_NORMALE
                add A, #5
                mov VITESSE, A
                jmp fin_direction

niGaucheNiDroite:

tourne:
            jb NOIR_DROIT, tourne_droite
            mov A, #125
            add A, DIVERGE
            mov DIRECTION, A
            jmp fin_direction
tourne_droite:
            mov A, #125
                clr C
                subb A, DIVERGE
            mov DIRECTION, A             
fin_direction:

; ----------------------
; gestion des boutons poussoirs

            mov C, BP0
            mov ACC.1, C
            mov C, BP1
            mov ACC.2, C
            push ACC
            xrl A, BP_MEM    ; on v?rifie que l'?tat a chang? (qu'on soit sur un front)
            anl A, BP_MEM  ; on v?rifie que la pr?c?dente valeur est 1. Ces deux lignes d?tectent donc un front descendant.
            rr A
            rrc A
            jnc pas_bp0
            dec VITESSE_NORMALE   ; si BP0 est enfonc?, on ralentit
            jmp pas_bp1
pas_bp0:
            rrc A
            jnc pas_bp1
            inc VITESSE_NORMALE    ; si BP1 est enfonc?, on acc?l?re
pas_bp1:
            pop BP_MEM_ADR        ; on actualise la m?moire
fin_bp:

; --------------------
; Asservissement vitesse et direction

            djnz ATTENTE_ASSERV, pasEncore
            mov ATTENTE_ASSERV, #20
            mov A, DIVERGE
            cjne A, #80, change_diverge
            jmp dejaTrop
change_diverge:
            inc A
            inc A
            cjne A, #10, dejaTrop
            mov A, #80
            mov B, VITESSE_NORMALE
             mov VITESSE, B
dejaTrop:
            mov DIVERGE, A
          ; asservissement vitesse
          mov A, TL1            ; on récupc(re le nombre de fragments de tours de roues, qu'on réinitialise au passage
          mov TL1, #0
          clr C
          subb A, #3d
          jmp pas_bloque
;             jnb ACC.7, pas_bloque
          ; TL1 < 3
          mov VITESSE, #180d        ; BOOST!
          jmp pasEncore
pas_bloque:
             mov VITESSE, VITESSE_NORMALE
pasEncore:

; ----------------------
; C'est la fin! On attend une seconde avant de s'arrêter.

jnb ATTEND, pasFin
djnz COMPTE_FIN, pasFin
mov COMPTE_FIN, #1
mov VITESSE, #125
pasFin:

; ----------------------
; fin gestion du PWM

         inc R0
         anl 08h, #111b    ; on tourne sur 8 registres
         inc PCON
               ; DODO
         jmp demiBouclePWM

         end
           
