# A "virtual" target that encompasses both the binary output and the built
# symbols.
redo-ifchange tforth.S ../third/fasm/fasm
grep include tforth.S | awk '{print $2}' | xargs redo-ifchange

tmp=".$2.tmp"
rm -rf "$tmp"
mkdir -p "$tmp"

../third/fasm/fasm -s "$tmp/$2.sym" tforth.S "$tmp/$2" >&2

redo-ifchange "$tmp/$2" "$tmp/$2.sym"

# vim: ft=sh:
