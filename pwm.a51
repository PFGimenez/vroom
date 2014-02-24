
org 0000h
        jmp init
       
        org 0030h
init:
        mov TMOD,#1b        ;initialisation du timer
        setb tr0                ;on démarre le timer
boucleseconde:
        setb P1.4    ;au début, on envoie "1" sur P1.4
        mov R0,#200d        ;un cycle = 200 * 100µs = 20ms
boucle:
        mov tl0, #0A3h        ;valeur initiale du timer pour qu'il boucle en 100µs
        mov th0, #0FFh
        clr tf0
attente:
        jnb tf0, attente
        cjne R0, #186d, continue
        clr P1.4           ; en dessous d'une certaine valeur, on envoie 1 sur P1.4, puis 0
continue:
        djnz R0, boucle    ;on recommence 200 fois
seconde:
    ; petit hack pour finir les 20ms
        mov tl0, #042h
        mov th0, #0FFh
        clr tf0
attente2:
        jnb tf0, attente2
        jmp boucleseconde ;une fois les 200fois terminés, on reprend le cycle
