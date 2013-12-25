# Defaults to DMD >= 2.062. Change the extension to ".gdc" to use GDC >= 4.7.1 instead.

DEFAULT=Makefile.dmd

default:
	$(MAKE) -f $(DEFAULT)

.PHONY: clean

clean:
	$(MAKE) clean -f $(DEFAULT)
