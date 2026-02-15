#!/bin/sh
set -xe
odin build src -debug
gf2 ./src.bin
