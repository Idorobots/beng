# Defaults to GDC. Change the extension to ".dmd" to use DMD instead.

DEFAULT=Makefile.dmd

default:
	$(MAKE) -f $(DEFAULT)

.PHONY: clean

clean:
	$(MAKE) clean -f $(DEFAULT)
