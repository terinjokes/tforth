default: all

build:
	+if type redo >/dev/null 2>&1; then redo; else ./third/do/do -c; fi

all:
	+if type redo >/dev/null 2>&1; then redo; else ./third/do/do -c; fi

clean:
	+if type redo >/dev/null 2>&1; then redo clean; else ./third/do/do -c clean; fi

.PHONY: build all clean
