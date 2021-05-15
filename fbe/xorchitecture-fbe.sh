#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
gcc fbe.c -lSDL2 -O2 -o fbe
dd if=/dev/zero of=/tmp/fb0 bs=1 count=3145728 2>/dev/null
./fbe&
./xorchitecture
