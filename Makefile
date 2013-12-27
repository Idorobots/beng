# Defaults to DMD >= 2.064. Change the extension to ".gdc" to use GDC >= 4.8.2 instead.

DEFAULT=Makefile.dmd

default:
	$(MAKE) -f $(DEFAULT)

.PHONY: clean

clean:
	$(MAKE) clean -f $(DEFAULT)
