; VROUM PROJECT / PF

; Principe de fonctionnement du PWM:
; (? r??crire)
; Le code est fait de manicre r ce que la partie pour commander la direction soit la meme que pour commander le moteur.
; La diff?renciation se fait au niveau de la banque utilis?e (direction: banque 0 / moteur: banque 1).

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
            VITESSE            equ    0Bh
            DIRECTION            equ    03h
                CONSIGNE                equ     30h
                CONSIGNE_INIT        equ     31h
                ATTENTE_ASSERV        equ     32h
                BP_MEM                equ     33h
                                   
            org 0000h
            jmp init
           
            org 0030h
;---------------------------
; Initialisation
init:
            mov SP, #0Fh             ; afin de ne pas ?craser la banque 1
            clr DIODE                     ; on allume la diode de la carte
           
            ; ASSERV
            mov DIRECTION, #125d     ; roues droites
            mov VITESSE, #165d       ; vitesse standard
            mov CONSIGNE_INIT, #10                ; consigne de r?f?rence, constante a priori (peut-?tre modifi?e par les boutons poussoirs)
            mov CONSIGNE, CONSIGNE_INIT        ; consigne en vitesse, variable
            mov ATTENTE_ASSERV, #50     ; 500ms entre deux changements de puissance d?livr?e au moteur
           
            ; TIMER
            mov TMOD, #01010001b     ; initialisation du timer 0 (mode 16bits) et du timer 1 (mode 16bits, avec horloge externe)
            setb TR1                         ; on lance directement le timer 1
               
demiBouclePWM:
; --------------------------
; PWM
            ; ces quelques lignes mettent ? 1 la pin soit de direction (si on est dans l'?tape de la direction) soit du moteur
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

; ne rien ?crire ici, sinon le cas o? R3=0 serait d?cal? de quelques microsecondes, ce qui pourrait faire exploser le v?hicule.

boucleElementaire:    ; dur?e d'une boucle ?l?mentaire: 4microsecondes
                nop
                nop
            djnz ACC, boucleElementaire

etat_bas:
                nop                        ; ajustement de la parit? de PC
            clr PIN_MOTEUR
            nop                ; le nop est ici pour synchroniser la mise ? 1 et la mise ? 0.
            clr PIN_DIR
           
boucle_attente_1ms_bis:
            jnb TF0, boucle_attente_1ms_bis    ;si R3 vaut 250, alors lorsqu'on arrive ici pour la premi?re fois, THL0 = 0
            clr TF0
            clr TR0
           
             ; on lance le timer pour 8ms
            mov TL0, #0D8h
            mov TH0, #0E0h
            setb TR0

; ----------------------
; gestion des capteurs et de la direction

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
                mov CONSIGNE, CONSIGNE_INIT
                jmp fin_direction
               
tourne_normalement:
                jb NOIR_DROIT, tourne_droite
                mov A, DIRECTION
                clr C        ; pour ne pas fausser les subb
                subb A, #221
                jz fin_direction
                ; on tourne progressivement et on abaisse la vitesse
                inc DIRECTION
                inc DIRECTION
;                mov A, CONSIGNE
;                subb A, #3
;                mov CONSIGNE, A
                jmp fin_direction
tourne_droite:
                mov A, DIRECTION            ;pas de commentaires ici. ?a vous apprendra.
                clr C
                subb A, #29
                jz fin_direction
                dec DIRECTION
                dec DIRECTION
;                mov A, CONSIGNE
;                subb A, #3
;                mov CONSIGNE, A
fin_direction:

; ----------------------
; gestion des boutons poussoirs

      jmp fin_bp
                mov A, P1
                xrl A, BP_MEM    ; on v?rifie que l'?tat a chang? (qu'on soit sur un front)
                anl A, BP_MEM  ; on v?rifie que la pr?c?dente valeur est 1. Ces deux lignes d?tectent donc un front descendant.
                rr A
                rrc A
                jnc pas_bp0
                dec CONSIGNE_INIT   ; si BP0 est enfonc?, on ralentit
                setb DIODE        ; et on ?teint la diode
                jmp pas_bp1
pas_bp0:
                rrc A
                jnc pas_bp1
                inc CONSIGNE_INIT    ; si BP1 est enfonc?, on acc?l?re
                clr DIODE        ; et on allume la diode
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
      mov VITESSE, #180d
      jmp pasEncore
pas_bloque:
      mov VITESSE, #165d

;      jmp pasEncore
;                djnz ATTENTE_ASSERV, pasEncore
;                mov A, TL1
;                mov TL1, #0            ; on n'?teint pas le timer1 seulement pour ?a, WOLOLO
;                clr C                    ; sait-on jamais, on ne peut pas lui faire confiance
;                subb A, CONSIGNE
;                cjne A, #0, modifier_vitesse
;                jmp fin_asserv
;modifier_vitesse:
;                jc augmente
;                ; ici, A est positif
;                jnb ACC.1, fin_asserv    ; seuil
;                dec VITESSE                    ; la vitesse est trop grande, il faut la diminuer
;                dec VITESSE
;                dec VITESSE
;                setb DIODE
;                jmp fin_asserv
;augmente:
;                ; ici, A est négatif
;;                jb ACC.1, fin_asserv    ; seuil
;                inc VITESSE                    ; la vitesse est trop basse, il faut l'augmenter
;                inc VITESSE
;                inc VITESSE
;                clr DIODE
;fin_asserv:
;                mov ATTENTE_ASSERV, #50    ; on relance une nouvelle attente
pasEncore:
               
; ----------------------
; fin gestion du PWM
                                            ; attente du reste des 5ms (?tape 2 et 4)
attente_fin_pwm:
            jnb TF0, attente_fin_pwm
                 mov A, TL0
                 rrc A
 ;Le probl?me vient du fait qu'on recharge TL0 sans prendre en compte la valeur qu'il avait d?j?.
 ;Or, celle-ci peut varier de 1 car "jnb" dure deux cycles. On red?cale donc afin de ne plus avoir ce probl?me.
 ;Ce probl?me ne se pose qu'ici car, en d?but du programme, les embranchements conditionnels ne modifient pas la parit? de PC.
                 jc pasNop
                 nop                                    ; COUCOU MARC !!!
pasNop:
            clr TF0
            clr TR0                       ; on arrete le timer 0
            cpl RS0                           ; toggle de banque
            jmp demiBouclePWM                 ;? pr?sent, on refait l'autre moiti? de la boucle

            end    
