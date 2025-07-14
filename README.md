# My-CPM-Adventure-Game
Written in 8080 assembly language, this 350 point Colossal Cave Adventure runs on CPM with 32KB RAM
My Colossal Cave Virtual Adventure

I have always been intrigued by the 1970’s master-stroke of computing, the “Adventure” game, based on the work of Will Crowther and Don Woods.  Ever since my first exposure to the program on a CP/M machine, I have marveled at the creativity of the words.  More importantly, I wondered how the many clever program features worked.

The internet is rich with versions of the program, walkthroughs, maps and even the original source code, written in FORTRAN.  While I was able to peruse every room and puzzle with the analysis of many, none of the postings covered my question…how did this fantasy world work?  Reading the source code was very frustrating…so I gathered a few walkthroughs and maps.  I found an assembler and a CP/M emulator for Windows.  I pulled my Dynabyte DB/8 CP/M machine out of the attic and repaired the memory board.  In that same attic, I brought out a CRT terminal that I designed long ago.  I repaired it as well. (an extensive story in itself).   I then proceeded to write an Adventure program in 8080 assembler, as true as practical to the walkthroughs for the 350 point versions.

I’m sure to lose most of the readers right here.  Why on earth would anyone be interested in re-writing 37 year old software on a 30 year old machine when so many ready-to-run copies exist in cyberspace for free?

I do have some reasons, most of them dating back to that special era when personal computers were emerging.

Like most engineers, I really want to understand how things work on the inside, particularly things that spark my imagination and motivate me to learn, like Adventure.  This wasn’t working for me with the Adventure source code I could find; there just weren’t enough comments and my FORTRAN experience from decades ago was too limited.
I have fond 1980’s memories of playing Adventure on the (just retrieved from the attic) Dynabyte CP/M system with friends.  The Adventure program I had was implemented with code that opened data files on the disk with every user input.  The floppy disks were slow and the head went clunk at the beginning of each access.  This made progress through the game slow and frustrating.  The head clunking was too noisy to play late into the night with others sleeping nearby. Envision young engineers in the picture here; we always stayed up late and the others in the house went to bed earlier.
In the modern era, we write programs or components that are a part of a far larger compilation, with all sorts of dependencies, abstractions and learning curves.  Programming in assembler on a CP/M machine offers complete control and knowledge of the machine.  You own and control everything, which feels good.
In the 1980’s I never actually won the game.  If I wrote my own version, I would know exactly how to win, albeit decades later.
The Goals of My Adventure

The first goal was to implement the game such that it ran totally within memory.  After the program load, I wanted to run without the painful disk access delay.  Furthermore, these are very old disks.  I’m not sure how much abuse they can take.  

The second goal was to follow the available maps and walkthroughs for a reasonably true experience.  I had to draw clues from multiple sources as there was no one comprehensive description of the entire game.  The most daunting research was with respect to the puzzle solutions at the end of the game.

A third goal was to add my own creativity to provide full access to the game environment without sacrificing the feel of the game.  This goal became the addition of a few commands not found in any other Adventure versions.  My new commands gave me free access to everything for debugging puzzles and cave areas.  For example, I added support for “get all” and “drop all” so I didn’t have to type many commands for many objects in one room.  To protect the puzzles in the game, the “all” commands have the same perils as the explicit equivalent commands.  If the player has the vase and “drop all” is used, there needs to be a pillow in the room.

My Steps to Adventure

My review of the Adventure data files from the Internet inspired me to imagine big memory problems.  The smallest data file was twice the size of the 64 kilobytes of physical memory.  From the walkthroughs and maps, I found about 125 “rooms” in the cave; I knew there were two versions of the room descriptions, one used for the first “visit” and abbreviated versions for subsequent visits.  I was also aware of many strings for the “events” in the game.  Stripping authentic strings out of some data files I found in several copies of “350” point adventure games,  I found more than 36 kilobytes of strings.  Using a simple, lossless sentence player scheme that eliminated the storage of duplicate words, the entire program and data now fits into a single executable that is less than 32,768 bytes in size. 

I imagined for a while that I might be able to compress that text down to run all in memory on a CP/M machine with 32 kilobytes of physical ram.  In the end, I had to settle for the next size of CP/M, 48 kilobytes, as there has to be room for the roughly 4 kilobytes of BIOS code.  My Dynabyte computer has 64 kilobytes of memory and disks that hold 160 kilobytes, so this project had a future without constant disk access.

In the old machines, the compression issue is significant.  I wrote the routines I needed in 8080 assembler and I ended up with about 8.5 kilobytes of code.  Breaking down all of the sentences into words and indexing them shrank my 36 kilobytes of sentences into 23 kilobytes of words and indexes.  As a bonus, my 32 kilobyte program takes far less precious disk space as well.
