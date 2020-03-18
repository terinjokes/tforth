# tforth

A work-in-progress (and currently broken) FORTH for x86_64 Linux systems, based
on jombloforth, which is based on the jonesforth tutorial.

## Assembling

tforth can be built on x86_64 Linux systems by running:

```
make
```

This project is built with redo. The `do` implementation of redo is packaged as
part of this source for systems without a redo installation. The do
implementation is minimalist and does not automatically rebuild targets. A full
redo installation will check and rebuilt modified targets and their
dependencies.

## Running

```
./out/tforth
```

The interpreter runs, but many words are not properly or completely implemented.


## License
UNLICENSE. See UNLICENSE.txt
