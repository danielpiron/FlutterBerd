srcdir=src

flutter.nes: flutter.o nes.cfg
	ld65 -o flutter.nes -C nes.cfg flutter.o

flutter.o: $(srcdir)/flutter.s
	ca65 $(srcdir)/flutter.s -o flutter.o

.PHONY: clean

clean:
	rm *.o *.nes
