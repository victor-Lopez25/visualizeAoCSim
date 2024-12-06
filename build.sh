#!/bin/bash

opts='-debug -vet -vet-using-param'
releaseopts='-no-bounds-check -no-type-assert -o:speed'

odin run . $releaseopts