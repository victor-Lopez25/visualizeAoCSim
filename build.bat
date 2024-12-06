@echo off

set opts=-debug -vet -vet-using-param

odin build %cd% %opts%
day6visualize.exe