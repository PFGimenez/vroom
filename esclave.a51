		; ESCLAVE
		; Deux proto-threads sont utilisAäs sur cette carte.
		; Le thread 0 s'occupe de la communication avec le capteur infrarouge et de commander les lasers. Sa pile commence r 60h.
		; Le thread 1 s'occupe de l'affichage LCD. Sa pile commence r 40h
		; Le passage de l'un L? l'autre se fait de la maniƒçre suivant.
		; A chaque fois que le timer1 (sur 13bits) overflow, son interruption dAäroute le programme, push le contexte, modifie SP et pop le contexte.
		; Un mAäcanisme de mutex est mis en place pour les donnÈes partagÈes (ADRESSE_H et ADRESSE_L) entre les deux threads
		
		; Variables de gestion des threads
		NUM_THREAD bit P1.0
		MUTEX bit 00h ; 0 si A occupAä, 1 si A disponible
		QUI_UTILISE bit 01h
		DODO_FINI bit 02h
		AUTRE_SP equ 32h


		; Variables de gestion du laser
		laser bit p1.2 ;demande de l'emission laser si 1
		sirene bit p1.3 ;enclenchement de la sirene
		LAISSE_ALLUME bit 03h


		; Variables de l'affichage LCD		
		RS bit p0.5 ;bit qui indique le type de donnAäes AächangAäes:
		;RS=0 instruction
		;Rs=1 donnAäe
		;jaune
		
		RW bit p0.6 ;bit qui indique:
		;RW=1 lecture (read)
		;RW=0 ecriture (write)
		;vert
		
		E bit p0.7 ;bit de validation des donnAäes en entrAäe
		;actif sur front descendant
		;bleu
		
		LCD equ p2 ;bus de donnAäes de l'afficheur; p2.0=jaune
		;p2.1=vert; p2.2=bleu;et ainsi de suite
		
		busy bit p2.7 ;drapeau de fin d'Aäxecution d'une commande:
		;BUSY=0 terminAä
		;BUSY=1 en cours
		

		; Variables partagÈes
		ADRESSE_H equ 30h
		ADRESSE_L equ 31h
		
		org 0000h
		jmp init
		
		; ----------------------
		; GESTION DU TIMER 0 (gestion des threads)
		org 000Bh
		sjmp gestion_threads
		
		; ----------------------
		; GESTION DE LA SERIE
		org 0023h
		jmp interrupt_serie_laser
		
		org 0030h
		; ----------------------
		; Gestion des threads
		
		gestion_threads:
		mov TL0, #058h
		mov TH0, #09Eh
		push PSW
		push ACC
		mov A, SP
		xch A, AUTRE_SP
		mov SP, A
		cpl NUM_THREAD
		setb DODO_FINI
		pop ACC
		pop PSW ; le changement de banque se fait au chargement de PSW
		reti
		
		init:
		; --------------------
		; INITIALISATION
		
		; pas besoin de mutex car les threads ne sont pas encore lancÈs
		mov ADRESSE_H, #01h
		mov ADRESSE_L, #0B0h
		
		; Adresse du thread 1, valeur de sa pile
		mov 40h, #30h ; octet de poids faible
		mov 41h, #02h ; octet de poids fort
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
		jmp init_laser
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
		
attente_laser:
		jnb RI, attente_laser
		
		setb sirene
		lcall sleep_50ms ; la tempo de 50ms
		; setb maitre ; COMMUNICATION AVEC LE MAITRE : demander a aller tout droit
		;enclenchement du laser : (enfin !!!)
		setb laser
		
		mov R1, #20
boucle_attente_laser:
		lcall sleep_50ms
		djnz R1, boucle_attente_laser
		
		jbc LAISSE_ALLUME, attente_laser
		clr laser
		call lock
		mov ADRESSE_H, #01h
		mov ADRESSE_L, #0B0h
		call unlock
		lcall sleep_50ms
		clr sirene
		jmp attente_laser
		
interrupt_serie_laser:
		; attention! dans cette interruption, on ne sait pas quel contexte on a. Il faut donc le conserver et ne pas utiliser les registres R.
		push PSW
		push ACC
		clr RI
		setb LAISSE_ALLUME
		mov A, SBUF
		call lock
		mov adresse_H, #01h
		cjne A, #47h, pas47		; a-t-on dÈtectÈ "G"?
		mov adresse_L, #80h
		jmp fin_interrupt_serie
pas47:
		cjne A, #0C4h, pasC4		; a-t-on dÈtectÈ "D"?
		mov adresse_L, #50h
		jmp fin_interrupt_serie
pasC4:
		cjne A, #043h, pas43		; a-t-on dÈtectÈ "C"?
		mov adresse_L, #20h
		jmp fin_interrupt_serie
pas43:
		mov adresse_H, #00h
		mov adresse_L, #0F0h		; si ce n'est rien de tout Áa, c'est qu'on a dÈtectÈ "4"
fin_interrupt_serie:
		call unlock
		pop ACC
		pop PSW
		reti ; retourne apres la boucle d'attente
		
		;messages a envoyer a l'ecran LCD :
		org 0F0h
		db '.: DETECTION! :..: DETECTION! :.'
		org 120h
		db '.: TIR CENTRE :..: TIR CENTRE :.'
		org 150h
		db '.: TIR DROITE :..: TIR DROITE :.'
		org 180h
		db '.: TIR GAUCHE :..: TIR GAUCHE :.'
		org 1B0h
		db 'IL EST BEAU LE PACMAN, NON?     '
		
		
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
		mov lcd,#06h ;incrAämente le curseur
		lcall en_lcd_code ;sous programme de validation d'une commande
		mov lcd,#38h ;affiche sur 2 lignes en 5x8 points
		lcall en_lcd_code ;sous programme de validation d'une commande
		ret
		
		;----------------------------------------------------------------------------------------------
		;validation de l'envoi d'une instruction avec verification de l'etat du BUSY FLAG
		
en_lcd_code: ;sous programme de validation d'une instruction
		clr rs ;5 lignes = sAäquence permettant de valider l'envoi d'une
		clr rw ;instruction au LCD
		clr E
		setb E
		clr E
		lcall test_busy_lcd ;appel au sous programme de test de l'Aätat d'occupation du LCD
		ret
		;-----------------------------------------------------------------------------------------------
		;test du busy flag pour envoi d'autres instructions ou donnees
test_busy_lcd: ;test de la valeur du BUSY FLAG renvoyAä sur DB7 par le LCD
		
		mov lcd,#0ffh ;dAäclaration du port de communication avec LCD en lecture
		setb rw ;2 lignes pour autoriser la lecture de BF
		clr rs
		setb E ;Bf doit AStre lu entre un front montant et un front descendant
		;de E
		
check_busy:
		jb busy,check_busy ;BF = 1 LCD occupAä, BF = 0 LCD libre
		clr E
		ret
		;--------------------------------------------------------------------------------------------------
		;validation de l'envoi d'un caractA®re avec verification de l'etat du BUSY FLAG
en_lcd_data:
		
		setb rs ;5 lignes = sAäquence permettant de valider l'envoi d'une
		clr rw ;instruction au LCD
		clr E
		setb E
		clr E
		lcall test_busy_lcd ;appel au sous programme de test de l'Aätat d'occupation du LCD
		ret
		;-----------------------------------------------------------------------------------------------------
		;programme principal

debut_lcd:
		org 230h
		lcall init_lcd
		mov R1,#18h
		lcall CGRAM_lcd

restart_lcd:
		mov lcd, #02h
		lcall en_lcd_code
		mov R3, #13h

mange_lcd:
		mov R1, #20h
		lcall LINE1_lcd
		mov R1, #28h
		mov DPTR, #map_lcd
		lcall LINE2_lcd
		mov DPTR,#pacman_open_lcd
		mov R1,#02h
		lcall LINE2_lcd
		lcall sleep_50ms
		lcall sleep_50ms
		mov R1, #20h
		lcall LINE1_lcd
		lcall sleep_50ms
		lcall sleep_50ms
		mov R1, #20h
		lcall LINE1_lcd
		mov DPTR,#pacman_close_lcd
		mov R1,#02h
		lcall LINE2_lcd
		lcall sleep_50ms
		lcall sleep_50ms
		mov R1, #20h
		lcall LINE1_lcd
		lcall sleep_50ms
		lcall sleep_50ms
		
		lcall decale_lcd
		djnz R3, mange_lcd
		
		
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
		mov lcd,#1Dh ;incrAämente le curseur
		lcall en_lcd_code
		
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
		
		
		; les textes A envoyer
map_lcd:
		db 0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,0A5h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h
		
pacman_skin_lcd:
		db 03h,07h,0Fh,1Fh,1Fh,0Fh,07h,03h,18h,1Ch,0Ch,18h,10h,18h,1Ch,18h,18h,1Ch,0Eh,1Fh,1Fh,1Eh,1Ch,18h
		
pacman_open_lcd: db 00h,01h
		
pacman_close_lcd: db 00h,02h
		
		
		; ----------------------
		; ProcAädure lock. Si on tente de verrouiller alors que ce meme thread a dÈjr verrouillÈ, le verrouillage ne bloque pas.
		
lock:
		jbc MUTEX, fin_lock ; le choix de cette instruction n'est pas innocent. C'est une des rares instructions A fournir A la fois un test et une affectation. De ce fait, ces deux Aätapes d'acquisition du mutex sont atomiques et ne peuvent AStre interrompues par un changement de thread qui pourrait tout ruiner.
		; si on est ici, c'est que la variable n'est pas disponible
		mov C, QUI_UTILISE
		jb NUM_THREAD, pasComplement
		cpl C
pasComplement:
		jc fin_lock ; dans ce cas, c'est que c'est ce meme thread qui utilise dÈjr la ressource
		call sleep_50ms
		jmp lock
fin_lock:
		mov C, NUM_THREAD
		mov QUI_UTILISE, C
		ret
		
		; ----------------------
		; ProcAädure unlock. On ne peut dÈverouiller qu'une ressource qu'on a soi-meme verrouiller.
		
unlock:
		mov C, QUI_UTILISE
		jb NUM_THREAD, pasComplementUnlock
		cpl C
pasComplementUnlock:
		jnc fin_unlock ; c'est l'autre qui l'utilise, on ne peut pas libÈrer la ressource
		setb MUTEX
fin_unlock:
		ret
		
		; ----------------------
		; ProcÈdure sleep_50ms
sleep_50ms:
		clr DODO_FINI
boucle_dodo:
		inc PCON
		jnb DODO_FINI, boucle_dodo ; afin d'etre rÈveillÈ par la bonne interruption
		ret
		
		end
		

