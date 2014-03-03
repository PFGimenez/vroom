; ESCLAVE
; Deux proto-threads sont utilis√©s sur cette carte.
; Le thread 0 s'occupe de la communication avec le capteur infrarouge et de commander les lasers. Sa pile commence ‡ 70h.
; Le thread 1 s'occupe de l'affichage LCD. Sa pile commence ‡ 60h
; Le passage de l'un ≈ï l'autre se fait de la maniƒçre suivant.
; A chaque fois que le timer1 (sur 13bits) overflow, son interruption d√©route le programme, push le contexte, modifie SP et pop le contexte.
; Un m√©canisme de mutex est mis en place pour les donnÈes partagÈes (ADRESSE_H et ADRESSE_L) entre les deux threads

	 MUTEX		  bit		00h	; 0 si A occup√©, 1 si A disponible
    NUM_THREAD   bit    01h
	 QUI			  bit 	02h 
	 DODO_FINI	  bit		03h
    AUTRE_SP     equ    32h
	; ressource partagÈe
	 ADRESSE_H    equ    30h
	 ADRESSE_L    equ    31h


	org 0000h
	jmp init

; ----------------------
; GESTION DU TIMER 1 (gestion des threads)
	org 001Bh
	sjmp gestion_threads

	org 0030h   
; ----------------------
; Gestion des threads

gestion_threads:
	 mov TL1, #058h
	 mov TH1, #09Eh
    push PSW
    push ACC
    mov A, SP
    xch A, AUTRE_SP    
    mov SP, A
    cpl NUM_THREAD
    setb DODO_FINI
    pop ACC
    pop PSW     ; le changement de banque se fait au chargement de PSW
    reti


	org 0050h
	
init:
; --------------------
; INITIALISATION
	; Adresse du thread 1, valeur de sa pile
	mov 60h, #20h			; octet de poids faible
	mov 61h, #12h        ; octet de poids fort
   mov 62h, #08h 			; PSW, banque 1
   ;mov 63h, #00h			; A
   mov SP, #6Fh
   mov AUTRE_SP, #63h
   ; Mutex
	setb MUTEX
	; Lancement du timer 1 (mode 1, 16 bits)
   mov TMOD, #10000b
	 mov TL1, #058h
	 mov TH1, #09Eh
	setb EA
	setb ET1
	setb TR1
    
	jmp thread0

; ----------------------
; THREAD 0, banque 0
	; TODO
thread0:
mov A, #1
	call sleep_50ms
; thread laser et infrarouge
	jmp thread0
	
; ----------------------
; THREAD 1, banque 1
;Afficher sur LCD
;1- les variables de l'afficheur


RS                bit        p1.5            ;bit qui indique le type de donn√©es √©chang√©es:
                                            ;RS=0    instruction
                                            ;Rs=1    donn√©e
                                            ;jaune
                            
RW                bit        p1.6            ;bit qui indique:
                                            ;RW=1 lecture    (read)
                                            ;RW=0    ecriture    (write)
                                            ;vert
                            
E                bit        p1.7            ;bit de validation des donn√©es en entr√©e
                                            ;actif sur front descendant
                                            ;bleu
                            
LCD            equ        p2                ;bus de donn√©es de l'afficheur; p2.0=jaune
                                            ;p2.1=vert; p2.2=bleu;et ainsi de suite

busy            bit        p2.7            ;drapeau de fin d'√©xecution d'une commande:
                                            ;BUSY=0    termin√©
                                            ;BUSY=1    en cours
belle            bit        p1.3            ;led test de bon fonctionnement

;---------------------------------------------------------------------------------
;1' les variables de votre programme
;----------------------------------------------------------------------------------
;2- les sous programmes d'interruption
                org        1030h
;----------------------------------------------------------------------------------
;3 les sous programmes du LCD
init_lcd:
                clr        belle
                lcall        tempo
                mov        lcd,#38h            ;affiche sur 2 lignes en 5x8 points
                lcall        en_lcd_code        ;sous programme de validation d'une commande
                lcall        tempo
                mov        lcd,#0Ch            ;allumage de l'afficheur
                lcall        en_lcd_code        ;sous programme de validation d'une commande
                lcall        tempo 
                mov        lcd,#01h            ;effacement de l'affichage
                lcall        en_lcd_code        ;sous programme de validation d'une commande
                lcall        tempo
                mov        lcd,#06h            ;incr√©mente le curseur
                lcall        en_lcd_code        ;sous programme de validation d'une commande
                mov        lcd,#38h            ;affiche sur 2 lignes en 5x8 points
                lcall        en_lcd_code        ;sous programme de validation d'une commande
                setb        belle
                ret

;----------------------------------------------------------------------------------
;tempo de 50ms
;tempo:
;                clr        tr0
;                clr        tf0
;                mov        tmod,#01h        ;comptage sur 16 bits avec horloge interne (Quartz 12 MHz)
;                mov        th0,#3Ch            ;(65535-15535)=50000d soit 3CB0h
;                mov        tl0,#0B0h
;                setb        tr0                ;lance le comptage de Timer0
;attent_tf0:
;                jnb        tf0,attent_tf0    ;attente de la fin du comptage
;                clr        tr0                ;remise √† 0 du drapeau de fin de comptage
;                ret
;----------------------------------------------------------------------------------------------
;validation de l'envoi d'une instruction avec verification de l'etat du BUSY FLAG

en_lcd_code:                                ;sous programme de validation d'une instruction 
                clr        rs                    ;5 lignes = s√©quence permettant de valider l'envoi d'une 
                clr        rw                    ;instruction au LCD
                clr        E
                setb        E
                clr        E
                lcall        test_busy_lcd    ;appel au sous programme de test de l'√©tat d'occupation du LCD
                ret
;-----------------------------------------------------------------------------------------------
;test du busy flag pour envoi d'autres instructions ou donnees
test_busy_lcd:                                ;test de la valeur du BUSY FLAG renvoy√© sur DB7 par le LCD
                
                mov        lcd,#0ffh        ;d√©claration du port de communication avec LCD en lecture    
                setb        rw                    ;2 lignes pour autoriser la lecture de BF
                clr        rs
                setb        E                    ;Bf doit √™tre lu entre un front montant et un front descendant
                                                ;de E

check_busy:
                jb            busy,check_busy    ;BF = 1 LCD occup√©, BF = 0 LCD libre
                clr        E
                ret
;--------------------------------------------------------------------------------------------------    
;validation de l'envoi d'un caract√®re avec verification de l'etat du BUSY FLAG
en_lcd_data:
                
                setb        rs                    ;5 lignes = s√©quence permettant de valider l'envoi d'une
                clr        rw                    ;instruction au LCD
                clr        E
                setb        E
                clr        E
                lcall        test_busy_lcd    ;appel au sous programme de test de l'√©tat d'occupation du LCD
                ret
;-----------------------------------------------------------------------------------------------------                
;4 les textes √† envoyer
                org        10F0h
map_lcd:
                db 0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h
                
pacman_skin_lcd:
                db    03h,07h,0Fh,1Fh,1Fh,0Fh,07h,03h,18h,1Ch,0Ch,18h,10h,18h,1Ch,18h,18h,1Ch,0Eh,1Fh,1Fh,1Eh,1Ch,18h
;-----------------------------------------------------------------------------------------------------
;5 vos sous programmes
                org        1180h


;-----------------------------------------------------------------------------------------------------
;6 programme principal
                org        1220h
debut_lcd:                
                lcall        init_lcd
                mov         R1,#18h
                lcall     CGRAM_lcd 
restart_lcd:
                mov         lcd, #02h
                lcall     en_lcd_code
                mov         R3, #13h
mange_lcd:
                mov        R1, #10h
                lcall        LINE1_lcd 
                mov         R1, #28h
                mov         DPTR, #map_lcd
                lcall     LINE2_lcd
                mov         DPTR,#pacman_open_lcd
                mov         R1,#02h
                lcall     LINE2_lcd
                lcall     tempo
                lcall     tempo
                mov        R1, #10h
                lcall        LINE1_lcd 
                lcall     tempo
                lcall     tempo
                mov        R1, #10h
                lcall        LINE1_lcd 
                mov         DPTR,#pacman_close_lcd
                mov         R1,#02h
                lcall     LINE2_lcd
                lcall     tempo
                lcall     tempo
                mov        R1, #10h
                lcall        LINE1_lcd 
                lcall     tempo
                lcall     tempo

                lcall        decale_lcd
                djnz         R3, mange_lcd

                
                jmp restart_lcd

;-----------------------------------------------------------------------------------------------------
LINE1_lcd:
            mov lcd,#80h
            lcall en_lcd_code
            call lock
            mov A, ADRESSE_H
            mov DPH, A
            mov A, ADRESSE_L
            mov DPL, A
            call unlock

            lcall boucle_ligne_lcd
            ret
LINE2_lcd: 
            mov lcd,#0C0h
            lcall en_lcd_code
            lcall boucle_ligne_lcd
            ret

decale_lcd:
            mov        lcd,#1Dh            ;incr√©mente le curseur
            lcall        en_lcd_code    
            
boucle_ligne_lcd:
            clr A
            movc A, @A + DPTR
            mov lcd, A
            lcall en_lcd_data
            inc DPTR
            djnz R1,boucle_ligne_lcd
            ret
CGRAM_lcd:
            mov lcd,#40h
            lcall en_lcd_code
            mov DPTR,#pacman_skin_lcd
            lcall boucle_ligne_lcd
            ret

pacman_open_lcd: db 00h,01h

pacman_close_lcd: db 00h,02h

            
; ----------------------
; Proc√©dure lock. Si on tente de verrouiller alors que ce mÍme thread a dÈj‡ verrouillÈ, le verrouillage ne bloque pas.

lock:
	jbc MUTEX, fin_lock ; le choix de cette instruction n'est pas innocent. C'est une des rares instructions √† fournir √† la fois un test et une affectation. De ce fait, ces deux √©tapes d'acquisition du mutex sont atomiques et ne peuvent √™tre interrompues par un changement de thread qui pourrait tout ruiner.
	; si on est ici, c'est que la variable n'est pas disponible
	mov C, QUI
	jb NUM_THREAD, pasComplement
	cpl C
pasComplement:	
	jc fin_lock	; dans ce cas, c'est que c'est ce mÍme thread qui utilise dÈj‡ la ressource
	call sleep_50ms
	jmp lock
fin_lock:
	mov C, NUM_THREAD
	mov QUI, C
	ret

; ----------------------
; Proc√©dure unlock. On ne peut dÈverouiller qu'une ressource qu'on a soi-mÍme verrouiller.

unlock:
	mov C, QUI
	jb NUM_THREAD, pasComplementUnlock
	cpl C
pasComplementUnlock:	
	jnc fin_unlock	; c'est l'autre qui l'utilise, on ne peut pas libÈrer la ressource
	setb MUTEX
fin_unlock:
	ret

; ----------------------
; ProcÈdure sleep_50ms
tempo:
sleep_50ms:
	clr DODO_FINI
boucle_dodo:
	inc PCON
	jnb DODO_FINI, boucle_dodo	; afin d'Ítre rÈveillÈ par la bonne interruption
	ret
	end
