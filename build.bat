@echo off

set opts=-debug -vet -vet-using-param
set releaseopts=-no-bounds-check -no-type-assert -o:speed

odin build %cd% %releaseopts%
visualizeAoCSim.exe