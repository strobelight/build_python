# build\_python

**doit.sh** clones the python source, checks out the latest tag from the latest branch other than main/master, runs the configure script, runs make, checks if all modules built, runs install, and removes the source.

There are some optional modules, that you most likely want, so hence the check for all optional modules to be built. If you get the error, figure out what devel headers/libraries are missing, install them, and try again. *Each OS distribution names them differently, some -dev some -devel, or even obscure ones you'd never think you needed.*


