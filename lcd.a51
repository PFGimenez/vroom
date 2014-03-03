;Afficher sur LCD
;1- les variables de l'afficheur

RS                bit        p1.5            ;bit qui indique le type de données échangées:
                                            ;RS=0    instruction
                                            ;Rs=1    donnée
                                            ;jaune
                            
RW                bit        p1.6            ;bit qui indique:
                                            ;RW=1 lecture    (read)
                                            ;RW=0    ecriture    (write)
                                            ;vert
                            
E                bit        p1.7            ;bit de validation des données en entrée
                                            ;actif sur front descendant
                                            ;bleu
                            
LCD            equ        p2                ;bus de données de l'afficheur; p2.0=jaune
                                            ;p2.1=vert; p2.2=bleu;et ainsi de suite

busy            bit        p2.7            ;drapeau de fin d'éxecution d'une commande:
                                            ;BUSY=0    terminé
                                            ;BUSY=1    en cours
belle            bit        p1.3            ;led test de bon fonctionnement

ADRESSE_H    equ        30h
ADRESSE_L    equ        31h

;---------------------------------------------------------------------------------
;1' les variables de votre programme
;----------------------------------------------------------------------------------
;2- les sous programmes d'interruption
                org        0000h
                ljmp        debut_lcd
                org        0030h
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
                mov        lcd,#06h            ;incrémente le curseur
                lcall        en_lcd_code        ;sous programme de validation d'une commande
                mov        lcd,#38h            ;affiche sur 2 lignes en 5x8 points
                lcall        en_lcd_code        ;sous programme de validation d'une commande
                setb        belle
                ret

;----------------------------------------------------------------------------------
;tempo de 50ms
tempo:
                clr        tr0
                clr        tf0
                mov        tmod,#01h        ;comptage sur 16 bits avec horloge interne (Quartz 12 MHz)
                mov        th0,#3Ch            ;(65535-15535)=50000d soit 3CB0h
                mov        tl0,#0B0h
                setb        tr0                ;lance le comptage de Timer0
attent_tf0:
                jnb        tf0,attent_tf0    ;attente de la fin du comptage
                clr        tr0                ;remise à 0 du drapeau de fin de comptage
                ret
;----------------------------------------------------------------------------------------------
;validation de l'envoi d'une instruction avec verification de l'etat du BUSY FLAG

en_lcd_code:                                ;sous programme de validation d'une instruction 
                clr        rs                    ;5 lignes = séquence permettant de valider l'envoi d'une 
                clr        rw                    ;instruction au LCD
                clr        E
                setb        E
                clr        E
                lcall        test_busy_lcd    ;appel au sous programme de test de l'état d'occupation du LCD
                ret
;-----------------------------------------------------------------------------------------------
;test du busy flag pour envoi d'autres instructions ou donnees
test_busy_lcd:                                ;test de la valeur du BUSY FLAG renvoyé sur DB7 par le LCD
                
                mov        lcd,#0ffh        ;déclaration du port de communication avec LCD en lecture    
                setb        rw                    ;2 lignes pour autoriser la lecture de BF
                clr        rs
                setb        E                    ;Bf doit être lu entre un front montant et un front descendant
                                                ;de E

check_busy:
                jb            busy,check_busy    ;BF = 1 LCD occupé, BF = 0 LCD libre
                clr        E
                ret
;--------------------------------------------------------------------------------------------------    
;validation de l'envoi d'un caractère avec verification de l'etat du BUSY FLAG
en_lcd_data:
                
                setb        rs                    ;5 lignes = séquence permettant de valider l'envoi d'une
                clr        rw                    ;instruction au LCD
                clr        E
                setb        E
                clr        E
                lcall        test_busy_lcd    ;appel au sous programme de test de l'état d'occupation du LCD
                ret
;-----------------------------------------------------------------------------------------------------                
;4 les textes à envoyer
                org        00F0h
map_lcd:
                db 0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h
                
pacman_skin_lcd:
                db    03h,07h,0Fh,1Fh,1Fh,0Fh,07h,03h,18h,1Ch,0Ch,18h,10h,18h,1Ch,18h,18h,1Ch,0Eh,1Fh,1Fh,1Eh,1Ch,18h
;-----------------------------------------------------------------------------------------------------
;5 vos sous programmes
                org        0180h


;-----------------------------------------------------------------------------------------------------
;6 programme principal
                org        0220h
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
            ; lock
            mov A, ADRESSE_H
            mov DPH, A
            mov A, ADRESSE_L
            mov DPL, A
            ; unlock

            lcall boucle_ligne_lcd
            ret
LINE2_lcd: 
            mov lcd,#0C0h
            lcall en_lcd_code
            lcall boucle_ligne_lcd
            ret

decale_lcd:
            mov        lcd,#1Dh            ;incrémente le curseur
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
            end
