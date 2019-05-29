srcdir=src

flutter.nes: flutter.o nes.cfg
	ld65 -o flutter.nes -C nes.cfg flutter.o

flutter.o: $(srcdir)/flutter.s $(srcdir)/pipe.inc
	ca65 $(srcdir)/flutter.s -o flutter.o

$(srcdir)/pipe.inc: assets/FlutterBerd-Pipe.piskel scripts/nesdata.py
	scripts/nesdata.py assets/FlutterBerd-Pipe.piskel $(srcdir)/pipe.inc

.PHONY: clean

clean:
	rm *.o *.nes
