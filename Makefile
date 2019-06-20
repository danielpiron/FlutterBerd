srcdir=src

flutter.nes: gfx.o flutter.o nes.cfg
	ld65 -o flutter.nes -C nes.cfg flutter.o gfx.o

flutter.o: $(srcdir)/flutter.s
	ca65 $(srcdir)/flutter.s -o flutter.o

gfx.o: $(srcdir)/gfx.s $(srcdir)/pipe.inc $(srcdir)/bird.inc $(srcdir)/deadbird.inc $(srcdir)/digits.inc
	ca65 $(srcdir)/gfx.s -o gfx.o

$(srcdir)/pipe.inc: assets/FlutterBerd-Pipe.piskel scripts/nesdata.py
	scripts/nesdata.py assets/FlutterBerd-Pipe.piskel $(srcdir)/pipe.inc

$(srcdir)/bird.inc: assets/FlutterBerd-FlappingAnim.piskel scripts/nesdata.py
	scripts/nesdata.py assets/FlutterBerd-FlappingAnim.piskel $(srcdir)/bird.inc

$(srcdir)/deadbird.inc: assets/FlutterBerd-DeathAnim.piskel scripts/nesdata.py
	scripts/nesdata.py assets/FlutterBerd-DeathAnim.piskel $(srcdir)/deadbird.inc

$(srcdir)/digits.inc: assets/FlutterBerd-Numerals.piskel scripts/nesdata.py
	scripts/nesdata.py assets/FlutterBerd-Numerals.piskel $(srcdir)/digits.inc

.PHONY: clean

clean:
	rm *.o *.nes
