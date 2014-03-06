; ESCLAVE
        ; Deux proto-threads sont utilisA?s sur cette carte.
        ; Le thread 0 s'occupe de la communication avec le capteur infrarouge et de commander les lasers. Sa pile commence r 60h.
        ; Le thread 1 s'occupe de l'affichage LCD. Sa pile commence r 40h
        ; Le passage de l'un L? l'autre se fait de la maniÄ re suivant.
        ; A chaque fois que le timer1 (sur 13bits) overflow, son interruption dA?route le programme, push le contexte, modifie SP et pop le contexte.
        ; Un mA?canisme de mutex est mis en place pour les données partagées (ADRESSE_H et ADRESSE_L) entre les deux threads
     
        ; Variables de gestion des threads
        DIODE bit P1.0
        ATTEND bit P3.2
        MUTEX bit 00h ; 0 si A occupA?, 1 si A disponible
        DODO_FINI bit 02h
        COMPTEUR_ON bit 03h
        AUTRE_SP equ 32h
        NB_TOURS equ 33h
        QUI_UTILISE equ 34h     
        COMPTEUR equ 35h

        ; Variables de gestion du laser
        laser bit p1.2 ;demande de l'emission laser si 1
        sirene bit p1.3 ;enclenchement de la sirene


        ; Variables de l'affichage LCD     
        RS bit p0.5 ;bit qui indique le type de donnA?es A?changA?es:
        ;RS=0 instruction
        ;Rs=1 donnA?e
        ;jaune
     
        RW bit p0.6 ;bit qui indique:
        ;RW=1 lecture (read)
        ;RW=0 ecriture (write)
        ;vert
     
        E bit p0.7 ;bit de validation des donnA?es en entrA?e
        ;actif sur front descendant
        ;bleu
     
        LCD equ p2 ;bus de donnA?es de l'afficheur; p2.0=jaune
        ;p2.1=vert; p2.2=bleu;et ainsi de suite
     
        busy bit p2.7 ;drapeau de fin d'A?xecution d'une commande:
        ;BUSY=0 terminA?
        ;BUSY=1 en cours
     

        ; Variables partagées
        ADRESSE_H equ 30h
        ADRESSE_L equ 31h
     
        org 0000h
        mov ADRESSE_H, #03h
        mov ADRESSE_L, #38h
        setb PT0
        jmp init
     
        ; ----------------------
        ; GESTION DU TIMER 0 (gestion des threads)
        org 000Bh
          jmp gestion_threads

        ; ----------------------
        ; GESTION DE LA SERIE
        org 0023h
interrupt_serie_laser:
        ; attention! dans cette interruption, on ne sait pas quel contexte on a.
        push PSW
        push ACC
          mov PSW, #10h        ; banque 2
        clr RI
        mov A, SBUF
;        anl A, #01111111b        ; on supprime le bit de parité
        call lock
        cjne A, #047h, pas47        ; a-t-on détecté "G"?
        mov 01h, #20        ;on relance l'attente de fin de laser pour 1s. 01h: R1 du thread 0
        mov adresse_H, #03h
        mov adresse_L, #10h
        jmp fin_interrupt_serie
pas47:
        cjne A, #044h, pas44        ; a-t-on détecté "D"?
        mov 01h, #20        ;on relance l'attente de fin de laser pour 1s. 01h: R1 du thread 0
        mov adresse_H, #02h
        mov adresse_L, #0E8h
        jmp fin_interrupt_serie
pas44:
        cjne A, #0C3h, pas43        ; a-t-on détecté "C"?
        mov 01h, #20        ;on relance l'attente de fin de laser pour 1s. 01h: R1 du thread 0
        mov adresse_H, #02h
        mov adresse_L, #0C0h
        jmp fin_interrupt_serie
pas43:
        cjne A, #0B4h, pas34        ; a-t-on détecté "4"?
        mov 01h, #20        ;on relance l'attente de fin de laser pour 1s. 01h: R1 du thread 0
        mov adresse_H, #02h
        mov adresse_L, #98h
        jmp fin_interrupt_serie
pas34:
        cjne A, #030h, pas30        ; a-t-on détecté "0"?
        jb COMPTEUR_ON, fin_interrupt_serie
        setb COMPTEUR_ON
        dec NB_TOURS
        mov ADRESSE_H, #03h
        mov A, NB_TOURS
        jnz pasFini
        setb ATTEND
        jmp debute
pasFini:
        clr DIODE
        clr ATTEND
debute:
            ; l'adresse pour NB_TOURS = 0 est 0360h
            ; l'adresse pour NB_TOURS = 1 est 0360h + 28h = 0388h
            ; l'adresse pour NB_TOURS = 2 est 0360h + 2*28h = 03B0h
            ; l'adresse pour NB_TOURS = 3 est 0360h + 3*28h = 03D8h
        mov B, #28h
        mul AB
        add A, #60h        ; on ajoute au produit 60h, ce qui donne l'octet de poids faible de l'adresse du message (puisqu'il n'y a pas de retenue)
        mov ADRESSE_L, A
pas30:
    ; par défaut on ne change pas le message
fin_interrupt_serie:
        call unlock
        pop ACC
        pop PSW
        reti ; retourne apres la boucle d'attente

           
        init:
        ; --------------------
        ; INITIALISATION

        ; --------------------
        ; INITIALISATION
        ; pas besoin de mutex car les threads ne sont pas encore lancés
;              mov NB_TOURS, #3
              mov NB_TOURS, #4
          clr COMPTEUR_ON
        mov DPTR, #debut_lcd
         ; Adresse du thread 1, valeur de sa pile
        mov 40h, DPL     ; octet de poids faible
        mov 41h, DPH     ; octet de poids fort
                mov 42h, #08h ; PSW, banque 1

        ;mov 43h, #00h ; A
        mov SP, #5Fh
        mov AUTRE_SP, #43h
        ; Mutex
        setb MUTEX
        ; Lancement du timer 1 (mode 1, 16 bits)
        mov TMOD, #1b
        mov TL0, #058h
        mov TH0, #09Eh
        setb EA
        setb ET0
        setb TR0
     
        ; ----------------------
        ; THREAD 0, banque 0
     
        ;----------------------------------------------------;
        ;----------- Gestion emission laser -----------------;
        ;----------------------------------------------------;
     
        ;--------------------------------------
        ;----------- Programme principal ------
        ;--------------------------------------
     
        ;initialisation pour pouvoir recevoir et enregistrer un message :
        ;----------------------------------------------------------------


init_laser:
        ; EXTINCTION GENERALE !!!! (securite)
        clr laser
        clr sirene

        ;reglages des timers:
        orl tmod, #100000b ;timer 1 : auto-remplissage 8 bits
        mov scon, #01010000b ;Mode 1, Ren a 1, ri=0 (pas fin de reception), ti=0 (pas fin de transmission)
        setb ES
        mov th1, #230d ;reglage pour 1200bauds
        mov tl1, #230d ;car mode de rechargement
        setb tr1 ;enclenchement timer
     
        setb REN
        mov R1, #0
attente_laser:
        lcall sleep_50ms
        cjne R1, #20, attente_laser
        setb sirene
        lcall sleep_50ms ; la tempo de 50ms
        ; setb maitre ; COMMUNICATION AVEC LE MAITRE : demander a aller tout droit
        ;enclenchement du laser : (enfin !!!)
        setb laser
boucle_attente_laser:
        lcall sleep_50ms
        djnz R1, boucle_attente_laser
     
        clr laser
        call lock
        mov ADRESSE_H, #03h
        mov ADRESSE_L, #38h
        call unlock
        lcall sleep_50ms
        clr sirene
        jmp attente_laser
             
       ; ----------------------
        ; THREAD 1, banque 1
        ; Afficher sur LCD
        ;1- les variables de l'afficheur
     
init_lcd:
        lcall sleep_50ms
        mov lcd,#38h ;affiche sur 2 lignes en 5x8 points
        lcall en_lcd_code ;sous programme de validation d'une commande
        lcall sleep_50ms
        mov lcd,#0Ch ;allumage de l'afficheur
        lcall en_lcd_code ;sous programme de validation d'une commande
        lcall sleep_50ms
        mov lcd,#01h ;effacement de l'affichage
        lcall en_lcd_code ;sous programme de validation d'une commande
        lcall sleep_50ms
        mov lcd,#06h ;incrA?mente le curseur
        lcall en_lcd_code ;sous programme de validation d'une commande
        mov lcd,#38h ;affiche sur 2 lignes en 5x8 points
        lcall en_lcd_code ;sous programme de validation d'une commande
        ret
     
        ;----------------------------------------------------------------------------------------------
        ;validation de l'envoi d'une instruction avec verification de l'etat du BUSY FLAG
     
en_lcd_code: ;sous programme de validation d'une instruction
        clr rs ;5 lignes = sA?quence permettant de valider l'envoi d'une
        clr rw ;instruction au LCD
        clr E
        setb E
        clr E
        lcall test_busy_lcd ;appel au sous programme de test de l'A?tat d'occupation du LCD
        ret
        ;-----------------------------------------------------------------------------------------------
        ;test du busy flag pour envoi d'autres instructions ou donnees
test_busy_lcd: ;test de la valeur du BUSY FLAG renvoyA? sur DB7 par le LCD
     
        mov lcd,#0ffh ;dA?claration du port de communication avec LCD en lecture
        setb rw ;2 lignes pour autoriser la lecture de BF
        clr rs
        setb E ;Bf doit AStre lu entre un front montant et un front descendant
        ;de E
     
check_busy:
        jb busy,check_busy ;BF = 1 LCD occupA?, BF = 0 LCD libre
        clr E
        ret
        ;--------------------------------------------------------------------------------------------------
        ;validation de l'envoi d'un caractA¨re avec verification de l'etat du BUSY FLAG
en_lcd_data:
     
        setb rs ;5 lignes = sA?quence permettant de valider l'envoi d'une
        clr rw ;instruction au LCD
        clr E
        setb E
        clr E
        lcall test_busy_lcd ;appel au sous programme de test de l'A?tat d'occupation du LCD
        ret
        ;-----------------------------------------------------------------------------------------------------
        ;programme principal

debut_lcd:
        lcall init_lcd    ;initialisation du LCD
        mov R1,#18h
        lcall CGRAM_lcd    ;ajout des caractères de pacman dans la CGRAM

restart_lcd:
        mov lcd, #02h    ;Se place à l'adresse 00h de la DDRAM et remet le curseur à son origine
        lcall en_lcd_code
        mov R3, #13h        ;On recommance la boucle mange_lcd 19 fois avant de recommencer

mange_lcd:
        mov R1, #28h    ;Registe permetant de sélectionner le nombre de caractère à rentrer en mémoire pour la 1ère ligne
        lcall LINE1_lcd    ;Donne l'état de la détection de la balise
        mov R1, #28h
        mov DPTR, #map_lcd ;Copie de la carte pour le pacman dans DPTR
        lcall LINE2_lcd ;Met la carte du pacman sur la ligne 2
        mov DPTR,#pacman_open_lcd ;Copie le caractère du pacman avec la bouche ouverte dans DPTR
        mov R1,#02h
        lcall LINE2_lcd_pacman   ;Affiche le pacman avec la bouche ouverte sur la ligne 2
        lcall sleep_50ms
        lcall sleep_50ms
        mov R1, #28h  
        lcall LINE1_lcd    ;Donne l'état de la détection de la balise
        lcall sleep_50ms
        lcall sleep_50ms
        mov R1, #28h
        lcall LINE1_lcd    ;Donne l'état de la détection de la balise
        mov DPTR,#pacman_close_lcd    ;Copie le caractère du pacman avec la bouche fermée dans DPTR
        mov R1,#02h
        lcall LINE2_lcd_pacman    ;Affiche le pacman avec la bouche ouverte sur la ligne 2
        lcall sleep_50ms
        lcall sleep_50ms
        mov R1, #28h
        lcall LINE1_lcd    ;Donne l'état de la détection de la balise
        lcall sleep_50ms
        lcall sleep_50ms
     
        lcall decale_lcd    ;Décale l'affichage vers la gauche
        djnz R3, mange_lcd    ;On boucle pour animer le pacman
     
     
        jmp restart_lcd    ;Quand le pacman arrive à la fin, on recommence l'animation
     
        ;-----------------------------------------------------------------------------------------------------
LINE1_lcd:
        call lock
        mov A, ADRESSE_H
        mov DPH, A
        mov A, ADRESSE_L
        mov DPL, A
        call unlock

        mov lcd,#80h ;Se place au début de la première ligne
        lcall en_lcd_code     
        lcall boucle_ligne_lcd
        ret
LINE2_lcd:
        mov lcd,#0C0h    ;Se place au début de la seconde ligne
        lcall en_lcd_code
        lcall boucle_ligne_lcd
        ret
      
LINE2_lcd_pacman:
        mov lcd,#0D0h    ;Se place à la fin de la seconde ligne
        lcall en_lcd_code
        lcall boucle_ligne_lcd
        ret
     
decale_lcd:
        mov lcd,#18h ;incrA?mente le curseur
        lcall en_lcd_code
     
boucle_ligne_lcd:    ;Permet d'envoyer le code des caractère
        clr A
        movc A, @A + DPTR
        mov lcd, A
        lcall en_lcd_data
        inc DPTR
        djnz R1,boucle_ligne_lcd
        ret

CGRAM_lcd:
        mov lcd,#40h    ;Se place à l'adresse 00h de la CGRAM
        lcall en_lcd_code
        mov DPTR,#pacman_skin_lcd
        lcall boucle_ligne_lcd
        ret
     
     
        ; les textes A envoyer
map_lcd:
        db 0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h
     
pacman_skin_lcd:
        db 18h,1Ch,1Eh,1Fh,1Fh,1Eh,1Ch,18h,03h,07h,06h,03h,01h,03h,07h,03h,03h,07h,0Eh,1Fh,1Fh,0Fh,07h,03h
     
pacman_open_lcd: db 01h,00h
     
pacman_close_lcd: db 02h,00h
     
     
        ; ----------------------
        ; ProcA?dure lock.
      
lock:
            push ACC
boucle_lock:
        mov A, PSW
        anl A, #00011000b    ; on ne garde que la banque, qui sert de fiche d'identité r' un thread
        jbc MUTEX, fin_lock ; le choix de cette instruction n'est pas innocent. C'est une des rares instructions A fournir A la fois un test et une affectation. De ce fait, ces deux A?tapes d'acquisition du mutex sont atomiques et ne peuvent AStre interrompues par un changement de thread qui pourrait tout ruiner.
        ; si on est ici, c'est que la variable n'est pas disponible
        clr C
        subb A, QUI_UTILISE
        jz fin_lock     ; dans ce cas, c'est que c'est ce meme thread qui utilise déjr la ressource
        call sleep_50ms
        jmp boucle_lock
fin_lock:
          mov QUI_UTILISE, A
            pop ACC
        ret
     
        ; ----------------------
        ; ProcA?dure unlock.
     
unlock:
        push ACC
          mov A, PSW
          anl A, #00011000b
          clr C
          subb A, QUI_UTILISE
        jnz fin_unlock    ; c'est l'autre qui l'utilise, on ne peut pas libérer la ressource
        setb MUTEX
fin_unlock:
        pop ACC
        ret
     
        ; ----------------------
        ; Procédure sleep_50ms
sleep_50ms:
        clr DODO_FINI
boucle_dodo:
        inc PCON
        jnb DODO_FINI, boucle_dodo ; afin d'etre réveillé par la bonne interruption
        ret

gestion_threads:
        push PSW
        push ACC
        mov TL0, #058h
        mov TH0, #09Eh
        mov A, SP
        xch A, AUTRE_SP
        mov SP, A
        jnb COMPTEUR_ON, pasCompteur
        inc COMPTEUR
        mov A, COMPTEUR
        jnz pasCompteur
        clr COMPTEUR_ON
pasCompteur:
;        cpl DIODE
        setb DODO_FINI
        pop ACC
        pop PSW ; le changement de banque se fait au chargement de PSW   
        reti

        ;messages a envoyer a l'ecran LCD :
        org 298h
        db '.: DETECTION! :.: DETECTION! :.: DETECTI'
        org 2C0h
        db '.: TIR CENTRE :.: TIR CENTRE :.: TIR CEN'
        org 2E8h
        db '.: TIR DROITE :.: TIR DROITE :.: TIR DRO'
        org 310h
        db '.: TIR GAUCHE :.: TIR GAUCHE :.: TIR GAU'
        org 338h
        db 'SUPER VROUM! SUPER VROUM! SUPER VROUM!! '
        org 360h
        db 'C', 27h,'EST FINI! C', 27h, 'EST FINI! C', 27h, 'EST FINI! C', 27h, 'ES'
        org 388h
        db 'PLUS QUE 1 TOUR! PLUS QUE 1 TOUR! PLUS Q'
        org 3B0h
        db 'ENCORE 2 TOURS! ENCORE 2 TOURS! ENCORE 2'
        org 3D8h
        db 'DEBUT DES 3 TOURS! DEBUT DES 3 TOURS! DE'
             
        end
        
