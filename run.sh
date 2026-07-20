#!/bin/sh
set -xe
i3-msg "workspace number 2"; cd /home/arch/data/diver && odin run src -keep-executable
# odin run src/tools -keep-executable
# odin build src
