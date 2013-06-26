
Data matching
=============


Example of code in Python and Haskell to do a standard data processing task. This is an example of the sort of code that python/perl gets used for a lot, and where Haskell is often thought of as not a good choice.

The code takes the input given, which represents login and logout times and matches up logins/logouts to print a list of sessions.

As the data is rubbish, the code has to deal with missing logins and/or logouts at any point.

This is just example code to show how the algorithm looks in both languages.

The implementation isn't the same: the Python version is written in an imperative style (though with use of itertools and map) as a) this is how I wrote it to start with and b) I think it'd more idiomatic that way.

Variable/function names etc use the conventions for each language:

* Haskell: short variable (x, y, l etc), CamelCase
* Python: long_variable_names

Compilation
===========

Install the Haskell Platform (http://www.haskell.org/platform/)
```
$ cabal install -j errors
$ ghc -O2 format_seclist.hs
```
