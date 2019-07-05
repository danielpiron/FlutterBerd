srcdir=src

flutter.nes: flutter.o chr0.o chr1.o nes.cfg
	ld65 -o flutter.nes -C nes.cfg flutter.o chr0.o chr1.o

flutter.o: $(srcdir)/flutter.s
	ca65 $(srcdir)/flutter.s -o flutter.o

chr0.o: $(srcdir)/chr0.s
	ca65 $(srcdir)/chr0.s -o chr0.o

chr1.o: $(srcdir)/chr1.s
	ca65 $(srcdir)/chr1.s -o chr1.o

$(srcdir)/chr0.s: assets/FlutterBerd-FlappingAnim.piskel assets/FlutterBerd-DeathAnim.piskel assets/FlutterBerd-Numerals.piskel
	scripts/nesdata.py assets/FlutterBerd-FlappingAnim.piskel assets/FlutterBerd-DeathAnim.piskel assets/FlutterBerd-Numerals.piskel --segment CHR0 > $(srcdir)/chr0.s

$(srcdir)/chr1.s: assets/FlutterBerd-Pipe.piskel assets/FlutterBerd-TitleScreen.piskel
	scripts/nesdata.py assets/FlutterBerd-Pipe.piskel assets/FlutterBerd-TitleScreen.piskel --segment CHR1 > $(srcdir)/chr1.s

.PHONY: clean

clean:
	rm *.o *.nes
