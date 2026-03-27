#!/bin/sh
set -xe
# odin run src/tools -- -disk
odin build src -debug
gf2 ./src.bin
