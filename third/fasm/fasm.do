redo-ifchange source/Linux/x64/fasm.asm
grep include source/Linux/x64/fasm.asm | awk '{print $2}' | sed 's/\\/\//'g | while read -r line; do
  echo "source/Linux/x64/$line";
done | xargs redo-ifchange

# flat assembler (fasm) is written in fasm, so it can only be built
# using an existing fasm. Unfortunately, there is no bootstrap
# toolchain.
#
# As a result, I have to cheat a improvise here and use the prebuilt
# "fasm.x64" from the upstream package to build our own fasm.
#
# Yes, this is a bit annoying.
if [ -x ./fasm ]; then
  ./fasm source/Linux/x64/fasm.asm "$3" >&2
elif [ -x ./fasm.x64 ]; then
  ./fasm.x64 source/Linux/x64/fasm.asm "$3" >&2
else
  printf "was not able build fasm from self-host" >&2
  exit 1
fi

# vim: ft=sh:
