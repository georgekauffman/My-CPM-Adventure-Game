
r;********************************************
; Adventure Game July 2011
;********************************************
;
; missing 7 item limit on what can be carried
; cave closure trigger is only 12 well house treasures in deadtest
; one dead end missing down from all alike maze room 105  room 127? two moves in s_index, scoring implications
; bug fix plover does not work without emerald in inventory work44 but autorun busted May 2015
; bug fixed block move west from debris room 11 to cobble crawl 12 only with lamp on work32/33
; bug fixed add event for room 10 and 11 for darkness when lamp is off Dec 2014
; bug fixed allow lantern or lamp object word work14/work15/work32/work33 May 2015
; bug fixed objwords description scan 28 movable objects, not 26  Nov 2016
; bug fixed imdead description 0=dead 1,2,3=alive Nov 2016
;
;what happens every turn
;
;Deadtest    if player has messed up, reincarnate, if all treasures found, push for end game
;DoRoom	     present a room primary or secondary description sentence built from words
;MyStuff     present sentence for any movable objects
;Event	     present sentences for magic objects that come and go in current room
;MyRand	     generate random numbers for encounters with magic, dwarves and pirate
;Take_Input  get an action word and object word
;DoWork	     act on the action word and object word
;MyMoves     use tables to move to next room
;NoMoves     if requested move is blocked and there is no puzzle, randomly say cannot move
;Been2       track what rooms have been visited
;Puzzle      if in the room with a puzzle, output puzzle status messages
;Workxx      handler routines for specific action words and object words
;
;data tables
;S_index1  table of initial cave description sentences stored as words
;S_index2  table of secondary cave description sentences stored as words
;S_index3  table of sentence descriptions for objects found in the caves
;S_Index4  table of sentence descriptions for objects when held by the player
;Inlist is a two column table with current room number and an index into object sentence list sindex_3
; the room value "126" identifies objects 'with player'
;objwords is a list of single words for objects
;roomb is a bit table of visited rooms
;bedlist is a list of randomly set destination room numbers from Bedquilt
;we_tab is an index of pointers to randomly set room destinations from Witts End
;m_west,m_east,m_north,m_south,m_ne,m_se,m_nw,m_sw,m_up,m_down
;  two column tables with room numbers of permitted directional moves, source & destination
;Elist is a three column table with room number, activity flag and label of specific event handler code
;Puztab is a three column table with room number, directional action word and label of the puzzle handler code
;Relist is a one column table of object room locations used to reset items if the player dies.
;act_words is a list of action words for player input, by word numbers
;Pscore is a table of player credits, added to roomb room visits and treasures in the Well House
;myroom is the current room number value
;
; Treasures: coins,gold chain,magazine,pearl,emerald,vase,rug,pyramid,diamonds,golden eggs,trident,gold nugget,bars of silver,jewelry,spices
; Tools:     keys,lamp,food,cage,bird,rod,bottle with water,axe,pillow,oil,magazine editions,bear,trident,golden eggs
; Puzzles:   locked grate, crossing the fissure, fierce snake, hungry bear, dragon, heavy gold nugget, beanstalk, locked rusty door, pearl in shell, getting golden eggs back
; Perils:    lamp battery life, rickety bridge collapse, fragile vase, no chain if food lost, pits in the dark, dwarf axe attacks, Pirate robbery
;
; action word  routine     action word  routine     action word    routine
; -----------  -------     -----------  -------     -----------    -------
; (none found) work0       forest       work20      water          work40
; f(orward)    work1       enter        work21      feefiefoefoo   work41
; quit         work2       exit         work22      fill           work42
; b(ackward)   work3       grate        work23      cross (bridge) work43
; west         work4       xyzzy        work24      plover         work44
; east         work5       y2           work25      info           work45
; north        work6       unlock       work26      words          work46
; south        work7       lock         work27      save (game)    work47
; sw           work8       score        work28      load (game)    work48
; nw           work9       wave         work29      blast/detonate work49
; se           work10      open         work30      forest door    work50 (for game testing)
; ne           work11      free         work31      jump           work51
; up           work12      lamp on      work32      walk           work52
; down         work13      lamp off     work33      run            work52
; take/get     work14      kill         work34      go             work52
; drop         work15      attack       work35      climb          work52
; inventory    work16      plugh        work36   
; look         work17      throw        work37   
; help         work18      room         work38   
; building     work19      feed         work39   
;
;new word and sentence database adoption checklist
;
;1.MyStart for welcome and help
;2.Inlist for single words for the objects
;3.S_index1 for initial descriptions by room
;4.S_index2 for secondary descriptions by room
;5.S_index3 for object descriptions
;6.S_index4 for object descriptions
;7.N_index for random cannot go there messages
;8.act_words that invoke specific work routines
;9.objwords names for each object 
;10.sentences used in many work routines
;11.sentences used in puzzle handlers
;
	org	100h	
;
bdos	equ	5	
Mykeys	equ	66	; number of action words to check with user input  last routine # +1
Myobs	equ	40	; number of objects to check with user input, work16 routine for take checks only the first 23
;
;
MyStart:			
	lxi	h,sent1	; sentence 1 asks the question
	shld	mysent1	; set introduction
	call	DoSentence	; play it
	mvi	c,1	; console in
	call	bdos	; job for dos
	cpi	'y'	; yes?
	jnz	MyStart1	; branch if no instructions to play
	call	sentcr	; print cr lf
	lxi	h,sent347	; sentence with instructions
	shld	mysent1	; set introduction
	call	DoSentence	; play it
MyStart1:			
	call	sentcr	; print cr lf
	mvi	a,0	; room 0 is outside building
	sta	myroom	; initial room
	sta	ColCount; initial console column
	mvi	a,3	; I am alive for 3 accidents
	sta	imdead	; for now...
TheLoop:			
	call	DeadTest; Check for player pulse
	call	DoRoom	; present a room description sentence
	call	MyStuff	; present sentence for any movable objects
	call	Event	; present sentences for magic objects that come and go
	call	MyRand	; generate random numbers
	call	Take_Input	; get an action word
	call	DoWork	; act on it
	call	sentcr	; print cr lf
	call	NoMoves	; tell player if move request failed or present puzzles in the room
	jmp	TheLoop	; do next room
;
; output the phrase for the room or object in rooms 0 through 125  room 126 is used for the player's treasure
;
DoRoom:			
	lda	myroom	; get current room
	call	Been2	; get base pointer to appropriate sentence table
DoObject:			
	call	GetAdd	; get pointer to appropriate sentence word list
	shld	mysent1	; save address of sentence for this room
DoSentence:			
	push	psw	
	push	b	
	push	d	
	push	h	
DoSent1:			
	lhld	mysent1	; get address of word in current sentence again
	mov	e,m	; get ls byte to current word
	inx	h	; bump pointer
	mov	d,m	; get ms byte to current word
	inx	h	; bump to ls byte of next word
	shld	mysent1	; setup for next word in sentence
	mov	a,d	; setup test for end of sentence
	cpi	0	; test needed in case of d+e=100
	jnz	DoSent2	; branch if we havent found the 00 at end of sentence
	mov	a,e	; get lsbyte of sentence address
	cpi	0	; end of sentence is zero
	jz	DoSent3	; branch if this sentence is done
DoSent2:			
	mvi	c,9	; print string
	call	bdosf	; output it without wrapping past column 80
	lda	ColCount	; get current column position on the console
	cpi	1	; will bdosf wrap to the next line with a space?
	jz	DoSent1	; branch to avoid a space at the beginning of line
	lxi	d,wordsp	; print space
	mvi	c,9	; print string
	call	bdos	; output it
	jmp	DoSent1	; loop until sentence is done
DoSent3:			
	sta	ColCount	; clear the column counter, new line with next word
	call	sentcr	; print cr lf
	pop	h	
	pop	d	
	pop	b	
	pop	psw	
	ret		
;
;given table base address in hl and index in a, return table address in hl
;
GetAdd:			
	mvi	d,0	; small offsets
	add	a	; convert to address offset
	mov	e,a	; index into e
	dad	d	; calculate address of address in table
	mov	e,m	; get ls byte to current sentence list
	inx	h	; bump pointer
	mov	d,m	; get ms byte to current sentence list
	xchg		; pointer into sentence list now in hl
	ret		
;
;given myroom value in a, output announcements of any movable objects located there
;
MyStuff:			
	push	psw	
	push	b	
	push	d	
	push	h	
	call	sentcr	; print cr lf
	mvi	c,28	; 28 items can put in the room now with spices
	lxi	h,Inlist; base of list for items that move
MyStuff1:			
	shld	mysent2	; keep track of this pointer
	lda	myroom	; get current location
	cmp	m	; is this item in this room?
	jnz	MyStuff2	; if not, branch, no sentence play
	inx	h	; set pointer to item description	
	mov	a,m	; get offset into table for sentence #
	lxi	h,S_Index3	; point to base of addresses to moving object sentences
	call	DoObject	; announce this item
	lhld	mysent2	; get back pointer into object location table
MyStuff2:			
	inx	h	; now pointing to table index for object sentence just displayed
	inx	h	; pointing to next item room #
	dcr	c	; item counter
	jnz	MyStuff1	; loop until all items are displayed
	pop	h	
	pop	d	
	pop	b	
	pop	psw	
	ret		
;
Inlist:	; current room #, object sentence #, must match order of objwords
	db	1,0	; 0.keys
	db	1,1	; 1.lamp
	db	1,2	; 2.food
	db	1,3	; 3.bottle
	db	10,4	; 4.empty cage
	db	13,5	; 5.bird nearby
	db	11,6	; 6.rod
	db	130,4	; 7.bird in cage
	db	130,8	; 8.bottle with water
	db	130,9	; 9.axe
	db	76,10	; 10.pillow
	db	91,11	; 11.oil
	db	41,12	; 12.coins
	db	130,13	; 13.gold chain
	db	58,14	; 14.magazine
	db	130,15	; 15.pearl
	db	83,16	; 16.emerald
	db	74,17	; 17.vase
	db	46,18	; 18.rug
	db	84,19	; 19.pyramid
	db	17,20	; 20.diamonds
	db	130,21	; 21.bear
	db	94,22	; 22.golden eggs
	db	97,23	; 23.trident
	db	18,24	; 24.gold nugget
	db	39,25	; 25.bars of silver
	db	42,26	; 26.jewelry
	db	72,27	; 27.spices
;
; list of sentences for objects found in the cave
;
S_Index3:			
	dw	sent267,sent268,sent269,sent275,sent271,sent272,sent273,sent274,sent275,sent276,sent277	
	dw	sent278,sent279,sent280,sent281,sent282,sent283,sent284,sent285,sent286,sent288	
	dw	sent289,sent290,sent291,sent292,sent293,sent294,sent480
;
; list of sentences for objects carried by player
;
S_Index4:
	dw	sent321,sent322,sent324,sent325,sent326,sent328,sent327,sent328,sent329,sent330,sent331	
	dw	sent332,sent333,sent334,sent335,sent336,sent337,sent338,sent339,sent340,sent341,sent342	
	dw	sent343,sent344,sent345,sent346,sent435,sent481	
;
; return an index for the right object word  warning- objwords items must match the order of inlist and S_index3
; only the first 28 items, 0-27 can be taken or dropped
;
Objwords:			
	dw	word927	;0 keys
	dw	word788	;1 lamp
	dw	word932	;2 food
	dw	word933	;3 bottle
	dw	word935	;4 cage
	dw	word198	;5 bird
	dw	word939	;6 rod
	dw	word198	;7 bird
	dw	word933	;8 bottle
	dw	word943	;9 axe
	dw	word945	;10 pillow
	dw	word784	;11 oil
	dw	word318	;12 coins
	dw	word948	;13 chain
	dw	word952	;14 magazine
	dw	word900	;15 pearl
	dw	word955	;16 emerald
	dw	word959	;17 vase
	dw	word962	;18 rug
	dw	word964	;19 pyramid
	dw	word966	;20 diamonds
	dw	word968	;21 bear
	dw	word969	;22 eggs
	dw	word970	;23 trident
	dw	word822	;24 gold
	dw	word972	;25 silver
	dw	word974	;26 jewelry
	dw	word1544;27 spices
	dw	word150	;28 grate
	dw	word990	;29 snake
	dw	word1321;30 shell
	dw	word133	;31 all
	dw	word1215;32 plant
	dw	word1207;33 dragon
	dw	word16	;34 inven
	dw	word845	;35 bridge
	dw	word821	;36 nugget
	dw	word1035;37 door
	dw	word1017;38 dwarf
	dw	word25	;39 inventory
	dw	word1044;40 lantern aka lamp
	dw	0	
;
;
;given myroom value in a, return either sent1 or sent2 base address in reg hl
;
Been2:			
	push	psw	; preserve room #
	push	b	; preserve registers
	lxi	h,roomb	; point to table of sixteen room visit record bytes, eight rooms each
Been2a:			
	cpi	8	; a<8?
	jc	Been2b	; branch if less than 8
	sui	8	; adjust to next byte
	inx	h	; bump pointer to next byte
	jmp	Been2a	; loop until we index to correct byte
Been2b:			
	cpi	0	; our visit info is on bit 0?
	jnz	Been2c	; branch if some other bit
	mvi	a,1	; mask bit to be positioned
	jmp	Been2e	; go around bit rotate code
Been2c:			
	mov	c,a	; remainder becomes the counter
	mvi	a,1	; bit mask to rotate
Been2d:			
	ral		; rotate mask
	dcr	c	; bump counter
	jnz	Been2d	; loop until positioned on our bit	
Been2e:			
	mov	c,a	; save bit mask in c
	mov	a,m	; get selected byte with visit bits
	ana	c	; mask for this room's bit in the visit byte
	jnz	Been2f	; branch if not the first time in the room
	mov	a,m	; get selected byte with visit bits
	ora	c	; set this room bit for the visit
	mov	m,a	; update the visit byte	
	lxi	h,S_Index1	; point to first visit messages
	jmp	Been2g	; go around other code
Been2f:			
	lxi	h,S_Index2	; point to subsequent visit messages
Been2g:			
	pop	b	; dont trash registers
	pop	psw	; don't trash room #
	ret		; go play the right message
;
; each roomb bit is set for a visited room
;
roomb:	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	
;
; random number generators, integers range 1-3, 0-4, 0-9
;
MyRand:			
	push	psw	
	push	b	
	push	d	
	push	h	
	lda	automove	; moving automatically?
	cpi	1	; 1= auto moving
	jz	Rand6	; branch to skip randomizing during auto moves
Rand0:			
	lda	ran3	; get last random #
	inr	a	; bump it
	cpi	4	; past 3?
	jc	Rand1	; branch if not time to go back to 1
	mvi	a,1	; reset to 1
Rand1:			
	sta	ran3	; update random integer
	lda	ran5	; get last random #
	inr	a	; bump it
	cpi	5	; past 4?
	jc	Rand2	; branch if not time to go back to 1
	mvi	a,0	; reset to 0
Rand2:			
	sta	ran5	; update random integer
	lda	ran10	; get last random #
	inr	a	; bump it
	cpi	10	; past 9?
	jc	Rand3	; branch if not time to go back to 0
	mvi	a,0	; reset to 0
Rand3:			
	sta	ran10	; update random integer
	mvi	c,11	; console status
	call	bdos	; job for dos
	ani	1	; mask for console ready
	jz	Rand0	; continue randomizing while waiting
;
; move the pirate around
;
	lda	even7a	; pirate appearance flag
	cpi	1	; 1=pirate has appeared
	jz	Rand4	; branch if pirate stays here
	lda	ran10	; random range of 0-9
	adi	50	; rooms 50-59
	sta	Pirate1	; move the pirate
	sta	Puzt8	; robbery scene follows pirate
;
; move the dwarf around
;
Rand4:			
	lda	Puzt6	; dwarf location
	cpi	130	; dwarf inactive?
	jz	Rand5	; dwarf stays put when disabled
	lda	ran5	; random range of 0-4
	adi	41	; dwarf attacks in rooms 41-45
	sta	Puzt6	; move the dwarf resolution
	sta	Dwarf1	; move the dwarf attack
;
; update Witts End
;
Rand5:			
	mvi	a,59	; Witts End
	sta	m_west+9	; reset west
	sta	m_east+9	; reset east
	sta	m_north+9	; reset north
	sta	m_south+9	; reset south
	sta	m_sw+9	; reset southwest
	sta	m_se+9	; reset southeast
	sta	m_nw+9	; reset northwest
	sta	m_ne+9	; reset northeast
	sta	m_up+9	; reset up
	sta	m_down+9	; reset down
	lda	ran5	; get 1 in 5 random number range 1-5
	lxi	h,we_tab	; table of Witt's end
	call	GetAdd	; get address into table
	mvi	m,58	; anteroom is accessable from this direction
	lda	ran5	; get 1 in 5 random number range 1-5
	inr	a	; bump to next one
	lxi	h,we_tab	; table of Witt's end
	call	GetAdd	; get address into table
	mvi	m,58	; anteroom is accessable from this direction
	lda	ran5	; get 1 in 5 random number range 1-5
	inr	a	; bump to next one
	inr	a	; bump to next next one
	lxi	h,we_tab	; table of Witt's end
	inr	a	; bump to next one
	call	GetAdd	; get address into table
	mvi	m,58	; anteroom is accessable from this direction
;
; update Bedquilt
; 6 destinations: 58-Anteroom, 61-Lrg Low, 49-Dusty Rocks, 86-Jct 3 Cyns, 85-Secret N/S Cyn, 88-Slab 
; 4 directions: m_north+11, m_south+11, m_up+11, m_down+11
;
	lda	ran3	; random 1-3
	dcr	a	; random range of 0-2
	mov	e,a	; setup for random selection
	mvi	d,0	; small offsets
	lxi	h,Bedlist	; table of random destinations
	dad	d	; calculate base of destinations
	mov	a,m	; get room destination
	sta	m_north+11	; set north destination
	inx	h	; next random dest
	mov	a,m	; get room destination
	sta	m_south+11	; set south destination
	inx	h	; next random dest
	mov	a,m	; get room destination
	sta	m_up+11	; set up destination
	inx	h	; next random dest
	mov	a,m	; get room destination
	sta	m_down+11	; set down destination
Rand6:			
	pop	h	
	pop	d	
	pop	b	
	pop	psw	
	ret		
;
Bedlist:db	61,86,85,88,49,58	
ran3:	db	0	; random integer 1-3
ran5:	db	0	; random integer 0-4
ran10:	db	0	; random integer 0-9
we_tab:	dw	m_west+9,m_east+9,m_north+9,m_south+9,m_sw+9,m_se+9,m_nw+9,m_ne+9,m_up+9,m_down+9	
;
;
; there are 10 lists of possible moves with current room # and next room #
; reg hl has the base address of move tables for up,down,west,east,north,south, ne,nw,se and sw.
; reg a returns with the same or new room number.
;
MyMoves:
	push	psw	
	push	b	
	push	d	
	push	h	
	mvi	a,1	; set flag for directional work
	sta	AW_flag	; indicate action word is a directional AW
	lda	myroom	; get current location
	sta	mylast	; record soon to be former location
MyMoves1:			
	mov	a,m	; get table entry
	cpi	0ffh	; at end of move list?
	jz	MyMoves3; return with same room number, no move to make
	lda	myroom	; get current location
	cmp	m	; is this a move from the current room?
	jnz	MyMoves2; if not, branch 
	inx	h	; point to new room	
	mov	a,m	; get new room #
	sta	myroom	; update room number
	lda	bears	; what is the bear state?
	cpi	4	; is bear following player?
	jnz	MyMoves3; all done without bear
	lda	myroom	; get current location
	sta	Bear	; update bear location
	jmp	MyMoves3; all done, exit
MyMoves2:			
	inx	h	; now pointing to next room byte
	inx	h	; now pointing to next move record
	jnz	MyMoves1; loop until the entire list is checked
MyMoves3:			
	pop	h	
	pop	d	
	pop	b	
	pop	psw	
	ret		
;
; always permitted move bytes in pairs  first value is current room, second value is destination room
; room 126 is an entry that will be changed to a valid room once a puzzle is solved
; down grate from room 8 to 9 puzz1 changed by work26a
; west/east across fissure between room 16 and 17 puzz2 work29
; snake north/south/west from room 40 puzz3  work30, work31
; darkness west from room 10 to 11 and room 36 to west 37,south 39 and east 35 puzz4 lamp on work
; pirate robbery changes m_nw to 122,48
; witts end is always the fifth pair of moves, randomly updated to permit exit
;

m_west:	db	126,11,126,17,126,37,126,41,59,59,1,0,0,2,2,3,3,4,6,5,9,10,126,12,12,13,13,14,15,16,17,19,19,20,20,23,22,20,24,31,25,24,26,25,27,26,28,27,29,28,30,29,31,30,38,86,41,22,43,46,50,49,51,50,53,60,58,60,60,75,66,65,67,66,72,71,74,61,75,89,76,75,77,78,81,82,83,82,89,90,90,88,97,98,121,120,122,121,69,68,70,69,93,94,100,100,99,100,102,99,101,99,106,109,105,108,107,106,108,107,119,105	
	db	109,106,110,109,111,100,113,102,117,110,0ffh	
m_east:	db	126,16,126,35,40,15,15,14,59,59,14,13,13,12,130,43,12,11,11,10,10,9,6,5,5,4,4,6,3,2,2,0,0,1,16,15,19,17,20,19,22,41,23,20,24,25,25,26,26,27,27,28,28,29,29,30,30,31,31,24,37,36,41,40,43,40,49,50,50,51,53,58,58,59,60,53,66,67,71,72,63,61,75,76,77,79,89,75,90,89,94,95,68,69,69,70,98,97,99,101,101,102,104,101,106,107,107,104,108,109,109,108,119,122,121,122	
	db	105,119,100,111,112,102,102,113,118,119,120,121,0ffh	
m_north:db	126,39,2,5,5,4,7,6,59,59,60,61,130,97,130,44,6,2,8,7,15,40,20,22,23,22,22,21,24,31,25,24,26,25,27,26,28,27,29,28,30,29,31,30,34,33,33,32,35,15,39,36,42,40,44,45,45,47,53,54,54,55,61,62,68,67,71,73,77,75,79,77,80,79,85,86,86,38,87,85,88,60,94,96,100,99,99,99,102,101,110,108,108,105,119,121,122,119,104,114,0ffh	
m_south:db	126,39,126,42,2,6,3,5,59,59,60,88,4,5,6,7,7,8,14,15,15,18,19,99,21,22,22,23,23,24,24,25,25,26,26,27,27,28,28,29,29,30,30,31,31,24,33,34,39,40,44,46,45,44,47,45,54,53,62,61,71,67,73,71,74,75,75,77,78,77,79,80,81,74,84,83,85,87,86,85,88,90,94,93,95,94,96,94,97,96,121,119,19,99,99,102,100,100,101,104,104,107,107,108,108,108,109,110,102,112,114,104,110,117,119,118,0ffh	
m_ne:	db	126,65,65,66,67,71,75,60,59,59,32,24,124,123,0ffh	
m_se:	db	61,74,67,68,24,23,25,23,59,59,26,23,27,23,28,23,29,23,30,23,31,23,32,33,86,60,48,122,0ffh	
m_nw:	db	126,48,82,81,75,74,130,130,59,59,0ffh	
m_sw:	db	126,64,24,32,126,43,61,63,59,59,25,32,26,32,27,32,28,32,29,32,30,32,31,32,123,124,0ffh	
m_up:	db	126,15,126,8,130,93,11,12,59,59,60,69,15,14,35,15,40,15,41,22,50,39,52,51,53,49,54,55,56,54,57,56,58,53,63,64,74,81,88,44,91,89,92,90,2,3,99,19,102,103,103,102,109,107,108,110,115,104,116,108,0ffh	
m_down:	db	126,9,14,15,15,40,24,23,59,59,60,58,35,36,39,50,43,79,44,88,49,53,51,52,54,56,55,54,56,57,64,63,85,60,87,107,89,91,90,92,93,90,98,61,102,103,103,102,119,13,104,115,107,109,108,116,0ffh	
;
; if the move is blocked by a puzzle, put out a message
; if there is no move and no puzzle then put out one of three standard statements
;
NoMoves:			
	push	psw	
	push	b	
	push	d	
	push	h	
	lda	AW_flag	; is the action word a directional AW?
	cpi	1	; 1=directional AW
	jnz	NoMoves1	; go around no move messages, AW is something else
	lda	mylast	; get former room
	mov	b,a	; setup for compare
	lda	myroom	; get updated room
	cmp	b	; were we able to move?
	jnz	NoMoves1	; branch if we moved
	call	Puzzle	; check to see if puzzle is blocking player move	
	jc	NoMoves1	; go around no move messages, c=1 is puzzle in play
	lda	ran3	; get random # 1-3
	dcr	a	; convert to 0-2
	lxi	h,N_index	; base of sentence table
	call	DoObject	; play one of 3 cannot move sentences
	call	sentcr	; print cr lf
NoMoves1:			
	lda	turns+2 ; get ls digit of moves counter
	inr	a	; bump it
	cpi	3Ah	; time to carry the digit?
	jz	NoMoves2; branch to carry
	sta	turns+2	; update digit
	jmp	NoMoves4; go around digit carry code
NoMoves2:
	mvi	a,30h	; reset digit
	sta	turns+2	; update digit
	lda	turns+1	; get mid digit of moves counter
	inr	a	; bump it
	cpi	3Ah	; time to carry the digit?
	jz	NoMoves3; branch to carry
	sta	turns+1	; update digit
	jmp	NoMoves4; go around digit carry code
NoMoves3:
	mvi	a,30h	; reset digit
	sta	turns+1	; update digit
	lda	turns	; get high digit of moves counter
	inr	a	; bump it
	sta	turns	; update digit
NoMoves4:
	pop	h	
	pop	d	
	pop	b	
	pop	psw	
	ret		
;	
N_index:dw	sent349,sent350,sent351	
;
; Output announcements of any event objects active, given myroom value in reg a
; Event announces issues upon the arrival in a room
; Puzzle announces issues upon action in a room
; One event can happen anywhere underground- lamp battery death
;
Event:			
	push	psw	
	push	b	
	push	d	
	push	h	
	lxi	h,Elist	; base of list for events that come and go
	shld	Eroom1	; keep track of this pointer
Event1:			
	lhld	Eroom1	; get list pointer
	mov	a,m	; look for end of list
	cpi	0ffh	; at end?
	jz	Event4	; all done
	lda	myroom	; get current location
	cmp	m	; is this item in this room?
	jnz	Event2	; if not, branch, no sentence play
	inx	h	; set pointer to activity flag	
	mov	a,m	; get activity flag
	cpi	1	; 1=active
	jnz	Event3	; if not, branch, no sentence play
	shld	Eroom1	; save pointer
	inx	h	; set pointer to ls byte of handler address	
	mov	e,m	; get ls byte of handler address
	inx	h	; set pointer to ms byte of handler address	
	mov	d,m	; get ms byte of handler address
	shld	Eroom1	; save list pointer
	push	d	; setup for dispatch
	ret		; de to pc jmp instruction via stack
Event2:			
	inx	h	; now pointing to active byte of object
Event3:			
	inx	h	; now pointing to ls byte of object word address
	inx	h	; now pointing to ms byte of object word address
	inx	h	; pointing to next item room #
	shld	Eroom1	; save pointer
	jmp	Event1	; loop until all items are displayed
Event4:			
	lda	Battery	; get the battery charge value
	dcr	a	; every move drains the battery
	cpi	0	; at bottom of lower byte drain range?
	jnz	Event5	; branch if something to decrement
	lda	Battery+1; get ms byte of battery life
	cpi	0	; battery really dead?
	jz	event6  ; yes, so is player
	mvi	a,0	; discharge the battery to 50%
	sta	Battery+1; update it
Event5:
	sta	Battery	; update it
	lda	Battery+1; get ms byte of battery life
	cpi	1	; still 50% charge or better?
	jz	event8	; go around warning, plenty of battery left
	lxi	h,Sent436	; battery warning
	lda	Battery	; get ls byte of battery charge again
	cpi	100	; mid water mark for warning
	jz	event7	; branch if battery weak
	lxi	h,Sent437	; battery near death warning
	cpi	50	; low water mark for warning
	jz	event7	; branch if battery weak
	cpi	10	; light going out?
	jnz	event8	; branch if battery still strong
event6:
	lda	myroom	; get current location
	cpi	11	; player outside cave?
	jc	event8	; darkness not an issue
	mvi	a,0	; in the dark, player falls into pits
	sta	imdead	; time to restart
	lxi	h,Sent438	; battery now dead, player will be soon
event7:			
	shld	mysent1	; set phrase
	call	DoSentence	; play it
event8:			
	pop	h	
	pop	d	
	pop	b	
	pop	psw	
	ret		
;
Elist:		; event room, state where 0=inactive 1=active, event sentence #, 
	db	8,1	;
	dw	events1	; grate is locked
	db	8,0	;
	dw	events2	; grate is unlocked
Bridge1:db	16,0	;
	dw	events3	; crystalline bridge visible on east
Bridge2:db	17,0	;
	dw	events3	; crystalline bridge visible on west
Snake:	db	40,1	;
	dw	events4	; fierce snake
Lamp1:	db	10,1	; coming in from grate
	dw	events5	; need lamp in dark cave
Lamp2:	db	11,1	; coming via xyzzy
	dw	events5	; need lamp in dark cave
Lamp3:	db	36,1	; coming via y2
	dw	events5	; need lamp in dark cave
Plugh:	db	18,1	;
	dw	events6	; A hollow voice says "Plugh"
Pirate1:db	50,1	; 
	dw	events7	; A faint rustling noise...random rooms 50-59
Pirate2:db	48,1	; 
	dw	events8	; pirates lair with treasure chest
Dragon:	db	46,1	; 
	dw	events9	; dragon on rug
Dwarf0:	db	43,0	;
	dw	events10; dwarf in room with player
Bean1:	db	92,1	;
	dw	events11; beanstalk grows to giant room
Bean2:	db	90,0	; 
	dw	events12; Beanstalk in west pit
Dwarf1:	db	43,0	; 
	dw	events14; Dwarf attack
Door1:	db	96,1	; 
	dw	events15; massive rusted door closed
Door2:	db	96,0	; 
	dw	events16; massive rusted door open
Troll1:	db	64,1	;
	dw	events18; sw rickety bridge
Troll2:	db	65,1	;
	dw	events18; ne rickety bridge
Bear:	db	70,1	;
	dw	events17; bear with player
Dark:	db	84,1	
	dw	events13; dark room message
Mag1:	db	126,1	
	dw	events19; Spelunker Today January Edition
Mag2:	db	126,1	
	dw	events20; Spelunker Today Februrary Edition
Mag3:	db	126,1	
	dw	events21; Spelunker Today March Edition
Mag4:	db	126,1	
	dw	events22; Spelunker Today April Edition
Mag5:	db	126,1	
	dw	events23; Spelunker Today May Edition
Mag6:	db	126,1	
	dw	events24; Spelunker Today June Edition
Mag7:	db	126,1	
	dw	events25; Spelunker Today July Edition
Mag8:	db	126,1	
	dw	events26; Spelunker Today August Edition
Mag9:	db	126,1	
	dw	events27; Spelunker Today September Edition
Mag10:	db	126,1	
	dw	events28; Spelunker Today October Edition
Mag11:	db	126,1	
	dw	events29; Spelunker Today November Edition
Mag12:	db	126,1	
	dw	events30; Spelunker Today December Edition
	db	0ffh	; end of list
;
Eroom1:	dw	0	; temp storage for Elist table pointer
Battery:db	0ffh	; a lamp battery life measured in 512 moves
	db	1	; ms byte of battery life
;
; event routines in the cave
;
events1:			
	lxi	h,sent354	; grate is locked
	jmp	events99	
events2:			
	lxi	h,sent355	; grate is unlocked
	jmp	events99	
events3:			
	lxi	h,sent356	; crystalline bridge visible
	jmp	events99	
events4:			
	lxi	h,sent303	; fierce snake here
	jmp	events99	
events5:			
	lxi	h,sent359	; it is dark, without light there are pits
	jmp	events99	
events6:			
	lxi	h,sent360	; hollow voice says plugh
	jmp	events99	
;
; pirate lurks nearby
;
events7:			
	mvi	a,1	; stop pirate movement
	sta	even7a	; save it
	lxi	h,sent265	; faint rustling noises
	shld	mysent1	; set phrase
	call	DoSentence	; play it
	call	sentcr	; print cr lf
	jmp	Event4	; restore stack, done
even7a:	db	0	; flag to stop pirate movement once encountered
;
; pirate is found and runs away
;
events8:			
	call	sentcr	; print cr lf
	lxi	h,sent439	; pirate leaving room as player arrives
	shld	mysent1	; set phrase
	call	DoSentence	; play it
	call	sentcr	; print cr lf
	mvi	a,0	; pirate seen once
	sta	Pirate2+1	; won't be seen next time
	jmp	Event4	; restore stack, done
;
; dragon on the rug
;
events9:			
	lxi	h,Sent441	; dragon on rug
	shld	mysent1	; set phrase
	call	DoSentence	; play it
	call	sentcr	; print cr lf
	jmp	Event4	; restore stack, done
;
; dwarf in room
;
events10:			
	lxi	h,sent468	; nearby dwarf
	shld	mysent1	; save address of sentence
	call	DoSentence	; put it out there
	jmp	Event4	; restore stack, done
;
; beanstalk lifecycle
;
events11:			
	lda	even11f	; get beanstalk status
	cpi	0	; tiny plant?
	jnz	event11a	; branch if not
	lxi	h,sent364	; tiny little plant
	jmp	event11d	; go around other code
event11a:			
	cpi	1	; 12 foot stalk?
	jnz	event11b	; branch if not
	lda	even11h	; get flag for growing beanstalk
	cpi	1	; shown sent365 already?
	jz	event11e	; skip explosive growth after once
	mvi	a,1	; set flag
	sta	even11h	; beanstalk growing up
	lxi	h,sent365	; furious growth beanstalk
	shld	mysent1	; set phrase
	call	DoSentence	; play it
	call	sentcr	; print cr lf
event11e:			
	lxi	h,sent366	; 12 foot stalk
	shld	mysent1	; set phrase
	call	DoSentence	; play it
	lxi	h,sent367	; bellowing water
	jmp	event11d	; go around other code
event11b:			
	cpi	2	; big beanstalk?
	jnz	event11c	; branch if not
	mvi	a,90	; enable hole access
	sta	m_up+4	; hole above 2 pit room
	mvi	a,1	; show beanstalk in 2 pit room
	sta	Bean2+1	; change event flag
	mvi	a,10	; 10 points
	sta	pscore6	; post credit
	lxi	h,sent370	; big beanstock now
	lda	even11i	; get flag for explosive beanstalk
	cpi	1	; shown sent368 already?
	jz	event11g	; show secondary string once
	mvi	a,1	; set flag
	sta	even11i	; beanstalk fully grown
	lxi	h,sent368	; explosive plant growth
event11g:			
	jmp	event11d	; go around other code
event11c:			
	mvi	a,130	; cut off hole access
	sta	m_up+4	; hole above 2 pit room
	mvi	a,0	; remove beanstalk in 2 pit room
	sta	Bean2+1	; change event flag
	sta	even11f	; reset beanstalk status
	sta	even11h	; reset beanstalk status
	sta	even11i	; reset beanstalk status
	lxi	h,sent369	; over watered plant shrivel
event11d:			
	shld	mysent1	; set phrase
	call	DoSentence	; play it
	call	sentcr	; print cr lf
	jmp	Event4	; restore stack, done
;
even11f:db	0	; flag for beanstalk status
even11h:db	0	; flag for 12 foot beanstalk growth
even11i:db	0	; flag for explosive beanstalk growth
;
; beanstalk access to giant room
;
events12:			
	call	sentcr	; print cr lf
	lxi	h,sent370	; gigantic beanstalk now
	shld	mysent1	; set phrase
	call	DoSentence	; play it
	call	sentcr	; print cr lf
	jmp	Event4	; restore stack, done
;
; dark room has light
;
events13:			
	mvi	a,0	; play this message once
	sta	Dark+1	; reset flag that sent us here
	call	sentcr	; print cr lf
	lxi	h,sent363	; massive stone tablet reads congrats
	shld	mysent1	; set phrase
	call	DoSentence	; play it
	call	sentcr	; print cr lf
	jmp	Event4	; restore stack, done
;
; dwarf scheme: 
;  Puzz6 activates events14 seven times, decrement dwarfcnt
;  events10 dwarf in room after dwarf throws axe
;  events14 dwarf comes around a corner, he throws a little axe
;  work37 player throws axe, 2 in 3 chance dwarf is killed, events14 shut down Puzz6 restored
;
events14:			
	lxi	h,sent310	; dwarf appears and throws axe
	shld	mysent1	; save address of sentence
	call	DoSentence	; put it out there
	lda	ran10	; get random # 0-9
	cpi	2	; ran10=0-4
	jc	event14d	; branch if axe hit player 1 in 5 chance
	lxi	h,sent311	; the axe missed
	shld	mysent1	; save address of sentence
	call	DoSentence	; put it out there
	lda	Inlist+18	; where is the axe?
	cpi	126	; with player?
	jz	event14b	; player keeps axe
	lda	myroom	; get current room
	sta	Inlist+18	; drop the axe here
event14b:			
	lda	ran10	; get same random # 0-9
	cpi	6	; ran10=2-5 axe misses, dwarf leaves
	jc	event14a	; branch if dwarf splits
;
; axe missed player, dwarf stays
;
	mvi	a,1	; set the dwarf in room event
	sta	Dwarf0+1	; dwarf remains in room
	jmp	Event4	; restore stack, done
;
; axe missed player, dwarf splits
;
event14a:			
	lxi	h,sent467	; dwarf ran away
	shld	mysent1	; save address of sentence
	call	DoSentence	; put it out there
	mvi	a,131	; dwarf runs from rooms 41-45
	sta	Puzt6	; disable dwarf trigger until random returns it
	mvi	a,0	; clear the dwarf attack event flag
	sta	Dwarf1+1	; disable dwarf attack until next Puzz6 trigger
	jmp	Event4	; restore stack, done
;
; axe hit player, game restarts
;
event14d:			
	lxi	h,sent309	; axe kills player
	shld	mysent1	; save address of sentence
	call	DoSentence	; put it out there
	mvi	a,0	; axe killed player
	sta	imdead	; flag for Deadtest
	mvi	a,1	; axe killed player
	sta	axeflag	; set flag for dwarf killed player
	mvi	a,0	; clear the dwarf attack event flag
	sta	Dwarf1+1	; disable dwarf attack until next Puzz6 trigger
	mvi	a,131	; dwarf runs from rooms 41-45
	sta	Puzt6	; disable dwarf trigger
	jmp	Event4	; restore stack, done
;
; door to plover room is rusted shut
;
events15:			
	lxi	h,Sent315	; massive rusty door
	jmp	events99	; restore stack, done
;
; door to plover room has been opened
;
events16:			
	lxi	h,Sent317	; massive rusty door is open
	jmp	events99	; restore stack, done
;
; bear scheme
; 0= bear chained, dangerous  sent485 room 70 and sent483 once
; 1= bear chained, dangerous  sent485 room 70
; 2= bear chained, fed        sent289 room 70
; 3= bear unchained           sent486 room 70
; 4= bear taken               event17 sent 295 and set inlist+42 to 126, player
; 4= bear dropped, event17 off  set inlist+42 to myroom
;
events17:			
	lda	bears	; get bear state
	lxi	h,btable; point to table of bear messages
	call	GetAdd	; get address of appropriate bear message
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	call	sentcr	; sent crlf
	lda	bears	; get the bear state again
	cpi	0	; 
	jnz	events17a; branch if not state 0
	lxi	h,Sent483	; bear here, locked with chain
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	mvi	a,1	; event 0 happens only once
	sta	bears	; update flag
events17a:
	jmp	Event4	; restore stack, done
;
bears	db	0	; flag for bear state
btable	dw	sent485,sent485,sent289,sent486,sent295
;
; troll toll at rickety bridge
;
events18:			
	lxi	h,sent248	; troll toll to cross bridge
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	call	sentcr	; sent crlf
	jmp	Event4	; restore stack, done
;
; magazines dropped in the maze
;
events19:			
	lxi	d,word1417	; January
	jmp	events98	; Drop this issue here
events20:			
	lxi	d,word1418	; February
	jmp	events98	; Drop this issue here
events21:			
	lxi	d,word1419	; March
	jmp	events98	; Drop this issue here
events22:			
	lxi	d,word1420	; April
	jmp	events98	; Drop this issue here
events23:			
	lxi	d,word1421	; May
	jmp	events98	; Drop this issue here
events24:			
	lxi	d,word1422	; June
	jmp	events98	; Drop this issue here
events25:			
	lxi	d,word1423	; July
	jmp	events98	; Drop this issue here
events26:			
	lxi	d,word1424	; August
	jmp	events98	; Drop this issue here
events27:			
	lxi	d,word1425	; September
	jmp	events98	; Drop this issue here
events28:			
	lxi	d,word1426	; October
	jmp	events98	; Drop this issue here
events29:			
	lxi	d,word1427	; November
	jmp	events98	; Drop this issue here
events30:			
	lxi	d,word1428	; December
	jmp	events98	; Drop this issue here
;
; shared routine for magazines
;
events98:			
	push	d	; save the month
	mvi	c,9	; print string
	lxi	d,even98a	; string
	call	bdos	; print it
	mvi	c,9	; print string
	pop	d	; monthly string
	call	bdos	; print it
	lxi	h,sent443	; edition of Spelunker Today here
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	call	sentcr	; print cr lf
	jmp	Event4	; restore stack, done
;
even98a:	db	'There is a $'	
;
events99:			
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	jmp	Event4	; restore stack, done
;
; Check room list for puzzles, return carry to indicate c=1 puzzle in play to suppress generic no move messages
; If room has a puzzle, check to see that requested direction applies and issue a statement
; Event announces issues upon the arrival in a room
; Puzzle announces issues upon action in a room
; 
; Example
; The grate is locked in room 8, in the down direction, msg- You cannot go through a locked steel grate
;
Puzzle:			
	lxi	h,Puztab	; point to list of rooms with puzzles
Puzzle1:			
	mov	a,m	; get table entry
	cpi	0ffh	; at end of puzzle room list?
	jz	Puzzle5	; branch if no puzzle here
	lda	myroom	; get current location
	cmp	m	; is this a puzzle for the current room?
	jnz	Puzzle3	; if not, branch 
	inx	h	; direction of the puzzle for this room	
	mov	a,m	; get puzzle copy of action word
	cpi	69	; is this a puzzle for all blocked directions?
	jz	Puzzle2	; branch for puzzle with any blocked direction from this room
	lda	Actionw	; get action word
	cmp	m	; direction and puzzle match?
	jnz	Puzzle4	; if not branch for next puzzle check
Puzzle2:			
	inx	h	; point to ls byte of puzzle routine address
	mov	e,m	; get ls byte from dispatch table
	inx	h	; bump pointer
	mov	d,m	; get ms byte from dispatch table
	push	d	; setup for dispatch
	ret		; de to pc jmp instruction via stack
Puzzle3:			
	inx	h	; now pointing to puzzle direction byte
Puzzle4:			
	inx	h	; now ls byte of puzzle routine address
	inx	h	; now ms byte of puzzle routine address
	inx	h	; now pointing to next puzzle record
	jmp	Puzzle1	; loop until the entire list is checked
Puzzle5:			
	stc		; set carry flag
	cmc		; invert carry flag to indicate no puzzle in play
	ret		
;
; Puztab  table of rooms, action words and handlers for the puzzles
; ActionW values: 4:west 5:east 6:north 7:south 8:sw 9:nw 10:se 11:ne 
;                 12:up 13:down 18:n 19:s 20:e 21:w
;
Puztab:	db	8,13	; room 8, down
	dw	Puzz1	; puzzle handler is Puzz1 (grate)
	db	8,23	; room 8, d(own)
	dw	Puzz1	; puzzle handler is Puzz1
	db	16,4	; room 16, west
	dw	Puzz2	; puzzle handler is Puzz2 (fissure)
	db	16,21	; room 16, w(est)
	dw	Puzz2	; puzzle handler is Puzz2
	db	17,5	; room 17, east
	dw	Puzz2	; puzzle handler is Puzz2
	db	17,20	; room 17, e(ast)
	dw	Puzz2	; puzzle handler is Puzz2
	db	40,4	; room 40, west
	dw	Puzz3	; puzzle handler is Puzz3 (snake)
	db	40,21	; room 40, w(est)
	dw	Puzz3	; puzzle handler is Puzz3
	db	40,6	; room 40, north
	dw	Puzz3	; puzzle handler is Puzz3
	db	40,18	; room 40, n(orth)
	dw	Puzz3	; puzzle handler is Puzz3
	db	40,7	; room 40, south
	dw	Puzz3	; puzzle handler is Puzz3
	db	40,19	; room 40, s(outh)
	dw	Puzz3	; puzzle handler is Puzz3
	db	40,8	; room 40, sw
	dw	Puzz3	; puzzle handler is Puzz3
	db	10,4	; room 10, west
	dw	Puzz4	; puzzle handler is Puzz4 (darkness)
	db	10,21	; room 10, w(est)
	dw	Puzz4	; puzzle handler is Puzz4
	db	11,4	; room 11, west
	dw	Puzz4	; puzzle handler is Puzz4 (darkness)
	db	11,21	; room 11, w(est)
	dw	Puzz4	; puzzle handler is Puzz4 (darkness)
	db	36,4	; room 36, west
	dw	Puzz4	; puzzle handler is Puzz4
	db	36,21	; room 36, w(est)
	dw	Puzz4	; puzzle handler is Puzz4
	db	36,7	; room 36, south
	dw	Puzz4	; puzzle handler is Puzz4
	db	36,19	; room 36, s(outh)
	dw	Puzz4	; puzzle handler is Puzz4
	db	36,5	; room 36, east
	dw	Puzz4	; puzzle handler is Puzz4
	db	36,20	; room 36, e(ast)
	dw	Puzz4	; puzzle handler is Puzz4
	db	18,6	; room 18, north
	dw	Puzz5	; puzzle handler is Puzz5 (gold nugget)
	db	18,18	; room 18, n(orth)
	dw	Puzz5	; puzzle handler is Puzz5
	db	59,69	; room 59, all directions
	dw	Puzz5a	; puzzle handler is Puzz5a (Witts End)
Puzt6:	db	43,69	; randomized room 41-45 any direction
	dw	Puzz6	; puzzle handler is Puzz6 (dwarf attack)
	db	64,11	; room 64, ne
	dw	Puzz7	; puzzle handler is Puzz7 (pay troll)
	db	65,8	; room 65, sw
	dw	Puzz7	; puzzle handler is Puzz7 (pay troll)
Puzt8:	db	50,69	; varies from 50-59, any direction
	dw	Puzz8	; puzzle handler is Puzz8 (pirate robbery)
	db	90,12	; up in west two pit
	dw	Puzz10	; puzzle handler is Puzz10 (beanstalk up to Giant room)
	db	82,5	; room 82 east
	dw	Puzz11	; puzzle handler is Puzz11 (drop everything to get into plover room)
	db	82,20	; room 82 e(ast)
	dw	Puzz11	; puzzle handler is Puzz11 (drop everything to get into plover room)
	db	99,69	; maze 99
	dw	Puzz5a	; show no message (all alike maze)
	db	100,69	; maze 100
	dw	Puzz5a	; show no message (all alike maze)
	db	101,69	; maze 101
	dw	Puzz5a	; show no message (all alike maze)
	db	102,69	; maze 102
	dw	Puzz5a	; show no message (all alike maze)
	db	103,69	; maze 103
	dw	Puzz5a	; show no message (all alike maze)
	db	104,69	; maze 104
	dw	Puzz5a	; show no message (all alike maze)
	db	105,69	; maze 105
	dw	Puzz5a	; show no message (all alike maze)
	db	106,69	; maze 106
	dw	Puzz5a	; show no message (all alike maze)
	db	107,69	; maze 107
	dw	Puzz5a	; show no message (all alike maze)
	db	108,69	; maze 108
	dw	Puzz5a	; show no message (all alike maze)
	db	109,69	; maze 109
	dw	Puzz5a	; show no message (all alike maze)
	db	83,11	; room 83 ne
	dw	Puzz12	; puzzle handler is Puzz12 (plover room tight entrance)
	db	17,6	; room 17 north
	dw	Puzz13	; handler is Puzz13 (Hall of Mists crossover)
	db	17,18	; room 17 n(orth)
	dw	Puzz13	; handler is Puzz13 (Hall of Mists crossover)
	db	19,6	; room 19 north
	dw	Puzz13	; handler is Puzz13 (Hall of Mists crossover)
	db	19,18	; room 19 n(orth)
	dw	Puzz13	; handler is Puzz13 (Hall of Mists crossover)
Puzt14:	db	96,6	; room 96 north
	dw	Puzz14	; handler is Puzz14 (Rusty Door immense N/S Canyon)
Puzt14a:db	96,18	; room 96 n(orth)
	dw	Puzz14	; handler is Puzz14 (Rusty Door immense N/S Canyon)
	db	46,6	; room 46 north
	dw	Puzz15	; handler is Puzz15 (stuck with Dragon)
	db	46,18	; room 46 n(orth)
	dw	Puzz15	; handler is Puzz15 (stuck with Dragon)
	db	46,5	; room 46 east
	dw	Puzz15	; handler is Puzz15 (stuck with Dragon)
	db	46,20	; room 46 e(ast)
	dw	Puzz15	; handler is Puzz15 (stuck with Dragon)
	db	0ffh	; table end
;
; grate
;
Puzz1:			
	lxi	h,sent258	; cannot go through locked grate
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	stc		; do not add generic cannot move msg
	ret		
;
; fissure
;
Puzz2:			
	lxi	h,sent260	; no way across fissure
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	stc		; do not add generic cannot move msg
	ret		
;
; snake
;
Puzz3:			
	lxi	h,sent358	; snake blocks the way
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	stc		; do not add generic cannot move msg
	ret		
;
; pits in the dark
;
Puzz4:			
	lda	imdead	; get life counter
	dcr	a	; take 1 of 3 lives
	sta	imdead	; remember this
	lxi	h,sent359	; it is dark and there are pits
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	stc		; do not add generic cannot move msg
	ret		
;
; gold nugget
;
Puzz5:			
	mvi	a,15	; player moves north from nugget room 18
	sta	myroom	; to Hall of Mists
	lda	Inlist+48	; but if we are carrying gold, it drops
	cpi	126	; holding gold?
	jnz	Puzz5a	; branch if not
	mvi	a,18	; player moves, gold stays
	sta	Inlist+48	; put gold back
	lxi	h,sent372	; something fell
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
Puzz5a:			
	stc		; suppress cannot move messages
	ret		
;
; dwarf attack
;
Puzz6:			
	lda	dwcount	; get dwarf remaining count
	dcr	a	; bump it
	cpi	0	; 7 dead dwarfs?
	jz	Puzz6a	; if all dead, branch
	sta	dwcount	; update it
	lda	Dwarf0+1	; dwarf present?
	cpi	1	; 1=dwarf around
	jz	Puzz6a	; if already present, branch
	mvi	a,0	; clear dwarf present event
	sta	Dwarf0+1	; set it
	mvi	a,1	; set the attack flags
	sta	Dwarf1+1	; enable dwarf event14 for attack and resolution
Puzz6a:			
	ret		
;
dwcount	db	7	; 7 dwarfs that attack
;
; Pay toll to troll in rooms 64 and 65
;
Puzz7:			
	mvi	c,15	; 15 objects of value to scan
	lxi	h,Inlist+24	; list of treasure objects
Puzz7a:			
	mvi	a,63	; troll crossing is rooms 64 and 65
	cmp	m	; is this treasure in room higher than 63?
	jnc	Puzz7b	; branch if not
	mvi	a,65	;
	cmp	m	; is this treasure in room higher than 65?
	jc	Puzz7b	; branch if treasure is not in 64 or 65
	mvi	a,125	; troll takes treasure away
;	mvi	a,1	 ; debug troll treasure dump in well house
	mov	m,a	; set item location to troll storage
	jmp	Puzz7c	; take only 1 treasure
Puzz7b:			
	inx	h	; bump to byte2 of this entry
	inx	h	; bump to next item
	dcr	c	; bump counter
	jnz	Puzz7a	; loop until all are examined
	call	sentcr	; print cr lf
	lxi	h,sent251	; troll blocks the way
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	call	sentcr	; print cr lf
	jmp	Puzz7d	; go around no treasure condition
Puzz7c:			
	inx	h	; bump inlist to catch treasure index number
	mov	a,m	; get object number
	sta	Puzz7k	; save for later
	mvi	c,9	; print string
	lxi	d,Puzz7n	; Troll catches...
	call	bdos	; job for dos, can't term with crlf like DoSentence
	lda	Puzz7k	; get index of the object
	lxi	h,objwords	; base of treasure words list
	call	GetAdd	; get address of word
	xchg		; string address in reg de
	mvi	c,9	; print string
	call	bdos	; print treasure name
	mvi	c,9	; print string
	lxi	d,wordsp	; put in a word space
	call	bdos	; job for dos
	lxi	h,sent253	; troll scurries away
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	lda	inlist+42	; bear with player?
	cpi	126	; 126= with player
	jnz	Puzz7m	; branch if no bear here
	lxi	h,sent254	; bridge, player, bear collapses
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	mvi	a,0	; bear causes bridge collapse
	sta	imdead	; set flag for player health
	jmp	Puzz7d	; go around other outcome
Puzz7m:			
	lda	myroom	; find out where player stands
	cpi	64	; se of bridge?
	mvi	a,64	; move from room 65 to 64
	jnz	Puzz7l	; go around code for other bridge direction
	mvi	a,65	; move across bridge from room 64
Puzz7l:			
	sta	myroom	;
Puzz7d:			
	stc		; do not add generic cannot move msg
	ret		
;
Puzz7k:	db	0	; word number for troll toll
Puzz7n:	db	'The troll catches the $'	
;
; Pirate robbery
;
Puzz8:			
	mvi	c,15	; 15 objects of value to scan
	lxi	h,Inlist+24	; list of treasure objects
Puzz8a:			
	mvi	a,126	; player holds items tagged with 126
	cmp	m	; player holding this item?
	jnz	Puzz8b	; branch if not
	mvi	a,48	; pirate lair and treasure chest room
	mov	m,a	; set item location to treasure chest
Puzz8b:			
	inx	h	; bump to byte2 of this entry
	inx	h	; bump to next item
	dcr	c	; bump counter
	jnz	Puzz8a	; loop until all are examined
	mvi	a,0	; turn off rustling noise
	sta	Pirate1+1	; Pirate comes once
	mvi	a,122	; pirates lair appears nw of this room
	sta	m_nw	; update permitted moves table
	lxi	h,sent266	; pirate robs player
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	call	sentcr	; print cr lf
	stc		; do not add generic cannot move msg
	ret		
;
; beanstalk access from west two pit to giant room
;
Puzz10:			
	lxi	h,sent320	; hint that climbing might be possible
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	stc		; do not add generic cannot move msg
	ret		
;
; drop everything to get into Plover Room
;
Puzz11:
	mvi	c,26	; 26 items that might be with player
	lxi	h,inlist; point to base of inlist locations
Puzz11a:			
	mov	a,m	; get room flag
	cpi	126	; is this item with Player?
	jz	Puzz11b	; branch if not yet dropped
	inx	h	; bump pointer
	inx	h	; bump pointer
	dcr	c	; bump counter
	jnz	Puzz11a	; loop until all checked
	mvi	a,83	; permit plover room move
	sta	myroom	; move player
	jmp	Puzz11c	; go around other code
Puzz11b:		
	lxi	h,sent262	; you will get stuck in tunnel
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	call	sentcr	; print crlf
Puzz11c:		
	stc		; do not add generic cannot move msg
	ret		
;
; Working lamp required for Dark Room after Player drops it for Plover Room
;
Puzz12:
	lda	Inlist+2; look at lamp location
	cpi	126	; player holding lamp?
	jnz	Puzz12a	; branch if we do not have lamp
	lda	Lamp1+1	; is the lamp on?
	cpi	1	; 1=lamp off
	jz	Puzz12b	; Dark room needs light
	mvi	a,84	; dark room
	sta	myroom	; send player in
	jmp	Puzz12c	; go around other code
Puzz12a:		
	lxi	h,sent415	; emerald glow still need lamp
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	jmp	Puzz12c	; go around other code
Puzz12b:		
	lxi	h,sent416	; too dark to go without lamp
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
Puzz12c:		
	stc		; do not add generic cannot move msg
	ret		
;
; Crossover north of Hall of Mists
;
Puzz13:			
	lda	myroom	; player's current room
	cpi	17	; west Hall of Mists?
	jnz	Puzz13a	; branch if not
	mvi	a,19	; move to other end of hall
	jmp	Puzz13b	; go around other code
Puzz13a:			
	mvi	a,17	; move to other end of hall
Puzz13b:			
	sta	myroom	; update the room
	lxi	h,sent465	; you have crawled around the Hall of Mists
	shld	mysent1	; save address of sentence
	call	Dosentence	; put it out there
	call	sentcr	; print cr lf
	stc		; do not add generic cannot move
	ret		
;
; rusty door to Plover Room
;
Puzz14:			
	lxi	h,Sent316	; rusty door is closed
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	call	sentcr	; print cr lf
	stc		; do not add generic cannot move
	ret		
;
; stuck with Dragon
;
Puzz15:			
	lxi	h,Sent362	; you can't get past the dragon
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	call	sentcr	; print cr lf
	stc		; do not add generic cannot move
	ret		
;
; count the columns we are using to avoid wrapping a word across two lines
; input is sentence string at DL, terminated with $
;
Bdosf:			
	push	psw	
	push	b	
	push	d	
	push	h	
	mov	h,d	; copy ms byte of string address
	mov	l,e	; copy ls byte of string address
	mvi	c,0	; counter
Bdosf1:			
	inr	c	; bump counter
	mov	a,m	; get char from string
	inx	h	; bump char pointer
	cpi	'$'	; at end of string?
	jnz	Bdosf1	; loop until when all chars are counted (count $ for trailing space)
	lda	ColCount	; get console column counter
	add	c	; add the length of this new word
	sta	ColCount	; save it
	cpi	80	; less than 80 chars on this line?
	jc	Bdosf2	; branch if we still fit on this line
	mov	a,c	; resetting column counter
	sta	ColCount	; we will be on a new line with this word
	push	d	; save original string address for a moment
	call	sentcr	; print cr lf
	pop	d	; bring original string address back
Bdosf2:			
	mvi	c,9	; print string
	call	bdos	; call the real bdos
	pop	h	
	pop	d	
	pop	b	
	pop	psw	
	ret		
;
ColCount:	db	0	
;
; take input from the user and capture the action word and the object word
; return with action and object word numbers in Actionw and Objectw locations
;
Take_Input:			
	push	psw	
	push	b	
	push	d	
	push	h	
	lda	automove	; moving automatically?
	cpi	0	; 1= auto moving
	jz	Take_I0	; branch to take regular input
	call	work50	; take auto input
	jmp	Take_I8	; go around non auto code
Take_I0:			
	mvi	a,0	; reset action and object word values
	sta	Actionw	; action word cleared
	sta	Objectw	; object word cleared
	lxi	h,In_two	; point to buffer for second input from user
	shld	In_2	; init pointer
	lxi	h,In_one	; point to buffer for first input from user
	shld	In_1	; init pointer
	mvi	c,20	; set loop counter
	mvi	a,20h	; ascii space
Take_I1:			
	mov	m,a	; clear buffer byte
	inx	h	; bump pointer
	dcr	c	; bump counter
	jnz	Take_I1	; loop until done
	mvi	a,0	; action word and object word length limit counts up to 10
	sta	In_1_len; word 1 length counter
	sta	In_2_len; word 2 length counter
Take_I2:			
	mvi	c,1	; console in
	call	bdos	; job for dos
	cpi	07fh	; delete key?
	jnz	Take_I3	; not delete, go around backspace code
	mvi	c,9	; print string
	lxi	d,cl_line	; wipe out current entries
	call	bdos	; job for dos
	jmp	Take_I0	; made mistake, start over
bu_chr	db	08h,20h,08h,08h,20h,08h,'$'  ; bs,sp over /,bs,bs,sp over bad char,bs
cl_line	db	0dh,'                ',0dh,'$'	
Take_I3:			
	cpi	2fh	; slash for backspace key?
	jnz	Take_I3a; not slash, go around backspace code
	lda	In_1_len; get char counter
	cpi	0	; still at beginning?
	jz	Take_I2	; nothing to do, keep getting input
	dcr	a	; unbump count
	sta	In_1_len; save count
	lhld	In_1	; get pointer
	dcx	h	; unbump pointer
	shld	In_1	; save pointer
	mvi	m,20h	; erase char in buffer
	mvi	c,9	; print string
	lxi	d,bu_chr; wipe the terminal character
	call	bdos	; job for dos
	jmp	Take_I2	; made mistake, now cleaned up
Take_I3a:
	cpi	0dh	; user terminated input?
	jz	Take_I6	; branch to analyze input
	cpi	20h	; user space between action words?
	jz	Take_I4	; branch to collect second input word
	jc	Take_I2	; eat control chars that BDOS does not trap
	call	Caps_lc	; change any upper case to lower case
	lhld	In_1	; get pointer
	mov	m,a	; save character
	inx	h	; bump pointer
	shld	In_1	; save pointer
	lda	In_1_len; get char counter
	inr	a	; bump count
	sta	In_1_len; save count
	cpi	11	; got 10 chars?
	jc	Take_I2	; branch if more to collect
Take_I4:			
	mvi	c,1	; console in
	call	bdos	; job for dos
	cpi	07fh	; delete key?
	jnz	Take_I5	; not delete, go around backspace code
	mvi	c,9	; print string
	lxi	d,cl_line	; wipe out current entries
	call	bdos	; job for dos
	jmp	Take_I0	; made mistake, start over
Take_I5:
	cpi	2Fh	; slash for backspace key?
	jnz	Take_I5a; not slash, go around backspace code
	lda	In_2_len; get char counter
	cpi	0	; still at beginning?
	jz	Take_I4	; nothing to do, keep getting input
	dcr	a	; unbump count
	sta	In_2_len; save count
	lhld	In_2	; get pointer
	dcx	h	; unbump pointer
	shld	In_2	; save pointer
	mvi	m,20h	; erase char in buffer
	mvi	c,9	; print string
	lxi	d,bu_chr; wipe the terminal character
	call	bdos	; job for dos
	jmp	Take_I4	; branch to collect more
Take_I5a:			
	cpi	0dh	; user terminated input?
	jz	Take_I6	; branch to analyze input
	cpi	20h	; user space between action words?
	jz	Take_I6	; got two words, branch to analyze
	jc	Take_I4	; eat control chars that BDOS does not trap
	call	Caps_lc	; change any upper case to lower case
	lhld	In_2	; get pointer
	mov	m,a	; save character
	inx	h	; bump pointer
	shld	In_2	; save pointer
	lda	In_2_len	; get char counter
	inr	a	; bump count
	sta	In_2_len	; save count
	cpi	11	; got 10 chars?
	jc	Take_I4	; branch if more to collect
;
;look at word1 and word2 to match with an action word
;
Take_I6:			
	lxi	h,in_two	; start of user string 2
	call	Match_me	; routine to set Actionw
	lda	Actionw	; see if an action word was found
	cpi	0	; zero if no action word
	jnz	Take_I7	; branch to not trash found action word
	lxi	h,in_one	; start of user string 1
	call	Match_me	; routine to set Actionw
Take_I7:			
	lxi	h,in_one	; start of user string 1
	call	Find_me	; routine to set Objectw
	lda	Objectw	; see if an object word was found
	cpi	0	; zero if no action word
	jnz	Take_I8	; branch to not trash found object word
	lxi	h,in_two	; start of user string 2
	call	Find_me	; routine to set Objectw
Take_I8:			
	pop	h	
	pop	d	
	pop	b	
	pop	psw	
	ret		
;
; convert any alpha char in reg a to lower case
;
Caps_lc:			
	cpi	5bh	; c=1 if capital Z or lower?
	jnc	Caps_lc2	; branch if higher than capital Z
	cpi	41h	; c=1 if less than capital A
	jc	Caps_lc2	; branch if less than capital A
	adi	20h	; converts alpha CAP to lc alpha
Caps_lc2:			
	ret		
;
; match the string at HL with user entered keywords and set Actionw, if there is a match
;
Match_me:			
	mvi	a,0	; action word counter
	sta	Mat3	; start at beginning of action word list
	sta	Actionw	; clear the last action word found
	sta	Actionf	; reset action word found flag
	shld	Mat1	; save the address to the buffer pointer for the possible action word
	lxi	h,act_words	; base address of action words pointer list
	shld	Mat2	; save address to address of action words
Match_1:			
	lhld	Mat2	; get address of current action for compare
	mov	e,m	; get ls byte
	inx	h	; bump pointer
	mov	d,m	; get ms byte
	lhld	Mat1	; get address of current user input for compare
Match_2:			
	ldax	d	; get action word char
	cpi	'$'	; at end of reference action word?
	jz	Match_4	; branch if we have a match
	cmp	m	; compare to user input word at hl
	jnz	Match_3	; branch if not the same
	inx	d	; bump pointer
	inx	h	; bump pointer
	jmp	Match_2	; keep checking
Match_3:			
	lda	Mat3	; get action word counter
	cpi	Mykeys	; number of action words to check
	jz	Match_5	; branch if done checking	; 
	inr	a	; bump it, we have more checking
	sta	Mat3	; remember it
	lhld	Mat2	; get address of action word we just compared
	inx	h	; bump address
	inx	h	; 16 bit bump
	shld	Mat2	; save for next pass
	jmp	Match_1	; try next action word
Match_4:			
	mov	a,m	; get the next char from user input
	cpi	20h	; we are at end of keyword, are we at end of user input?
	jnz	Match_3	; keep checking, this may have been just a single letter match
	mvi	a,1	; flag
	sta	Actionf	; set action word found flag
	lda	Mat3	; get action word counter
	sta	Actionw	; report the word found	
Match_5:			
	ret		
;
; match the string at HL with user entered keywords and set Objectw, if there is a match
;
Find_me:			
	mvi	a,0	; object word counter
	sta	Mat3	; start at beginning of object word list
	sta	Objectw	; clear the last object name found
	sta	Objectf	; reset object word found flag
	shld	Mat1	; save the address to the buffer pointer for the possible object name
	lxi	h,objwords	; base address of object names pointer list
	shld	Mat2	; save address to address of action words
Find_1:			
	lhld	Mat2	; get address of current object for compare
	mov	e,m	; get ls byte
	inx	h	; bump pointer
	mov	d,m	; get ms byte
	lhld	Mat1	; get address of current user input for compare
Find_2:			
	ldax	d	; get object name char
	cpi	'$'	; at end of reference object name?
	jz	Find_4	; branch if we have a match
	cmp	m	; compare to user input word at hl
	jnz	Find_3	; branch if not the same
	inx	d	; bump pointer
	inx	h	; bump pointer
	jmp	Find_2	; keep checking
Find_3:			
	lda	Mat3	; get object name counter
	cpi	Myobs	; number of object names to check
	jz	Find_5	; branch if done checking	; 
	inr	a	; bump it, we have more checking
	sta	Mat3	; remember it
	lhld	Mat2	; get address of object name we just compared
	inx	h	; bump address
	inx	h	; 16 bit bump
	shld	Mat2	; save for next pass
	jmp	Find_1	; try next object name
Find_4:			
	mov	a,m	; get the next char from user input
	cpi	20h	; we are at end of keyword, are we at end of user input?
	jnz	Find_3	; keep checking, this may have been just a single letter match
	mvi	a,1	; flag
	sta	Objectf	; set object word found flag
	lda	Mat3	; get object name counter
	sta	Objectw	; report the object name found	
Find_5:			
	ret		
;
; Dead Test  
; If all treasures are found, push for end of game
; if the player has blown it, start over (reincarnate)
;
Deadtest:			
	call	trcount	; start the scoring with a treasure count in reg de
	mov	a,e	; get number of treasures times 8 points each
	cpi	100	; debug more than 12 treasures retrieved? will be 8*15
	jc	dead0	; branch if not enough treasures yet
	mvi	a,1	; 1=cave closing
	sta	Closed	; enable end of game items
;
; if the cave is closing, remind player 1 in 10 times
;
	lda	caveclose	; get reminder counter
	dcr	a	; bump the counter
	sta	caveclose	; update it
	jnz	dead0	; branch if not time to chime
	mvi	a,10	; reset chime counter
	sta	caveclose	; update it
	call	sentcr	; print cr lf
	lxi	h,sent469	; cave closing soon
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	call	sentcr	; print cr lf
;
; check player health
;
dead0:			
	lda	imdead	; get flag for player health
	cpi	0	; still kicking?
	jnz	dead5	; branch if alive
	mvi	c,15	; 15 travel bytes
	lxi	h,roomb	; clear travel records
dead1:
	mvi	m,0	; clear the bits
	inx	h	; bump pointer
	dcr	c	; bump counter
	jnz	dead1	; loop until done
	mvi	a,0	; reset location
	sta	myroom	; update it
	sta	bears	; reset bear scheme
	mvi	a,3	; revive the player life
	sta	imdead	; save it
	mvi	a,0ffh	; recharge batteries
	sta	Battery	; back to full charge
	mvi	a,1	; Battery charge
	sta	Battery+1; is a 16 bit number
	sta	Bear+1	; reset bear events
	mvi	a,70	; barren room
	sta	Bear	; put the bear back
	mvi	c,28	; 28 objects to move back
	lxi	d,Relist	; point to object starting room list
	lxi	h,Inlist	; point to object location list
dead2:			
	ldax	d	; get original room
	mov	m,a	; reset it
	inx	d	; bump to next in Relist table
	inx	h	; bump to inlist second byte
	inx	h	; bump to inlist next entry
	dcr	c	; bump counter
	jnz	dead2	; loop until done
	mvi	c,10	; 10 puzzles
	lxi	h,pscore0	; puzzle score table
deadp:			
	mvi	m,0	; clear puzzle score
	inx	h	; bump pointer
	dcr	c	; bump counter
	jnz	deadp	; loop until done
	jmp	dead3	; go around reset data table
Relist:			
	db	1	; 0.keys
	db	1	; 1.lamp
	db	1	; 2.food
	db	1	; 3.bottle
	db	10	; 4.empty cage
	db	13	; 5.bird nearby
	db	11	; 6.rod
	db	130	; 7.bird in cage
	db	130	; 8.bottle empty
	db	130	; 9.axe
	db	76	; 10.pillow
	db	91	; 11.oil
	db	41	; 12.coins
	db	70	; 13.gold chain
	db	58	; 14.magazine
	db	130	; 15.pearl rolls to 57 after shell is opened
	db	83	; 16.emerald
	db	74	; 17.vase
	db	46	; 18.rug
	db	84	; 19.pyramid
	db	17	; 20.diamonds
	db	70	; 21.bear
	db	94	; 22.golden eggs
	db	97	; 23.trident
	db	18	; 24.gold nugget
	db	39	; 25.bars of silver
	db	42	; 26.jewelry
	db	72	; 27.spices
;
dead3:			
	lda	axeflag	; was the dwarf a killer?
	cpi	1	; 1=dwarf did it
	jz	dead4	; go around pitfall messages
	call	sentcr	; print cr lf
	lxi	h,sent417	; Oh dear, pitfall
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	lxi	h,sent418	; broken everything
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
dead4:			
	mvi	a,0	; one last clean up
	sta	axeflag	; reset flag for dwarf killed player
	call	sentcr	; print cr lf
	lxi	h,sent419	; poof
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
dead5:			
	ret		
;
Mat1:	dw	0	
Mat2:	dw	0	
Mat3:	db	8	
In_1:	dw	In_one	
In_2:	dw	In_two	
In_one	db	'          '	
In_two	db	'          '	
In_1_len:	db	0	
In_2_len:	db	0	
Actionw:	db	0	; action word found becomes a number
Actionf:	db	0	; flag=1 when action word found
Objectw:	db	0	; object word found becomes a number
Objectf:	db	0	; flag=1 when object word found
AW_flag:	db	0	; 0= regular action word  1=directional action word
caveclose:	db	10	; counter for cave closure messages
;
;Work routines to respond to specific action and object keywords
;
DoWork:			
	mvi	a,0	; reset flag for directional work
	sta	AW_flag	; indicate action word is not a directional AW
	lda	Actionw	; get the action word from the user
	lxi	h,worktab	; base of work routine dispatch table
	mvi	d,0	; small offsets
	add	a	; convert to table offset
	mov	e,a	; setup for calculation
	dad	d	; point to appropriate work routine address
	mov	e,m	; get ls byte from dispatch table
	inx	h	; bump pointer
	mov	d,m	; get ms byte from dispatch table
	push	d	; setup for dispatch
	ret		; de to pc instruction via stack
;
; no Action Word match, say Huh?
;
work0:			
	lda	Actionf	; action word found flag
	cpi	1	; 1=valid action word found
	jz	work0b	; don't add a response if valid action word
	lda	In_1_len	; get char counter
	cpi	0	; more than nothing entered?
	jz	work0b	; branch to say nothing to just a cr
work0a:			
	call	sentcr	; print cr lf
	call	sentcr	; print cr lf again
	mvi	c,9	; print string
	lxi	h,sent352	; Huh?
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
work0b:			
	ret		
;
; f  move forward one room
;
work1:			
	lda	myroom	; get current room
	inr	a	; bump to next (temporary up)
	cpi	125	; in next to last room?
	jz	work1a	; branch if at end
	sta	myroom	; update it
	lda	bears	; what is the bear state?
	cpi	4	; is bear following player?
	jnz	work1a  ; all done without bear
	sta	Bear	; update bear location
work1a:			
	ret		
;
; quit: end program
;
work2:			
	mvi	c,9	; print string
	lxi	h,sent301	; sure you want to quit?
	shld	mysent1	; set sentence to say
	call	DoSentence	;say it
	mvi	c,1	; console in
	call	bdos	; job for dos
	cpi	'y'	; y is enough
	jnz	work2a	; branch if not quitting
;
; This is where the player ends up when the game is won
;
work2c:			
	mvi	a,1	; set the quit flag
	sta	work2b	; show the score assessment
	call	work28	; show the score, then the door.
	pop	h	; straighten up the stack.
	rst	0	; quit program
work2a:			
	ret		; keep playing
;
work2b:	db	0	; quit flag for score report
;
; b  move back one room
;
work3:	lda	myroom	; get current room
	cpi	0	; are we in room 0?
	jz	work3a	; branch if at zero already
	dcr	a	; bump to previous (temporary down)
	sta	myroom	; update it
	lda	bears	; what is the bear state?
	cpi	4	; is bear following player?
	jnz	work3a  ; all done without bear
	sta	Bear	; update bear location
work3a:			
	ret		
;
; directional routines
;
work4:	lxi	h,m_west	; go west travel table
	call	MyMoves	; update room # if permitted
	ret		
work5:	lxi	h,m_east	; go east travel table
	call	MyMoves	; update room # if permitted
	ret		
work6:	lxi	h,m_north	; go north travel table
	call	MyMoves	; update room # if permitted
	ret		
work7:	lxi	h,m_south	; go south travel table
	call	MyMoves	; update room # if permitted
	ret		
work8:	lxi	h,m_sw	; go south west travel table
	call	MyMoves	; update room # if permitted
	ret		
work9:	lxi	h,m_nw	; go north west travel table
	call	MyMoves	; update room # if permitted
	ret		
work10:	lxi	h,m_se	; go south east travel table
	call	MyMoves	; update room # if permitted
	ret		
work11:	lxi	h,m_ne	; go north east travel table
	call	MyMoves	; update room # if permitted
	ret		
work12:	lxi	h,m_up	; go up travel table
	call	MyMoves	; update room # if permitted
	ret		
work13:	lxi	h,m_down	; go down travel table
	call	MyMoves	; update room # if permitted
	ret		
;
; take something that moves
;
work14:			
	lda	Objectf	; object found flag
	cpi	0	; 1=valid object found
	jz	work14a	; cannot take invalid object
	lxi	h,inlist; point to base of object room locations
	lda	objectw	; get index to the object from user input
	cpi	6	; is the object word rod?
	jz	work14d	; branch for rod special case in repository
	cpi	35	; is the object word inven?
	jz	work16	; go do the inventory
	cpi	39	; is the object word inventory?
	jz	work16	; go do the inventory
	cpi	21	; is the object word bear?
	jz	work14m	; go deal with the bear
	cpi	13	; is the object word chain?
	jz	work14x ; go deal with the chain
	cpi	31	; take all?
	jz	work14g	; pickup everything in the room
	cpi	14	; magazine?
	jz	work14n	; pickup magic magazines
	cpi	36	; player used nugget?
	jnz	work14t	; branch if some other object
	mvi	a,24	; gold=nugget
	sta	objectw	; change player input
	jmp	work14tt; go around lantern code
work14t:
	cpi	40	; player used lantern?
	jnz	work14tt; branch if some other object
	mvi	a,1	; lantern=lamp
	sta	objectw	; change player input
work14tt:			
	add	a	; two bytes in every record so mult by two
	mvi	d,0	; small offset
	mov	e,a	; ls byte of offset in e
	dad	d	; set pointer to memory with hl
	mov	d,m	; get current room # of object
	shld	work14r	; save address to current room # of object
	lda	myroom	; get current room #
	cmp	d	; requested object in current room?
	jz	work14b	; branch if something to take
work14a:			
	mvi	c,9	; print string
	lxi	d,wordcr; print cr lf
	call	bdos	; output it
	lxi	h,sent414	; I cannot take it...
	jmp	work14w	; say sentence and go around object found code
work14b:			
	lda	objectw	; get index to the object from user input
	cpi	5	; is the action word bird?
	jz	work14e	; branch for restrictions on bird
	cpi	18	; is the action word rug?
	jz	work14k	; branch for restrictions on rug
work14z:			
	lhld	work14r	; get address to current room # of object
	mvi	m,126	; set object location to user
	jmp	work14j	; say ok and exit
work14d:			
	lda	myroom	; where is the player?
	cpi	123	; in Repository?
	jc	work14l	; branch if not in room 123 or 124
	mvi	a,126	; Player gets Repository Rod
	sta	Inlist+12	; update rod location
	jmp	work14j	; say ok and move on
work14l:			
	lda	objectw	; get index to the object from user input again
	jmp	work14t	; Not in repository, get rod according to standard rules 	
work14m:
	lda	myroom	; get current room
	cpi	70	; in barren room?
	jnz	work14qq
	lda	Bears	; get bear state
	cpi	3	; unlocked?
	jz	work14q	; initial bear pickup, just do it
	cpi	4	; already picked up and dropped?
	jz	work14q	; just do it again
	lxi	h,sent483	; the bear is locked to the wall!
	jmp	work14w	; play sentence and go around other object code
work14qq:
	lda	inlist+42; where is the bear?
	mov	b,a	; setup for room check
	lda	myroom	; where is the player?
	cmp	b	; in the same room?
	jnz	work14a	; wrong room
work14q:
	mvi	a,4	; bear events17 state 4
	sta	Bears	; update event for bear in room
	mvi	a,1	; bear events come back, enable events17
	sta	Bear+1	; enable event for bear in room
	mvi	a,126	; bear with player
	sta	inlist+42; bear goes with player
	jmp	work14c	; go around other code
work14x:
	lda	myroom	; where is the player?
	cpi	70	; in Barren Room?
	jnz	work14a	; wrong room
	lda	Bears	; bear unlocked?
	cpi	2	; 0 or 1, cannot unlock yet
	jnc	work14y	; branch if player can get past bear
	lxi	h,sent484; cannot get past unfed bear
	jmp	work14w	; play sentence and go around other object code
work14y:
	mvi	a,126	; player is 126
	sta	inlist+26; chain goes with player
	jmp	work14c	; go around other code
work14k:			
	lda	dragon+1	; dragon status
	cpi	0	; dragon in the way?
	jz	work14z	; branch if dragon out of the way
	lxi	h,sent421	; dangerous dragon on the rug
work14w:
	shld	mysent1	; save address of sentence for this situation
	call	DoSentence	; put it out there
	jmp	work14c	; go around other object code
work14n:			
	lxi	h,inlist+28	; point to magazine object
	lda	myroom	; get current room number
	cmp	m	; is the magazine in players current room?
	jnz	work14o	; branch if tangible magazines are not here
	mvi	m,126	; set item location to player
	jmp	work14j	; ack the pickup
work14o:			
	mvi	c,12	; 12 magic magazines to scan for pickup
	lxi	h,Mag1	; point to magazine events list
work14p:			
	lda	myroom	; get current room number
	cmp	m	; magazine already in a room?
	jnz	work14s	; branch if not
	mvi	m,126	; remove magic magazine from current room
	jmp	work14j	; dropped mag, all done
work14s:			
	inx	h	; bump to activity byte of this entry
	inx	h	; bump to ls byte of routine address
	inx	h	; bump to ms byte of routine address
	inx	h	; bump to next magazine room location
	dcr	c	; bump counter
	jnz	work14p	; loop until all are examined
	jmp	work14a	; not found, I cannot take...
;
work14e:			
	lda	Inlist+12	; look at rod location
	cpi	126	; player holding rod?
	jnz	work14f	; branch if we do not have rod
	lxi	h,sent307	; bird afraid
	jmp	work14w	; say sentence and go around other code 
work14f:			
	lda	Inlist+8	; look at cage location
	cpi	126	; player holding cage?
	jz	work14z	; branch if we have cage
	lxi	h,sent306	; no cage for bird
	jmp	work14w	; say sentence and go around other code 
work14g:			
	lda	inlist+10	; get current bird location
	sta	work14u	; save current bird location
	mvi	c,28	; 28 objects to scan
	lxi	h,inlist	; point to base of object room locations
	lda	myroom	; get current room number
work14h:			
	cmp	m	; is the object in players current room?
	jnz	work14i	; branch if not
	mvi	m,126	; set item location to player
work14i:			
	inx	h	; bump to byte2 of this entry
	inx	h	; bump to next item
	dcr	c	; bump counter
	jnz	work14h	; loop until all are examined
;
; if there is a dragon, rug is not taken
;
	lda	dragon+1	; dragon status
	cpi	0	; dragon in the way?
	jz	work14v	; branch if dragon out of the way
	lda	inlist+36	; rug location
	cpi	126	; rug now with player?
	jnz	work14v	; branch if no rug
	lda	myroom	; get current room
	sta	inlist+36	; dragon still around, put rug back
;
; if there is a rod and a bird, the bird doesn't get taken
;
work14v:			
	lda	inlist+12	; rod location
	cpi	126	; now with the player?
	jnz	work14j	; rod not here, bird ok to take
	lda	inlist+10	; bird location
	cpi	126	; bird with player?
	jnz	work14j	; not here, no bird issue
	lda	work14u	; where was bird before?
	cpi	126	; already with the player?
	jz	work14j	; don't drop bird already acquired
	lda	myroom	; get current room
	sta	inlist+10	; put the bird back, bird take fails
work14j:			
	lxi	d,wordok	; point to string
	mvi	c,9	; print string
	call	bdos	; job for dos
work14c:			
	ret		
;
work14r:dw	0	; temp storage for table pointer in work14
work14u:db	0	; temp storage for bird and rod test
;
; drop something
;
work15:			
	lda	Objectf	; object found flag
	cpi	0	; 1=valid object found
	jz	work15a	; cannot drop invalid object
	lxi	h,inlist; point to base of object room locations
	lda	objectw	; get index to the object from user input
	cpi	40	; player wants to drop lantern?
	jnz	work15zz; branch if not a lamp issue
	mvi	a,1	; lantern = lamp
	sta	objectw	; now a lamp
work15zz:
	cpi	31	; drop all objects?
	jz	work15g	; drop everything
	cpi	3	; drop dry bottle?
	jz	work15u	; handle bottles with and without water
	cpi	8	; drop wet bottle?
	jz	work15u	; handle bottles with and without water
	cpi	14	; drop magic magazine?
	jz	work15m	; branch to handle magazine
	cpi	12	; drop coins?
	jnz	work15v	; branch if not coins
	lda	myroom	; where is the player?
	cpi	34	; in room with vending machine?
	jnz	work15v	; branch if just dropping coins elsewhere
	lda	inlist+24	; where are the coins?
	cpi	126	; with player?
	jnz	work15a	; branch if no coins
	mvi	a,0ffh	; new batteries
	sta	Battery	; update it
	mvi	a,130	; coins go away
	sta	Inlist+24	; update coins location
	call	sentcr	; print cr lf
	mvi	c,9	; print string
	lxi	h,sent423	; vending machine batteries...
	shld	mysent1	; set sentence to say
	call	DoSentence	;say it
	jmp	work15k	; go around other outcomes
work15u:			
	lda	Inlist+6	; empty bottle
	cpi	126	; player has bottle?
	jnz	work15w	; branch if no empty bottle to drop
work15p:			
	lda	myroom	; get current room
	sta	Inlist+6; drop the empty bottle
	jmp	work15y	; go around other outcomes
work15w:			
	lda	Inlist+16	; wet bottle
	cpi	126	; player has bottle?
	jnz	work15a	; branch if no bottle to drop
work15x:			
	mvi	a,130	; wet bottles drain when dropped
	sta	Inlist+16	; drop the wet bottle
	lxi	h,sent457	; dropped bottle with water drains dry
	shld	mysent1	; set sentence to say
	call	DoSentence	;say it
	jmp	work15p	; drop the bottle dry
work15v:			
	lda	objectw	; get index to the object from user input
	add	a	; convert to 16 bit offset
	mvi	d,0	; small offset
	mov	e,a	; ls byte of offset in e
	dad	d	; set pointer to memory with hl
	mov	a,m	; get current room # of object
	cpi	126	; is the object with the player or elsewhere?
	jz	work15b	; branch if something we can drop
work15a:			
	call	sentcr	; print cr lf
	lxi	h,sent299	; Cannot drop something you do not have...
	lda	actionw	; get action word that sent us here
	cpi	45	; is this a throw?
	jnz	work15j	; branch if drop, not throw
	lxi	h,sent456	; Cannot throw something you do not have...
work15j:			
	shld	mysent1	; set sentence to say
	call	DoSentence	;say it
	jmp	work15f	; go around drop object code
work15b:			
	lda	myroom	; get players current location
	mov	m,a	; update the record for this object
	lxi	d,wordok; point to string
	mvi	c,9	; print string
	call	bdos	; job for dos
	lda	objectw	; what are we dropping?
	cpi	5	; bird?
	jnz	work15c	; branch if not bird
	lda	myroom	; get players current location
	sta	Inlist+8; drop cage with bird
	jmp	work15f	; go around other bird cage case
work15g:			
	lda	Inlist+34	; get vase current location
	sta	VasePlace	; if the player is holding it, remember
	mvi	c,28	; 28 objects to scan
work15h:			
	mvi	a,126	; player holding item
	cmp	m	; player holding this item?
	jnz	work15i	; branch if not
	lda	myroom	; get current room
	mov	m,a	; set item location to current room
work15i:			
	inx	h	; bump to byte2 of this entry
	inx	h	; bump to next item
	dcr	c	; bump counter
	jnz	work15h	; loop until all are examined
;
;special pillow case for vase
;
	lda	VasePlace	; vase location before work15h code
	cpi	126	; was player holding the vase?
	jnz	work15y	; branch around vase destruction if not here
	lda	myroom	; get current room
	mov	c,a	; setup for compare
	lda	Inlist+20	; get pillow current location
	cmp	c	; if same, ok to drop anything including vase
	jz	work15y	; go around vase location test
	lda	Inlist+34	; get vase current location
	cmp	c	; have vase just been dropped?
	jnz	work15y	; branch around vase destruction if not here
	call	vasegone	; vase is smashed
work15y:			
	lxi	d,wordok; point to string
	mvi	c,9	; print string
	call	bdos	; job for dos
	jmp	work15k	; exit
work15c:			
	cpi	4	; cage?
	jnz	work15d	; branch if not cage
	lda	Inlist+10	; get current bird location?
	cpi	126	; player holding bird?
	jnz	work15f	; branch if we don't have bird
	lda	myroom	; get players current location
	sta	Inlist+10	; update bird location, drop with cage
work15d:			
	cpi	17	; vase?  pillow=10
	jnz	work15e	; branch if not vase
	lda	Inlist+20	; current pillow location
	mov	b,a	; set aside for compare
	lda	myroom	; get players current location
	cmp	b	; are we dropping the vase on a pillow?
	jz	work15f	; player beats the peril, branch
	call	vasegone	; vase is smashed
	jmp	work15k	; go around other code
work15e:			
	cpi	21	; bear?
	jnz	work15f	; branch if not bear
	lda	myroom	; get players current location
	sta	inlist+42; put bear in current room
	mvi	a,0	; disable bear events in events17
	sta	Bear+1	; disable event for bear in room
	lxi	d,wordok; point to string
	mvi	c,9	; print string
	call	bdos	; job for dos
	jmp	work15z	; all done with drop bear
work15f:			
	lxi	h,myroom; player throwing at the troll chasm?
	mvi	a,63	; troll crossing is rooms 64 and 65
	cmp	m	; is this treasure in room higher than 63?
	jnc	work15k	; branch if not
	mvi	a,65	;
	cmp	m	; is this treasure in room higher than 65?
	jc	work15k	; branch if treasure is not in 64 or 65
	lda	myroom	; get current room
	cpi	65	; player crossing chasm for second time?
	jnz	work15l	; branch if not the second crossing
	mvi	a,64	; future crossing unlimited
	sta	m_ne	; update permitted moves
	mvi	a,65	; future returns unlimited
	sta	m_sw	; update permitted moves
work15l:			
	jmp	Puzz7	; throw held objects to troll
;
;enable 1-12 magazine events for the current room
;if all 12 magazines have been dropped, 'nothing happens', then magazine goes to well house
;
work15m:			
	lda	inlist+28	; magazine location
	cpi	126	; player has magazine?
	jnz	work15o	; branch if no magazine
;
;after cave is closed, dropping a magazine in Witt's end sends player to room 123
;
	lda	Closed	; is the cave closed?
	cpi	1	; 1=closed
	jnz	work15n	; branch if not closed
	lda	myroom	; where is player?
	cpi	59	; in Witt's end?
	jnz	work15n	; branch if somewhere else
	lda	Lamp1+1	; is the lamp on?
	cpi	1	; 1=lamp off
	jnz	work15n	; only proceed if lamp is off and magazine down
;
; commence with end game
;
work15t:			
	call	sentcr	; print cr lf
	lxi	h,Sent470	; cave is closed for end game
	shld	mysent1	; set sentence
	call	DoSentence	; play it
	mvi	a,1	; room #1
	sta	inlist	; take away keys for end game
	mvi	a,123	; end game ne repository
	sta	myroom	; move the player
	mvi	a,1	; put a magazine in the well house for scoring
	sta	inlist+28; magazine location
	mvi	a,5	; add 5 points to score for entry
	sta	pscorea	; post credit
	jmp	work15z	; all done with drop
work15n:			
	mvi	c,12	; 12 magazines to scan
	lxi	h,Mag1	; point to magazine events list
work15r:			
	mvi	a,126	; undropped magazine is set for 126
	cmp	m	; magazine already in a room?
	jnz	work15s	; branch if not
	lda	myroom	; get current room
	mov	m,a	; set item location to current room
	jmp	work15k	; dropped mag, all done
work15s:			
	inx	h	; bump to activity byte of this entry
	inx	h	; bump to ls byte of routine address
	inx	h	; bump to ms byte of routine address
	inx	h	; bump to next magazine room location
	dcr	c	; bump counter
	jnz	work15r	; loop until all are examined
	mvi	a,58	; send magazine back to anteroom when all 12 are dropped
	sta	inlist+28	; magazine location
	lxi	h,sent300	; nothing happens
	shld	mysent1	; set sentence to say
	call	DoSentence	;say it
	jmp	work15k	; go around other outcome
work15o:			
	call	sentcr	; print cr lf
	mvi	c,9	; print string
	lxi	d,work15q	; no magazine
	call	bdos	; job for dos
	call	sentcr	; print cr lf
work15k:			
	lda	myroom	; get current room
	lxi	h,Inlist+16	; look at bottle location
	cmp	m	; bottle on floor with water?
	jz	work15x	; branch to fix bottles	
work15z:			
	ret		
;
work15q	db	'Go get a magazine first.$'	
;
vasegone:			
	mvi	a,130	; room 130 is where lost items go
	sta	Inlist+34	; vase is now lost
	call	sentcr	; print cr lf
	lxi	h,sent373	; vase is smashed
	shld	mysent1	; set sentence to say
	call	DoSentence	;say it
	call	sentcr	; print cr lf
	lxi	h,sent374	; vase disappears
	shld	mysent1	; set sentence to say
	call	DoSentence	;say it
	ret		
;
VasePlace	db	0	
;
; show inventory
;
work16:			
	mvi	a,0	; 28 objects that can be moved
	sta	Myinven1; save for loop references
	sta	Myinven2; set flag for no objects with user
	mvi	c,28	; 28 objects to scan
	lxi	h,inlist; point to base of object room locations
work16a:			
	mov	a,m	; get room flag
	cpi	126	; are we holding this item?
	jnz	work16b	; branch if not
	mvi	a,1	; flag set
	sta	Myinven2; remember that we found something
work16b:			
	inx	h	; bump to byte2 of this entry
	inx	h	; bump to next item
	dcr	c	; bump counter
	jnz	work16a	; loop until all are examined
	call	sentcr	; print cr lf
	call	sentcr	; print cr lf
	lda	Myinven2; get flag for object carried
	cpi	0	; player has nothing?
	jnz	work16c	; go around no inventory sentence
	lxi	h,sent256; not carrying anything
	jmp	work16d	; go around other code
work16c:			
	lxi	h,sent255; you are carrying the following
work16d:			
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
work16e:			
	lxi	h,inlist; point to base of object room locations
	lda	Myinven1; get pointer
	add	a	; convert to offset
	mov	e,a	; setup for pointer calculation
	mvi	d,0	; small offsets, please
	dad	d	; 
	mov	a,m	; get object location
	cpi	126	; is the player carrying this object?
	jnz	work16f	; branch if this object is somewhere else
	lda	Myinven1	; get pointer
	lxi	h,S_Index4	; point to base of object descriptions list
	call	GetAdd	; get pointer
	shld	mysent1	; save address of sentence for this room
	call	DoSentence	; show inventory item description
work16f:			
	lda	Myinven1; get object counter
	cpi	27	; have we scanned to the last one?
	jz	work16g	; branch if all done
	inr	a	; bump counter
	sta	Myinven1; save for later
	jmp	work16e	; loop for next object 
work16g:			
	ret		
;
;look show full description for current room
;
work17:			
	lxi	h,roomb	; point to table of fifteen room visit record bytes, eight rooms each
	lda	myroom	; get current room number
	cpi	11	; are we underground?
	jc	work17a	; branch if we do not need light
	lda	Inlist+2	; look at lamp location
	cpi	126	; player holding lamp?
	jnz	work17c	; branch if we do not have lamp
	lda	Lamp1+1	; is the lamp on?
	cpi	1	; 1=lamp off
	jz	work17c	; can't look without light
	lda	myroom	; get current room number again
work17a:			
	cpi	8	; a<8?
	jc	work17b	; branch if less than 8
	sui	8	; adjust to next byte
	inx	h	; bump pointer to next byte
	jmp	work17a	; loop until we index to correct byte
work17b:			
	cpi	0	; our visit info is on bit 0?
	jnz	work17d	; branch if some other bit
	mvi	a,1	; mask bit to be positioned
	jmp	work17f	; go around bit rotate code
work17c:			
	call	sentcr	; print cr lf
	lxi	h,sent375	; no source of light
	shld	mysent1	; set sentence to say
	call	DoSentence	;say it
	jmp	work17g	; go around other action
work17d:			
	mov	c,a	; remainder becomes the counter
	mvi	a,1	; bit mask to rotate
work17e			
	ral		; rotate mask
	dcr	c	; bump counter
	jnz	work17e	; loop until positioned on our bit	
work17f:			
	mov	c,a	; save bit mask in c
	mov	a,m	; get selected byte with visit bits
	xra	c	; reset this room bit for the visit
	mov	m,a	; update the visit byte	
work17g:			
	ret		; go play the full message
;
Myinven1	db	0	; counter used to scan object lists
Myinven2	db	0	; flag used for empty handed players
;
; help  offer some help
;
work18:			
	lxi	h,sent348	; I know of...
	shld	mysent1		; set sentence to say
	call	DoSentence	; say it
	lxi	h,sent487	; For mistakes...
	shld	mysent1		; set sentence to say
	call	DoSentence	; say it
	ret		
;
; building move to building if not lost in forest
;
work19:			
	lda	myroom	; where are we now?
	cpi	4	; are lost in the forest?
	jz	work19a	; magic does not work when lost
	cpi	9	; are we underground?
	jnc	work19a	; no magic from underground
	mvi	a,1	; go to building
	sta	myroom	; update room location
	jmp	work19b	; go around do nothing code
work19a:			
	lxi	h,sent300	; Nothing happens
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
work19b:			
	ret		
;
; forest move from anywhere above ground to forest
; autorun through the cave triggered by forest 27 door 37
;
work20:			
	lda	myroom	; where are we now?
	cpi	9	; are we underground?
	jnc	work20b	; no magic from underground
	lda	objectw	; get objectw
	cpi	37	; is this an autorun start?
	jnz	work20a	; branch if not autorun
	mvi	a,1	; room one
	sta	myroom	; start from a known place
	sta	automove	; start moving automatically
	lxi	h,mpoint	; reset pointer to move table
	shld	apoint	; set current auto move pointer address
	jmp	work20c	; go around do nothing code
work20a:			
	mvi	a,4	; go to forest
	sta	myroom	; update room location
	jmp	work20c	; go around do nothing code
work20b:			
	lxi	h,sent300	; Nothing happens
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
work20c:			
	ret		
;
; enter building
;
work21:			
	lda	myroom	; where are we now?
	cpi	0	; are we in front of building?
	jnz	work20b	; if not, nothing happens
	mvi	a,1	; room inside building
	sta	myroom	; update room location
	ret		
;
; exit building
;
work22:			
	lda	myroom	; where are we now?
	cpi	1	; are we inside building?
	jnz	work20b	; if not, nothing happens
	mvi	a,0	; room inside building
	sta	myroom	; update room location
	ret		
;
; goto grate
;
work23:			
	lda	myroom	; where are we now?
	cpi	8	; on the surface?
	jnc	work20b	; if not, nothing happens
	mvi	a,8	; go downstream to grate
	sta	myroom	; update room location
	ret		
;
; go to debris room with magic
;
work24:			
	lda	myroom	; where are we now?
	cpi	1	; in the building?
	jnz	work24a	; pass on this magic
	mvi	a,11	; teleport into cave
	jmp	work24b	; go around other code
work24a:			
	cpi	11	; in the cave at debris room?
	jnz	work20b	; if not, nothing happens
	mvi	a,1	; back to building
work24b:			
	sta	myroom	; update room location
	ret		
;
; go to Y2 room with magic
;
work25:			
	lda	myroom	; where are we now?
	cpi	1	; in the building?
	jnz	work25a	; pass on this magic
	mvi	a,36	; teleport into cave
	jmp	work25b	; go around other code
work25a:			
	cpi	36	; in the cave at Y2?
	jnz	work20b	; if not, nothing happens
	mvi	a,1	; back to building
work25b:			
	sta	myroom	; update room location
	ret		
;
; unlock grate, chain or bear
;
; in room 124 with locked grate?, if so branch to say you have no keys
; in room 8 above grate?, if not branch to say see no grate
;
work26:			
	lda	objectw	; get object named by user
	cpi	28	; grate?
	jz	work26a	; branch if unlocking grate
	cpi	13	; chain?
	jz	work26c	; branch if unlocking chain for bear
	cpi	21	; bear?
	jz	work26c	; branch if unlocking bear
	lda	myroom	; where are we now?
	cpi	10	; beyond the grate and not under the grate?
	jnc	work29d	; branch if nothing happens
	lxi	h,sent425	; I think you want to unlock grate
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	jmp	work26g	; nothing more to do
work26a:			
	lda	myroom	; where are we now?
	cpi	8	; above the grate?
	jz	work26b	; branch if above the grate
	cpi	9	; just below the grate?
	jz	work26b	; branch if just below the grate
	cpi	124	; in the Repository?
	jz	work26b	; branch if in Repository
	call	sentcr	; print cr lf
	lxi	h,sent477	; I see no grate here
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	jmp	work26g	; nothing more to do
work26b:			
	lda	inlist	; where are the keys?
	cpi	126	; with player?  Lost when entering Repository
	jnz	work26e	; no keys, no unlocking anything
	mvi	a,0	; set locked message inactive
	sta	Elist+1	; remember this
	mvi	a,1	; set unlocked message active
	sta	Elist+5	; remember this
	mvi	a,8	; room 8 now has a down
	sta	m_down	; patch move table to permit passage down
	mvi	a,9	; room 9 now has an up
	sta	m_up+2	; patch move table to permit passage up
	mvi	a,10	; 10 points
	sta	pscore0	; post credit
	call	sentcr	; print cr lf
	lxi	d,wordok	; point to string
	mvi	c,9	; print string
	call	bdos	; job for dos
	jmp	work26g	; go around unlock bear code
work26c:			
	call	sentcr	; print cr lf
	lda	myroom	; where are we now?
	cpi	70	; in barren room?
	jnz	work26d	; branch in not in barren room
	lda	bears	; get bear state
	cpi	3	; c=1 if locked
	jnc	work26d	; branch if already unlocked
	lda	inlist	; where are the keys?
	cpi	126	; with player?
	jnz	work26e	; no keys, no unlocking anything
work26f:
	lda	bears	; get the bear state
	cpi	2	; fed bear?
	jc	work26h	; branch if not yet fed
	mvi	a,3	; bear state 3 for events17
	sta	bears	; show bear freed
	mvi	a,70	; barren room with gold chain
	sta	inlist+26; chain available for manual pickup
;	sta	inlist+42; bear available for take/get
	mvi	a,10	; 10 points
	sta	pscore3	; post credit for bear puzzle
	lxi	h,sent378	; chain unlocks, bear is free
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	jmp	work26g	; nothing more to do
work26d:			
	lxi	h,sent478; I see nothing to unlock here
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	jmp	work26g	; nothing more to do
work26e:			
	lxi	h,sent353; You have no keys
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	jmp	work26g	; nothing more to do
work26h:
	lxi	h,sent484; cannot get past angry bear
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	jmp	work26g	; nothing more to do
work26g:			
	ret		
;
; lock grate
;
work27:			
	lda	myroom	; where are we now?
	cpi	8	; at the grate?
	jnz	work20b	; pass on this magic	ret
	lda	Elist+1	; get activity flag for grate
	cpi	0	; is it unlocked?
	jnz	work20b	; branch if not
	mvi	a,1	; set locked message active
	sta	Elist+1	; remember this
	mvi	a,0	; set unlocked message inactive
	sta	Elist+5	; remember this
	mvi	a,126	; room 8 no longer has a down
	sta	m_down	; patch move table to block passage down
	sta	m_up+2	; patch move table to block passage up
	ret		
;
; score
;
work28:			
	mvi	a,30h	; ascii zero score reset
	sta	work28h	; save it
	sta	work28h+1	; save it
	sta	work28h+2	; save it
	call	trcount	; start the scoring with a treasure count in reg de
	lxi	h,roomb	; point to table of sixteen room visit record bytes, eight rooms each
	mvi	b,16	; byte counter
work28a:			
	mvi	c,8	; byte shift counter
	mov	a,m	; get a byte
work28b:			
	ral		; shift a bit into carry bit
	jnc	work28c	; branch if bit not set	
	inx	d	; tally a point
work28c:			
	dcr	c	; bump bit shift counter
	jnz	work28b	; get all 8 bits checked
	inx	h	; bump to next byte
	dcr	b	; bump byte counter
	jnz	work28a	; loop for all bits and bytes
	mvi	c,11	; ten puzzles plus the repository
	lxi	h,pscore0	; table of puzzle scores
	mvi	a,0	; start with zero
work28p:			
	add	m	; get individual puzzle score
	inx	h	; bump pointer
	dcr	c	; bump counter
	jnz	work28p	; loop to complete puzzle tally
	mov	l,a	; setup for add to other scores
	mvi	h,0	; small addition
	dad	d	; add puzzles to rooms and treasures
	push	h	; save the tally
	call	sentcr	; print cr lf
	mvi	c,9	; print string
	lxi	d,work28g	; score report
	call	bdos	; job for dos
	pop	h	; get raw tally back
	shld	work28i	; save binary count for messages	
	xchg		; count in de now
	mov	a,d	; get ms byte
	cpi	0	; score of LT 255?
	jz	work28d	; branch if score is LT 256
	mvi	a,'2'	; ascii 2
	sta	work28h	; save it
	mvi	a,'5'	; ascii 5
	sta	work28h+1	; save it
	mvi	a,'6'	; ascii 6
	sta	work28h+2	; save it
work28d:			
	mov	a,e	; get ls byte
	cpi	0	; count exhausted?
	jz	work28f	; branch if done
	lda	work28h+2	; get units digit
	inr	a	; bump it
	sta	work28h+2	; update
	cpi	3ah	; increment past 9?
	jc	work28e	; branch if in range
	mvi	a,'0'	; ascii zero
	sta	work28h+2	; roll over units digit
	lda	work28h+1	; get tens digit
	inr	a	; bump it
	sta	work28h+1	; update
	cpi	3ah	; increment past 9?
	jc	work28e	; branch if still in range
	mvi	a,'0'	; ascii zero
	sta	work28h+1	; roll over 10s digit
	lda	work28h	; get hundreds digit
	inr	a	; bump it
	sta	work28h	; update
work28e:			
	dcr	e	; reduce ls byte by one
	jmp	work28d	; loop until done
work28f:			
	lxi	d,work28h	; score value in ascii
	lda	work28h	; get hundreds digit
	cpi	'0'	; leading zero?
	jnz	work28m	; branch if significant digit
	lxi	d,work28h+1	; don't show leading zero
	lda	work28h+1	; get tens digit
	cpi	'0'	; two leading zeros?
	jnz	work28m	; branch if significant digit
	lxi	d,work28h+2	; don't show leading zero
work28m:			
	mvi	c,9	; print string
	call	bdos	; job for dos
	lxi	d,turns	; turns value in ascii
	lda	turns	; get hundreds digit
	cpi	'0'	; leading zero?
	jnz	work28r	; branch if significant digit
	lxi	d,turns+1	; don't show leading zero
	lda	turns+1	; get tens digit
	cpi	'0'	; two leading zeros?
	jnz	work28r	; branch if significant digit
	lxi	d,turns+2	; don't show leading zero
work28r:
	mvi	c,9	; print string
	call	bdos	; job for dos
	lda	work2b	; get score assessement flag
	cpi	1	; need an assessment at quitting time?
	jnz	work28t	; bypass assessment in mid game.
	call	sentcr	; print cr lf
;
; 16 bit binary score stored at work28i, issue assessment 0-7 in reg a based on the value
; minimum scores for each level   350,340,270,200,130,75,25,0
;
	mvi	c,7	; start with highest rating
	lxi	h,ratehi	; base of high rating table
	lda	work28i+1	; get ms byte of score
	cpi	1	; is the score above 256?
	jz	work28u	; branch if score range below 256
	mvi	c,4	; start with highest rating below 256
	lxi	h,ratelo	; base of low rating table
work28u:			
	lda	work28i	; get ls byte of score
	cmp	m	; c=1 if score<rank
	jnc	work28v	; branch if rank achieved
	inx	h	; bump table pointer
	dcr	c	; lower rating value
	jnz	work28u	; loop until rating level found
work28v:			
	mov	a,c	; count becomes rating, scale of 0-7, 7 highest
	push	psw	; save rating
	lxi	h,scotab	; rank table base
	call	GetAdd	; get string address from table
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	pop	psw	; get rating back
	lxi	h,rantab	; next rank table base
	call	GetAdd	; get string address from table
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
work28t:			
	call	sentcr	; print cr lf
	ret		
;
; treasure counter, return total in de
;
trcount:			
	lxi	d,0	; point accumulator
	mvi	c,16	; 16 treasures to scan for points
	lxi	h,inlist+24	; point to base of treasure room locations
trcnt1:			
	mov	a,m	; get room flag
	cpi	1	; is this item back in the well house?
	jnz	trcnt2	; branch if not
	push	h	; save mem pointer
	xchg		; score moves to hl 
	lxi	d,8	; accumulate 8 points for each treasure
	dad	d	; add to total
	xchg		
	pop	h	; put pointer back in hl, score in de
trcnt2:			
	inx	h	; bump to byte2 of this entry
	inx	h	; bump to next item
	dcr	c	; bump counter
	jnz	trcnt1	; loop until all are examined for points
	ret		
;
work28g	db	'The current score is $'	
work28h	db	'000 points after $'	
work28i	dw	0	; binary score for rank messages
pscore0	db	0	; grate unlocked
pscore1	db	0	; crystalline bridge
pscore2	db	0	; snake gone
pscore3	db	0	; bear freed
pscore4	db	0	; dragon moved
pscore5	db	0	; plugh used for gold
pscore6	db	0	; beanstalk grown
pscore7	db	0	; rusty door open
pscore8	db	0	; shell opened
pscore9	db	0	; eggs retrieved
pscorea	db	0	; player entered Repository
turns	db	'000 turns.$'	
ratehi	db	350-256,340-256,270-256	
ratelo	db	200,130,75,25,0	
scotab	dw	sent389,sent390,sent391,sent392,sent393,sent394,sent395,sent396	
rantab	dw	sent464,sent463,sent462,sent461,sent460,sent459,sent458,sent397
;
;
; wave rod
;
work29:			
	lda	Objectw	; get object word
	cpi	6	; rod?
	jnz	work29e	; player waving something else
	lda	Inlist+12	; look at rod location
	cpi	126	; player holding rod?
	jnz	work29c	; branch if we do not have rod
	lda	myroom	; where are we now?
	cpi	18	; beyond chasm?
	jnc	work29d	; pass on this magic
	cpi	16	; not yet next to chasm?
	jc	work29d	; pass on this magic
	lda	Bridge1+1	; get bridge status
	cpi	1	; bridge visible?
	jnz	work29b	; branch if not visible
	mvi	a,0	; get rid of bridge
	sta	Bridge1+1	; from west side
	sta	Bridge2+1	; and east side
	mvi	a,126	; block western travel
	sta	m_west+2	; update west travel permissions
	mvi	a,126	; block eastern travel
	sta	m_east	; update east travel permissions
	lxi	h,sent399	; the bridge is gone
	jmp	work29f	; tell player
work29b:			
	mvi	a,1	; bridge appears
	sta	Bridge1+1	; from west side
	sta	Bridge2+1	; and east side
	mvi	a,16	; permit western travel
	sta	m_west+2	; update west travel permissions
	mvi	a,17	; permit eastern travel
	sta	m_east	; update east travel permissions
	mvi	a,10	; 10 points
	sta	pscore1	; post credit
	jmp	work29g	; go around other code
work29c:			
	lxi	h,sent398	; need a rod to wave one
	jmp	work29f	; tell player
work29d:			
	lxi	h,sent300	; Nothing happens
	jmp	work29f	; go around other code
work29e:			
	lxi	h,sent400	; wave what?
work29f:
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
work29g:			
	ret		
;
; open  cage, door, shell
;
work30:			
	lda	Objectw	; get object word
	cpi	4	; cage?
	jnz	work30e	; branch for something else
	lda	Inlist+8; look at cage location
	cpi	126	; player holding cage?
	jnz	work30b	; branch if we do not have cage
	lda	Inlist+10; look at bird location
	cpi	126	; player holding bird?
	jnz	work30a	; branch if we do not have bird
	lda	myroom	; where are we now?
	cpi	40	; with the snake?
	jnz	work30c	; check for bird and dragon
	jmp	work31a	; releasing bird in front of snake
work30a:			
	lxi	h,sent300; Nothing happens
	jmp	work30m	; go around other code
work30b:			
	lxi	h,sent401; need a cage to open one
	jmp	work30m	; go around other action
work30c:			
	cpi	46	; with the dragon?
	jnz	work30d ; branch if not with dragon
	mvi	a,130	; bird goes away
	sta	inlist+10; reset bird location
	lxi	h,sent479; the bird is burned by dragon
	jmp	work30m	; go around other action
work30d:
	mvi	a,13	; room with bird nest
	sta	inlist+10; reset bird location
	lxi	h,sent403; the bird returns to nest
	jmp	work30m	; go around other action
work30e:			
	lda	Objectw	; get object word
	cpi	30	; shell?
	jnz	work30g	; branch for something else
	lda	Inlist+46; look at trident location
	cpi	126	; player holding trident?
	jnz	work30f	; branch if we do not have trident
	lda	myroom	; where are we now?
	cpi	54	; with the shell?
	jnz	work30g	; branch if player not in right room
	lda	inlist+30; is the pearl still there?
	cpi	130	; held in room 130 until found the first time
	jnz	work30h	; branch if already gone
	mvi	a,57	; pearl rolls to cul-de-sac
	sta	inlist+30; pearl ready for pickup in another room
	mvi	a,10	; 10 points
	sta	pscore8	; post credit
	lxi	h,sent406; the pearl rolls away
	jmp	work30m	; go around other action
work30f:			
	lxi	h,sent263; no trident to open clam shell
	jmp	work30m	; go around other action
work30g:			
	lda	Objectw	; get object word
	cpi	37	; door?
	jnz	work30j	; branch for something else
	lda	myroom	; where are we now?
	cpi	96	; in front of the rusty door?
	jnz	work30j	; branch if no door here
	lda	Inlist+22; look at oil location
	cpi	126	; player holding oil?
	jz	work30k	; branch if player has oil
	call	sentcr	; print crlf
	call	sentcr	; print crlf
	lxi	h,sent371	; door rusted shut
	jmp	work30m	; go around other code
work30j:			
	lxi	h,sent405; named object not here to open
	jmp	work30m	; go around other action
work30k:			
	mvi	a,0	; turn off door closed event
	sta	Door1+1	; update event list
	mvi	a,1	; turn on door open event
	sta	Door2+1	; update event list
	mvi	a,96	; door in room 96
	sta	m_north+12; update north to allow passage
	mvi	a,130	; turn off rusty door closed message
	sta	Puzt14	; update puzzle table
	sta	Puzt14a	; update puzzle table
	mvi	a,10	; 10 points
	sta	pscore7	; post credit
	jmp	work30z	; go around other action
work30h:			
	lxi	h,sent407; no pearl in shell
work30m:
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
work30z:			
	ret		
;
; free bird, bear
;
work31:			
	lda	Objectw	; get object word
	cpi	5	; bird?
	jnz	work31e	; branch for something else
	lda	Inlist+10	; look at bird location
	cpi	126	; player holding bird?
	jnz	work31b	; branch if we do not have bird
	lda	myroom	; where are we now?
	cpi	40	; with the snake?
	jnz	work31c	; let bird go to nest
work31a:
	mvi	a,0	; turn off snake warning
	sta	snake+1	; update event table
	mvi	a,13	; room with bird nest
	sta	inlist+10	; reset bird location
	mvi	a,40	; permit passage by dead snake
	sta	m_west+6	; now go west
	sta	m_south+2	; now go south
	sta	m_north	; now go north
	sta	m_sw+4	; now go sw
	mvi	a,10	; 10 points
	sta	pscore2	; post credit
	call	sentcr	; print cr lf
	lxi	h,sent308	; bird kills snake
	jmp	work31m	; go around other code	
work31b:			
	call	sentcr	; print cr lf
	lxi	h,sent402	; no bird here
	jmp	work31m	; go around other action
work31c:			
	mvi	a,13	; room with bird nest
	sta	inlist+10	; reset bird location
	lxi	h,sent411	; no snake, bird goes to nest
	jmp	work31m	; go around other action
work31e:			
	lda	Objectw	; get object word
	cpi	21	; bear?
	jnz	work31h	; branch for something else
	lda	myroom	; where are we now?
	cpi	70	; in the barren room?
	jnz	work31h	; branch if not with bear
	lda	bears	; get the bear state
	cpi	3	; unchained bear?  c=1 if bear is chained
	jnc	work26f ; free the bear if appropriate
	lxi	h,sent300; Nothing happens
	jmp	work31m ; bear already free
work31h:			
	lxi	h,sent413	; free what?
work31m:
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	ret		
;
; lamp on
;
work32:			
	lda	Objectw	; get object word
	cpi	1	; lamp?
	jz	work32d	; branch for lamp
	lda	Objectw	; get object word
	cpi	40	; lantern?
	jnz	work32c	; branch for something else
work32d:
	lda	Inlist+2; look at lamp location
	cpi	126	; player holding lamp?
	jnz	work32b	; branch if we do not have lamp
	mvi	a,0	; turn off darkness warning
	sta	Lamp1+1	; update event table for cobble crawl
	sta	Lamp2+1	; update event table for debris room xyzzy
	sta	Lamp3+1	; update event table for y2
	mvi	a,10	; permit western travel
	sta	m_west	; update west travel permissions
	mvi	a,11	; permit western travel bug fix xyzzy goes to this room
	sta	m_west+22	; update west travel permissions
	mvi	a,36	; permit travel from Y2
	sta	m_west+4	; update west travel permissions
	sta	m_south	; update south travel permissions
	sta	m_east+2	; update east travel permissions
	call	sentcr	; print cr lf
	mvi	c,9	; print string
	lxi	h,sent296	; lamp is now on.
	jmp	work32a	; go around other action code
work32b:			
	lxi	h,sent410	; no lamp
	jmp	work32a	; go around other action code
work32c:			
	call	sentcr	; print cr lf
	lxi	h,sent352	; huh?
work32a:
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	ret		
;
; lamp off
;
work33:			
	lda	Objectw	; get object word
	cpi	1	; lamp?
	jz	work33f	; branch for lamp
	lda	Objectw	; get object word
	cpi	40	; lantern?
	jnz	work33c	; branch for something else
work33f:
	lda	Inlist+2	; look at lamp location
	cpi	126	; player holding lamp?
	jnz	work33b	; branch if we do not have lamp
	mvi	a,1	; turn on darkness warning
	sta	Lamp1+1	; update event table for cobble crawl
	sta	Lamp2+1	; update event table for xyzzy
	sta	Lamp3+1	; update event table for y2
	mvi	a,130	; prohibit western travel
	sta	m_west	; update west travel permissions room 10
	sta	m_west+22	; update west travel permissions room 11
	sta	m_west+4	; update west travel permissions Y2
	sta	m_south	; update south travel permissions Y2
	sta	m_east+2	; update east travel permissions Y2
	call	sentcr	; print cr lf
	mvi	c,9	; print string
	lxi	h,sent297	; lamp is now off.
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
;
; lamp off is part of the end game
;
	lda	Closed	; is the cave closed?
	cpi	1	; 1=closed
	jnz	work33d	; branch if not closed
	lda	myroom	; where is player?
	cpi	59	; in Witt's end?
	jnz	work33d	; branch if somewhere else
	mvi	c,12	; 12 magazines to scan
	lxi	h,Mag1	; point to magazine events list
	mvi	a,59	; is there a magazine on the floor in Witts End?
work33r:			
	cmp	m	; magazine already in a room?
	jz	work15t	; send player to end game if found
	inx	h	; bump pointer
	dcr	c	; bump counter
	jnz	work33r	; loop until done looking
	jmp	work33d	; no mag, no action
;
; need a lamp to turn off
;
work33b:			
	call	sentcr	; print cr lf
	lxi	h,sent410	; no lamp
	jmp	work33e	; go around other action code
work33c:			
	call	sentcr	; print cr lf
	lxi	h,sent352	; huh?
work33e:
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
work33d:			
	ret		
;
; kill snake,dragon,dwarf,(something else)
; handle snake and dragon here, pass control to work35 for everything else
; if in room with active snake, with your bare hands
; if in rooom with active dragon, with your bare hands yes
;
work34:			
	lxi	h,sent352; huh?
	lda	Objectw	; get object word
	cpi	0	; no object?
	jz	work35e	; nothing named, say huh?
	cpi	29	; snake?
	jnz	work34a	; branch if not snake
	lxi	h,sent411; no snake here
	lda	myroom	; where are we now?
	cpi	40	; in the room with the snake?
	jnz	work35e	; branch to say no snake here
	lda	snake+1	; is snake still there?
	cpi	0	; 0=snake gone
	jz	work35e	; branch to say no snake here	
	jmp	work34b	; ask bare hands question in snake room
work34a:
	cpi	33	; dragon?
	jnz	work35	; branch for anything else
	lxi	h,sent420; what dragon?
	lda	myroom	; where are we now?
	cpi	46	; with the dragon?
	jnz	work35e	; branch to say no dragon here
	lda	dragon+1; is dragon still there?
	cpi	0	; 0=dragon gone
	jz	work35e	; branch to say no dragon here	
work34b:			
	call	sentcr	; print cr lf
	lxi	h,sent305	; with bare hands?
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	call	sentcr	; print cr lf
	lda	Objectw	; get object word
	cpi	33	; dragon?
	jnz	work34c	; not dragon, no more to do
	mvi	c,1	; console in
	call	bdos	; job for dos
	cpi	'y'	; y for yes?
	jnz	work34c	; go around other object code
	mvi	c,1	; console in
	call	bdos	; job for dos
	cpi	'e'	; e for yes?
	jnz	work34c	; go around other object code
	mvi	c,1	; console in
	call	bdos	; job for dos
	cpi	's'	; s for yes?
	jnz	work34c	; go around other object code
	mvi	a,0	; dragon dies here
	sta	dragon+1; update event records
	mvi	a,46	; permit moves north and east from dragon room
	sta	m_north+14; change 130 block to valid move from 46
	sta	m_east+14; change 130 block to valid move from 46
	mvi	a,10	; 10 points
	sta	pscore4	; post credit
	call	sentcr	; print cr lf
	lxi	h,sent422; congrats vanquished dragon
	jmp	work35e	; branch to say congrats	
work34c:			
	ret		
;
; attack snake, dragon, dwarf, (anything else), (no object)
;
; attack (no object) - sent302  if not with snake, dragon, dwarf       nothing to attack
; attack (no object) - sent352  with snake, dragon, dwarf              huh
; attack (anything else) - sent352                                     huh
; if with snake, attack snake - sent304  room 40 and snake+1=1         very dangerous
; if not with snake, attack snake - sent411 if room 40 snake+1=0       no snake here
; if with dragon, attack dragon - work34 room 46 and dragon+1=1        same as kill
; if not with dragon, attack dragon - sent420 in work34 dragon+1=0     no dragon here
; if with dwarf, attack dwarf - sent404                                how?
; if not with dwarf, attack dwarf - sent357                            no dwarf here 
; 
;
work35:
	call	sentcr	; print cr lf
	lxi	h,sent352; huh?
	lda	Objectw	; get object word
	cpi	0	; no object?
	jnz	work35a	; branch to say something else
	lda	myroom	; where are we now?
	cpi	40	; with the snake?
	jz	work35e	; say huh in snake room
	cpi	34	; with the dragon?
	jz	work35e	; say huh in dragon room
	mov	b,a	; save room #
	lda	Dwarf0	; get dwarf location
	cmp	b	; is the dwarf here?
	jnz	work35c	; say nothing to attack here
	lda	Dwarf0+1; get dwarf activity flag
	cpi	1	; 1=dwarf around?
	jz	work35e	; say huh in front of dwarf
	jmp	work35c	; say nothing to attack if no dwarf
work35a:
	lda	Objectw	; get object word
	cpi	29	; snake?
	jnz	work35b	; branch to say something else
	lxi	h,sent411; no snake here
	lda	myroom	; where are we now?
	cpi	40	; with the snake?
	jnz	work35e	; branch to say no snake here
	lda	snake+1	; is snake still there?
	cpi	0	; 0=snake gone
	jz	work35e	; branch to say no snake here	
	lxi	h,sent304; snake very dangerous
	jmp	work35e	; say it
work35b:
	cpi	33	; dragon?
	jnz	work35d	; branch to say something else
	lxi	h,sent420; no dragon here
	lda	myroom	; where are we now?
	cpi	46	; with the dragon?
	jnz	work35e	; branch to say no dragon here
	lda	dragon+1; is dragon still there?
	cpi	0	; 0=dragon gone
	jz	work35e	; branch to say no dragon here	
	jmp	work34b	; with bare hands?
work35c:
	lxi	h,sent302; nothing to attack here
	jmp	work35e	; go around other code
work35d:
	cpi	38	; dwarf?
	jnz	work35e	; say huh for something else
	lxi	h,sent357; no dwarf here
	lda	Dwarf0+1; dwarf active?
	cpi	1	; 1=dwarf around
	jnz	work35e	; say no dwarf here
	lda	myroom	; where are we now?
	mov	b,a	; save for dwarf location test
	lda	Dwarf0	; current dwarf room
	cmp	b	; Player with the dwarf?
	jnz	work35e	; branch to say no dwarf here
	lxi	h,sent404; how?
work35e:
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	ret		
;
; plugh please lift up gold here
;
work36:			
	lda	myroom	; where are we now?
	cpi	18	; player in nugget of gold room?
	jnz	work36a	; magic does not work elsewhere
	lda	Inlist+48	; where is the gold?
	cpi	126	; holding gold?
	jnz	work36a	; branch if not
	mvi	a,0	; turn off hollow voice clue
	sta	Plugh+1	; player uses plugh, no need for clues
	mvi	a,10	; 10 points
	sta	pscore5	; post credit
	mvi	a,15	; gold moves north to Hall of Mists
	sta	Inlist+48	; make a record of it
	lxi	h,sent412	; gold went north of here
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	call	sentcr	; print cr lf
	jmp	work36b	; go around do nothing code
work36a:			
	lxi	h,sent300	; Nothing happens
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
work36b:			
	ret		
;
; throw axe, not the same as drop axe, also throw something at troll
;
work37:			
	lda	Objectw	; object number
	cpi	9	; throwing an axe?
	jnz	work37a	; branch if something else
	lda	Inlist+18	; does the player have an axe?
	cpi	126	; 126=player
	jnz	work37a	; branch if no axe to throw for credit
	lda	dwarf0+1	; do we have a dwarf present?
	cpi	0	; 0=no dwarf event right now
	jz	work37a	; just throwing an axe, no dwarf to hit
	call	sentcr	; print cr lf
	lda	ran3	; get random # 1-3
	dcr	a	; convert to 0-2
	lxi	h,work37b	; base of sentence table
	call	GetAdd	; get address of sentence to play
	shld	mysent1	; save address of sentence for this puzzle
	call	DoSentence	; put it out there
	mvi	a,43	; room 43, will be randomized
	sta	Puzt6	; restore dwarf trigger
	mvi	a,0	; clear the attack flags
	sta	Dwarf0+1	; remove dwarf from room
	sta	Dwarf1+1	; disable dwarf attack until next Puzz6 trigger
	lda	ran3	; get random # 1-3
	cpi	3	; did the player get stabbed?
	jnz	work37a	; go around dead player code
	mvi	a,0	; player dead
	sta	imdead	; update record
	mvi	a,1	; note dwarf killed player
	sta	axeflag	; save it
work37a:			
	
	jmp	work15	; throw becomes a drop
;
work37b	dw	Sent312,Sent313,Sent314	
axeflag	db	0	; indicates death by dwarf
;
;phr312 You killed a little dwarf. The body vanishes in a cloud of greasy black smoke.
;phr313 You attack a little dwarf, but he dodges out of the way.
;phr314 You attack a little dwarf, but he dodges out of the way and stabs you with his nasty sharp knife
;
; room  show available passages
;
work38:			
	call	sentcr	; print cr lf
	call	sentcr	; print cr lf
	lda	myroom	; get current room
	mov	b,a	; save for compares
	lxi	h,word6	; north
	shld	work38x	; save for display routine
	lxi	h,m_north	; point to list of directional travels
	call	work38m	; search for room
	jnc	work38a	; branch if no message needed
	call	work38p	; show message
work38a:			
	lda	myroom	; get current room
	mov	b,a	; save for compares
	lxi	h,word7	; south
	shld	work38x	; save for display routine
	lxi	h,m_south	; point to list of directional travels
	call	work38m	; search for room
	jnc	work38b	; branch if no message needed
	call	work38p	; show message
work38b:			
	lda	myroom	; get current room
	mov	b,a	; save for compares
	lxi	h,word5	; east
	shld	work38x	; save for display routine
	lxi	h,m_east	; point to list of directional travels
	call	work38m	; search for room
	jnc	work38c	; branch if no message needed
	call	work38p	; show message
work38c:			
	lda	myroom	; get current room
	mov	b,a	; save for compares
	lxi	h,word4	; west
	shld	work38x	; save for display routine
	lxi	h,m_west	; point to list of directional travels
	call	work38m	; search for room
	jnc	work38d	; branch if no message needed
	call	work38p	; show message
work38d:			
	lda	myroom	; get current room
	mov	b,a	; save for compares
	lxi	h,word12	; up
	shld	work38x	; save for display routine
	lxi	h,m_up	; point to list of directional travels
	call	work38m	; search for room
	jnc	work38e	; branch if no message needed
	call	work38p	; show message
work38e:			
	lda	myroom	; get current room
	mov	b,a	; save for compares
	lxi	h,word13	; down
	shld	work38x	; save for display routine
	lxi	h,m_down	; point to list of directional travels
	call	work38m	; search for room
	jnc	work38f	; branch if no message needed
	call	work38p	; show message
work38f:			
	lda	myroom	; get current room
	mov	b,a	; save for compares
	lxi	h,word9	; nw
	shld	work38x	; save for display routine
	lxi	h,m_nw	; point to list of directional travels
	call	work38m	; search for room
	jnc	work38g	; branch if no message needed
	call	work38p	; show message
work38g:			
	lda	myroom	; get current room
	mov	b,a	; save for compares
	lxi	h,word11	; ne
	shld	work38x	; save for display routine
	lxi	h,m_ne	; point to list of directional travels
	call	work38m	; search for room
	jnc	work38h	; branch if no message needed
	call	work38p	; show message
work38h:			
	lda	myroom	; get current room
	mov	b,a	; save for compares
	lxi	h,word8	; sw
	shld	work38x	; save for display routine
	lxi	h,m_sw	; point to list of directional travels
	call	work38m	; search for room
	jnc	work38i	; branch if no message needed
	call	work38p	; show message
work38i:			
	lda	myroom	; get current room
	mov	b,a	; save for compares
	lxi	h,word10	; se
	shld	work38x	; save for display routine
	lxi	h,m_se	; point to list of directional travels
	call	work38m	; search for room
	jnc	work38j	; branch if no message needed
	call	work38p	; show message
work38j:			
	lxi	h,Puztab	; now search for puzzle passages
work38k:			
	lda	myroom	; get current room
	mov	b,a	; for puzzle location compares
	mov	a,m	; get puzzle room number
	cpi	0ffh	; at end of puzzle list?
	jz	work38q	; branch if done
	cmp	b	; puzzle for current room
	jnz	work38l	; branch if no puzzle here
	inx	h	; look at direction byte
	mov	a,m	; get a copy
	push	h	; preserve pointer into Puztab
	sui	4	; first item is list is word5
	cpi	10	; 10 items for the list, do not display others
	jnc	work38s	; go around display code
	lxi	h,work38z	; base of direction work index
	call	GetAdd	; get address
	xchg		; word address now in reg de
	mvi	c,9	; print string
	call	bdos	; job for dos
	lxi	h,sent466	; puzzle path
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
work38s:			
	pop	h	; get hl pointer into Puztab
	jmp	work38l+1	; bump pointer only 4 times
work38l:			
	inx	h	; bump to Puztab byte 2
	inx	h	; bump to Puztab address byte 1
	inx	h	; bump to Puztab address byte 2
	inx	h	; bump to Puztab next record
	jmp	work38k	; keep searching	
work38q:			
	ret		
;
work38m:			
	mov	a,m	; get room number
	cpi	0ffh	; at end of list?
	jz	work38n	; branch if at end of this list
	mov	a,m	; get room number from table
	cmp	b	; player in that room?
	jz	work38o	; branch if in this room
	inx	h	; bump pointer
	inx	h	; bump pointer
	jmp	work38m	; loop until done
work38n:			
	stc		; set carry
	cmc		; reset carry to indicate room not found
	ret		
work38o:			
	stc		; set carry to indicate room found
	ret		
;
; subroutine for the work38 routines
;
work38p:			
	inx	h	; bump to destination pointer
	mov	a,m	; get destination room number
	lxi	h,S_Index2	; point to table of room sentences
	call	GetAdd	; get address of sentence from the table
	shld	work38y	; save for display routine
	mvi	c,9	; print string
	lhld	work38x	; get address of current direction review
	xchg		; word address in de
	call	bdos	; job for dos
	mvi	c,9	; print string
	lxi	d,wordsp	; print space
	call	bdos	; output it
	lhld	work38y	; get address of current direction review
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
;	call	sentcr	 ; print cr lf
	ret		
;
work38x	dw	0	; address of directional word
work38y	dw	0	; address of destination sentence
work38z	dw	word4,word5,word6,word7,word8,word9,word10,word11,word12,word13	
;
; feed bear
;
work39:			
	lda	objectw	; who is the player feeding?
	cpi	21	; bear?
	jnz	work39c	; branch if not bear
	call	sentcr	; print cr lf
	lda	myroom	; what room?
	cpi	70	; in barren room?
	jnz	work39b	; branch if not in right room
	lda	inlist+4; get food location
	cpi	126	; does the player have the food?
	jnz	work39a	; branch if food is not available
	lda	bears	; get the bear state
	cpi	1	; is the bear ferocious?
	jnz	work39e	; if not, branch
	mvi	a,2	; bear state 2 for events17
	sta	bears	; show bear fed
work39e:
	mvi	a,1	; well house room number
	sta	Inlist+4; take food from player, send back to well house
	lxi	h,sent377	; bear eats food
	jmp	work39d	; go around other outcome
work39a:			
	lxi	h,sent376	; bear is hungry, without food, player is food
	jmp	work39d	; go around other outcome
work39b:			
	lxi	h,sent380	;  bears eat only in barren room
	jmp	work39d	; go around other outcome
work39c:			
	lxi	h,sent379	; The food has another purpose
work39d:
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	call	sentcr	; print cr lf
	ret		
;
; water plant
;
work40:			
	call	sentcr	; print cr lf
	lda	objectw	; object word?
	cpi	32	; plant?
	jnz	work40b	; branch if something else
	lda	myroom	; is player with a plant?
	cpi	92	; west pit room?
	jnz	work40c	; branch if not
	lda	inlist+6	; get dry bottle location
	cpi	126	; does the player have the empty bottle?
	jz	work40j	; branch if dry bottle
	lda	inlist+16	; get wet bottle location
	cpi	126	; does the player have the bottle with water?
	jnz	work40d	; branch if no bottle
	lda	even11f	; get beanstalk status
	inr	a	; bump status
	cpi	4	; wilted?
	jc	work40a	; branch if still growing
	mvi	a,0	; back to little plant
work40a:			
	sta	even11f	; update beanstalk status
	mvi	a,126	; player
	sta	inlist+6	; now has empty bottle
	mvi	a,130	; 
	sta	inlist+16	; and bottle with water is gone
	jmp	work40f	; go around other code
work40b:			
	lxi	h,sent381	; don't waste water
	jmp	work40e	; go around other code
work40c:			
	lxi	h,sent382	; no plant here
	jmp	work40e	; go around other code
work40d:			
	lxi	h,sent383	; no bottle with water 
	jmp	work40e	; go around other code
work40j:			
	lxi	h,sent384	; bottle has no water
work40e:			
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	call	sentcr	; print cr lf
work40f:			
	ret		
;
;fee fie foe foo put golden eggs in giant room
;
work41:			
	lda	actionw	; which giant action word?
	cpi	49	; fee?
	jnz	work41a	; branch if not
	lda	get_eggs	; current state?
	cpi	0	; waiting for fee?
	jnz	work41e	; must say in order
	mvi	a,1	
	sta	get_eggs	; 
work41a:			
	cpi	50	; fie?
	jnz	work41b	; branch if not
	lda	get_eggs	; current state?
	cpi	1	; waiting for fie?
	jnz	work41e	; must say in order
	mvi	a,2	
	sta	get_eggs	; 
work41b:			
	cpi	51	; foe?
	jnz	work41c	; branch if not
	lda	get_eggs	; current state?
	cpi	2	; waiting for foe?
	jnz	work41e	; must say in order
	mvi	a,3	
	sta	get_eggs	; 
work41c:			
	cpi	52	; foo?
	jnz	work41d	; branch if not
	lda	get_eggs; current state?
	cpi	3	; waiting for foo?
	jnz	work41e	; must say in order
	mvi	a,4	
	sta	get_eggs; 
work41d:			
	lda	get_eggs; fee fie foe foo?
	cpi	4	; eggs are ready?
	jnz	work41e	; branch if not
	mvi	a,0	; reset call for eggs
	sta	get_eggs; record it
	mvi	a,94	; giant room
	sta	Inlist+44	; put eggs back
	mvi	a,10	; 10 points
	sta	pscore9	; post credit
work41e:			
	ret		
;
get_eggs	db	0	
;
; fill bottle with water
;
work42:			
	lda	objectw	; filling what?
	cpi	3	; bottle?
	jnz	work42d	; branch if not bottle
	lxi	h,work42f	; base of water table
work42a:			
	lda	myroom	; what room?
	cmp	m	; in room with water?
	jz	work42b	; branch if water here
	inx	h	; bump to next room
	mov	a,m	; get next room number
	cpi	0	; at end of table?
	jnz	work42a	; loop until all rooms checked
	call	sentcr	; print cr lf
	lxi	h,sent385	; need water to fill bottle
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	jmp	work42j	; go around other code
work42b:			
	lda	Inlist+6	; bottle location
	cpi	126	; player has the bottle?
	jz	work42c	; branch if all set for the fillup
	lda	Inlist+16	; full bottle location
	cpi	126	; player has the bottle?
	jz	work42c	; branch for a refill
	call	sentcr	; print cr lf
	mvi	c,9	; print string
	lxi	h,sent387	; no bottle to fill
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	jmp	work42j	; go around other code
work42c:			
	mvi	a,126	; bottle with water
	sta	inlist+16	; now with player
	mvi	a,130	; empty bottle
	sta	inlist+6	; not with player
	mvi	c,9	; print string
	lxi	d,wordok	; ack the bottle filling
	call	bdos	; job for dos
	jmp	work42j	; go around other code
work42d:			
	call	sentcr	; print cr lf
	lxi	h,sent386	; I can only fill the bottle with water
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	jmp	work42j	; go around other code
work42j:			
	ret		
;
work42f	db	0,1,6,7,47,52,97,0	; rooms with water
;
; cross bridge (crystalline or rickety)
;
work43:			
	lda	objectw	; crossing what?
	cpi	35	; bridge?
	jnz	work0a	; branch if not bridge, say huh?
	mvi	a,4	; actionw for west
	sta	actionw	; substitute action word
	lda	myroom	; player next to a bridge?
	cpi	16	; hall of mists west bank?
	jz	work4	; go west if there
	mvi	a,5	; actionw for east
	sta	actionw	; substitute action word
	lda	myroom	; player next to a bridge?
	cpi	17	; hall of mists east bank?
	jz	work5	; go east if there
	mvi	a,11	; actionw for ne
	sta	actionw	; substitute action word
	lda	myroom	; player next to a bridge?
	cpi	64	; sw side of chasm?
	jz	work11	; go ne if there
	mvi	a,8	; actionw for sw
	sta	actionw	; substitute action word
	lda	myroom	; player next to a bridge?
	cpi	65	; ne side of chasm?
	jz	work8	; go sw if there
	call	sentcr	; print cr lf
	lxi	h,sent426	; no bridge
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	ret		
;
; teleport y2--plover
;
work44:			
	lda	Inlist+32; emerald location
	cpi	126	; player has it?
;
; bypass to make forest door work
;	jnz	work36a	; branch if no rock, no teleport
	lda	myroom	; player location
	cpi	36	; y2?
	jz	work44a	; go to plover room if at Y2
	cpi	83	; plover?
	jz	work44b	; go to Y2 room if at plover
	jmp	work36a	; otherwise, nothing happens
work44a:			
	mvi	a,83	; plover room
	jmp	work44c	; go around other code
work44b:			
	mvi	a,36	; y2 room
work44c:			
	sta	myroom	; teleport!	
	ret		
;
; Info
;
work45:			
	mvi	a,0	; reset string counter
	sta	work45f	; record it
work45h:			
	lda	work45f	; get counter
	lxi	h,work45g	; base of string address table
	call	getadd	; get string address
	shld	mysent1	; set phrase
	call	DoSentence	; play it
	lda	work45f	; get counter
	inr	a	; bump it
	cpi	6	; sent 6 sentences?
	jz	work45i	; branch if done
	sta	work45f	; update it
	jmp	work45h	; loop
work45i:			
	ret		
;
work45f	db	0	; counter
work45g	dw	Sent427,Sent428,Sent429,Sent430,Sent431,Sent432	
;
; words  offer some usage help
;
work46:			
	lxi	h,Sent433	; 
	shld	mysent1	; Action words heading
	call	DoSentence	; play it
	call	sentcr	; print cr lf
	lxi	h,act_words+6	; Action Words, don't show hidden debug f and b
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	call	sentcr	; print cr lf
	lxi	h,Sent434	; 
	shld	mysent1	; Object words heading
	call	DoSentence	; say it
	call	sentcr	; print cr lf
	lxi	h,objwords	; Object Words
	shld	mysent1	; set sentence to say
	call	DoSentence	; say it
	ret		
;
; save game
;
; dma buffer is mybuff, in unused ram at the end of code
; Inlist, Roomb, Pscore, directional tables, Elist
;
work47:			
	call	refresh	; reset fcb
	mvi	c,26	; set dma address
	lxi	d,mybuff; point to save buffer
	call	bdos	
	mvi	c,19	; delete file..create doesn't clear existing?
	lxi	d,myfcb	
	call	bdos	
	mvi	c,22	; create file
	lxi	d,myfcb	
	call	bdos	
	lxi	d,mybuff; point to save buffer
	mvi	c,28	; 28 objects to save
	lxi	h,Inlist; point to object location list
work47a:			
	mov	a,m	; get current value
	stax	d	; save
	inx	d	; bump to next in dma buffer
	inx	h	; bump to inlist second byte
	inx	h	; bump to inlist next entry
	dcr	c	; bump counter
	jnz	work47a	; loop until done
	mvi	c,16	; 16 room visit bytes
	lxi	h,roomb	; room storage area
work47b:			
	mov	a,m	; get room visit byte
	stax	d	; save
	inx	d	; bump to next in dma buffer
	inx	h	; bump pointer
	dcr	c	; bump counter
	jnz	work47b	; loop until done
	mvi	c,14	; 10 puzzle score bytes plus repository credit and 3 turns digits
	lxi	h,pscore0	; score storage area
work47c:			
	mov	a,m	; get puzzle score
	stax	d	; save
	inx	d	; bump to next in dma buffer
	inx	h	; bump pointer
	dcr	c	; bump counter
	jnz	work47c	; loop until done
	lda	myroom	; get current room
	stax	d	; save
	inx	d	; bump dma pointer
	mvi	a,28	; 15 directional permissions and 13 elist items are dynamic
work47d:			
	lxi	h,b_tab	; point to table of directional permissions that change
	push	psw	; save count of bytes to transfer
	push	d	; save buffer address
	dcr	a	; convert count to index, GetAdd changes index to index offset
	call	GetAdd	; hl gets next address to save from b_tab
	pop	d	; restore next save buffer address to de
	mov	a,m	; get byte to save
	stax	d	; save it
	inx	d	; bump pointer
	pop	psw	; get counter back
	dcr	a	; bump counter
	jnz	work47d	; loop until all saved
	mvi	c,32	; 32 objects to save in elist
	lxi	h,Elist+1	; point to event list second byte, first record
work47e:			
	mov	a,m	; get current value
	stax	d	; save
	inx	d	; bump to next in dma buffer
	inx	h	; bump to elist this entry ls byte
	inx	h	; bump to elist this entry ms byte
	inx	h	; bump to elist next entry first byte
	inx	h	; bump to elist next entry second byte
	dcr	c	; bump counter
	jnz	work47e	; loop until done
;
; data in dma buffer, write to disk
;
	mvi	c,21	; write record
	lxi	d,myfcb	
	call	bdos	
	mvi	c,16	; close file
	lxi	d,myfcb	
	call	bdos	
	jmp	work2	
;
myfcb	db	0,'MYADVENTSAV',0,0,0,1	
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	
fcbak	db	0,'MYADVENTSAV',0,0,0,1	
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	
;
; fcb refresh
;
refresh:			
	mvi	c,33	; 33 bytes in a fcb
	lxi	d,myfcb	; fcb used for calls
	lxi	h,fcbak	; fcb template
refresh1:			
	mov	a,m	; get a byte
	stax	d	; set a byte
	inx	d	; bump dest pointer
	inx	h	; bump source pointer
	dcr	c	; bump counter
	jnz	refresh1	; loop until done
	ret		
;
; directional table and elist items to save and load
;
b_tab	dw	m_west,m_west+2,m_west+4,m_west+6,m_east,m_east+2,m_north,m_south,m_south+2,m_ne,m_sw,m_sw+4,m_up,m_up+2,m_down,Bear,Mag1,Mag2,Mag3,Mag4,Mag5,Mag6,Mag7,Mag8,Mag9,Mag10,Mag11,Mag12	
;
;
; load game
;
; dma buffer is above the program at mybuff
; 0-1Bh   Inlist 28 bytes
; 1Ch-2Bh Roomb  16 bytes
; 2Ch-39h Pscore 10 bytes plus 4 bytes for end game and turns count
; 3Ah     Myroom 1 byte
; 3Bh-49h Directional permissions  15 bytes
; 4Ah-56h Elist locations (byte 1) 13 bytes
; 57h-76h Elist values (byte 2)    32 bytes
;
;
work48:			
	call	refresh	; reset fcb
	mvi	c,26	; set dma address
	lxi	d,mybuff; point to save buffer
	call	bdos	
	mvi	c,15	; open file
	lxi	d,myfcb	
	call	bdos	
	mvi	c,20	; read record
	lxi	d,myfcb	
	call	bdos	
	lxi	d,mybuff; point to save buffer
	mvi	c,28	; 28 objects to restore
	lxi	h,Inlist; point to object location list
work48a:			
	ldax	d	; read
	mov	m,a	; set current value
	inx	d	; bump to next in dma buffer
	inx	h	; bump to inlist second byte
	inx	h	; bump to inlist next entry
	dcr	c	; bump counter
	jnz	work48a	; loop until done
	mvi	c,16	; 16 room visit bytes
	lxi	h,roomb	; room storage area
work48b:			
	ldax	d	; read
	mov	m,a	; set room visit byte
	inx	d	; bump to next in dma buffer
	inx	h	; bump pointer
	dcr	c	; bump counter
	jnz	work48b	; loop until done
	mvi	c,14	; 10 puzzle score bytes plus repository and 3 turns digits
	lxi	h,pscore0	; score storage area
work48c:			
	ldax	d	; read
	mov	m,a	; set puzzle score
	inx	d	; bump to next in dma buffer
	inx	h	; bump pointer
	dcr	c	; bump counter
	jnz	work48c	; loop until done
	ldax	d	; read
	sta	myroom	; set current room
	inx	d	; bump dma pointer
	mvi	a,28	; 15 directional permissions and 13 elist items are dynamic
work48d:			
	lxi	h,b_tab	; point to table of directional permissions that change
	push	psw	; save count of bytes to transfer
	push	d	; save buffer address
	dcr	a	; convert count to index, GetAdd changes index to index offset
	call	GetAdd	; hl gets next address to save from b_tab
	pop	d	; restore next saved buffer address to de
	ldax	d	; get the saved byte
	mov	m,a	; load byte for game
	inx	d	; bump pointer
	pop	psw	; get counter back
	dcr	a	; bump counter
	jnz	work48d	; loop until all saved
	mvi	c,32	; 32 objects to restore to elist
	lxi	h,Elist+1	; point to event list second byte, first record
work48e:			
	ldax	d	; retrieve
	mov	m,a	; set saved value
	inx	d	; bump to next in dma buffer
	inx	h	; bump to elist this entry ls byte
	inx	h	; bump to elist this entry ms byte
	inx	h	; bump to elist next entry first byte
	inx	h	; bump to elist next entry second byte
	dcr	c	; bump counter
	jnz	work48e	; loop until done
;
	mvi	c,16	; close file
	lxi	d,myfcb	
	call	bdos	
	ret		
;
; blast/detonate to win, player in room 123, rod in room 124 or nothing happens
;
work49:			
	call	sentcr	; print cr lf
	lda	myroom	; where is player?
	cpi	123	; in Repository?
	jc	work49b	; branch if somewhere else
	lda	inlist+12	; where is rod?
	cpi	124	; in final SW room?
	jnz	work49a	; branch if it is somewhere else
	lxi	h,Sent475	; end game last sentence
	shld	mysent1	; set sentence
	call	DoSentence	; play it
	jmp	work2c	; Game Over, close it down
work49a:			
	lxi	h,Sent300	; end game conditions not met, Nothing happens.
	jmp	work49c	; go around end game response 
work49b:			
	lxi	h,Sent476	; not in Repository, I see no dynamite here.
work49c:			
	shld	mysent1	; set sentence
	call	DoSentence	; play it
	ret		
;
Closed	db	0	; flag for Cave Closure, set by Deadtest when treasures are back in well house
;
; sentcr  keep the presentation nice with a crlf
;
sentcr:			
	mvi	c,9	; print string
	lxi	d,wordcr	; cr lf to the screen
	call	bdos	; job for dos
	ret		
;
; autorun through the cave triggered by forest 27 door 37
;
work50:			
	lhld	apoint	; get current auto move pointer address
	mov	a,m	; get next action word
	cpi	0ffh	; at end of list?
	jz	work50b	; branch if auto move has ended
	sta	actionw	; set it
	inx	h	; bump pointer
	mov	a,m	; get next object word
	sta	objectw	; set it
	cpi	0	; object word?
	jz	work50a	; branch if no object word	
	mvi	a,1	; 1= object word present
work50a:			
	sta	Objectf	; set flag for object word or no object word
	inx	h	; bump pointer
	shld	apoint	; update for next move
	lda	actionw	; get action word
	lxi	h,act_words; base of action word list
	call	Getadd	; get address of action word address
	xchg		; string address in de for bdos
	mvi	c,9	; print string
	call	bdos	; put it out there
	call	sentcr	; and a new line
	jmp	work50c	; go around other code
work50b:			
	mvi	a,0	; reset automove flag
	sta	actionw	; clear action word
	sta	objectw	; clear object word
	sta	Objectf	; clear object word present
	sta	automove	; return control to user
work50c:			
	ret		; all done
;
automove	db	0	; flag for automatic movement through the cave  auto=1
apoint	dw	0	; address pointer to actionw objectw pair for next move
;
mpoint			
; above- get all,w,w,w,w,s,e,e,s,s,unlock grate,d
	db	37,31,4,0,4,0,4,0,4,0,7,0,5,0,5,0,7,0,7,0,33,28,13,0	
; first- on lamp,w,get cage,w,get rod,w,w,drop rod,get bird,get rod,w,d
	db	40,1,4,0,37,4,4,0,37,6,4,0,4,0,15,6,37,5,37,6,4,0,13,0	
; mists- s,get gold,plugh,n,get gold,w,wave rod,w,get diamonds,n,w,w,s
	db	7,0,37,24,44,0,6,0,37,24,4,0,36,6,4,0,37,20,6,0,4,0,4,0,7,0	
; maze all different- s,s,s,s,s,s,s,sw,se,s,n,n,ne,d,n,n,s,w,e
	db	7,0,7,0,7,0,7,0,7,0,7,0,7,0,8,0,10,0,7,0,6,0,6,0,11,0,13,0,6,0,6,0,7,0,4,0,5,0	
; maze all alike- s,w,e,w,n,s,s,e,d,u,e,w,n,s,n,s,d,u,s,w,w,s,s,w,n,d,u,n,d,u,e
	db	7,0,4,0,5,0,4,0,6,0,7,0,7,0,5,0,13,0,12,0,5,0,4,0,6,0,7,0,6,0,7,0,13,0,12,0,7,0,4,0,4,0,7,0,7,0,4,0,6,0,13,0,12,0,6,0,13,0,12,0,5,0
; brink of pit tour- s,e,e,w,w,e,s
	db	7,0,5,0,5,0,4,0,4,0,5,0,7,0
; mountain king from brink of pit- d,w,s,d,open cage,s,take jewelry,n,w,take coins,e,n,take silver.n,w,e,e,d,y2
	db	13,0,4,0,7,0,13,0,38,4,7,0,14,26,6,0,4,0,14,12,5,0,6,0,14,25,6,0,4,0,5,0,5,0,13,0,32,0
; canyon tour from well house to tall E/W canyon- y2,s,s,sw,d,s,n,n,w,s,(tall ewc)
	db	32,0,7,0,7,0,8,0,13,0,7,0,6,0,6,0,4,0,7,0
; canyon tour from tall E/WC through secret canyons -n,w,w,w,u,n,n,f,b,s,s,s,kill dragon,yes,take rug,e,e,n,n,w,f,w,s,s,n,d,e,u,e,e,d,u,w,u,n,y2
	db	6,0,4,0,4,0,4,0,12,0,6,0,6,0,1,0,2,0,7,0,7,0,7,0,42,33,14,18,5,0,5,0,6,0,6,0,4,0,1,0,4,0,7,0,7,0,6,0,13,0,5,0,12,0,5,0,5,0,13,0,12,0,4,0,12,0,6,0,32,0
; two pit, swiss cheese, soft room, beanstalk-fill bottle,y2,s,d,w,d,w,w,e,get pillow,w,w,w,d,water plant,u,w,u,n,n,fill bottle,s,s,d,s,d,water plant,u
	db	53,3,32,0,7,0,13,0,4,0,13,0,4,0,4,0,5,0,37,10,4,0,4,0,4,0,13,0,48,32,12,0,4,0,12,0,6,0,6,0,53,3,7,0,7,0,13,0,7,0,13,0,48,32,12,0
; magnificent canyon from west two pit-e,d,get oil,u,w,u,w,get eggs,e,s,n,open door,n,get trident,w,d,n,s,se,get vase,u,w,nw,s,s,ne,e,u,e,u,n,y2
	db	5,0,13,0,37,11,12,0,4,0,12,0,4,0,37,22,5,0,7,0,6,0,38,37,6,0,37,23,4,0,13,0,6,0,7,0,10,0,37,17,12,0,4,0,9,0,7,0,7,0,11,0,5,0,12,0,5,0,12,0,6,0,32,0
; plover tour from well house-y2,plover,get emerald,ne,get pyramid,s,plover,y2
	db	32,0,55,0,37,16,11,0,37,19,7,0,55,0,32,0
; volcano and bear from well house-y2,s,d,w,d,w,w,nw,w,n,s,sw,u,throw eggs,ne,e,ne,e,get spices,w,n,s,s,se,s,e,e,e,feed bear,unlock chain,take chain,take bear,e,n,w,w
	db	32,0,7,0,13,0,4,0,13,0,4,0,4,0,9,0,4,0,6,0,7,0,8,0,12,0,45,22,11,0,5,0,11,0,5,0,37,27,4,0,6,0,7,0,7,0,10,0,7,0,5,0,5,0,47,21,33,13,14,13,14,21,5,0,6,0,4,0,4,0
; back to well house from limestone passage-n,w,w,throw bear,sw,d,e,se,s,ne,e,u,e,u,n,y2
	db	6,0,4,0,4,0,45,21,8,0,13,0,5,0,10,0,7,0,11,0,5,0,12,0,5,0,12,0,6,0,32,0
; scoop up pearl, magazine- y2,s,d,w.d.n,u,d,open shell,d,d,get pearl,u,u,s,e,get magazine
	db	32,0,7,0,13,0,4,0,13,0,6,0,12,0,13,0,38,30,13,0,13,0,37,15,12,0,12,0,7,0,5,0,37,14
; get eggs, back to well house- w,w,w,w,u,w,fee,fie,foe,foo,get eggs,s,d,e,e,ne,e,u,e,u,n,y2
	db	4,0,4,0,4,0,4,0,12,0,4,0,49,0,50,0,51,0,52,0,37,22,7,0,13,0,5,0,5,0,11,0,5,0,12,0,5,0,12,0,6,0,32,0
; drop treasures in well house-drop all get lamp, get magazine
	db	15,31,14,1,14,14
; go to Witts End for end game- y2,s,d,w,d,e,d,e,drop magazine,lamp off,ne,get rod,sw,drop rod,ne,blast
	db	32,0,7,0,13,0,4,0,13,0,5,0,13,0,5,0,15,14,41,1,11,0,37,6,8,0,15,6,11,0,60,0
; end autorun
	db	0ffh	
;
; jump to death if in breath taking view, next to fissure without bridge, next to rickety bridge
;
work51:
	lda	myroom  ; get current room
	cpi	73	; breathtaking view?
	jz	work51a ; branch if deadly
	cpi	64	; sw side of rickety bridge?
	jz	work51a	; branch if deadly
	cpi	65	; ne side of rickety bridge?
	jz	work51a ; branch if deadly
	lda	Bridge1+1; crystalline bridge
	cpi	1	; is the bridge visible?
	jz	work52	; branch if bridge makes jumping safe
	lda	myroom  ; get current room
	cpi	16	; east bank of fissure?
	jz	work51a ; branch if deadly
	cpi	17	; west bank of fissure?
	jnz	work52  ; branch if not deadly
work51a:
	mvi	a,0	; player dead
	sta	imdead	; update record
	ret
;
; to where?
;
work52:
	lxi	h,sent482; walk,run,climb to where?
	shld	mysent1	 ; set sentence to say
	call	DoSentence	; say it
	ret		
;
; match act_words with the right work routine
; user action words
;                
act_words:			
	dw	word1192;0 Huh?
	dw	word1	;1 f
	dw	word2	;2 b
	dw	word3	;3 quit
	dw	word4	;4 west
	dw	word5	;5 east
	dw	word6	;6 north
	dw	word7	;7 south
	dw	word8	;8 sw
	dw	word9	;9 nw
	dw	word10	;10 se
	dw	word11	;11 ne
	dw	word12	;12 up
	dw	word13	;13 down
	dw	word14	;14 take
	dw	word15	;15 drop
	dw	word16	;16 inven
	dw	word17	;17 look
	dw	word18	;18 n
	dw	word19	;19 s
	dw	word20	;20 e
	dw	word21	;21 w
	dw	word22	;22 u
	dw	word23	;23 d
	dw	word24	;24 help
	dw	word25	;25 inventory
	dw	word26	;26 building
	dw	word27	;27 forest
	dw	word28	;28 enter
	dw	word29	;29 exit
	dw	word30	;30 downstream
	dw	word31	;31 xyzzy
	dw	word32	;32 Y2
	dw	word33	;33 unlock
	dw	word34	;34 lock
	dw	word35	;35 score
	dw	word36	;36 wave
	dw	word37	;37 get
	dw	word38	;38 open
	dw	word39	;39 free
	dw	word40	;40 on
	dw	word41	;41 off
	dw	word42	;42 kill
	dw	word43	;43 attack
	dw	word44	;44 plugh
	dw	word45	;45 throw
	dw	word46	;46 room
	dw	word47	;47 feed
	dw	word48	;48 water
	dw	word49	;49 fee
	dw	word50	;50 fie
	dw	word51	;51 foe
	dw	word52	;52 foo
	dw	word53	;53 fill
	dw	word54	;54 cross
	dw	word55	;55 plover
	dw	word56	;56 info
	dw	word57	;57 words
	dw	word58	;58 save
	dw	word59	;59 load
	dw	word1457;60 blast
	dw	word1458;61 detonate
	dw	word742 ;62 jump
	dw	word1545;63 walk
	dw	word1546;64 run
	dw	word386	;65 go
	dw	word740	;66 climb
	dw	0	
;
; table with address of work routines, indexed to match action words
;
worktab:			
	dw	work0,work1,work3,work2,work4,work5,work6,work7,work8,work9,work10,work11,work12,work13,work14,work15	
	dw	work16,work17,work6,work7,work5,work4,work12,work13,work18,work16,work19,work20,work21,work22,work23	
	dw	work24,work25,work26,work27,work28,work29,work14,work30,work31,work32,work33,work34,work35,work36,work37	
	dw	work38,work39,work40,work41,work41,work41,work41,work42,work43,work44,work45,work46,work47,work48,work49
	dw	work49,work51,work52,work52,work52,work52
;
myroom:	db	0	; where we are now
mylast:	db	0	; where we were before
imdead:	db	0	; 0=dead 1,2,3=alive
mysent1:dw	0	; word vector pointer for current sentence
mysent2:dw	0	; word vector pointer for next sentence
wordsp:	db	' $'	
wordok:	db	0dh,0ah,0ah,'OK'	; OK with cr lf lf before and cr lf after
wordcr:	db	0dh,0ah,'$'	
;
word1:	db	'f$'	
word2:	db	'b$'	
word3:	db	'quit$'	
word4:	db	'west$'	
word5:	db	'east$'	
word6:	db	'north$'	
word7:	db	'south$'	
word8:	db	'sw$'	
word9:	db	'nw$'	
word10:	db	'se$'	
word11:	db	'ne$'
word12:	db	'up$'
word13:	db	'down$'
word14:	db	'take$'
word15:	db	'drop$'
word16:	db	'inven$'
word17:	db	'look$'
word18:	db	'n$'
word19:	db	's$'
word20:	db	'e$'
word21:	db	'w$'
word22:	db	'u$'
word23:	db	'd$'
word24:	db	'help$'
word25:	db	'inventory$'
word26:	db	'building$'
word27:	db	'forest$'
word28:	db	'enter$'
word29:	db	'exit$'
word30:	db	'downstream$'
word31:	db	'xyzzy$'
word32:	db	'y2$'
word33:	db	'unlock$'
word34:	db	'lock$'
word35:	db	'score$'
word36:	db	'wave$'
word37:	db	'get$'
word38:	db	'open$'
word39:	db	'free$'
word40:	db	'on$'
word41:	db	'off$'
word42:	db	'kill$'
word43:	db	'attack$'
word44:	db	'plugh$'
word45:	db	'throw$'
word46:	db	'room$'
word47:	db	'feed$'
word48:	db	'water$'
word49:	db	'fee$'
word50:	db	'fie$'
word51:	db	'foe$'
word52:	db	'foo$'
word53:	db	'fill$'
word54:	db	'cross$'
word55:	db	'plover$'
word56:	db	'info$'
word57:	db	'words$'
word58:	db	'save$'
word59:	db	'load$'
word60:	db	'Welcome$'
word61:	db	'to$'
word62:	db	'Adventure!$'
word63:	db	'$'
word64:	db	'Would$'
word65:	db	'you$'
word66:	db	'like$'
word67:	db	'instructions?$'
word68:	db	'You$'
word69:	db	'are$'
word70:	db	'standing$'
word71:	db	'at$'
word72:	db	'the$'
word73:	db	'end$'
word74:	db	'of$'
word75:	db	'a$'
word76:	db	'road$'
word77:	db	'before$'
word78:	db	'small$'
word79:	db	'brick$'
word80:	db	'building.$'
word81:	db	'Around$'
word82:	db	'is$'
word83:	db	'forest.$'
word84:	db	'A$'
word85:	db	'stream$'
word86:	db	'flows$'
word87:	db	'out$'
word88:	db	'and$'
word89:	db	'gully.$'
word90:	db	'inside$'
word91:	db	'building,$'
word92:	db	'well$'
word93:	db	'house$'
word94:	db	'for$'
word95:	db	'large$'
word96:	db	'spring.$'
word97:	db	'road',39,'s$'
word98:	db	'end.$'
word99:	db	'The$'
word100:	db	'rises$'
word101:	db	'hill$'
word102:	db	'behind$'
word103:	db	'you.$'
word104:	db	'have$'
word105:	db	'walked$'
word106:	db	'hill,$'
word107:	db	'still$'
word108:	db	'in$'
word109:	db	'slopes$'
word110:	db	'back$'
word111:	db	'other$'
word112:	db	'side$'
word113:	db	'hill.$'
word114:	db	'There$'
word115:	db	'distance.$'
word116:	db	'near$'
word117:	db	'both$'
word118:	db	'valley$'
word119:	db	'road.$'
word120:	db	'forest,$'
word121:	db	'with$'
word122:	db	'deep$'
word123:	db	'one$'
word124:	db	'side.$'
word125:	db	'beside$'
word126:	db	'tumbling$'
word127:	db	'along$'
word128:	db	'rocky$'
word129:	db	'bed.$'
word130:	db	'At$'
word131:	db	'your$'
word132:	db	'feet$'
word133:	db	'all$'
word134:	db	'splashes$'
word135:	db	'into$'
word136:	db	'2-inch$'
word137:	db	'slit$'
word138:	db	'rock.$'
word139:	db	'Downstream$'
word140:	db	'stream'	
word140a:	db	'bed$'	
word141:	db	'bare$'
word142:	db	'20-foot$'
word143:	db	'depression$'
word144:	db	'floored$'
word145:	db	'dirt.$'
word146:	db	'Set$'
word147:	db	'dirt$'
word148:	db	'strong$'
word149:	db	'steel$'
word150:	db	'grate$'
word151:	db	'mounted$'
word152:	db	'concrete.$'
word153:	db	'dry$'
word154:	db	'leads$'
word155:	db	'depression.$'
word156:	db	'chamber$'
word157:	db	'beneath$'
word158:	db	'3x3$'
word159:	db	'surface.$'
word160:	db	'low$'
word161:	db	'crawl$'
word162:	db	'over$'
word163:	db	'cobbles$'
word164:	db	'inward$'
word165:	db	'west.$'
word166:	db	'wide$'
word167:	db	'passage$'
word168:	db	'becomes$'
word169:	db	'plugged$'
word170:	db	'mud$'
word171:	db	'debris$'
word172:	db	'here,$'
word173:	db	'but$'
word174:	db	'an$'
word175:	db	'awkward$'
word176:	db	'canyon$'
word177:	db	'upward$'
word178:	db	'filled$'
word179:	db	'stuff$'
word180:	db	'washed$'
word181:	db	'from$'
word182:	db	'path$'
word183:	db	'sloping$'
word184:	db	'awkwardly$'
word185:	db	'east.$'
word186:	db	'splendid$'
word187:	db	'thirty$'
word188:	db	'high.$'
word189:	db	'walls$'
word190:	db	'frozen$'
word191:	db	'rivers$'
word192:	db	'orange$'
word193:	db	'stone.$'
word194:	db	'An$'
word195:	db	'good$'
word196:	db	'sides$'
word197:	db	'chamber.$'
word198:	db	'bird$'
word199:	db	'has$'
word200:	db	'been$'
word201:	db	'nesting$'
word202:	db	'here.$'
word203:	db	'You',39,'re$'
word204:	db	'top$'
word205:	db	'pit.$'
word206:	db	'pit$'
word207:	db	'breathing$'
word208:	db	'traces$'
word209:	db	'white$'
word210:	db	'mist.$'
word211:	db	'ends$'
word212:	db	'here$'
word213:	db	'except$'
word214:	db	'crack$'
word215:	db	'leading$'
word216:	db	'on.$'
word217:	db	'Rough$'
word218:	db	'stone$'
word219:	db	'steps$'
word220:	db	'lead$'
word221:	db	'vast$'
word222:	db	'hall$'
word223:	db	'mists$'
word224:	db	'stretching$'
word225:	db	'forward$'
word226:	db	'sight$'
word227:	db	'west,$'
word228:	db	'wisps$'
word229:	db	'mist$'
word230:	db	'that$'
word231:	db	'sway$'
word232:	db	'fro$'
word233:	db	'almost$'
word234:	db	'as$'
word235:	db	'if$'
word236:	db	'alive.$'
word237:	db	'dome$'
word238:	db	'above$'
word239:	db	'staircase$'
word240:	db	'runs$'
word241:	db	'downward$'
word242:	db	'darkness;$'
word243:	db	'chill$'
word244:	db	'wind$'
word245:	db	'blows$'
word246:	db	'below.$'
word247:	db	'passages$'
word248:	db	'south,$'
word249:	db	'bank$'
word250:	db	'fissure.$'
word251:	db	'quite$'
word252:	db	'thick$'
word253:	db	'fissure$'
word254:	db	'too$'
word255:	db	'jump.$'
word256:	db	'Hall$'
word257:	db	'Mists.$'
word258:	db	'crude$'
word259:	db	'note$'
word260:	db	'wall.$'
word261:	db	'says,$'
word262:	db	'"You$'
word263:	db	'won',39,'t$'
word264:	db	'it$'
word265:	db	'steps".$'
word266:	db	'continues$'
word267:	db	'another$'
word268:	db	'goes$'
word269:	db	'north.$'
word270:	db	'To$'
word271:	db	'little$'
word272:	db	'6$'
word273:	db	'floor.$'
word274:	db	'very$'
word275:	db	'long$'
word276:	db	'hall,$'
word277:	db	'apparently$'
word278:	db	'without$'
word279:	db	'chambers.$'
word280:	db	'east,$'
word281:	db	'slants$'
word282:	db	'up.$'
word283:	db	'around$'
word284:	db	'two$'
word285:	db	'foot$'
word286:	db	'hole$'
word287:	db	'down.$'
word289:	db	'crossover$'
word290:	db	'high$'
word291:	db	'N/S$'
word292:	db	'E/W$'
word293:	db	'one.$'
word294:	db	'featureless$'
word295:	db	'hall.$'
word296:	db	'joins$'
word297:	db	'nar'	
word297a:	db	'row$'
word298:	db	'north/south$'
word299:	db	'passage.$'
word300:	db	'maze$'
word301:	db	'twisting$'
word302:	db	'passages,$'
word303:	db	'different.$'
word304:	db	'twisty$'
word305:	db	'In$'
word306:	db	'this$'
word307:	db	'enormous$'
word308:	db	'vending$'
word309:	db	'machine$'
word318:	db	'coins$'
word320:	db	'"$'
word321:	db	'next$'
word324:	db	'it.$'
word325:	db	'jumble$'
word326:	db	'rocks,$'
word327:	db	'cracks$'
word328:	db	'everywhere.$'
word329:	db	'room,$'
word330:	db	'wall$'
word331:	db	'broken$'
word332:	db	'rock$'
word333:	db	'"Y2"$'
word334:	db	'room',39,'s$'
word335:	db	'center.$'
word336:	db	'window$'
word337:	db	'overlooking$'
word338:	db	'huge$'
word339:	db	'pit,$'
word340:	db	'which$'
word341:	db	'extends$'
word342:	db	'sight.$'
word343:	db	'floor$'
word344:	db	'indistinctly$'
word345:	db	'visible$'
word346:	db	'50$'
word347:	db	'Traces$'
word348:	db	'cover$'
word349:	db	'becoming$'
word350:	db	'thicker$'
word351:	db	'right.$'
word352:	db	'Marks$'
word353:	db	'dust$'
word354:	db	'would$'
word355:	db	'seem$'
word356:	db	'indicate$'
word357:	db	'someone$'
word358:	db	'recently.$'
word359:	db	'Directly$'
word360:	db	'across$'
word361:	db	'25$'
word362:	db	'away$'
word363:	db	'there$'
word364:	db	'similar$'
word365:	db	'looking$'
word366:	db	'lighted$'
word367:	db	'room.$'
word368:	db	'shadowy$'
word369:	db	'figure$'
word370:	db	'can$'
word371:	db	'be$'
word372:	db	'seen$'
word373:	db	'peering$'
word374:	db	'left.$'
word375:	db	'Mountain$'
word376:	db	'King,$'
word377:	db	'directions.$'
word378:	db	'King.$'
word379:	db	'secret$'
word380:	db	'E/W.$'
word381:	db	'It$'
word382:	db	'crosses$'
word383:	db	'tight$'
word384:	db	'15$'
word385:	db	'If$'
word386:	db	'go$'
word387:	db	'may$'
word388:	db	'not$'
word389:	db	'able$'
word390:	db	'about$'
word391:	db	'across.$'
word392:	db	'covered$'
word393:	db	'by$'
word394:	db	'seeping$'
word395:	db	'extend$'
word396:	db	'100$'
word397:	db	'feet.$'
word398:	db	'Suspended$'
word399:	db	'some$'
word400:	db	'unseen$'
word401:	db	'point$'
word402:	db	'far$'
word403:	db	'you,$'
word404:	db	'two-sided$'
word405:	db	'mirror$'
word406:	db	'hanging$'
word407:	db	'parallel$'
word408:	db	'midway$'
word409:	db	'between$'
word410:	db	'walls.$'
word411:	db	'(The$'
word412:	db	'obviously$'
word413:	db	'provided$'
word414:	db	'use$'
word415:	db	'dwarves,$'
word416:	db	'who$'
word417:	db	'know,$'
word418:	db	'extremely$'
word419:	db	'vain).$'
word420:	db	'either$'
word421:	db	'wall,$'
word422:	db	'fifty$'
word423:	db	'N/E$'
word424:	db	'southern$'
word425:	db	'edge$'
word426:	db	'underground$'
word427:	db	'reservoir.$'
word428:	db	'cloud$'
word429:	db	'fills$'
word430:	db	'rising$'
word431:	db	'surface$'
word432:	db	'drifting$'
word433:	db	'rapidly$'
word434:	db	'upwards.$'
word435:	db	'lake$'
word436:	db	'fed$'
word437:	db	'stream,$'
word438:	db	'tumbles$'
word439:	db	'10$'
word440:	db	'overhead$'
word441:	db	'noisily$'
word442:	db	'reservoir',39,'s$'
word443:	db	'northern$'
word444:	db	'dimly-seen$'
word445:	db	'exits$'
word446:	db	'through$'
word447:	db	'can',39,'t$'
word448:	db	'Another$'
word449:	db	'Pirate$'
word450:	db	'Lair.$'
word451:	db	'treasure$'
word452:	db	'chest$'
word453:	db	'half-hidden$'
word454:	db	'rock!$'
word455:	db	'full$'
word456:	db	'dusty$'
word457:	db	'rocks.$'
word458:	db	'big$'
word459:	db	'everywhere,$'
word460:	db	'dirty$'
word461:	db	'crawl.$'
word462:	db	'Above$'
word463:	db	'brink$'
word464:	db	'clean$'
word465:	db	'climbable$'
word466:	db	'bottom$'
word467:	db	'enters$'
word468:	db	'tiny$'
word469:	db	'slits.$'
word470:	db	'complex$'
word471:	db	'junction.$'
word472:	db	'hands$'
word473:	db	'knees$'
word474:	db	'higher$'
word475:	db	'make$'
word476:	db	'walking$'
word477:	db	'going$'
word478:	db	'also$'
word479:	db	'above.$'
word480:	db	'air$'
word481:	db	'damp$'
word482:	db	'shell,$'
word483:	db	'tightly$'
word484:	db	'shut.$'
word485:	db	'arched$'
word486:	db	'corridor$'
word487:	db	'ragged$'
word488:	db	'sharp$'
word489:	db	'cul-de-sac$'
word490:	db	'eight$'
word491:	db	'anteroom$'
word492:	db	'Small$'
word493:	db	'remnants$'
word494:	db	'recent$'
word495:	db	'digging$'
word496:	db	'evident.$'
word497:	db	'sign$'
word498:	db	'midair$'
word499:	db	'says$'
word500:	db	'"Cave$'
word501:	db	'under$'
word502:	db	'construction$'
word503:	db	'beyond$'
word504:	db	'point.$'
word505:	db	'Proceed$'
word506:	db	'own$'
word507:	db	'risk.$'
word508:	db	'{Witt$'
word509:	db	'Construction$'
word510:	db	'Company}.$'
word511:	db	'Witt',39,'s$'
word512:	db	'End.$'
word513:	db	'Passages$'
word514:	db	'*all*$'
word515:	db	'Bedquilt,$'
word516:	db	'east/west$'
word517:	db	'holes$'
word518:	db	'explore$'
word519:	db	'random$'
word520:	db	'select$'
word521:	db	'NORTH,$'
word522:	db	'SOUTH,$'
word523:	db	'UP,$'
word524:	db	'or$'
word525:	db	'DOWN.$'
word526:	db	'Crawls$'
word527:	db	'north,$'
word528:	db	'SE,$'
word529:	db	'SW.$'
word530:	db	'dead$'
word531:	db	'winding$'
word532:	db	'large,$'
word533:	db	'chasm.$'
word534:	db	'heavy$'
word535:	db	'below$'
word536:	db	'obscures$'
word537:	db	'view$'
word538:	db	'SW$'
word539:	db	'chasm$'
word540:	db	'corridor.$'
word541:	db	'NE$'
word542:	db	'long,$'
word543:	db	'faint$'
word544:	db	'rumbling$'
word545:	db	'noise$'
word546:	db	'heard$'
word547:	db	'forks$'
word548:	db	'left$'
word549:	db	'fork$'
word550:	db	'northeast.$'
word551:	db	'dull$'
word552:	db	'seems$'
word553:	db	'louder$'
word554:	db	'direction.$'
word555:	db	'right$'
word556:	db	'southeast$'
word557:	db	'gentle$'
word558:	db	'slope.$'
word559:	db	'main$'
word560:	db	'gently$'
word561:	db	'lined$'
word562:	db	'oddly$'
word563:	db	'shaped$'
word564:	db	'limestone$'
word565:	db	'formations.$'
word566:	db	'entrance$'
word567:	db	'barren$'
word568:	db	'posted$'
word569:	db	'reads:$'
word570:	db	'"Caution!$'
word571:	db	'Bear$'
word572:	db	'room!"$'
word573:	db	'center$'
word574:	db	'completely$'
word575:	db	'empty$'
word576:	db	'dust.$'
word577:	db	'toward$'
word578:	db	'only$'
word579:	db	'way$'
word580:	db	'came$'
word581:	db	'in.$'
word582:	db	'warm$'
word583:	db	'From$'
word584:	db	'steady$'
word585:	db	'roar,$'
word586:	db	'so$'
word587:	db	'loud$'
word588:	db	'entire$'
word589:	db	'cave$'
word590:	db	'trembling.$'
word591:	db	'boulders.$'
word592:	db	'breath-taking$'
word593:	db	'view.$'
word594:	db	'Far$'
word595:	db	'active$'
word596:	db	'volcano,$'
word597:	db	'gr'
word597a:	db	'eat$'
word598:	db	'gouts$'
word599:	db	'molten$'
word600:	db	'lava$'
word601:	db	'come$'
word602:	db	'surging$'
word603:	db	'out,$'
word604:	db	'cascading$'
word605:	db	'depths.$'
word606:	db	'glowing$'
word607:	db	'farthest$'
word608:	db	'reaches$'
word609:	db	'cavern$'
word610:	db	'blood-red$'
word611:	db	'glare,$'
word612:	db	'giving$'
word613:	db	'every-thing$'
word614:	db	'eerie,$'
word615:	db	'macabre$'
word616:	db	'appearance.$'
word617:	db	'flickering$'
word618:	db	'sparks$'
word619:	db	'ash$'
word620:	db	'smell$'
word621:	db	'brimstone.$'
word622:	db	'hot$'
word623:	db	'touch,$'
word624:	db	'thundering$'
word625:	db	'volcano$'
word626:	db	'drowns$'
word627:	db	'sounds.$'
word628:	db	'Embedded$'
word629:	db	'jagged$'
word630:	db	'roof$'
word631:	db	'myriad$'
word632:	db	'twisted$'
word633:	db	'formations$'
word634:	db	'composed$'
word635:	db	'pure$'
word636:	db	'alabaster,$'
word637:	db	'scatter$'
word638:	db	'murky$'
word639:	db	'light$'
word640:	db	'sinister$'
word641:	db	'apparitions$'
word642:	db	'upon$'
word643:	db	'gorge,$'
word644:	db	'bizarre$'
word645:	db	'chaos$'
word646:	db	'tortured$'
word647:	db	'crafted$'
word648:	db	'devil$'
word649:	db	'himself.$'
word650:	db	'immense$'
word651:	db	'river$'
word652:	db	'fire$'
word653:	db	'cr'
word653a:	db	'ashes$'
word654:	db	'depths$'
word655:	db	'burns$'
word656:	db	'its$'
word657:	db	'plummets$'
word658:	db	'bottomless$'
word659:	db	'Across$'
word660:	db	'dimly$'
word661:	db	'visible.$'
word662:	db	'right,$'
word663:	db	'geyser$'
word664:	db	'blistering$'
word665:	db	'steam$'
word666:	db	'erupts$'
word667:	db	'continuously$'
word668:	db	'island$'
word669:	db	'sulfurous$'
word670:	db	'lake,$'
word671:	db	'bubbles$'
word672:	db	'ominously.$'
word673:	db	'flame$'
word674:	db	'incandescence$'
word675:	db	'own,$'
word676:	db	'lends$'
word677:	db	'additional$'
word678:	db	'infernal$'
word679:	db	'splendor$'
word680:	db	'already$'
word681:	db	'hellish$'
word682:	db	'scene.$'
word683:	db	'dark,$'
word684:	db	'foreboding$'
word685:	db	'south.$'
word686:	db	'This$'
word687:	db	'Oriental$'
word688:	db	'Ancient$'
word689:	db	'oriental$'
word690:	db	'drawings$'
word691:	db	'whose$'
word692:	db	'resemble$'
word693:	db	'Swiss$'
word694:	db	'cheese.$'
word695:	db	'Obvious$'
word696:	db	'NE,$'
word697:	db	'NW.$'
word698:	db	'Part$'
word699:	db	'occupied$'
word700:	db	'bedrock$'
word701:	db	'block.$'
word702:	db	'soft$'
word703:	db	'curtains,$'
word704:	db	'pile$'
word705:	db	'carpet.$'
word706:	db	'Moss$'
word707:	db	'covers$'
word708:	db	'ceiling.$'
word709:	db	'tall$'
word710:	db	'canyon.$'
word711:	db	'3$'
word712:	db	'Dead$'
word713:	db	'place$'
word714:	db	'further$'
word715:	db	'following$'
word716:	db	'outer$'
word717:	db	'misty$'
word718:	db	'cavern.$'
word719:	db	'below,$'
word720:	db	'mist,$'
word721:	db	'strange$'
word722:	db	'splashing$'
word723:	db	'noises$'
word724:	db	'heard.$'
word725:	db	'alcove.$'
word726:	db	'NW$'
word727:	db	'widen$'
word728:	db	'after$'
word729:	db	'short$'
word730:	db	'tunnel$'
word731:	db	'looks$'
word732:	db	'squeeze.$'
word733:	db	'eerie$'
word734:	db	'Plover$'
word735:	db	'Dark$'
word736:	db	'exit.$'
word737:	db	'sizable$'
word738:	db	'stalactite$'
word739:	db	'could$'
word740:	db	'climb$'
word741:	db	'it,$'
word742:	db	'jump$'
word743:	db	'floor,$'
word744:	db	'having$'
word745:	db	'done$'
word746:	db	'unable$'
word747:	db	'reach$'
word748:	db	'junction$'
word749:	db	'three$'
word750:	db	'canyons,$'
word751:	db	'bearing$'
word752:	db	'SE.$'
word753:	db	'combined.$'
word754:	db	'stalactite.$'
word755:	db	'circular$'
word756:	db	'slab$'
word757:	db	'fallen$'
word758:	db	'ceiling$'
word759:	db	'(Slab$'
word760:	db	'room).$'
word761:	db	'East$'
word762:	db	'once$'
word763:	db	'were$'
word764:	db	'they$'
word765:	db	'now$'
word766:	db	'Low,$'
word767:	db	'quickly$'
word768:	db	'bends$'
word769:	db	'Twopit$'
word770:	db	'littered$'
word771:	db	'thin$'
word772:	db	'slabs,$'
word773:	db	'easy$'
word774:	db	'descend$'
word775:	db	'pits.$'
word776:	db	'bypassing$'
word777:	db	'pits$'
word778:	db	'connect$'
word779:	db	'over,$'
word780:	db	'directly$'
word781:	db	'where$'
word782:	db	'eastern$'
word783:	db	'pool$'
word784:	db	'oil$'
word785:	db	'corner$'
word786:	db	'western$'
word787:	db	'Giant$'
word788:	db	'lamp$'
word789:	db	'show$'
word790:	db	'Cavernous$'
word791:	db	'On$'
word792:	db	'scrawled$'
word793:	db	'inscription,$'
word794:	db	'"Fee$'
word795:	db	'Fie$'
word796:	db	'Foe$'
word797:	db	'Foo"$'
word798:	db	'{sic}.$'
word799:	db	'magnificent$'
word800:	db	'rushing$'
word801:	db	'cascades$'
word802:	db	'sparkling$'
word803:	db	'waterfall$'
word804:	db	'roaring$'
word805:	db	'whirlpool$'
word806:	db	'dis'
word806a:	db	'appears$'
word807:	db	'steep$'
word808:	db	'incline$'
word809:	db	'alike.$'
word810:	db	'level.$'
word811:	db	'outside$'
word812:	db	'again.$'
word813:	db	'valley.$'
word814:	db	'streambed.$'
word815:	db	'grate.$'
word816:	db	'cobble$'
word817:	db	'dim$'
word818:	db	'"Magic$'
word819:	db	'word$'
word820:	db	'XYZZY".$'
word821:	db	'nugget$'
word822:	db	'gold$'
word823:	db	'explosion,$'
word824:	db	'machine.$'
word825:	db	'"Y2".$'
word826:	db	'Mt$'
word827:	db	'stream.$'
word828:	db	'Shell$'
word829:	db	'cul-de-sac.$'
word830:	db	'anteroom.$'
word831:	db	'Bedquilt.$'
word832:	db	'path.$'
word833:	db	'cheese$'
word834:	db	'mass$'
word835:	db	'boulders$'
word836:	db	'--$'
word837:	db	'Alcove.$'
word838:	db	'canyons.$'
word839:	db	'Slab$'
word840:	db	'Two$'
word841:	db	'Pit$'
word842:	db	'inc'
word842a:	db	'line.$'
word843:	db	'rickety$'
word844:	db	'wooden$'
word845:	db	'bridge$'
word846:	db	'chasm,$'
word847:	db	'vanishing$'
word848:	db	'reads,$'
word849:	db	'"STOP!$'
word850:	db	'Pay$'
word851:	db	'troll!"$'
word853:	db	'(and$'
word857:	db	'burly$'
word858:	db	'troll$'
word859:	db	'stands$'
word860:	db	'insists$'
word861:	db	'him$'
word862:	db	'cross.$'
word864:	db	'scurries$'
word865:	db	'bridge,$'
word866:	db	'800$'
word867:	db	'pound$'
word868:	db	'bear,$'
word869:	db	'collapses$'
word870:	db	'currently$'
word871:	db	'holding$'
word872:	db	'following:$'
word873:	db	'carrying$'
word874:	db	'anything.$'
word875:	db	'carry$'
word876:	db	'anything$'
word877:	db	'more.$'        ;(used only by sent257)
word878:	db	'You',39,'ll$'  ;(used only by sent257)
word879:	db	'something$'
word880:	db	'first.$'       ;(used only by sent257)
word881:	db	'locked$'
word882:	db	'grate!$'
word883:	db	'I$'
word885:	db	'what$'
word886:	db	'want$'
word887:	db	'no$'
word889:	db	'you',39,'re$'
word891:	db	'will$'
word892:	db	'stuck$'
word893:	db	'tunnel.$'
word894:	db	'Drop$'
word895:	db	'through.$'
word896:	db	'don',39,'t$'
word897:	db	'enough$'
word898:	db	'clam.$'
word899:	db	'glistening$'
word900:	db	'pearl$'
word901:	db	'falls$'
word903:	db	'rolls$'
word904:	db	'away.$'
word905:	db	'rustling$'
word906:	db	'darkness$'
word907:	db	'Out$'
word908:	db	'shadows$'
word909:	db	'pounces$'
word910:	db	'bearded$'
word911:	db	'pirate!$'
word912:	db	'"Har,$'
word913:	db	'har,$'
word914:	db	'"he$'
word915:	db	'chortles,$'
word916:	db	'"I',39,'ll$'
word917:	db	'just$'
word918:	db	'booty$'
word919:	db	'hide$'
word920:	db	'me$'
word921:	db	'maze!"$'
word922:	db	'He$'
word923:	db	'snatches$'
word924:	db	'vanishes$'
word925:	db	'gloom.$'
word926:	db	'set$'
word927:	db	'keys$'
word928:	db	'shiny$'
word929:	db	'brass$'
word930:	db	'nearby.$'
word931:	db	'tasty$'
word932:	db	'food$'
word933:	db	'bottle$'
word934:	db	'Wicker$'
word935:	db	'cage$'
word936:	db	'sitting$'
word937:	db	'cute$'
word938:	db	'black$'
word939:	db	'rod$'
word940:	db	'rusty$'
word941:	db	'star$'
word942:	db	'lies$'
word943:	db	'axe$'
word944:	db	'laying$'
word945:	db	'pillow$'
word946:	db	'here!$'
word947:	db	'golden$'
word948:	db	'chain$'
word949:	db	'copies$'
word950:	db	'Spelunker$'
word951:	db	'Today$'
word952:	db	'magazine$'
word953:	db	'beautiful$'
word954:	db	'green$'
word955:	db	'emerald$'
word956:	db	'ancient$'
word957:	db	'Ming$'
word958:	db	'Dynasty$'
word959:	db	'vase$'
word960:	db	'rare$'
word961:	db	'Persian$'
word962:	db	'rug$'
word963:	db	'platinum$'
word964:	db	'pyramid$'
word966:	db	'diamonds$'
word967:	db	'brown$'
word968:	db	'bear$'
word969:	db	'eggs$'
word970:	db	'trident$'
word971:	db	'bars$'
word972:	db	'silver$'
word973:	db	'fine$'
word974:	db	'jewelry$'
word975:	db	'being$'
word976:	db	'followed$'
word977:	db	'tame$'
word978:	db	'bear.$'
word979:	db	'Your$'
word980:	db	'off.$'
word981:	db	'cannot$'
word982:	db	'Nothing$'
word983:	db	'happens.$'
word984:	db	'Do$'
word985:	db	'really$'
word986:	db	'now?$'
word987:	db	'nothing$'
word988:	db	'attack.$'
word989:	db	'fierce$'
word990:	db	'snake$'
word991:	db	'way!$'
word992:	db	'Attacking$'
word993:	db	'doesn',39,'t$'
word994:	db	'work$'
word995:	db	'dangerous.$'
word996:	db	'With$'
word997:	db	'hands?$'
word998:	db	'might$'
word999:	db	'catch$'
word1000:	db	'bird,$'
word1001:	db	'was$'
word1002:	db	'unafraid$'
word1003:	db	'when$'
word1004:	db	'entered,$'
word1005:	db	'approach$'
word1006:	db	'disturbed$'
word1007:	db	'attacks$'
word1008:	db	'snake,$'
word1009:	db	'astounding$'
word1010:	db	'flurry$'
word1011:	db	'drives$'
word1012:	db	'Oh$'
word1013:	db	'dear.$'
word1014:	db	'nasty$'
word1015:	db	'hit$'
word1016:	db	'you!$'
word1017:	db	'dwarf$'
word1018:	db	'corner,$'
word1019:	db	'saw$'
word1020:	db	'threw$'
word1021:	db	'missed$'
word1022:	db	'cursed$'
word1023:	db	'ran$'
word1024:	db	'killed$'
word1025:	db	'dwarf.$'
word1026:	db	'dwarf,$'
word1027:	db	'he$'
word1028:	db	'dodges$'
word1029:	db	'way.$'
word1030:	db	'stabs$'
word1031:	db	'his$'
word1032:	db	'knife!$'
word1033:	db	'massive$'
word1034:	db	'metal$'
word1035:	db	'door$'
word1036:	db	'closed.$'
word1037:	db	'open.$'
word1040:	db	'chain!$'
word1042:	db	'climb.$'
word1043:	db	'Brass$'
word1044:	db	'lantern$'
word1045:	db	'Tasty$'
word1046:	db	'Glass$'
word1047:	db	'Black$'
word1048:	db	'Cute$'
word1049:	db	'Axe$'
word1050:	db	'Soft$'
word1051:	db	'Oil$'
word1052:	db	'Coins$'
word1053:	db	'Golden$'
word1054:	db	'Magazines$'
word1055:	db	'Glistening$'
word1056:	db	'Green$'
word1057:	db	'Pyramid$'
word1058:	db	'Diamonds$'
word1059:	db	'Brown$'
word1060:	db	'Trident$'
word1061:	db	'Gold$'
word1062:	db	'Silver$'
word1063:	db	'Somewhere$'
word1064:	db	'nearby$'
word1065:	db	'MyAdvent$'
word1066:	db	'& Don Woods (1976).$'
word1067:	db	'others$'
word1068:	db	'found$'
word1069:	db	'fortunes$'
word1070:	db	'gold,$'
word1071:	db	'though$'
word1072:	db	'rumored$'
word1073:	db	'never$'
word1074:	db	'Magic$'
word1075:	db	'said$'
word1076:	db	'cave.$'
word1077:	db	'eyes$'
word1078:	db	'hands.$'
word1079:	db	'Direct$'
word1080:	db	'commands$'
word1081:	db	'1$'
word1082:	db	'2$'
word1083:	db	'words.$'
word1084:	db	'should$'
word1085:	db	'warn$'
word1086:	db	'first$'
word1087:	db	'letters$'
word1088:	db	'each$'
word1089:	db	'word.$'
word1090:	db	'Should$'
word1091:	db	'stuck,$'
word1092:	db	'type$'
word1093:	db	'"HELP"$'
word1094:	db	'general$'
word1095:	db	'hints.$'
word1096:	db	'know$'
word1097:	db	'places,$'
word1098:	db	'actions,$'
word1099:	db	'things.$'
word1100:	db	'Most$'
word1101:	db	'my$'
word1102:	db	'vocabulary$'
word1103:	db	'describes$'
word1104:	db	'places$'
word1105:	db	'used$'
word1106:	db	'move$'
word1107:	db	'there.$'
word1108:	db	'move,$'
word1109:	db	'try$'
word1110:	db	'FOREST,$'
word1111:	db	'BUILDING,$'
word1112:	db	'DOWNSTREAM,$'
word1113:	db	'ENTER,$'
word1114:	db	'EAST,$'
word1115:	db	'WEST,$'
word1116:	db	'few$'
word1117:	db	'special$'
word1118:	db	'objects,$'
word1119:	db	'hidden$'
word1120:	db	'These$'
word1121:	db	'objects$'
word1122:	db	'manipulated$'
word1123:	db	'using$'
word1124:	db	'action$'
word1125:	db	'know.$'
word1126:	db	'Usually$'
word1127:	db	'need$'
word1128:	db	'give$'
word1129:	db	'object$'
word1130:	db	'(in$'
word1131:	db	'order),$'
word1132:	db	'sometimes$'
word1133:	db	'infer$'
word1134:	db	'verb$'
word1135:	db	'alone.$'
word1136:	db	'Some$'
word1137:	db	'imply$'
word1138:	db	'verbs;$'
word1139:	db	'particular,$'
word1140:	db	'"INVENTORY"$'
word1141:	db	'implies$'
word1142:	db	'"TAKE$'
word1143:	db	'INVENTORY",$'
word1144:	db	'causes$'
word1145:	db	'list$'
word1146:	db	'carrying.$'
word1147:	db	'effects;$'
word1148:	db	'instance,$'
word1149:	db	'scares$'
word1150:	db	'bird.$'
word1151:	db	'people$'
word1152:	db	'trouble$'
word1153:	db	'moving$'
word1154:	db	'more$'
word1155:	db	'trying$'
word1156:	db	'unsuccessfully$'
word1157:	db	'manipulate$'
word1158:	db	'attempting$'
word1159:	db	'their$'
word1160:	db	'(or$'
word1161:	db	'my!$'
word1162:	db	')$'
word1163:	db	'capabilities$'
word1164:	db	'different$'
word1165:	db	'tack.$'
word1166:	db	'speed$'
word1167:	db	'game,$'
word1168:	db	'distances$'
word1169:	db	'single$'
word1170:	db	'For$'
word1171:	db	'example,$'
word1172:	db	'"BUILDING"$'
word1173:	db	'usually$'
word1174:	db	'gets$'
word1175:	db	'anywhere$'
word1176:	db	'ground$'
word1177:	db	'lost$'
word1178:	db	'Also,$'
word1179:	db	'turn$'
word1180:	db	'lot,$'
word1181:	db	'leaving$'
word1182:	db	'does$'
word1183:	db	'guarantee$'
word1184:	db	'entering$'
word1185:	db	'Good$'
word1186:	db	'luck!$'
word1187:	db	'direction$'
word1188:	db	'proceed$'
word1189:	db	'direction!$'
word1190:	db	'Sorry.$'
word1191:	db	'Please$'
word1192:	db	'Huh?$'
word1193:	db	'keys!$'
word1194:	db	'locked.$'
word1195:	db	'unlocked.$'
word1196:	db	'crystalline$'
word1197:	db	'spans$'
word1198:	db	'past$'
word1199:	db	'snake.$'
word1200:	db	'pitch$'
word1201:	db	'dark.$'
word1202:	db	'likely$'
word1203:	db	'fall$'
word1204:	db	'hollow$'
word1205:	db	'voice$'
word1206:	db	'"Plugh"$'
word1207:	db	'dragon$'
word1208:	db	'sprawled$'
word1209:	db	'rug.$'
word1210:	db	'dragon.$'
word1211:	db	'tablet$'
word1212:	db	'imbedded$'
word1213:	db	'reads: "Congratulations$'
word1214:	db	'bringing$'
word1215:	db	'plant$'
word1216:	db	'murmuring$'
word1217:	db	'"Water,$'
word1218:	db	'water,$'
word1219:	db	'.$'
word1220:	db	'spurts$'
word1221:	db	'furious$'
word1222:	db	'growth$'
word1223:	db	'seconds.$'
word1224:	db	'12-foot-tall$'
word1225:	db	'beanstalk$'
word1226:	db	'bellowing$'
word1227:	db	'"WATER!$'
word1228:	db	'!$'
word1229:	db	'WATER!$'
word1230:	db	'grows$'
word1231:	db	'explosively,$'
word1232:	db	'filling$'
word1233:	db	'over-watered$'
word1234:	db	'plant!$'
word1235:	db	'shriveled$'
word1236:	db	'up!$'
word1237:	db	'gigantic$'
word1238:	db	'door,$'
word1239:	db	'hinges$'
word1240:	db	'rusted,$'
word1241:	db	'opened$'
word1242:	db	'oil.$'
word1243:	db	'Thud.$'
word1244:	db	'Did$'
word1245:	db	'something?$'
word1246:	db	'Smash!$'
word1247:	db	'land$'
word1248:	db	'on,$'
word1249:	db	'hits$'
word1250:	db	'All$'
word1251:	db	'pieces$'
word1252:	db	'magically$'
word1253:	db	'vanish.$'
word1254:	db	'source$'
word1255:	db	'light.$'
word1259:	db	'food.$'
word1261:	db	'hungry$'
word1262:	db	'eats$'
word1263:	db	'released$'
word1264:	db	'unlocked$'
word1265:	db	'purpose.$'
word1266:	db	'One$'
word1267:	db	'feeds$'
word1268:	db	'waste$'
word1269:	db	'water!$'
word1270:	db	'do$'
word1271:	db	'see$'
word1272:	db	'water.$'
word1273:	db	'bottle.$'
word1274:	db	'Go$'
word1275:	db	'find$'
word1276:	db	'"fill$'
word1277:	db	'bottle".$'
word1279:	db	'rank$'
word1280:	db	'amateur.$'
word1281:	db	'Better$'
word1282:	db	'luck$'
word1283:	db	'time.$'
word1284:	db	'qualifies$'
word1285:	db	'novice-class$'
word1286:	db	'adventurer.$'
word1287:	db	'achieved$'
word1288:	db	'rating;$'
word1289:	db	'"Experienced$'
word1290:	db	'Adventurer".$'
word1291:	db	'consider$'
word1292:	db	'yourself$'
word1293:	db	'"Seasoned$'
word1294:	db	'reached$'
word1295:	db	'"Junior$'
word1296:	db	'Master"$'
word1297:	db	'status.$'
word1298:	db	'puts$'
word1299:	db	'Master$'
word1300:	db	'Adventurer$'
word1301:	db	'class$'
word1302:	db	'C.$'
word1303:	db	'B.$'
word1304:	db	'A.$'
word1305:	db	'Adventuredom$'
word1306:	db	'gives$'
word1307:	db	'tribute$'
word1308:	db	'Grandmaster!$'
word1309:	db	'needs$'
word1310:	db	'vanished!$'
word1311:	db	'Wave$'
word1312:	db	'what?$'
word1313:	db	'cage.$'
word1314:	db	'flies$'
word1315:	db	'nest.$'
word1318:	db	'"open"$'
word1319:	db	'named$'
word1320:	db	'now.$'
word1321:	db	'shell$'
word1322:	db	'opens$'
word1323:	db	'moment$'
word1324:	db	'reveal$'
word1325:	db	'be.$'
word1328:	db	'lamp.$'
word1329:	db	'(nugget)$'
word1330:	db	'opportunity$'
word1331:	db	'"free"$'
word1332:	db	'"take"$'
word1333:	db	'Beyond$'
word1334:	db	'glow$'
word1335:	db	'see.$'
word1336:	db	'dark$'
word1337:	db	'dear,$'
word1338:	db	'everything$'
word1339:	db	'including$'
word1340:	db	'scoreboard!$'
word1341:	db	'Poof!$'
word1342:	db	'while$'
word1343:	db	'dangerous$'
word1344:	db	'Congratulations!$'
word1345:	db	'vanquished$'
word1346:	db	'hands!$'
word1347:	db	'makes$'
word1348:	db	'bright.$'
word1349:	db	'think$'
word1350:	db	'"unlock$'
word1351:	db	'grate".$'
word1353:	db	'Adventure$'
word1354:	db	'based$'
word1355:	db	'mostly$'
word1356:	db	'text$'
word1357:	db	'Will$'
word1358:	db	'Crowther$'
word1359:	db	'(1975)$'
word1360:	db	'game$'
word1361:	db	'new$'
word1362:	db	'8080$'
word1363:	db	'assembly$'
word1364:	db	'code$'
word1365:	db	'written$'
word1366:	db	'George$'
word1367:	db	'Kauffman$'
word1368:	db	'(2011).$'
word1369:	db	'uses$'
word1370:	db	'navigation$'
word1371:	db	'350$'
word1372:	db	'maps.$'
word1373:	db	'Once$'
word1374:	db	'loaded,$'
word1375:	db	'32$'
word1376:	db	'kilobytes$'
word1377:	db	'ram$'
word1378:	db	'disk$'
word1379:	db	'access.$'
word1380:	db	'65$'
word1381:	db	'words,$'
word1382:	db	'36$'
word1383:	db	'125$'
word1384:	db	'rooms,$'
word1385:	db	'487$'
word1386:	db	'sentences$'
word1387:	db	'1543$'
word1388:	db	'Scoring:$'
word1389:	db	'1/room$'
word1390:	db	'(125)$'
word1391:	db	'8/treasure$'
word1392:	db	'(15),$'
word1393:	db	'10/puzzle$'
word1394:	db	'(10)$'
word1395:	db	'maximum.$'
word1396:	db	'Action$'
word1397:	db	'Words:$'
word1398:	db	'Object$'
word1399:	db	'words:$'
word1400:	db	'Jewelry$'
word1401:	db	'getting$'
word1402:	db	'dim.$'
word1403:	db	'Are$'
word1404:	db	'fresh$'
word1405:	db	'batteries?$'
word1406:	db	'battery$'
word1407:	db	'dead.$'
word1408:	db	'Is$'
word1409:	db	'nearby?$'
word1410:	db	'total$'
word1411:	db	'darkness.$'
word1412:	db	'As$'
word1413:	db	'pirate$'
word1414:	db	'making$'
word1415:	db	'hasty$'
word1416:	db	' edition$'
word1417:	db	'January$'
word1418:	db	'February$'
word1419:	db	'March$'
word1420:	db	'April$'
word1421:	db	'May$'
word1422:	db	'June$'
word1423:	db	'July$'
word1424:	db	'August$'
word1425:	db	'September$'
word1426:	db	'October$'
word1427:	db	'November$'
word1428:	db	'December$'
word1429:	db	'have.$'
word1430:	db	'held.$'
word1431:	db	'points.$'
word1432:	db	'350$'
word1433:	db	'340$'
word1434:	db	'270$'
word1435:	db	'200$'
word1436:	db	'130$'
word1437:	db	'75$'
word1438:	db	'25$'
word1439:	db	'crawled$'
word1440:	db	'instructions$'
word1441:	db	'read:$'
word1442:	db	'"Drop$'
word1443:	db	'receive$'
word1444:	db	'batteries".$'
word1445:	db	' puzzle$'
word1446:	db	'body$'
word1447:	db	'greasy$'
word1448:	db	'smoke.$'
word1449:	db	'sepulchral$'
word1450:	db	'reverberating$'	
word1451:	db	'closing$'	
word1452:	db	'soon.$'	
word1453:	db	'adventurers$'	
word1454:	db	'immediately$'	
word1455:	db	'Main$'	
word1456:	db	'Office."$'	
word1457:	db	'blast$'
Word1458:	db	'detonate$'
word1459:	db	'intones,$'
word1460:	db	'"The$'
word1461:	db	'closed."$'
word1462:	db	'echoes$'
word1463:	db	'fade,$'
word1464:	db	'blinding$'
word1465:	db	'flash$'
word1466:	db	'puff$'
word1467:	db	'smoke). . . .$'
word1470:	db	'refocus,$'
word1471:	db	'find...$'
word1472:	db	'twenty-foot$'
word1473:	db	'burying$'
word1474:	db	'dwarves$'
word1475:	db	'rubble.$'
word1476:	db	'Office,$'
word1477:	db	'cheering band$'
word1478:	db	'friendly elves$'
word1489:	db	'conquering adventurer$'
word1490:	db	'sunset.$'
word1491:	db	'even larger than$'	
word1492:	db	'repository$'	
word1493:	db	'"Adventure" program.$'	
word1494:	db	'Massive torches$'	
word1495:	db	'bathe$'	
word1496:	db	'smoky yellow$'	
word1497:	db	'Scattered$'	
word1498:	db	'bottles$'	
word1499:	db	'northeast$'	
word1500:	db	'(all$'	
word1501:	db	'them empty),$'	
word1502:	db	'nursery$'	
word1503:	db	'young beanstalks$'	
word1504:	db	'quietly,$'	
word1505:	db	'oysters,$'	
word1506:	db	'bundle$'	
word1507:	db	'rods$'	
word1508:	db	'stars$'	
word1509:	db	'ends,$'	
word1510:	db	'collection$'	
word1511:	db	'lanterns.$'	
word1512:	db	'Off$'
word1513:	db	'many$'	
word1514:	db	'sleeping$'	
word1515:	db	'snoring loudly.$'	
word1516:	db	'southwest$'	
word1517:	db	'Repository.$'	
word1518:	db	'snakes.$'	
word1519:	db	'cages,$'	
word1520:	db	'contains$'	
word1521:	db	'sulking$'	
word1522:	db	'marks$'	
word1523:	db	'ends.$'	
word1524:	db	'"Do$'	
word1525:	db	'disturb$'	
word1526:	db	'dwarves!"$'	
word1527:	db	'against$'	
word1528:	db	'stretches$'	
word1529:	db	'various$'	
word1530:	db	'sundry$'	
word1531:	db	'glimpsed$'	
word1532:	db	'number$'	
word1533:	db	'velvet pillows$'	
word1534:	db	'scattered$'	
word1535:	db	'grate,$'	
word1536:	db	'"Treasure Vault.$'	
word1537:	db	'Keys$'	
word1538:	db	'dynamite$'
word1539:	db	'burned$'
word1540:	db	'cinder.$'
word1541:	db	'blow$'
word1542:	db	'How?$'
word1543:	db	'Colossal Cave,$'
word1544:	db	'spices$'
word1545:	db	'walk$'
word1546:	db	'run$'
word1547:	db	'where?$'
word1548:	db	'well.$'
word1549:	db	'probably$'
word1550:	db	'chain,$'
word1551:	db	'ferocious$'
word1552:	db	'eying$'
word1553:	db	'room!$'
word1554:	db	'contented-looking$'
word1555:	db	'wandering$'
word1556:	db	'wants$'
word1557:	db	'(except perhaps you).$'
word1558:	db	'mistakes, the Delete key erases$'
word1559:	db	'/$'
word1560:	db	'backspace key.$'
;
;
sent1:	dw	word60,word61,word62,word64,word65,word66,word67,0
sent2:	dw	word68,word69,word70,word71,word72,word73,word74,word75,word76,word77,word75,word78,word79,word80,word81,word65,word82,word75,word83,word84,word78,word85,word86,word87,word74,word72,word26,word88,word13,word75,word89,0
sent3:	dw	word68,word69,word90,word75,word91,word75,word92,word93,word94,word75,word95,word96,0
sent4:	dw	word68,word69,word71,word72,word97,word98,word99,word76,word100,word12,word75,word101,word102,word103,0
sent5:	dw	word68,word104,word105,word12,word75,word106,word107,word108,word72,word83,word99,word76,word109,word110,word13,word72,word111,word112,word74,word72,word113,word114,word82,word75,word26,word108,word72,word115,0
sent6:	dw	word68,word69,word108,word38,word27,word116,word117,word75,word118,word88,word75,word119,0
sent7:	dw	word68,word69,word108,word38,word120,word121,word75,word122,word118,word61,word123,word124,0
sent8:	dw	word68,word69,word108,word75,word118,word108,word72,word27,word125,word75,word85,word126,word127,word75,word128,word129,0
sent9:	dw	word130,word131,word132,word133,word72,word48,word74,word72,word85,word134,word135,word75,word136,word137,word108,word72,word138,word139,word72,word140,word82,word141,word138,0
sent10:	dw	word68,word69,word108,word75,word142,word143,word144,word121,word141,word145,word146,word135,word72,word147,word82,word75,word148,word149,word150,word151,word108,word152,word84,word153,word140,word154,word135,word72,word155,0
sent11:	dw	word68,word69,word108,word75,word78,word156,word157,word75,word158,word149,word150,word61,word72,word159,word84,word160,word161,word162,word163,word154,word164,word61,word72,word165,0
sent12:	dw	word84,word160,word166,word167,word121,word163,word168,word169,word121,word170,word88,word171,word172,word173,word174,word175,word176,word154,word177,word88,word165,0
sent13:	dw	word68,word69,word108,word75,word171,word46,word178,word121,word179,word180,word108,word181,word72,word159,0
sent14:	dw	word68,word69,word108,word75,word156,word121,word75,word167,word61,word72,word4,word88,word182,word183,word184,word185,0
sent15:	dw	word68,word69,word108,word75,word186,word156,word187,word132,word188,word99,word189,word69,word190,word191,word74,word192,word193,word194,word175,word176,word88,word75,word195,word167,word29,word181,word5,word88,word4,word196,word74,word72,word197,word84,word198,word199,word200,word201,word202,0
sent16:	dw	word203,word71,word204,word74,word78,word205,word130,word131,word132,word82,word75,word78,word206,word207,word208,word74,word209,word210,word194,word5,word167,word211,word212,word213,word94,word75,word78,word214,word215,word216,word217,word218,word219,word220,word13,word72,word205,0
sent17:	dw	word68,word69,word71,word123,word73,word74,word75,word221,word222,word74,word223,word224,word225,word87,word74,word226,word61,word72,word227,word178,word121,word228,word74,word209,word229,word230,word231,word61,word88,word232,word233,word234,word235,word236,word217,word218,word219,word220,word12,word61,word75,word167,word71,word72,word204,word74,word75,word237,word238,word103,word84,word166,word239,word240,word241,word135,word72,word242,word75,word243,word244,word245,word12,word181,word246,word114,word69,word78,word247,word61,word72,word6,word88,word248,word88,word75,word78,word214,word154,word185,0
sent18:	dw	word203,word40,word72,word5,word249,word74,word75,word250,word99,word229,word82,word251,word252,word172,word88,word72,word253,word82,word254,word166,word61,word255,0
sent19:	dw	word68,word69,word40,word72,word4,word249,word74,word72,word253,word108,word72,word256,word74,word257,0
sent20:	dw	word203,word108,word75,word160,word46,word121,word75,word258,word259,word40,word72,word260,word99,word259,word261,word262,word263,word37,word264,word12,word72,word265,0
sent21:	dw	word68,word69,word71,word72,word4,word73,word74,word256,word74,word257,word84,word160,word166,word161,word266,word4,word88,word267,word268,word269,word270,word72,word7,word82,word75,word271,word167,word272,word132,word41,word72,word273,0
sent22:	dw	word68,word69,word71,word72,word5,word73,word74,word75,word274,word275,word276,word277,word278,word112,word279,word270,word72,word280,word75,word160,word166,word161,word281,word282,word270,word72,word6,word283,word284,word285,word286,word281,word287,0
sent25:	dw	word68,word69,word71,word72,word4,word73,word74,word75,word274,word275,word294,word295,word99,word222,word296,word12,word121,word75,word297,word298,word299,0
sent26:	dw	word68,word69,word108,word75,word271,word300,word74,word301,word302,word133,word303,0
sent27:	dw	word68,word69,word108,word75,word300,word74,word301,word271,word302,word133,word303,0
sent28:	dw	word68,word69,word108,word75,word271,word300,word74,word304,word302,word133,word303,0
sent29:	dw	word68,word69,word108,word75,word301,word300,word74,word271,word302,word133,word303,0
sent30:	dw	word68,word69,word108,word75,word301,word271,word300,word74,word302,word133,word303,0
sent31:	dw	word68,word69,word108,word75,word304,word271,word300,word74,word302,word133,word303,0
sent32:	dw	word68,word69,word108,word75,word304,word300,word74,word271,word302,word133,word303,0
sent33:	dw	word68,word69,word108,word75,word271,word304,word300,word74,word302,word133,word303,0
sent34:	dw	word68,word69,word108,word75,word300,word74,word271,word301,word302,word133,word303,0
sent35:	dw	word68,word69,word108,word75,word300,word74,word271,word304,word302,word133,word303,0
sent36:	dw	word114,word82,word75,word1033,word308,word309,word202,word99,word1440,word40,word264,word1441,word1442,word318,word212,word61,word1443,word1404,word1444,0
sent37:	dw	word68,word69,word108,word75,word325,word74,word326,word121,word327,word328,0
sent38:	dw	word68,word69,word108,word75,word95,word329,word121,word75,word167,word61,word72,word248,word75,word167,word61,word72,word227,word88,word75,word330,word74,word331,word332,word61,word72,word185,word114,word82,word75,word95,word333,word40,word75,word332,word108,word72,word334,word335,0
sent39:	dw	word203,word71,word75,word160,word336,word337,word75,word338,word339,word340,word341,word12,word87,word74,word342,word84,word343,word82,word344,word345,word162,word346,word132,word246,word347,word74,word209,word229,word348,word72,word343,word74,word72,word339,word349,word350,word61,word72,word351,word352,word108,word72,word353,word283,word72,word336,word354,word355,word61,word356,word230,word357,word199,word200,word212,word358,word359,word360,word72,word206,word181,word65,word88,word361,word132,word362,word363,word82,word75,word364,word336,word365,word135,word75,word366,word367,word84,word368,word369,word370,word371,word372,word363,word373,word110,word71,word103,0
sent40:	dw	word203,word71,word75,word160,word336,word337,word75,word338,word339,word340,word341,word12,word87,word74,word342,word84,word343,word82,word344,word345,word162,word346,word132,word246,word347,word74,word209,word229,word348,word72,word343,word74,word72,word339,word349,word350,word61,word72,word374,word352,word108,word72,word353,word283,word72,word336,word354,word355,word61,word356,word230,word357,word199,word200,word212,word358,word359,word360,word72,word206,word181,word65,word88,word361,word132,word362,word363,word82,word75,word364,word336,word365,word135,word75,word366,word367,word84,word368,word369,word370,word371,word372,word363,word373,word110,word71,word103,0
sent41:	dw	word68,word69,word108,word75,word160,word291,word167,word71,word75,word286,word108,word72,word273,word99,word286,word268,word13,word61,word174,word292,word299,0
sent42:	dw	word68,word69,word108,word72,word256,word74,word72,word375,word376,word121,word247,word41,word108,word133,word377,0
sent43:	dw	word68,word69,word108,word72,word4,word112,word156,word74,word72,word256,word74,word72,word375,word378,word84,word167,word266,word4,word88,word12,word202,0
sent44:	dw	word68,word69,word108,word72,word7,word112,word156,word321,word61,word72,word256,word74,word72,word375,word378,0
sent45:	dw	word68,word69,word108,word75,word379,word176,word340,word212,word240,word380,word381,word382,word162,word75,word274,word383,word176,word384,word132,word246,word385,word65,word386,word13,word65,word387,word388,word371,word389,word61,word37,word110,word282,0
sent46:	dw	word68,word69,word108,word75,word379,word291,word176,word238,word75,word95,word367,0
sent47:	dw	word68,word69,word108,word75,word298,word176,word390,word361,word132,word391,word99,word343,word82,word392,word393,word209,word229,word394,word108,word181,word72,word269,word99,word189,word395,word177,word94,word92,word162,word396,word397,word398,word181,word399,word400,word401,word402,word238,word403,word174,word307,word404,word405,word82,word406,word407,word61,word88,word408,word409,word72,word176,word410,word411,word405,word82,word412,word413,word94,word72,word414,word74,word72,word415,word416,word234,word65,word417,word69,word418,word419,word84,word78,word336,word370,word371,word372,word108,word420,word421,word399,word422,word132,word282,0
sent48:	dw	word68,word69,word108,word75,word379,word423,word176,word121,word247,word61,word72,word6,word88,word185,0
sent49:	dw	word68,word69,word40,word72,word424,word425,word74,word75,word95,word426,word427,word84,word252,word428,word74,word209,word229,word429,word72,word329,word430,word181,word72,word431,word74,word72,word48,word88,word432,word433,word434,word99,word435,word82,word436,word393,word75,word437,word340,word438,word87,word74,word75,word286,word108,word72,word330,word390,word439,word132,word440,word88,word134,word441,word135,word72,word48,word116,word72,word442,word443,word260,word84,word444,word167,word445,word446,word72,word443,word421,word173,word65,word447,word37,word360,word72,word48,word61,word37,word61,word324,word448,word167,word154,word7,word181,word202,0
sent50:	dw	word68,word69,word108,word72,word449,word450,word114,word82,word75,word451,word452,word172,word453,word102,word75,word454,0
sent51:	dw	word68,word69,word108,word75,word95,word46,word455,word74,word456,word457,word114,word82,word75,word458,word286,word108,word72,word273,word114,word69,word327,word459,word88,word75,word167,word215,word185,0
sent52:	dw	word203,word108,word75,word460,word167,word121,word331,word457,word270,word72,word5,word82,word75,word461,word270,word72,word4,word82,word75,word95,word299,word462,word65,word82,word75,word286,word61,word267,word299,0
sent53:	dw	word68,word69,word40,word72,word463,word74,word75,word78,word464,word465,word205,word84,word161,word154,word165,0
sent54:	dw	word68,word69,word108,word72,word466,word74,word75,word78,word206,word121,word75,word271,word437,word340,word467,word88,word445,word446,word468,word469,0
sent55:	dw	word68,word69,word71,word75,word470,word471,word84,word160,word472,word88,word473,word167,word181,word72,word6,word296,word75,word474,word161,word181,word72,word5,word61,word475,word75,word476,word167,word477,word165,word114,word82,word478,word75,word95,word46,word479,word99,word480,word82,word481,word202,0
sent56:	dw	word68,word69,word108,word75,word46,word121,word174,word307,word482,word483,word484,word114,word82,word75,word167,word61,word72,word248,word75,word465,word286,word238,word88,word75,word78,word286,word108,word72,word343,word477,word287,0
sent57:	dw	word68,word69,word108,word174,word485,word295,word114,word82,word75,word286,word108,word72,word343,word477,word287,0
sent58:	dw	word68,word69,word108,word75,word275,word183,word486,word121,word487,word488,word410,0
sent59:	dw	word68,word69,word108,word75,word489,word390,word490,word132,word391,0
sent60:	dw	word68,word69,word108,word174,word491,word215,word61,word75,word95,word167,word61,word72,word185,word492,word247,word386,word4,word88,word282,word99,word493,word74,word494,word495,word69,word496,word84,word497,word108,word498,word212,word499,word500,word501,word502,word503,word306,word504,word505,word71,word506,word507,word508,word509,word510,0
sent61:	dw	word203,word71,word511,word512,word513,word220,word41,word108,word514,word377,0
sent62:	dw	word68,word69,word108,word515,word75,word275,word516,word167,word121,word517,word328,word270,word518,word71,word519,word520,word521,word522,word523,word524,word525,0
sent63:	dw	word68,word69,word108,word75,word95,word160,word367,word526,word220,word527,word528,word88,word529,0
sent64:	dw	word68,word69,word108,word75,word530,word73,word161,word238,word75,word95,word160,word367,0
sent65:	dw	word68,word69,word108,word75,word275,word531,word486,word183,word87,word74,word226,word108,word117,word377,0
sent66:	dw	word68,word69,word40,word123,word112,word74,word75,word532,word122,word533,word84,word534,word209,word229,word430,word12,word181,word535,word536,word133,word537,word74,word72,word402,word124,word84,word538,word182,word154,word362,word181,word72,word539,word135,word75,word531,word540,0
sent67:	dw	word68,word69,word40,word72,word402,word112,word74,word72,word533,word84,word541,word182,word154,word362,word181,word72,word539,word40,word306,word124,0
sent68:	dw	word68,word69,word108,word75,word542,word297,word292,word486,word224,word87,word74,word226,word61,word72,word165,word84,word543,word544,word545,word370,word371,word546,word108,word72,word115,0
sent69:	dw	word203,word108,word75,word540,word99,word182,word547,word202,word99,word548,word549,word154,word550,word84,word551,word544,word552,word61,word37,word553,word108,word230,word554,word99,word555,word549,word154,word556,word13,word75,word557,word558,word99,word559,word486,word467,word181,word72,word165,0
sent70:	dw	word68,word69,word476,word127,word75,word560,word183,word298,word167,word561,word121,word562,word563,word564,word565,0
sent71:	dw	word68,word69,word70,word71,word72,word566,word61,word75,word532,word567,word367,word84,word497,word568,word238,word72,word566,word569,word570,word571,word108,word572,0
sent72:	dw	word68,word69,word108,word72,word567,word367,word99,word573,word74,word72,word46,word82,word574,word575,word213,word94,word399,word576,word352,word108,word72,word353,word220,word362,word577,word72,word402,word73,word74,word72,word367,word99,word578,word29,word82,word72,word579,word65,word580,word581,0
sent73:	dw	word68,word69,word108,word75,word471,word99,word189,word69,word251,word582,word202,word583,word72,word6,word370,word371,word546,word75,word584,word585,word586,word587,word230,word72,word588,word589,word552,word61,word371,word590,word448,word167,word154,word248,word88,word75,word160,word161,word268,word185,0
sent74:	dw	word68,word69,word108,word75,word78,word156,word178,word121,word95,word591,0
sent75:	dw	word68,word69,word40,word72,word425,word74,word75,word592,word593,word594,word535,word65,word82,word174,word595,word596,word181,word340,word597,word598,word74,word599,word600,word601,word602,word603,word604,word110,word13,word135,word72,word605,word99,word606,word332,word429,word72,word607,word608,word74,word72,word609
	dw	word121,word75,word610,word611,word612,word613,word174,word614,word615,word616,word99,word480,word82,word178,word121,word617,word618,word74,word619,word88,word75,word534,word620,word74,word621,word99,word189,word69,word622,word61,word72,word623,word88,word72,word624,word74,word72,word625,word626,word87,word133
	dw	word111,word627,word628,word108,word72,word629,word630,word402,word440,word69,word631,word632,word633,word634,word74,word635,word209,word636,word340,word637,word72,word638,word639,word135,word640,word641,word642,word72,word410,word270,word123,word112,word82,word75,word122,word643,word178,word121,word75,word644,word645,word74
	dw	word646,word332,word340,word552,word61,word104,word200,word647,word393,word72,word648,word649,word194,word650,word651,word74,word652,word653,word87,word181,word72,word654,word74,word72,word596,word655,word656,word579,word446,word72,word643,word88,word657,word135,word75,word658,word206,word402,word41,word61,word131,word374,word63
	dw	word659,word72,word643,word72,word566,word61,word75,word118,word82,word660,word661,word270,word72,word662,word174,word650,word663,word74,word664,word665,word666,word667,word181,word75,word567,word668,word108,word72,word573,word74,word75,word669,word670,word340,word671,word672,word99,word402,word555,word330
	dw	word82,word75,word673,word121,word174,word674,word74,word656,word675,word340,word676,word174,word677,word678,word679,word61,word72,word680,word681,word682,word84,word683,word684,word167,word445,word61,word72,word685,0
sent76:	dw	word686,word82,word72,word687,word367,word688,word689,word589,word690,word348,word72,word410,word84,word560,word183,word167,word154,word177,word61,word72,word527,word267,word167,word154,word528,word88,word75,word472,word88,word473,word161,word154,word165,0
sent77:	dw	word68,word69,word108,word75,word46,word691,word189,word692,word693,word694,word695,word247,word386,word227,word280,word696,word88,word697,word698,word74,word72,word46,word82,word699,word393,word75,word95,word700,word701,0
sent78:	dw	word68,word69,word108,word72,word702,word367,word99,word189,word69,word392,word121,word534,word703,word72,word343,word121,word75,word252,word704,word705,word706,word707,word72,word708,0
sent79:	dw	word68,word69,word108,word75,word709,word292,word710,word84,word160,word383,word161,word268,word711,word132,word6,word88,word552,word61,word38,word282,0
sent80:	dw	word712,word98,0
sent81:	dw	word68,word69,word71,word75,word166,word713,word108,word75,word274,word383,word291,word710,word99,word176,word212,word168,word254,word383,word61,word386,word714,word685,0
sent82:	dw	word381,word82,word254,word383,word202,word114,word82,word75,word383,word291,word176,word6,word74,word103,0
sent83:	dw	word68,word69,word715,word75,word166,word182,word283,word72,word716,word425,word74,word75,word95,word717,word718,word594,word719,word446,word75,word534,word209,word720,word721,word722,word723,word370,word371,word724,word99,word229,word100,word12,word446,word75,word253,word108,word72,word708,word99,word182,word445,word61,word72,word7,word88,word165,0
sent84:	dw	word68,word69,word108,word174,word725,word84,word78,word726,word182,word552,word61,word727,word728,word75,word729,word115,word194,word418,word383,word730,word154,word185,word381,word731,word66,word75,word274,word383,word732,word194,word733,word639,word370,word371,word372,word71,word72,word111,word98,0
sent85:	dw	word203,word108,word734,word367,0
sent86:	dw	word203,word108,word72,word735,word367,word84,word486,word215,word7,word82,word72,word578,word736,0
sent87:	dw	word68,word69,word108,word75,word379,word291,word176,word238,word75,word737,word299,word84,word95,word738,word341,word181,word72,word630,word88,word233,word608,word72,word343,word246,word68,word739,word740,word13,word741,word88,word742,word181,word264,word61,word72,word743,word173,word744,word745,word586,word65,word354,word371,word746,word61,word747,word264,word61,word740,word110,word282,0
sent88:	dw	word68,word69,word108,word75,word379,word176,word71,word75,word748,word74,word749,word750,word751,word527,word248,word88,word752,word99,word6,word123,word82,word234,word709,word234,word72,word111,word284,word753,0
sent89:	dw	word203,word71,word204,word74,word754,0
sent90:	dw	word68,word69,word108,word75,word95,word160,word755,word156,word691,word343,word82,word174,word650,word756,word757,word181,word72,word758,word759,word760,word761,word88,word4,word363,word762,word763,word95,word302,word173,word764,word69,word765,word178,word121,word591,word766,word78,word247,word386,word6,word88,word248,word88,word72,word7,word123,word767,word768,word4,word283,word72,word591,0
sent91:	dw	word203,word71,word72,word5,word73,word74,word769,word367,0
sent92:	dw	word203,word71,word72,word4,word73,word74,word769,word367,word99,word343,word212,word82,word770,word121,word771,word332,word772,word340,word475,word264,word773,word61,word774,word72,word775,word114,word82,word75,word182,word212,word776,word72,word777,word61,word778,word247,word181,word5,word88,word165,word114,word69,word517,word133,word779,word173,word72,word578,word458,word123,word82,word40,word72,word330,word780,word162,word72,word4,word206,word781,word65,word447,word37,word61,word324,0
sent93:	dw	word68,word69,word71,word72,word466,word74,word72,word782,word206,word108,word72,word769,word367,word114,word82,word75,word78,word783,word74,word784,word108,word123,word785,word74,word72,word205,0
sent94:	dw	word68,word69,word71,word72,word466,word74,word72,word786,word206,word108,word72,word769,word367,word114,word82,word75,word95,word286,word108,word72,word330,word390,word361,word132,word238,word103,0
sent95:	dw	word203,word108,word292,word297,word540,0
sent96:	dw	word68,word69,word108,word72,word787,word367,word99,word758,word212,word82,word254,word290,word12,word94,word131,word788,word61,word789,word324,word790,word247,word220,word280,word527,word88,word685,word791,word72,word4,word330,word82,word792,word72,word793,word794,word795,word796,word797,word798,0
sent97:	dw	word203,word108,word75,word530,word73,word5,word74,word72,word787,word367,0
sent98:	dw	word68,word69,word71,word123,word73,word74,word174,word650,word298,word299,0
sent99:	dw	word68,word69,word108,word75,word799,word609,word121,word75,word800,word437,word340,word801,word162,word75,word802,word803,word135,word75,word804,word805,word340,word806,word446,word75,word286,word108,word72,word273,word513,word29,word61,word72,word7,word88,word165,0
sent100:	dw	word203,word71,word807,word808,word238,word95,word367,word68,word739,word740,word13,word172,word173,word65,word354,word388,word371,word389,word61,word740,word282,word114,word82,word75,word167,word215,word110,word61,word72,word269,0
sent101:	dw	word68,word69,word108,word75,word300,word74,word304,word271,word302,word133,word809,0
sent113:	dw	word712,word512,0
sent121:	dw	word68,word69,word40,word75,word463,word321,word61,word75,word205,word68,word739,word740,word13,word212,word173,word65,word739,word388,word37,word110,word282,word99,word300,word266,word71,word306,word810,0
sent125:	dw	word203,word811,word80,0
sent126:	dw	word203,word90,word80,0
sent127:	dw	word203,word71,word73,word74,word76,word812,0
sent128:	dw	word203,word71,word101,word108,word119,0
sent129:	dw	word203,word108,word83,0
sent130:	dw	word203,word108,word120,word116,word75,word813,0
sent131:	dw	word203,word108,word813,0
sent132:	dw	word203,word71,word137,word108,word814,0
sent133:	dw	word203,word811,word815,0
sent134:	dw	word203,word535,word72,word815,0
sent135:	dw	word203,word108,word816,word461,word114,word82,word75,word817,word639,word71,word72,word5,word73,word74,word72,word299,0
sent136:	dw	word68,word69,word108,word171,word367,word84,word259,word40,word72,word330,word499,word818,word819,word820,0
sent137:	dw	word68,word69,word108,word174,word175,word183,word516,word299,0
sent138:	dw	word203,word108,word198,word197,0
sent139:	dw	word68,word69,word40,word75,word463,word74,word78,word205,0
sent141:	dw	word203,word40,word72,word5,word249,word74,word250,0
sent142:	dw	word68,word69,word40,word72,word4,word249,word74,word250,0
sent143:	dw	word203,word108,word821,word74,word822,word367,0
sent144:	dw	word203,word71,word4,word73,word74,word256,word74,word257,0
sent145:	dw	word203,word71,word5,word73,word74,word256,word74,word257,0
sent146:	dw	word203,word71,word5,word73,word74,word75,word275,word295,0
sent147:	dw	word68,word69,word71,word75,word289,word74,word75,word290,word291,word167,word88,word75,word160,word292,word293,0
sent148:	dw	word203,word71,word4,word73,word74,word75,word275,word295,0
sent149:	dw	word68,word69,word108,word75,word271,word300,word74,word301,word302,word133,word303,0
sent150:	dw	word68,word69,word108,word75,word300,word74,word301,word271,word302,word133,word303,0
sent151:	dw	word68,word69,word108,word75,word271,word300,word74,word304,word302,word133,word303,0
sent152:	dw	word68,word69,word108,word75,word301,word300,word74,word271,word302,word133,word303,0
sent153:	dw	word68,word69,word108,word75,word301,word271,word300,word74,word302,word133,word303,0
sent154:	dw	word68,word69,word108,word75,word304,word271,word300,word74,word302,word133,word303,0
sent155:	dw	word68,word69,word108,word75,word304,word300,word74,word271,word302,word133,word303,0
sent156:	dw	word68,word69,word108,word75,word271,word304,word300,word74,word302,word133,word303,0
sent157:	dw	word68,word69,word108,word75,word300,word74,word271,word301,word302,word133,word303,0
sent158:	dw	word68,word69,word108,word75,word300,word74,word271,word304,word302,word133,word303,0
sent159:	dw	word68,word69,word108,word75,word46,word121,word75,word308,word824,0
sent160:	dw	word68,word69,word108,word75,word325,word74,word457,0
sent161:	dw	word203,word71,word825,0
sent162:	dw	word203,word71,word336,word40,word206,word121,word252,word229,word40,word72,word351,0
sent163:	dw	word203,word71,word336,word40,word206,word121,word252,word229,word40,word72,word374,0
sent164:	dw	word203,word108,word75,word160,word291,word299,0
sent165:	dw	word203,word108,word256,word74,word826,word378,0
sent166:	dw	word203,word108,word72,word4,word112,word197,0
sent167:	dw	word68,word69,word108,word72,word7,word112,word197,0
sent168:	dw	word203,word108,word379,word292,word176,word238,word383,word291,word710,0
sent169:	dw	word68,word69,word108,word75,word379,word291,word710,0
sent170:	dw	word203,word108,word405,word710,0
sent171:	dw	word68,word69,word108,word75,word379,word423,word710,0
sent172:	dw	word203,word40,word424,word425,word74,word427,0
sent173:	dw	word68,word69,word108,word72,word449,word450,0
sent174:	dw	word203,word108,word456,word332,word367,0
sent175:	dw	word68,word69,word108,word75,word460,word331,word299,0
sent176:	dw	word203,word71,word204,word74,word78,word205,0
sent177:	dw	word68,word69,word108,word75,word206,word121,word75,word78,word827,0
sent178:	dw	word203,word71,word470,word471,0
sent179:	dw	word203,word108,word828,word367,0
sent180:	dw	word203,word108,word485,word295,0
sent181:	dw	word203,word108,word183,word540,0
sent182:	dw	word68,word69,word108,word75,word829,0
sent183:	dw	word203,word108,word830,0
sent184:	dw	word68,word69,word71,word511,word512,0
sent185:	dw	word203,word110,word71,word831,0
sent186:	dw	word68,word69,word108,word75,word532,word160,word367,0
sent187:	dw	word712,word73,word461,0
sent188:	dw	word203,word108,word531,word540,0
sent189:	dw	word203,word40,word538,word112,word74,word533,0
sent190:	dw	word203,word40,word541,word112,word74,word533,0
sent191:	dw	word68,word69,word108,word75,word275,word292,word540,0
sent192:	dw	word203,word71,word549,word108,word832,0
sent193:	dw	word203,word108,word564,word299,0
sent194:	dw	word68,word69,word71,word566,word74,word72,word567,word367,0
sent195:	dw	word68,word69,word90,word75,word567,word367,0
sent196:	dw	word203,word71,word748,word121,word582,word410,0
sent197:	dw	word203,word108,word156,word74,word591,0
sent198:	dw	word203,word71,word592,word593,0
sent199:	dw	word203,word108,word687,word367,0
sent200:	dw	word203,word108,word693,word833,word367,0
sent201:	dw	word203,word108,word702,word367,0
sent202:	dw	word68,word69,word108,word75,word709,word292,word710,0
sent203:	dw	word99,word176,word240,word135,word75,word834,word74,word835,word836,word530,word98,0
sent204:	dw	word68,word69,word108,word75,word274,word383,word291,word710,0
sent205:	dw	word381,word82,word254,word383,word202,0
sent206:	dw	word68,word69,word40,word75,word166,word182,word108,word75,word95,word717,word718,0
sent207:	dw	word203,word108,word837,0
sent208:	dw	word203,word108,word734,word367,0
sent209:	dw	word203,word108,word735,word367,0
sent210:	dw	word68,word69,word108,word75,word379,word291,word710,0
sent211:	dw	word203,word71,word748,word74,word749,word379,word838,0
sent212:	dw	word203,word71,word204,word74,word754,0
sent213:	dw	word203,word108,word839,word367,0
sent214:	dw	word203,word71,word5,word73,word74,word840,word841,word367,0
sent215:	dw	word203,word71,word4,word73,word74,word840,word841,word367,0
sent216:	dw	word203,word108,word5,word205,0
sent217:	dw	word203,word108,word4,word205,0
sent218:	dw	word203,word108,word292,word297,word540,0
sent219:	dw	word68,word69,word108,word787,word367,0
sent220:	dw	word712,word73,word299,0
sent221:	dw	word203,word108,word650,word298,word299,0
sent222:	dw	word203,word108,word799,word718,0
sent223:	dw	word203,word71,word807,word842,0
sent248:	dw	word84,word843,word844,word845,word341,word360,word72,word846,word847,word135,word72,word210,word84,word497,word568,word40,word72,word845,word848,word849,word850,word851,0
sent251:	dw	word84,word857,word858,word859,word393,word72,word845,word88,word860,word65,word45,word861,word75,word451,word77,word65,word387,word862,0
sent253:	dw	word88,word864,word362,word87,word74,word342,0
sent254:	dw	word99,word843,word865,word121,word65,word88,word174,word866,word867,word868,word869,word135,word72,word533,0
sent255:	dw	word68,word69,word870,word871,word72,word872,0
sent256:	dw	word203,word388,word873,word874,0
sent258:	dw	word68,word447,word386,word446,word75,word881,word149,word882,0
sent260:	dw	word114,word82,word887,word579,word360,word72,word250,0
sent262:	dw	word68,word891,word37,word892,word108,word72,word893,word894,word879,word61,word37,word895,0
sent263:	dw	word68,word896,word104,word876,word148,word897,word61,word38,word72,word898,0
sent265:	dw	word114,word69,word543,word905,word723,word181,word72,word906,word102,word103,0
sent266:	dw	word907,word181,word72,word908,word102,word65,word909,word75,word910,word911,word912,word913,word914,word915,word916,word917,word14,word133,word306,word918,word88,word919,word264,word362,word121,word920,word452,word122,word108,word72,word921,word922,word923,word131,word451,word88,word924,word135,word72,word925,0
sent267:	dw	word114,word82,word75,word926,word74,word927,word202,0
sent268:	dw	word114,word82,word75,word928,word929,word788,word930,0
sent269:	dw	word114,word82,word399,word931,word932,word202,0
sent271:	dw	word114,word82,word75,word934,word198,word935,word936,word202,0
sent272:	dw	word114,word82,word75,word937,word271,word198,word930,0
sent273:	dw	word84,word749,word285,word938,word939,word121,word75,word940,word941,word40,word123,word73,word942,word930,0
sent274:	dw	word114,word82,word75,word198,word108,word75,word935,word202,0
sent275:	dw	word114,word82,word75,word933,word202,0
sent276:	dw	word114,word82,word75,word271,word943,word202,0
sent277:	dw	word114,word82,word75,word945,word202,0
sent278:	dw	word114,word82,word399,word784,word202,0
sent279:	dw	word114,word69,word318,word946,0
sent280:	dw	word114,word82,word75,word947,word948,word946,0
sent281:	dw	word114,word69,word949,word74,word950,word951,word952,word946,0
sent282:	dw	word114,word82,word75,word953,word209,word900,word946,0
sent283:	dw	word114,word82,word75,word458,word954,word955,word946,0
sent284:	dw	word114,word82,word174,word956,word957,word958,word959,word936,word946,0
sent285:	dw	word114,word82,word75,word960,word961,word962,word944,word946,0
sent286:	dw	word114,word82,word75,word963,word964,word946,0
sent288:	dw	word114,word69,word928,word966,word946,0
sent289:	dw	word114,word82,word75,word274,word95,word967,word968,word202,0
sent290:	dw	word114,word69,word947,word969,word946,0
sent291:	dw	word114,word82,word75,word970,word946,0
sent292:	dw	word114,word82,word75,word95,word821,word74,word822,word946,0
sent293:	dw	word114,word69,word971,word74,word972,word946,0
sent294:	dw	word114,word82,word973,word974,word944,word946,0
sent295:	dw	word68,word69,word975,word976,word393,word75,word274,word532,word977,word978,0
sent296:	dw	word979,word788,word82,word765,word216,0
sent297:	dw	word979,word788,word82,word765,word980,0
sent299:	dw	word883,word981,word15,word879,word230,word82,word388,word1430,0
sent300:	dw	word982,word983,0
sent301:	dw	word984,word65,word985,word886,word61,word3,word986,0
sent302:	dw	word114,word82,word987,word212,word61,word988,0
sent303:	dw	word84,word338,word954,word989,word990,word971,word72,word991,0
sent304:	dw	word992,word72,word990,word117,word993,word994,word88,word82,word274,word995,0
sent305:	dw	word996,word131,word141,word997,0
sent306:	dw	word68,word998,word371,word389,word61,word999,word72,word1000,word173,word65,word739,word388,word875,word324,0
sent307:	dw	word99,word198,word1001,word1002,word1003,word65,word1004,word173,word234,word65,word1005,word264,word168,word1006,word88,word65,word981,word999,word324,0
sent308:	dw	word99,word271,word198,word1007,word72,word954,word1008,word88,word108,word174,word1009,word1010,word1011,word72,word990,word904,0
sent309:	dw	word1012,word1013,word99,word1014,word271,word943,word1015,word1016,0
sent310:	dw	word84,word1017,word917,word105,word283,word75,word1018,word1019,word403,word88,word1020,word75,word271,word943,word71,word1016,0
sent311:	dw	word99,word943,word1021,word1016,0
sent312:	dw	word68,word1024,word75,word271,word1025,word99,word1446,word924,word108,word75,word428,word74,word1447,word938,word1448,0
sent313:	dw	word68,word43,word75,word271,word1026,word173,word1027,word1028,word87,word74,word72,word1029,0
sent314:	dw	word68,word43,word75,word271,word1026,word173,word1027,word1028,word87,word74,word72,word579,word88,word1030,word65,word121,word1031,word1014,word488,word1032,0
sent315:	dw	word114,word82,word75,word1033,word940,word1034,word1035,word202,0
sent316:	dw	word99,word1035,word82,word1036,0
sent317:	dw	word99,word940,word1035,word82,word1037,0
sent320:	dw	word68,word981,word386,word12,word61,word72,word286,word278,word399,word579,word61,word1042,0
sent321:	dw	word146,word74,word927,0
sent322:	dw	word1043,word1044,0
sent324:	dw	word1045,word932,0
sent325:	dw	word1046,word933,0
sent326:	dw	word934,word198,word935,0
sent327:	dw	word1047,word939,0
sent328:	dw	word1048,word198,0
sent329:	dw	word1046,word933,word121,word48,0
sent330:	dw	word1049,0
sent331:	dw	word1050,word945,0
sent332:	dw	word1051,0
sent333:	dw	word1052,0
sent334:	dw	word1053,word948,0
sent335:	dw	word1054,0
sent336:	dw	word1055,word900,0
sent337:	dw	word1056,word955,0
sent338:	dw	word957,word959,0
sent339:	dw	word961,word962,0
sent340:	dw	word1057,0
sent341:	dw	word1058,0
sent342:	dw	word1059,word968,0
sent343:	dw	word1053,word969,0
sent344:	dw	word1060,0
sent345:	dw	word1061,word821,0
sent346:	dw	word1062,word971,0
sent347:	dw	word1063,word1064,word82,word1543,word781,word1067,word104,word1068,word1069,word108,word451,word88,word1070,word1071,word264,word82,word1072,word230,word399,word416,word28,word69,word1073,word372,word812,word1074,word82,word1075,word61,word994,word108,word72,word1076,word883,word891,word371,word131,word1077,word88,word1078,word1079,word920,word121,word1080,word74,word1081,word524,word1082,word1083,word883,word1084,word1085,word65,word230,word883,word17,word71,word578,word72,word1086,word490,word1087,word74,word1088,word1089,word1090,word65,word37,word1091,word1092,word1093,word94,word399,word1094,word1095,0
sent348:	dw	word883,word1096,word74,word1097,word1098,word88,word1099,word1100,word74,word1101,word1102,word1103,word1104,word88,word82,word1105,word61,word1106,word65,word1107,word270,word1108,word1109,word57,word66,word1110,word1111,word1112,word1113,word1114,word1115,word521,word522,word523,word524,word525,word883,word1096,word390,word75,word1116,word1117,word1118,word66,word75,word938,word939,word1119,word108,word72,word1076,word1120,word1121,word370,word371,word1122,word1123,word399,word74,word72,word1124,word57,word230,word883,word1125,word1126,word65,word891,word1127,word61
		dw	word1128,word117,word72,word1129,word88,word1124,word57,word1130,word420,word1131,word173,word1132,word883,word370,word1133,word72,word1129,word181,word72,word1134,word1135,word1136,word1121,word478,word1137,word1138,word108,word1139,word1140,word1141,word1142,word1143,word340,word1144,word920,word61,word1128,word65,word75,word1145,word74,word885,word889,word1146,word99,word1121,word104,word112,word1147,word94,word1148,word72,word939,word1149,word72,word1150,word1126,word1151,word744,word1152,word1153,word917,word1127,word61,word1109,word75,word1116,word1154,word1083,word1126,word1151,word1155,word1156,word61,word1157,word174
		dw	word1129,word69,word1158,word879,word503,word1159,word1160,word1161,word1162,word1163,word88,word1084,word1109,word75,word574,word1164,word1165,word270,word1166,word72,word1167,word65,word370,word1132,word1106,word275,word1168,word121,word75,word1169,word1089,word1170,word1171,word1172,word1173,word1174,word65,word61,word72,word26,word181,word1175,word238,word1176,word213,word1003,word1177,word108,word72,word83,word1178,word259,word230,word589,word247,word1179,word75,word1180,word88,word230,word1181,word75,word46,word61,word72,word6,word1182,word388,word1183,word1184,word72,word321,word181,word72,word685,word1185,word1186,0
sent349:	dw	word68,word447,word386,word230,word1187,word181,word202,0
sent350:	dw	word114,word82,word887,word579,word61,word1188,word108,word230,word1189,0
sent351:	dw	word1190,word1191,word1109,word399,word111,word554,0
sent352:	dw	word1192,0
sent353:	dw	word68,word104,word887,word1193,0
sent354:	dw	word99,word150,word82,word1194,0
sent355:	dw	word99,word150,word82,word765,word1195,0
sent356:	dw	word84,word1196,word845,word765,word1197,word72,word250,0
sent357:	dw	word883,word1271,word887,word1017,word202,0
sent358:	dw	word68,word981,word37,word1198,word72,word1199,0
sent359:	dw	word381,word82,word765,word1200,word1201,word385,word65,word1188,word65,word891,word1202,word1203,word135,word75,word205,0
sent360:	dw	word84,word1204,word1205,word499,word1206,0
sent362:	dw	word68,word981,word37,word1198,word72,word1210,0
sent363:	dw	word84,word1033,word218,word1211,word1212,word108,word72,word330,word1213,word40,word1214,word639,word135,word72,word735,word572,0
sent364:	dw	word114,word82,word75,word468,word271,word1215,word108,word72,word339,word1216,word1217,word1218,word1219,word1219,word1219,word320,0
sent365:	dw	word99,word1215,word1220,word135,word1221,word1222,word94,word75,word1116,word1223,0
sent366:	dw	word114,word82,word75,word1224,word1225,word224,word12,word87,word74,word72,word205,0
sent367:	dw	word381,word82,word1226,word1227,word1228,word1229,word1228,word320,0
sent368:	dw	word99,word1215,word1230,word1231,word233,word1232,word72,word466,word74,word72,word205,0
sent369:	dw	word68,word104,word1233,word72,word1234,word381,word199,word1235,word1236,0
sent370:	dw	word114,word82,word765,word75,word1237,word1225,word224,word133,word72,word579,word12,word61,word75,word286,word479,0
sent371:	dw	word99,word1033,word1238,word121,word1239,word1240,word981,word371,word1241,word278,word399,word1242,0
sent372:	dw	word1243,word1244,word65,word15,word1245,0
sent373:	dw	word1246,word996,word987,word702,word61,word1247,word1248,word72,word956,word959,word1249,word72,word273,0
sent374:	dw	word1250,word74,word72,word959,word1251,word1252,word1253,0
sent375:	dw	word68,word104,word887,word1254,word74,word1255,0
sent376:	dw	word114,word82,word987,word212,word264,word1556,word61,word597a,word1557,0
sent377:	dw	word99,word1261,word968,word1262,word131,word1259,0
sent378:	dw	word99,word822,word948,word82,word1263,word181,word72,word968,word88,word82,word1264,word181,word72,word589,word260,0
sent379:	dw	word68,word886,word72,word932,word94,word267,word1265,0
sent380:	dw	word1266,word578,word1267,word75,word968,word1003,word363,word82,word75,word567,word367,0
sent381:	dw	word984,word388,word1268,word1269,0
sent382:	dw	word883,word1270,word388,word1271,word75,word1215,word202,0
sent383:	dw	word68,word1270,word388,word104,word75,word933,word996,word1272,0
sent384:	dw	word114,word82,word887,word48,word108,word72,word1273,word1274,word1275,word48,word88,word1276,word1277,0
sent385:	dw	word114,word82,word887,word48,word202,0
sent386:	dw	word883,word370,word578,word53,word72,word933,word121,word1272,0
sent387:	dw	word68,word1270,word388,word104,word75,word1273,0
sent389:	dw	word68,word69,word412,word75,word1279,word1280,word1281,word1282,word321,word1283,0
sent390:	dw	word979,word35,word1284,word65,word234,word75,word1285,word1286,0
sent391:	dw	word68,word104,word1287,word72,word1288,word1289,word1290,0
sent392:	dw	word68,word387,word765,word1291,word1292,word75,word1293,word1290,0
sent393:	dw	word68,word104,word1294,word1295,word1296,word1297,0
sent394:	dw	word979,word35,word1298,word65,word108,word1299,word1300,word1301,word1302,0
sent395:	dw	word979,word35,word1298,word65,word108,word1299,word1300,word1301,word1303,0
sent396:	dw	word979,word35,word1298,word65,word108,word1299,word1300,word1301,word1304,0
sent397:	dw	word1250,word74,word1305,word1306,word1307,word61,word403,word1300,word1308,0
sent398:	dw	word1266,word1309,word75,word939,word61,word36,word293,0
sent399:	dw	word99,word1196,word845,word199,word1310,0
sent400:	dw	word1311,word1312,0
sent401:	dw	word68,word69,word388,word871,word75,word1313,0
sent402:	dw	word68,word1270,word388,word104,word75,word1150,0
sent403:	dw	word99,word198,word1314,word110,word61,word656,word1315,0
sent404:	dw	word1542,0
sent405:	dw	word883,word981,word1318,word885,word65,word1319,word524,word1318,word264,word212,word524,word1318,word264,word1320,0
sent406:	dw	word84,word899,word900,word901,word87,word74,word72,word1321,word88,word903,word61,word75,word286,word108,word72,word273,0
sent407:	dw	word99,word1321,word1322,word94,word75,word1323,word61,word1324,word781,word75,word899,word900,word1105,word61,word1325,0
sent410:	dw	word68,word1270,word388,word104,word75,word1328,0
sent411:	dw	word883,word1270,word388,word1271,word75,word1199,0
sent412:	dw	word68,word104,word75,word947,word1329,word1330,word6,word74,word202,0
sent413:	dw	word883,word981,word1331,word885,word65,word1319,word524,word1331,word264,word212,word524,word1331,word264,word1320,0
sent414:	dw	word883,word981,word1332,word885,word65,word1319,word524,word1332,word264,word212,word524,word1332,word264,word1320,0
sent415:	dw	word1333,word72,word954,word1334,word74,word174,word955,word172,word123,word1309,word75,word788,word61,word1335,0
sent416:	dw	word381,word82,word254,word1336,word61,word386,word121,word72,word788,word980,0
sent417:	dw	word1012,word1337,word68,word104,word757,word135,word75,word205,0
sent418:	dw	word68,word104,word331,word1338,word1339,word72,word1340,0
sent419:	dw	word1341,0
sent420:	dw	word883,word1270,word388,word1271,word75,word1207,word202,0
sent421:	dw	word883,word981,word14,word75,word962,word1342,word75,word1343,word1207,word82,word944,word40,word324,0
sent422:	dw	word1344,word68,word104,word917,word1345,word75,word1207,word121,word131,word141,word1346,0
sent423:	dw	word99,word308,word309,word1347,word75,word545,word88,word131,word788,word82,word765,word1348,0
sent425:	dw	word883,word1349,word65,word886,word61,word1350,word1351,0
sent426:	dw	word883,word1270,word388,word1271,word75,word845,word202,0
sent427:	dw	word1065,word82,word1355,word1354,word40,word1356,word393,word1357,word1358,word1359,word1066,0
sent428:	dw	word99,word1360,word240,word40,word1361,word1362,word1363,word1364,word1365,word393,word1366,word1367,word1368,0
sent429:	dw	word686,word1361,word1364,word1369,word1360,word1370,word1355,word1354,word40,word1371,word401,word1353,word1372,0
sent430:	dw	word1373,word1374,word264,word240,word108,word1375,word1376,word74,word1377,word121,word887,word1378,word1379,0
sent431:	dw	word381,word199,word1380,word1124,word1381,word1382,word1118,word1383,word1384,word1385,word1386,word88,word1387,word1083,0
sent432:	dw	word1388,word1389,word1390,word1391,word1392,word1393,word1394,word1371,word1395,0
sent433:	dw	word1396,word1397,0
sent434:	dw	word1398,word1399,0
sent435:	dw	word1400,0
sent436:	dw	word979,word788,word552,word61,word371,word1401,word1402,word1403,word65,word365,word94,word1404,word1405,0
sent437:	dw	word979,word788,word1406,word82,word233,word1407,word1408,word363,word75,word206,word1409,0
sent438:	dw	word99,word788,word1406,word82,word765,word1407,word68,word69,word108,word1410,word1411,0
sent439:	dw	word1412,word65,word28,word72,word329,word363,word82,word75,word1413,word1414,word75,word1415,word736,0
sent441:	dw	word114,word82,word75,word1207,word1208,word87,word40,word72,word1209,0
sent443:	dw	word1416,word74,word950,word951,word202,0
sent456:	dw	word883,word981,word45,word879,word230,word65,word1270,word388,word1429,0
sent457:	dw	word1412,word72,word933,word1249,word72,word743,word72,word48,word806,0
sent458:	dw	word99,word321,word1279,word82,word1432,word1431,0
sent459:	dw	word99,word321,word1279,word82,word1433,word1431,0
sent460:	dw	word99,word321,word1279,word82,word1434,word1431,0
sent461:	dw	word99,word321,word1279,word82,word1435,word1431,0
sent462:	dw	word99,word321,word1279,word82,word1436,word1431,0
sent463:	dw	word99,word321,word1279,word82,word1437,word1431,0
sent464:	dw	word99,word321,word1279,word82,word1438,word1431,0
sent465:	dw	word68,word104,word1439,word283,word108,word75,word271,word167,word6,word74,word88,word407,word61,word72,word256,word74,word257,0
sent466:	dw	word1445,word182,0
sent467:	dw	word99,word1017,word1022,word88,word1023,word904,0
sent468:	dw	word84,word1014,word271,word1017,word82,word930,0
sent469:	dw	word84,word1449,word1205,word1450,word446,word72,word589,word261,word500,word1451,word1452,word1250,word1453,word29,word1454,word446,word72,word1455,word1456,0
sent470:	dw	word99,word1449,word1205,word1459,word1460,word589,word82,word765,word1461,word1412,word72,word1462,word1463,word363,word82,word75,word1464,word1465,word74,word639,word853,word75,word78,word1466,word74,word192,word1467,word1412,word131,word1077,word1470,word65,word17,word283,word88,word1471,0	
sent471:	dw	word68,word69,word71,word72,word1499,word73,word74,word174,word650,word329,word1491,word72,word787,word367,word381,word806a,word61,word371,word75,word1492,word94,word72,word1493,word1494,word402,word440,word1495,word72,word46,word121,word1496,word1255,word1497,word390,word65,word370,word371,word372,word75,word704,word74,word1498,word1500,word74,word1501,word75,word1502,word74,word1503,word1216,word1504,word75,word140a,word74,word1505,word75,word1506,word74,word938,word1507,word121,word940,word1508,word40,word1159,word1509,word88,word75,word1510,word74,word929,word1511	
		dw	word1512,word61,word123,word112,word75,word597,word1513,word1474,word69,word1514,word40,word72,word743,word1515,word84,word497,word1064,word569,word1524,word388,word1525,word72,word1526,word194,word650,word405,word82,word406,word1527,word123,word421,word88,word1528,word61,word72,word111,word73,word74,word72,word329,word781,word1529,word111,word1530,word1121,word370,word371,word1531,word660,word108,word72,word115,0	
sent472:	dw	word68,word69,word71,word72,word1516,word73,word74,word72,word1517,word270,word123,word112,word82,word75,word206,word455,word74,word989,word954,word1518,word791,word72,word111,word112,word82,word75,word297a,word74,word78,word934,word1519,word1088,word74,word340,word1520,word75,word271,word1521,word1150,word305,word123,word785,word82,word75,word1506,word74,word938,word1507,word121,word940,word1522,word40,word1159,word1523,word84,word95,word1532,word74,word1533,word69,word1534,word390,word40,word72,word273,word84,word221,word405,word1528,word41,word61,word72,word550,word130,word131,word132,word82,word75,word95,word149,word1535,word321,word61,word340,word82,word75,word497,word340,word848,word1536,word1537,word108,word1455,word1456,word99,word150,word82,word1194,0	
sent473:	dw	word203,word71,word541,word98,0	
sent474:	dw	word203,word71,word538,word98,word99,word150,word82,word1194,0	
sent475:	dw	word114,word82,word75,word587,word823,word88,word75,word1472,word286,word806a,word108,word72,word402,word421,word1473,word72,word1474,word108,word72,word1475,word68,word386,word446,word72,word286,word88,word1275,word1292,word108,word72,word1455,word1476,word781,word75,word1477,word74,word1478,word875,word72,word1489,word41,word135,word72,word1490,0	
sent476:	dw	word883,word1271,word887,word1538,word202,0	
sent477:	dw	word883,word1271,word887,word150,word202,0	
sent478:	dw	word883,word1271,word987,word61,word33,word202,0	
sent479:	dw	word99,word271,word198,word1007,word72,word954,word1207,word88,word108,word174,word1009,word1010,word1174,word1539,word61,word75,word1540,word99,word653a,word1541,word904,0
sent480:	dw	word114,word69,word960,word1544,word946,0
sent481:	dw	word960,word1544,0
sent482:	dw	word270,word1547,0
sent483:	dw	word99,word968,word82,word881,word61,word72,word330,word121,word75,word947,word1040,0
sent484:	dw	word114,word82,word887,word579,word61,word37,word1198,word72,word968,word61,word33,word72,word1550,word340,word82,word1549,word917,word234,word1548,0
sent485:	dw	word114,word82,word75,word1551,word589,word968,word1552,word65,word181,word72,word402,word73,word74,word72,word1553,0
sent486:	dw	word114,word82,word75,word1554,word968,word1555,word390,word930,0
sent487:	dw	word1170,word1558,word72,word588,word842a,word1559,word82,word75,word1560,0
;
; Sentence Indexes  First room visit, use S_Index1.  Subsequent visits use S_Index2.
;
S_Index1:			
	dw	sent2,sent3,sent4,sent5,sent6,sent7,sent8,sent9,sent10	
	dw	sent11,sent12,sent13,sent14,sent15,sent16,sent17,sent18,sent19,sent20	
	dw	sent21,sent22,sent220,sent147,sent25,sent26,sent27,sent28,sent29,sent30	
	dw	sent31,sent32,sent33,sent34,sent35,sent36,sent37,sent38,sent39,sent40	
	dw	sent41,sent42,sent43,sent44,sent45,sent46,sent47,sent48,sent49,sent50	
	dw	sent51,sent52,sent53,sent54,sent55,sent56,sent57,sent58,sent59,sent60	
	dw	sent61,sent62,sent63,sent64,sent65,sent66,sent67,sent68,sent69,sent70	
	dw	sent71,sent72,sent73,sent74,sent75,sent76,sent77,sent78,sent79,sent80	
	dw	sent81,sent82,sent83,sent84,sent85,sent86,sent87,sent88,sent89,sent90	
	dw	sent91,sent92,sent93,sent94,sent95,sent96,sent97,sent98,sent99,sent100	
	dw	sent101,sent101,sent101,sent101,sent101,sent101,sent101,sent101,sent101,sent101	
	dw	sent101,sent101,sent113,sent113,sent113,sent113,sent113,sent113,sent113,sent113	
	dw	sent121,sent113,sent101,sent101,sent471,sent472	
;
S_Index2:
	dw	sent125,sent126,sent127,sent128,sent129,sent130	
	dw	sent131,sent132,sent133,sent134,sent135,sent136,sent137,sent138,sent139,sent145	
	dw	sent141,sent142,sent143,sent144,sent146,sent220,sent147,sent148,sent149,sent150	
	dw	sent151,sent152,sent153,sent154,sent155,sent156,sent157,sent158,sent159,sent160	
	dw	sent161,sent162,sent163,sent164,sent165,sent166,sent167,sent168,sent169,sent170	
	dw	sent171,sent172,sent173,sent174,sent175,sent176,sent177,sent178,sent179,sent180	
	dw	sent181,sent182,sent183,sent184,sent185,sent186,sent187,sent188,sent189,sent190	
	dw	sent191,sent192,sent193,sent194,sent195,sent196,sent197,sent198,sent199,sent200	
	dw	sent201,sent202,sent203,sent204,sent205,sent206,sent207,sent208,sent209,sent210	
	dw	sent211,sent212,sent213,sent214,sent215,sent216,sent217,sent218,sent219,sent220	
	dw	sent221,sent222,sent223,sent101,sent101,sent101,sent101,sent101,sent101,sent101	
	dw	sent101,sent101,sent101,sent101,sent101,sent113,sent113,sent113,sent113,sent113	
	dw	sent113,sent113,sent113,sent121,sent113,sent101,sent101,sent473,sent474	
;
;padding to ensure that the intel hex file download does not stop early
;
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0	
mybuff:	db	0	; do I/O in ram not otherwise used
;
	end		
;
; sentence database, text version, not needed for program assembly
;
;
;phr1 Welcome to Adventure!  Would you like instructions?$
;phr2 You are standing at the end of a road before a small brick building. Around you is a forest. A small stream flows out of the building and down a gully.$
;phr3 You are inside a building, a well house for a large spring.$
;phr4 You are at the road's end.  The road rises up a hill behind you.$
;phr5 You have walked up a hill, still in the forest. The road slopes back down the other side of the hill. There is a building in the distance.$
;phr6 You are in open forest near both a valley and a road.$
;phr7 You are in open forest, with a deep valley to one side.$
;phr8 You are in a valley in the forest beside a stream tumbling along a rocky bed.$
;phr9 At your feet all the water of the stream splashes into a 2-inch slit in the rock. Downstream the streambed is bare rock.$
;phr10 You are in a 20-foot depression floored with bare dirt. Set into the dirt is a strong steel grate mounted in concrete. A dry streambed leads into the depression.$
;phr11 You are in a small chamber beneath a 3x3 steel grate to the surface. A low crawl over cobbles leads inward to the west.$
;phr12 A low wide passage with cobbles becomes plugged with mud and debris here, but an awkward canyon leads upward and west.$
;phr13 You are in a debris room filled with stuff washed in from the surface.$
;phr14 You are in a chamber with a passage to the west and path sloping awkwardly east.$
;phr15 You are in a splendid chamber thirty feet high. The walls are frozen rivers of orange stone. An awkward canyon and a good passage exit from east and west sides of the chamber. A bird has been nesting here.$
;phr16 You're at top of small pit. At your feet is a small pit breathing traces of white mist. An east passage ends here except for a small crack leading on. Rough stone steps lead down the pit.$
;phr17 You are at one end of a vast hall of mists stretching forward out of sight to the west, filled with wisps of white mist that sway to and fro almost as if alive. Rough stone steps lead up to a passage at the top of a dome above you. A wide staircase runs downward into the darkness; a chill wind blows up from below. There are small passages to the north and south, and a small crack leads east.$
;phr18 You're on the east bank of a fissure. The mist is quite thick here, and the fissure is too wide to jump.$
;phr19 You are on the west bank of the fissure in the Hall of Mists.$
;phr20 You're in a low room with a crude note on the wall.  The note says,"You won't get it up the steps".$
;phr21 You are at the west end of Hall of Mists. A low wide crawl continues west and another goes north. To the south is a little passage 6 feet off the floor.$
;phr22 You are at the east end of a very long hall, apparently without side chambers. To the east, a low wide crawl slants up. To the north around two foot hole slants down.$
;phr23 You're at east end of a long hall in a crossover. You are at a crossover of a high N/S passage and a low E/W one.$ (not used)
;phr24 You're at west end of a long hall in a crossover.$  (not used)
;phr25 You are at the west end of a very long featureless hall.  The hall joins up with a narrow north/south passage.$
;phr26 You are in a little maze of twisting passages, all different.$
;phr27 You are in a maze of twisting little passages, all different.$
;phr28 You are in a little maze of twisty passages, all different.$
;phr29 You are in a twisting maze of little passages, all different.$
;phr30 You are in a twisting little maze of passages, all different.$
;phr31 You are in a twisty little maze of passages, all different.$
;phr32 You are in a twisty maze of little passages, all different.$
;phr33 You are in a little twisty maze of passages, all different.$
;phr34 You are in a maze of little twisting passages, all different.$
;phr35 You are in a maze of little twisty passages, all different.$
;phr36 There is a massive vending machine here. The instructions on it read: "Drop coins here to receive fresh batteries".
;phr37 You are in a jumble of rocks, with cracks everywhere.$
;phr38 You are in a large room, with a passage to the south, a passage to the west, and a wall of broken rock to the east. There is a large "Y2" on a rock in the room's center.$
;phr39 You're at a low window overlooking a huge pit, which extends up out of sight. A floor is indistinctly visible over 50 feet below. Traces of white mist cover the floor of the pit, becoming thicker to the right. Marks in the dust around the window would seem to indicate that someone has been here recently. Directly across the pit from you and 25 feet away there is a similar window looking into a lighted room. A shadowy figure can be seen there peering back at you.$
;phr40 You're at a low window overlooking a huge pit, which extends up out of sight. A floor is indistinctly visible over 50 feet below. Traces of white mist cover the floor of the pit, becoming thicker to the left. Marks in the dust around the window would seem to indicate that someone has been here recently. Directly across the pit from you and 25 feet away there is a similar window looking into a lighted room. A shadowy figure can be seen there peering back at you.$
;phr41 You are in a low N/S passage at a hole in the floor. The hole goes down to an E/W passage.$
;phr42 You are in the Hall of the Mountain King, with passages off in all directions.$
;phr43 You are in the west side chamber of the Hall of the Mountain King. A passage continues west and up here.$
;phr44 You are in the south side chamber next to the Hall of the Mountain King.$
;phr45 You are in a secret canyon which here runs E/W. It crosses over a very tight canyon 15 feet below. If you go down you may not be able to get back up.$
;phr46 You are in a secret N/S canyon above a large room.$
;phr47 You are in a north/south canyon about 25 feet across.  The floor is covered by white mist seeping in from the north. The walls extend upward for well over 100 feet. Suspended from some unseen point far above you, an enormous two-sided mirror is hanging parallel to and midway between the canyon walls. (The mirror is obviously provided for the use of the dwarves, who as you know, are extremely vain). A small window can be seen in either wall, some fifty feet up.$
;phr48 You are in a secret N/E canyon with passages to the north and east.$
;phr49 You are on the southern edge of a large underground reservoir. A thick cloud of white mist fills the room, rising from the surface of the water and drifting rapidly upwards. The lake is fed by a stream, which tumbles out of a hole in the wall about 10 feet overhead and splashes noisily into the water near the reservoir's northern wall. A dimly-seen passage exits through the northern wall, but you can't get across the water to get to it. Another passage leads south from here.$
;phr50 You are in the Pirate Lair. There is a treasure chest here, half-hidden behind a rock!$
;phr51 You are in a large room full of dusty rocks. There is a big hole in the floor. There are cracks everywhere, and a passage leading east.$
;phr52 You're in a dirty passage with broken rocks. To the east is a crawl. To the west is a large passage. Above you is a hole to another passage.$
;phr53 You are on the brink of a small clean climbable pit. A crawl leads west.$
;phr54 You are in the bottom of a small pit with a little stream, which enters and exits through tiny slits.$
;phr55 You are at a complex junction.  A low hands and knees passage from the north joins a higher crawl from the east to make a walking passage going west. There is also a large room above. The air is damp here.$
;phr56 You are in a room with an enormous shell, tightly shut. There is a passage to the south, a climbable hole above and a small hole in the floor going down.$
;phr57 You are in an arched hall. There is a hole in the floor going down.$
;phr58 You are in a long sloping corridor with ragged sharp walls.$
;phr59 You are in a cul-de-sac about eight feet across.$
;phr60 You are in an anteroom leading to a large passage to the east.  Small passages go west and up.  The remnants of recent digging are evident. A sign in midair here says "Cave under construction beyond this point.  Proceed at own risk. {Witt Construction Company}.$
;phr61 You're at Witt's End. Passages lead off in *all* directions.$
;phr62 You are in Bedquilt, a long east/west passage with holes everywhere.  To explore at random select NORTH, SOUTH, UP, or DOWN.$
;phr63 You are in a large low room.  Crawls lead north, SE, and SW.$
;phr64 You are in a dead end crawl above a large low room.$
;phr65 You are in a long winding corridor sloping out of sight in both directions.$
;phr66 You are on one side of a large, deep chasm. A heavy white mist rising up from below obscures all view of the far side.  A SW path leads away from the chasm into a winding corridor.$
;phr67 You are on the far side of the chasm. A NE path leads away from the chasm on this side.$
;phr68 You are in a long, narrow E/W corridor stretching out of sight to the west. A faint rumbling noise can be heard in the distance.$
;phr69 You're in a corridor. The path forks here. The left fork leads northeast. A dull rumbling seems to get louder in that direction. The right fork leads southeast down a gentle slope. The main corridor enters from the west.$
;phr70 You are walking along a gently sloping north/south passage lined with oddly shaped limestone formations.$
;phr71 You are standing at the entrance to a large, barren room. A sign posted above the entrance reads: "Caution! Bear in room!"$
;phr72 You are in the barren room. The center of the room is completely empty except for some dust. Marks in the dust lead away toward the far end of the room. The only exit is the way you came in.$
;phr73 You are in a junction. The walls are quite warm here. From the north can be heard a steady roar, so loud that the entire cave seems to be trembling. Another passage leads south, and a low crawl goes east.$
;phr74 You are in a small chamber filled with large boulders.$
;phr75 You are on the edge of a breath-taking view.  Far below you is an active volcano, from which great gouts of molten lava come surging out, cascading back down into the depths. The glowing rock fills the farthest reaches of the cavern with a blood-red glare, giving every-thing an eerie, macabre appearance.  The air is filled with flickering sparks of ash and a heavy smell of brimstone. The walls are hot to the touch, and the thundering of the volcano drowns out all other sounds. Embedded in the jagged roof far overhead are myriad twisted formations composed of pure white alabaster, which scatter the murky light into sinister apparitions upon the walls. To one side is a deep gorge, filled with a bizarre chaos of tortured rock which seems to have been crafted by the devil himself. An immense river of fire crashes out from the depths of the volcano, burns its way through the gorge, and plummets into a bottomless pit far off to your left.  Across the gorge, the entrance to a valley is dimly visible. To the
; right, an immense geyser of blistering steam erupts continuously from a barren island in the center of a sulfurous lake, which bubbles ominously. The far right wall is a flame with an incandescence of its own, which lends an additional infernal splendor to the already hellish scene. A dark, foreboding passage exits to the south.$
;phr76 This is the Oriental room.  Ancient oriental cave drawings cover the walls.  A gently sloping passage leads upward to the north, another passage leads SE, and a hands and knees crawl leads west.$
;phr77 You are in a room whose walls resemble Swiss cheese.  Obvious passages go west, east, NE, and NW. Part of the room is occupied by a large bedrock block.$
;phr78 You are in the soft room.  The walls are covered with heavy curtains,the floor with a thick pile carpet. Moss covers the ceiling.$
;phr79 You are in a tall E/W canyon. A low tight crawl goes 3 feet north and seems to open up.$
;phr80 Dead end.$
;phr81 You are at a wide place in a very tight N/S canyon. The canyon here becomes too tight to go further south.$
;phr82 It is too tight here.  There is a tight N/S canyon north of you.$
;phr83 You are following a wide path around the outer edge of a large misty cavern.  Far below, through a heavy white mist, strange splashing noises can be heard. The mist rises up through a fissure in the ceiling. The path exits to the south and west.$
;phr84 You are in an alcove.  A small NW path seems to widen after a short distance.  An extremely tight tunnel leads east. It looks like a very tight squeeze. An eerie light can be seen at the other end.$
;phr85 You're in Plover room.$
;phr86 You're in the Dark room. A corridor leading south is the only exit.$
;phr87 You are in a secret N/S canyon above a sizable passage. A large stalactite extends from the roof and almost reaches the floor below. You could climb down it, and jump from it to the floor, but having done so you would be unable to reach it to climb back up.$
;phr88 You are in a secret canyon at a junction of three canyons, bearing north, south, and SE. The north one is as tall as the other two combined.$
;phr89 You're at top of stalactite.$
;phr90 You are in a large low circular chamber whose floor is an immense slab fallen from the ceiling (Slab room). East and west there once were large passages, but they are now filled with boulders. Low, small passages go north and south, and the south one quickly bends west around the boulders.$
;phr91 You're at the east end of Twopit room.$
;phr92 You're at the west end of Twopit room. The floor here is littered with thin rock slabs, which make it easy to descend the pits. There is a path here bypassing the pits to connect passages from east and west. There are holes all over, but the only big one is on the wall directly over the west pit where you can't get to it.$
;phr93 You are at the bottom of the eastern pit in the Twopit room. There is a small pool of oil in one corner of the pit.$
;phr94 You are at the bottom of the western pit in the Twopit room. There is a large hole in the wall about 25 feet above you.$
;phr95 You're in E/W narrow corridor.$
;phr96 You are in the Giant room. The ceiling here is too high up for your lamp to show it. Cavernous passages lead east, north, and south. On the west wall is scrawled the inscription, "Fee Fie Foe Foo" {sic}.$
;phr97 You're in a dead end east of the Giant room.$
;phr98 You are at one end of an immense north/south passage.$
;phr99 You are in a magnificent cavern with a rushing stream, which cascades over a sparkling waterfall into a roaring whirlpool which disappears through a hole in the floor.  Passages exit to the south and west.$
;phr100 You're at steep incline above large room.  You could climb down here, but you would not be able to climb up. There is a passage leading back to the north.$
;phr101 You are in a maze of twisty little passages, all alike.$
;phr102 You are in a maze of twisty little passages, all alike.$
;phr103 You are in a maze of twisty little passages, all alike.$
;phr104 You are in a maze of twisty little passages, all alike.$
;phr105 You are in a maze of twisty little passages, all alike.$
;phr106 You are in a maze of twisty little passages, all alike.$
;phr107 You are in a maze of twisty little passages, all alike.$
;phr108 You are in a maze of twisty little passages, all alike.$
;phr109 You are in a maze of twisty little passages, all alike.$
;phr110 You are in a maze of twisty little passages, all alike.$
;phr111 You are in a maze of twisty little passages, all alike.$
;phr112 You are in a maze of twisty little passages, all alike.$
;phr113 Dead End.$
;phr114 Dead End.$
;phr115 Dead End.$
;phr116 Dead End.$
;phr117 Dead End.$
;phr118 Dead End.$
;phr119 Dead End.$
;phr120 Dead End.$
;phr121 You are on a brink next to a pit. You could climb down here but you could not get back up. The maze continues at this level.$
;phr122 Dead End.$
;phr123 You are in a maze of twisty little passages, all alike.$
;phr124 You are in a maze of twisty little passages, all alike.$
;phr125 You're outside building.$
;phr126 You're inside building.$
;phr127 You're at end of road again.$
;phr128 You're at hill in road.$
;phr129 You're in forest.$
;phr130 You're in forest, near a valley.$
;phr131 You're in valley.$
;phr132 You're at slit in streambed.$
;phr133 You're outside grate.$
;phr134 You're below the grate.$
;phr135 You're in cobble crawl. There is a dim light at the east end of the passage.$
;phr136 You are in debris room. A note on the wall says "Magic word XYZZY".$
;phr137 You are in an awkward sloping east/west passage.$
;phr138 You're in bird chamber.$
;phr139 You are on a brink of small pit.$
;phr140 You're in Hall of Mists.$  (not used)
;phr141 You're on the east bank of fissure.$
;phr142 You are on the west bank of fissure.$
;phr143 You're in nugget of gold room.$
;phr144 You're at west end of Hall of Mists.$
;phr145 You're at east end of Hall of Mists.$
;phr146 You're at east end of a long hall in a crossover.$ remove in a crossover
;phr147 You are at a crossover of a high N/S passage and a low E/W one.$
;phr148 You're at west end of a long hall.$
;phr149 You are in a little maze of twisting passages, all different.$
;phr150 You are in a maze of twisting little passages, all different.$
;phr151 You are in a little maze of twisty passages, all different.$
;phr152 You are in a twisting maze of little passages, all different.$
;phr153 You are in a twisting little maze of passages, all different.$
;phr154 You are in a twisty little maze of passages, all different.$
;phr155 You are in a twisty maze of little passages, all different.$
;phr156 You are in a little twisty maze of passages, all different.$
;phr157 You are in a maze of little twisting passages, all different.$
;phr158 You are in a maze of little twisty passages, all different.$
;phr159 YOu are in a room with a vending machine.$
;phr160 You are in a jumble of rocks.$
;phr161 You're at "Y2".$
;phr162 You're at window on pit with thick mist on the right.$
;phr163 You're at window on pit with thick mist on the left.$
;phr164 You're in a low N/S passage.$
;phr165 You're in Hall of Mt King.$
;phr166 You're in the west side chamber.$
;phr167 You are in the south side chamber.$
;phr168 You're in secret E/W canyon above tight N/S canyon.$
;phr169 You are in a secret N/S canyon.$
;phr170 You're in mirror canyon.$
;phr171 You are in a secret N/E canyon.$
;phr172 You're on southern edge of reservoir.$
;phr173 You are in the Pirate Lair.$
;phr174 You're in dusty rock room.$
;phr175 You are in a dirty broken passage.$
;phr176 You're at top of small pit.$
;phr177 You are in a pit with a small stream.$
;phr178 You're at complex junction.$
;phr179 You're in Shell room.$
;phr180 You're in arched hall.$
;phr181 You're in sloping corridor.$
;phr182 You are in a cul-de-sac.$
;phr183 You're in anteroom.$
;phr184 You are at Witt's End.$
;phr185 You're back at Bedquilt.$
;phr186 You are in a large, low room.$
;phr187 Dead end crawl.$
;phr188 You're in winding corridor.$
;phr189 You're on SW side of chasm.$
;phr190 You're on NE side of chasm.$
;phr191 You are in a long E/W corridor.$
;phr192 You're at fork in path.$
;phr193 You're in limestone passage.$
;phr194 You are at entrance of the barren room.$
;phr195 You are inside a barren room.$
;phr196 You're at junction with warm walls.$
;phr197 You're in chamber of boulders.$
;phr198 You're at breath-taking view.$
;phr199 You're in Oriental room.$
;phr200 You're in Swiss cheese room.$
;phr201 You're in soft room.$
;phr202 You are in a tall E/W canyon.$
;phr203 The canyon runs into a mass of boulders -- dead end.$
;phr204 You are in a very tight N/S canyon.$
;phr205 It is too tight here.$
;phr206 You are on a wide path in a large misty cavern.$
;phr207 You're in Alcove.$
;phr208 You're in Plover room.$
;phr209 You're in Dark room.$
;phr210 You are in a secret N/S canyon.$
;phr211 You're at junction of three secret canyons.$
;phr212 You're at top of stalactite.$
;phr213 You're in Slab room.$
;phr214 You're at east end of Two Pit room.$
;phr215 You're at west end of Two Pit room.$
;phr216 You're in east pit.$
;phr217 You're in west pit.$
;phr218 You're in E/W narrow corridor.$
;phr219 You are in Giant room.$
;phr220 Dead end passage.$
;phr221 You're in immense north/south passage.$
;phr222 You're in magnificent cavern.$
;phr223 You're at steep incline.$
;phr224 You are in a maze of twisty little passages, all alike.$
;phr225 You are in a maze of twisty little passages, all alike.$
;phr226 You are in a maze of twisty little passages, all alike.$
;phr227 You are in a maze of twisty little passages, all alike.$
;phr228 You are in a maze of twisty little passages, all alike.$
;phr229 You are in a maze of twisty little passages, all alike.$
;phr230 You are in a maze of twisty little passages, all alike.$
;phr231 You are in a maze of twisty little passages, all alike.$
;phr232 You are in a maze of twisty little passages, all alike.$
;phr233 You are in a maze of twisty little passages, all alike.$
;phr234 You are in a maze of twisty little passages, all alike.$
;phr235 You are in a maze of twisty little passages, all alike.$
;phr236 Dead End.$
;phr237 Dead End.$
;phr238 Dead End.$
;phr239 Dead End.$
;phr240 Dead End.$
;phr241 Dead End.$
;phr242 Dead End.$
;phr243 Dead End.$
;phr244 You are on a brink next to a pit.$
;phr245 Dead End.$
;phr246 You are in a maze of twisty little passages, all alike.$
;phr247 You are in a maze of twisty little passages, all alike.$
;phr248 A rickety wooden bridge extends across the chasm, vanishing into the mist.  A sign posted on the bridge reads, "STOP! Pay troll!"$
;phr249 The wreckage of a bridge (and a dead bear) can be seen at the bottom of the chasm.$
;phr250 The charred remains of a wooden bridge can be seen at the bottom of the chasm.$
;phr251 A burly troll stands by the bridge and insists you throw him a treasure before you may cross.$
;phr252 The troll catches the $
;phr253 and scurries away out of sight.$
;phr254 The rickety bridge, with you and an 800 pound bear, collapses into the chasm.$
;phr255 You are currently holding the following:$
;phr256 You're not carrying anything.$

;phr258 You can't go through a locked steel grate!$
;phr259 I believe what you want is right here with you.$  (not used)
;phr260 There is no way across the fissure.$
;phr261 Something you're carrying won't fit through the tunnel with you.$  (deleted)
;phr262 You will get stuck in the tunnel. Drop something to get through.$
;phr263 You don't have anything strong enough to open the clam.$
;phr264 A glistening pearl falls out of the clam and rolls away.$  (deleted) see 406
;phr265 There are faint rustling noises from the darkness behind you.$
;phr266 Out from the shadows behind you pounces a bearded pirate! "Har, har,"he chortles, "I'll just take all this booty and hide it away with me chest deep in the maze!" He snatches your treasure and vanishes into the gloom.$
;phr267 There is a set of keys here.$
;phr268 There is a shiny brass lamp nearby.$
;phr269 There is some tasty food here.$
;phr270 There is a bottle of water here.$ (deleted)
;phr271 There is a Wicker bird cage sitting here.$
;phr272 There is a cute little bird nearby.$
;phr273 A three foot black rod with a rusty star on one end lies nearby.$
;phr274 There is a bird in a cage here.$
;phr275 There is a bottle here.$
;phr276 There is a little axe laying nearby.$
;phr277 There is a pillow here.$
;phr278 There is some oil here.$
;phr279 There are coins here!$
;phr280 There is a golden chain here!$
;phr281 There are copies of Spelunker Today magazine here!$
;phr282 There is a beautiful white pearl here!$
;phr283 There is a big green emerald here!$
;phr284 There is an ancient Ming Dynasty vase sitting here!$
;phr285 There is a rare Persian rug laying here!$
;phr286 There is a platinum pyramid here!$
;phr287 There is a five foot long golden chain here!$  (deleted)
;phr288 There are shiny diamonds here!$
;phr289 There is a very large brown bear here.$
;phr290 There are golden eggs here!$
;phr291 There is a trident here!$
;phr292 There is a large nugget of gold here!$
;phr293 There are bars of silver here!$
;phr294 There is fine jewelry laying here!$
;phr295 You are being followed by a very large, tame bear.$
;phr296 Your lamp is now on.$
;phr297 Your lamp is now off.$
;phr298 I cannot take something that is not here.$  (deleted)
;phr299 I cannot drop something that is not held.$
;phr300 Nothing happens.$
;phr301 Do you really want to quit now?$
;phr302 There is nothing here to attack.$
;phr303 A huge green fierce snake bars the way!$
;phr304 Attacking the snake both doesn't work and is very dangerous.$
;phr305 With your bare hands?$
;phr306 You might be able to catch the bird, but you could not carry it.$
;phr307 The bird was unafraid when you entered, but as you approach it becomes disturbed and you cannot catch it.$
;phr308 The little bird attacks the green snake, and in an astounding flurry drives the snake away.$
;phr309 Oh dear. The nasty little axe hit you!$
;phr310 A dwarf just walked around a corner, saw you, and threw a little axe at you!$
;phr311 The axe missed you!$
;phr312 You killed a little dwarf. The body vanishes in a cloud of greasy black smoke.$
;phr313 You attack a little dwarf, but he dodges out of the way.$
;phr314 You attack a little dwarf, but he dodges out of the way and stabs you with his nasty sharp knife!$
;phr315 There is a massive rusty metal door here.$
;phr316 The door is closed.$
;phr317 The rusty door is open.$
;phr320 You cannot go up to the hole without some way to climb.$
;phr321 Set of keys$
;phr322 Brass lantern$
;phr323 Wicker cage$ (not used)
;phr324 Tasty food$
;phr325 Glass bottle$
;phr326 Wicker bird cage$
;phr327 Black rod$
;phr328 Cute bird$
;phr329 Glass bottle with water$
;phr330 Axe$
;phr331 Soft pillow$
;phr332 Oil$
;phr333 Coins$
;phr334 Golden chain$
;phr335 Magazines$
;phr336 Glistening pearl$
;phr337 Green emerald$
;phr338 Ming vase$
;phr339 Persian rug$
;phr340 Pyramid$
;phr341 Diamonds$
;phr342 Brown bear$
;phr343 Golden eggs$
;phr344 Trident$
;phr345 Gold nugget$
;phr346 Silver bars$
;phr347 Somewhere nearby is Colossal Cave, where others have found fortunes in treasure and gold, though it is rumored that some who enter are never seen again.  Magic is said to work in the cave.  I will be your eyes and hands.  Direct me with commands of 1 or 2 words.  I should warn you that I look at only the first eight letters of each word. Should you get stuck, type "HELP" for some general hints.$
;phr348 I know of places, actions, and things. Most of my vocabulary describes places and is used to move you there. To move, try words like FOREST, BUILDING, DOWNSTREAM, ENTER, EAST, WEST, NORTH, SOUTH, UP, or DOWN.  I know about a few special objects, like a black rod hidden in the cave. These objects can be manipulated using some of the action words that I know.  Usually you will need to give both the object and action words (in either order), but sometimes I can infer the object from the verb alone.  Some objects also imply verbs; in particular, "INVENTORY" implies "TAKE INVENTORY", which causes me to give you a list of what you're carrying.  The objects have side effects; for instance, the rod scares the bird.  Usually people having trouble moving just need to try a few more words.  Usually people trying unsuccessfully to manipulate an object are attempting something beyond their (or my!) capabilities and should try a completely different tack.  To speed the game, you can sometimes move long distances wi; with a single word.  For example, "BUILDING" usually gets you to the building from anywhere above ground except when lost in the forest.  Also, note that cave passages turn a lot, and that leaving a room to the north does not guarantee entering the next from the south. Good luck!$
;phr349 You can't go that direction from here.$
;phr350 There is no way to proceed in that direction!$
;phr351 Sorry. Please try some other direction.$
;phr352 Huh?$
;phr353 You have no keys!$
;phr354 The grate is locked.$
;phr355 The grate is now unlocked.$
;phr356 A crystalline bridge now spans the fissure.$
;phr357 I see no dwarf here.$
;phr358 You cannot get past the snake.$
;phr359 It is now pitch dark. If you proceed you will likely fall into a pit.$
;phr360 A hollow voice says "Plugh"$
;phr361 A huge green fierce dragon bars the way!  The dragon is sprawled out on a Persian rug.$ (dup, deleted)
;phr362 You cannot get past the dragon.$
;phr363 A massive stone tablet imbedded in the wall reads:"Congratulations on bringing light into the Dark room!"$
;phr364 There is a tiny little plant in the pit, murmuring "Water, water, ..."$
;phr365 The plant spurts into furious growth for a few seconds.$
;phr366 There is a 12-foot-tall beanstalk stretching up out of the pit.$
;phr367 It is bellowing "WATER!! WATER!!"$
;phr368 The plant grows explosively, almost filling the bottom of the pit.$
;phr369 You have over-watered the plant! It has shriveled up!$
;phr370 There is now a gigantic beanstalk stretching all the way up to a hole above.$
;phr371 The massive door, with hinges rusted, cannot be opened without some oil.$
;phr372 Thud. Did you drop something?$
;phr373 Smash! With nothing soft to land on, the ancient vase hits the floor.$
;phr374 All of the vase pieces magically vanish.$
;phr375 You have no source of light.$
;phr376 The bear is hungry.  Without food, you are the food. The bear remains chained.$
;phr376a There is nothing here it wants to eat (except perhaps you).$
;phr377 The hungry bear eats your food.$
;phr378 The gold chain is released from the bear and is unlocked from the cave wall.$
;phr379 You want the food for another purpose.$
;phr380 One only feeds a bear when there is a barren room.$
;phr381 Do not waste water!$
;phr382 I do not see a plant here.$
;phr383 You do not have a bottle with water.$
;phr384 There is no water in the bottle.  Go find water and "fill bottle".$
;phr385 There is no water here.$
;phr386 I can only fill the bottle with water.$
;phr387 You do not have a bottle.$
;phr388 The current score is $  (not used, deleted)
;phr389 You are obviously a rank amateur. Better luck next time.$
;phr390 Your score qualifies you as a novice-class adventurer.$
;phr391 You have achieved the rating; "Experienced Adventurer".$
;phr392 You may now consider yourself a "Seasoned Adventurer".$
;phr393 You have reached "Junior Master" status.$
;phr394 Your score puts you in Master Adventurer class C.$
;phr395 Your score puts you in Master Adventurer class B.$
;phr396 Your score puts you in Master Adventurer class A.$
;phr397 All of Adventuredom gives tribute to you, Adventurer Grandmaster!$
;phr398 One needs a rod to wave one.$
;phr399 The crystalline bridge has vanished!$
;phr400 Wave what?$
;phr401 You are not holding a cage.$
;phr402 You do not have a bird.$
;phr403 The bird flies back to its nest.$
;phr404 How?$
;phr405 I cannot "open" what you named or "open" it here or "open" it now.$
;phr406 A glistening pearl falls out of the shell and rolls to a hole in the floor.$ dup of phr264
;phr407 The shell opens for a moment to reveal where a glistening pearl used to be.$
;phr408 There is an enormous oyster here with its shell tightly closed.$ (not used, deleted)
;phr409 The shell is very strong and is impervious to attack.$ (not used, deleted)
;phr410 You do not have a lamp.$
;phr411 I do not see a snake.$
;phr412 You have a golden (nugget) opportunity north of here.$
;phr413 I cannot "free" what you named or "free" it here or "free" it now.$
;phr414 I cannot "take" what you named or "take" it here or "take" it now.$
;phr415 Beyond the green glow of an emerald here, one needs a lamp to see.$
;phr416 It is too dark to go with the lamp off.$
;phr417 Oh dear, You have fallen into a pit.$
;phr418 You have broken everything including the scoreboard!$
;phr419 Poof!$
;phr420 I do not see a dragon here.$
;phr421 I cannot take a rug while a dangerous dragon is laying on it.$
;phr422 Congratulations! You have just vanquished a dragon with your bare hands!$
;phr423 The vending machine makes a noise and your lamp is now bright.$
;phr425 I think you want to "unlock grate".$
;phr426 I do not see a bridge here.$
;phr427 MyAdvent is mostly based on text by Will Crowther (1975) & Don Woods (1976).$
;phr428 The game runs on new 8080 assembly code written by George Kauffman (2011).$
;phr429 This new code uses game navigation mostly based on 350 point Adventure maps.$
;phr430 Once loaded, it runs in 32 kilobytes of ram with no disk access.$
;phr431 It has 65 action words, 36 objects, 125 rooms, 482 sentences and 1547 words.$
;phr432 Scoring: 1/room (125) 8/treasure (15), 11/puzzle (10) 350 maximum.$
;phr433 Action Words:$
;phr434 Object words:$
;phr435 Jewelry$
;phr436 Your lamp seems to be getting dim.  Are you looking for fresh batteries?$
;phr437 Your lamp battery is almost dead.  Is there a pit nearby?$
;phr438 The lamp battery is now dead. You are in total darkness.$
;phr439 As you enter the room, there is a pirate making a hasty exit.$
;phr441 There is a dragon sprawled out on the rug.$
;phr443  edition of Spelunker Today here.$
;phr456 I cannot throw something that you do not have.$
;phr457 As the bottle hits the floor, the water disappears.$
;phr458 The next level rank is 350 points.$
;phr459 The next level rank is 340 points.$
;phr460 The next level rank is 270 points.$
;phr461 The next level rank is 200 points.$
;phr462 The next level rank is 130 points.$
;phr463 The next level rank is 75 points.$
;phr464 The next level rank is 25 points.$
;phr465 You have crawled around in a little passage north of and parallel to the Hall of Mists.$
;phr466  puzzle path$
;phr467 The dwarf cursed and ran away.$
;phr468 A nasty little dwarf is nearby.$
;phr469 A sepulchral voice reverberating through the cave says, "Cave closing soon. All adventurers exit 
;       immediately through the Main Office."$
;phr470 The sepulchral voice intones, "The cave is now closed." As the echoes fade, there is a blinding 
;       flash of light (and a small puff of orange smoke). . . . As your eyes refocus, you look around and find...
;phr471 You are at the northeast end of an immense room, even larger than the Giant Room. It appears to be 
;       a repository for the "Adventure" program. Massive torches far overhead bathe the room with smoky 
;       yellow light. Scattered about you can be seen a pile of bottles (all of them empty), a nursery of 
;       young beanstalks murmuring quietly, a bed of oysters, a bundle of black rods with rusty stars on 
;       their ends, and a collection of brass lanterns. Off to one side a great many dwarves are sleeping 
;       on the floor, snoring loudly. A sign nearby reads: "Do not disturb the dwarves!" An immense mirror 
;       is hanging against one wall, and stretches to the other end of the room, where various other 
;       sundry objects can be glimpsed dimly in the distance.$
;phr472 You are at the southwest end of the Repository. To one side is a pit full of fierce green snakes. 
;       On the other side is a row of small wicker cages, each of which contains a little sulking bird. In 
;       one corner is a bundle of black rods with rusty marks on their ends. A large number of velvet 
;       pillows are scattered about on the floor. A vast mirror stretches off to the northeast. At your 
;       feet is a large steel grate, next to which is a sign which reads, "Treasure Vault. Keys in Main 
;       Office." The grate is locked.$
;phr473 You're at NE end.$
;phr474 You're at SW end. The grate is locked.$
;phr475 There is a loud explosion, and a twenty-foot hole appears in the far wall, burying the dwarves in 
;       the rubble. You go through the hole and find yourself in the Main Office, where a cheering band 
;       of friendly elves carry the conquering adventurer off into the sunset.$
;phr476 I see no dynamite here.$
;phr477 I see no grate here.$
;phr478 I see nothing to unlock here.$
;phr479 The little bird attacks the green dragon, and in an astounding flurry gets burned to a cinder.  The ashes blow away.$
;phr480 There are rare spices here!$
;phr481 Rare spices$
;phr482 To where?$
;phr483 The bear is locked to the wall with a golden chain.$
;phr484 There is no way to get past the bear to unlock the chain, which is probably just as well.$
;phr485 There is a ferocious cave bear eying you from the far end of the room!$
;phr486 There is a contented-looking bear wandering about nearby.$
;phr487 For mistakes, the Delete key erases the entire line. / is a backspace key.$
;
;Unused stuff
;phr257 You can't carry anything more. You'll have to drop something first.$
;sent257:	dw	word68,word447,word875,word876,word877,word878,word104,word61,word15,word879,word880,0
;The bear eagarly wolfs down your food, after which he seems to calm down considerably and even becomes rather friendly.
;Just as you reach the other side, the bridge buckles beneath the weight of the bear, which was still following you around.  You scrabble desperately for support, but as the bridge collapses you stumble back and fall into the chasm.
;phr424 Go get a magazine first.$ 


