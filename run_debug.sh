#!/bin/sh
set -xe
# odin run src/tools -- -disk
rm cloud_noise && echo 1
odin build src -debug
./src.bin
# gf2 ./src.bin
