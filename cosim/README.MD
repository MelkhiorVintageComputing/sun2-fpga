For the cosimulation to work:

* recompile the [Mushahi](https://github.com/kstenerud/Musashi) Motorola 680x0 emulator with the patch in this directory. *beware* this try to compile Musashi as a 32-bits binary! It also enables the required callback for the FC signals
* in the Makefile, fix the include path to the 'cver' headers (and maybe Musashi as well)
* recompile the cosimulation object in this directory as a 32-bits shared object.

It seems [cver](https://sourceforge.net/projects/gplcver/) has issue with this project in 64-bits, so everything is run in 32-bits.
