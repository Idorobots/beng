# Defaults to GDC. Change the extension to ".dmd" to use DMD instead.

DEFAULT=Makefile.gdc

default:
	$(MAKE) -f $(DEFAULT)

.PHONY: clean

clean:
	$(MAKE) clean -f $(DEFAULT)
